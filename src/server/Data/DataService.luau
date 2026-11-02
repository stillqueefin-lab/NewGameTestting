-- Session-locked profile saves (from Grow a Golem; see vault "Data Saving and Session Locking").
-- UpdateAsync lease per player, token-checked saves, idempotent purchase receipts.
local SharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("SFTBShared")
local ServerRoot = game:GetService("ServerScriptService"):WaitForChild("SFTBServer")

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(SharedRoot:WaitForChild("Config"))
local Schema = require(ServerRoot:WaitForChild("Data"):WaitForChild("ProfileSchema"))
local StateChanged = ReplicatedStorage:WaitForChild("SFTBRemotes"):WaitForChild("StateChanged")
local DataService = {}
local profiles, sessions, pendingPush = {}, {}, {}
local storeName = Config.Data.StoreName
if RunService:IsStudio() and not Config.Data.StudioUsesLiveData then
	storeName ..= "_Studio"
end
local store
local function getStore()
	-- API Services may be off (unpublished place); the caller's pcall turns this into a temporary profile.
	store = store or DataStoreService:GetDataStore(storeName)
	return store
end

local function stopSession(player, session, message)
	session.CanSave, session.Closing = false, true
	player:SetAttribute("SessionClosing", true)
	if player.Parent then
		task.defer(function()
			player:Kick(message)
		end)
	end
end

function DataService.Load(player)
	if sessions[player] then
		return profiles[player]
	end
	local id = HttpService:GenerateGUID(false)
	local session = { Id = id, CanSave = false, LastSuccess = os.time(), Sequence = 0 }
	sessions[player] = session
	local acquired, result, lastError, locked, invalid = false, nil, nil, false, false
	for attempt = 1, 5 do
		locked, invalid = false, false
		local ok, value = pcall(function()
			return getStore():UpdateAsync("u_" .. player.UserId, function(previous, keyInfo)
				if previous ~= nil and type(previous) ~= "table" then
					invalid = true
					return nil
				end
				if previous and (tonumber(previous.Version) or 0) > Config.Data.ProfileVersion then
					invalid = true
					return nil
				end
				local lease = previous and previous._Session
				if
					type(lease) == "table"
					and lease.Id ~= id
					and (tonumber(lease.Expires) or 0) > os.time()
				then
					locked = true
					return nil
				end
				local nextData = Schema.Copy(previous or {})
				nextData._Session =
					{ Id = id, Expires = os.time() + Config.Data.SessionLeaseSeconds }
				return nextData,
					keyInfo and keyInfo:GetUserIds() or { player.UserId },
					keyInfo and keyInfo:GetMetadata() or {}
			end)
		end)
		if ok and type(value) == "table" and value._Session and value._Session.Id == id then
			acquired, result = true, value
			break
		end
		lastError = ok and (locked and "profile still in use" or "invalid profile") or value
		if invalid or not player.Parent then
			break
		end
		if attempt < 5 then
			task.wait(math.min(attempt, 2))
		end
	end
	if not acquired then
		if not RunService:IsStudio() then
			warn("[SFTB] Profile not loaded: " .. tostring(lastError))
			sessions[player] = nil
			return nil
		end
		-- Studio (unpublished place, API Services off, or a leftover lease): use an
		-- isolated, non-saving test profile instead of kicking or overwriting.
		result = nil
		session.CanSave, session.Temporary = false, true
		print(
			"[SFTB] Studio profile unavailable ("
				.. tostring(lastError)
				.. "); using a temporary test profile that won't save."
		)
	else
		session.CanSave, session.Temporary = true, false
	end
	sessions[player] = session -- A player may leave while the load request is yielding.
	local raw
	if result then
		for key in pairs(result) do
			if key ~= "_Session" and key ~= "_SaveToken" then
				raw = result
				break
			end
		end
	end
	local data, offline = Schema.Normalize(raw, os.time())
	data._Session, data._SaveToken = nil, nil
	profiles[player] = data
	session.PersistedReceipts = Schema.Copy(data.PurchaseReceipts)
	session.Offline, session.LastSuccess = offline, os.time()
	return data
end

function DataService.Get(player)
	local session = sessions[player]
	if not session or session.Closing then
		return nil
	end
	if
		session.CanSave
		and os.time() - session.LastSuccess >= Config.Data.SessionLeaseSeconds - 5
	then
		stopSession(
			player,
			session,
			"Your save connection timed out. Please rejoin to protect your progress."
		)
		return nil
	end
	return profiles[player]
end

function DataService.GetClientState(player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = {}
	for _, key in ipairs({ "Hatchlings", "Incubators", "CrewLevel", "Escapes" }) do
		state[key] = Schema.Copy(data[key])
	end
	local session = sessions[player]
	session.Revision = (session.Revision or 0) + 1
	state.Revision = session.Revision
	state.ServerNow = os.time()
	state.Offline = Schema.Copy(session.Offline)
	state.TemporarySession = session.Temporary
	return state
end

function DataService.CanPurchase(player)
	local session = sessions[player]
	return DataService.Get(player) ~= nil
		and session.CanSave
		and not session.Temporary
		and not session.Closing
end

function DataService.CommitPurchase(player, purchaseId, grant)
	if type(purchaseId) ~= "string" or #purchaseId == 0 or #purchaseId > 160 then
		return false
	end
	local session = sessions[player]
	local data = DataService.Get(player)
	if not data or not DataService.CanPurchase(player) then
		return false
	end
	if session.PersistedReceipts[purchaseId] == true then
		return true
	end
	if data.PurchaseReceipts[purchaseId] ~= true then
		-- Grant and receipt marker are one non-yielding mutation, persisted in the same write.
		local granted = grant(data)
		if not granted then
			return false
		end
		data.PurchaseReceipts[purchaseId] = true
	end
	DataService.Save(player)
	if session.PersistedReceipts[purchaseId] ~= true then
		return false
	end
	DataService.Push(player)
	return true
end

function DataService.Push(player)
	if pendingPush[player] or not profiles[player] then
		return
	end
	pendingPush[player] = true
	task.delay(0.10, function()
		pendingPush[player] = nil
		if player.Parent then
			local state = DataService.GetClientState(player)
			if state then
				StateChanged:FireClient(player, state)
			end
		end
	end)
end

function DataService.Save(player, release)
	local data, session = profiles[player], sessions[player]
	if not data or not session or session.Released then
		return true
	end
	if not session.CanSave then
		return session.Temporary == true
	end
	local deadline = os.clock() + 20
	while session.Saving and os.clock() < deadline do
		task.wait(0.05)
	end
	if session.Saving then
		return false
	end
	if session.Released or (session.Closing and not release) then
		return true
	end
	session.Saving = true
	session.Sequence += 1
	local token = session.Id .. ":" .. session.Sequence
	local snapshot = Schema.Copy(data)
	snapshot.LastSeen, snapshot._SaveToken = os.time(), token
	local success, lost = false, false
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return getStore():UpdateAsync("u_" .. player.UserId, function(previous, keyInfo)
				if type(previous) ~= "table" then
					lost = true
					return nil
				end
				-- A final write may succeed even if the response was lost.
				if release and previous._SaveToken == token then
					return previous,
						keyInfo and keyInfo:GetUserIds() or { player.UserId },
						keyInfo and keyInfo:GetMetadata() or {}
				end
				if type(previous._Session) ~= "table" or previous._Session.Id ~= session.Id then
					lost = true
					return nil
				end
				local nextData = Schema.Copy(snapshot)
				if release then
					nextData._Session = nil
				else
					nextData._Session =
						{ Id = session.Id, Expires = os.time() + Config.Data.SessionLeaseSeconds }
				end
				return nextData,
					keyInfo and keyInfo:GetUserIds() or { player.UserId },
					keyInfo and keyInfo:GetMetadata() or {}
			end)
		end)
		if ok and type(result) == "table" and result._SaveToken == token then
			success = true
			break
		end
		if lost then
			break
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	session.Saving = false
	if success then
		session.LastSuccess = os.time()
		session.PersistedReceipts = Schema.Copy(snapshot.PurchaseReceipts)
		if release then
			session.Released = true
		end
	elseif lost then
		stopSession(player, session, "Your profile moved to another server. Please rejoin.")
	else
		warn("[SFTB] Save failed for user " .. player.UserId .. "; retrying on the next save.")
	end
	return success
end

function DataService.Release(player)
	local session = sessions[player]
	if not session then
		return true
	end
	session.Closing = true
	player:SetAttribute("SessionClosing", true)
	return DataService.Save(player, true)
end

function DataService.Unload(player)
	profiles[player], sessions[player], pendingPush[player] = nil, nil, nil
end

function DataService.SaveAll(players, release)
	local pending = 0
	for _, player in ipairs(players) do
		pending += 1
		task.spawn(function()
			local ok, err = pcall(function()
				if release then
					DataService.Release(player)
				else
					DataService.Save(player)
				end
			end)
			if not ok then
				warn("[SFTB] Save worker: " .. tostring(err))
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end
return DataService
