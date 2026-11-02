--!strict
-- Stage 3: The Hush (Stage 7: one per lair copy). The server runs a cheap invisible mover (one
-- anchored root part) and the state machine; every client draws the greybox body over it
-- (Effects/HushView), as in the Creature Animation Pipeline. It hunts by sound only
-- (Senses/Hearing) and never leaves its nest (its body is far wider than the 8-stud doors).
-- States: Sleep > Stir > Alert (the warning, always before a hunt) > Hunt > Search > Return > Sleep.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local Hearing = require(script.Parent:WaitForChild("Senses"):WaitForChild("Hearing"))
local HushCaught =
	ReplicatedStorage:WaitForChild("SFTBRemotes"):WaitForChild("HushCaught") :: RemoteEvent

local H = Config.Hush
local K = Config.Lair

type Heard = { At: number, Source: string }
export type Hush = {
	Hear: (position: Vector3, radius: number, source: string, player: Player?) -> (),
	ScriptedChase: (position: Vector3) -> (),
	Destroy: () -> (),
}

local HushService = {}

-- Fires (player: Player, feet: Vector3) when any Hush swats someone (EggService drops their egg).
local caughtSignal = Instance.new("BindableEvent")
HushService.Caught = caughtSignal.Event

local caught: { [Player]: boolean } = {} -- knocked out right now (any lair)
local active: { [Hush]: boolean } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if hrp and humanoid and humanoid.Health > 0 and not caught[player] then
		return hrp, humanoid
	end
	return nil, nil
end

local function ragdoll(character: Model)
	for _, joint in ipairs(character:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Name ~= "Root" and joint.Part0 and joint.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = joint.C0
			a0.Parent = joint.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = joint.C1
			a1.Parent = joint.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0, socket.Attachment1 = a0, a1
			socket.LimitsEnabled, socket.TwistLimitsEnabled = true, true
			socket.UpperAngle, socket.TwistLowerAngle, socket.TwistUpperAngle = 60, -45, 45
			socket.Parent = joint.Part0
			joint.Enabled = false
		end
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = true
		end
	end
end

-- The stand-in becomes the look every client draws over each mover (made once).
local function makeLook(standIn: Model, home: CFrame)
	if ReplicatedStorage:FindFirstChild("SFTBHushLook") then
		return
	end
	local look = standIn:Clone()
	look:SetAttribute("Offset", home:ToObjectSpace(standIn:GetPivot()))
	for _, part in ipairs(look:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		end
	end
	look.Name = "SFTBHushLook"
	look.Parent = ReplicatedStorage
end

-- A Hush for one lair copy (built by LairBuilder). Returns nil if the lair has no stand-in.
function HushService.new(lair: Model): Hush?
	local standIn = lair:FindFirstChild("HushStandIn", true) :: Model?
	local body = standIn and standIn.PrimaryPart
	local head = standIn and standIn:FindFirstChild("Head") :: BasePart?
	if not standIn or not body or not head then
		warn("[SFTB] No HushStandIn in " .. lair:GetFullName() .. "; no Hush there.")
		return nil
	end
	local origin = lair:GetAttribute("Origin") :: Vector3? or Vector3.zero

	-- Nest bounds keep the body inside the walls.
	local nestMin, nestMax = Vector3.zero, Vector3.zero
	for _, room in ipairs(K.Rooms) do
		if room.Name == "Nest" then
			local S = K.CellSize
			local minCorner = K.Origin
				+ origin
				+ Vector3.new(room.Cell[1] * S - S / 2, 0, room.Cell[2] * S - S / 2)
			local maxCorner = minCorner + Vector3.new(room.Size[1] * S, 0, room.Size[2] * S)
			nestMin = minCorner + Vector3.new(H.NestInset, 0, H.NestInset)
			nestMax = maxCorner - Vector3.new(H.NestInset, 0, H.NestInset)
		end
	end
	local zones: { BasePart } = {}
	for _, spot in ipairs((lair:FindFirstChild("HidingSpots") or lair):GetChildren()) do
		local zone = spot:FindFirstChild("Zone")
		if zone and zone:IsA("BasePart") then
			table.insert(zones, zone)
		end
	end

	-- The invisible mover sits on the floor under the stand-in, facing where its head points.
	local floorY = body.Position.Y - body.Size.Y / 2
	local start = Vector3.new(body.Position.X, floorY + 2, body.Position.Z)
	local home = CFrame.lookAt(start, start + flat(head.Position - body.Position))
	makeLook(standIn, home)
	standIn:Destroy()

	local model = Instance.new("Model")
	model.Name = "SFTB_Hush"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- one tiny part; clients need it
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(4, 4, 4)
	root.CFrame = home
	root.Anchored = true
	root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
	root.Transparency = 1
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	local state = "Sleep"
	local stateAt = 0
	local suspicion = 0
	local lastHeardAt = 0
	local target: Vector3 = Vector3.zero
	local heardFrom: { [Player]: Heard } = {}
	local swatPlayer: Player? = nil
	local swatReadyAt = 0
	local scripted = false -- first-run scripted chase: slow and never catches
	local alive = true

	local path = PathfindingService:CreatePath({
		AgentRadius = H.PathAgentRadius,
		AgentHeight = 20,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})
	local waypoints: { Vector3 } = {}
	local wpIndex = 1
	local pathGoal: Vector3? = nil
	local bestDist = math.huge
	local bestAt = 0

	local function setState(s: string)
		if s == "Return" or s == "Sleep" then
			scripted = false
		end
		state, stateAt = s, os.clock()
		pathGoal = nil
		model:SetAttribute("State", s)
	end

	local function ears(): Vector3
		return (root.CFrame * CFrame.new(0, 0, -H.EarForward)).Position
	end

	local function clampToNest(p: Vector3): Vector3
		return Vector3.new(
			math.clamp(p.X, nestMin.X, nestMax.X),
			home.Position.Y,
			math.clamp(p.Z, nestMin.Z, nestMax.Z)
		)
	end

	local function hidden(pos: Vector3): boolean
		for _, zone in ipairs(zones) do
			local p = zone.CFrame:PointToObjectSpace(pos)
			local half = zone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
		return false
	end

	-- Turn the body toward a flat direction by at most maxTurn radians. Returns the angle left.
	local function turn(dir: Vector3, maxTurn: number): number
		local look = flat(root.CFrame.LookVector).Unit
		local want = flat(dir)
		if want.Magnitude < 0.01 then
			return 0
		end
		want = want.Unit
		local angle = math.acos(math.clamp(look:Dot(want), -1, 1))
		local newDir = want
		if angle > maxTurn then
			local side = look:Cross(want).Y
			newDir = CFrame.Angles(0, (if side < 0 then -1 else 1) * maxTurn, 0) * look
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + newDir)
		return math.max(angle - maxTurn, 0)
	end

	-- Walk toward goal along a path. Returns true when there (or stuck, which ends the walk too).
	local function follow(goal: Vector3, speed: number, dt: number): boolean
		local pos = root.Position
		local left = flat(goal - pos).Magnitude
		if left <= H.ArriveDistance then
			return true
		end
		if not pathGoal or flat(goal - pathGoal).Magnitude > 4 then
			pathGoal = goal
			bestDist, bestAt = left, os.clock()
			local ok = pcall(path.ComputeAsync, path, pos, goal)
			waypoints, wpIndex = { goal }, 1
			if ok and path.Status == Enum.PathStatus.Success then
				waypoints, wpIndex = {}, 2
				for _, wp in ipairs(path:GetWaypoints()) do
					table.insert(waypoints, wp.Position)
				end
			end
		end
		if left < bestDist - 1 then
			bestDist, bestAt = left, os.clock()
		elseif os.clock() - bestAt > H.StuckSeconds then
			return true
		end
		while
			waypoints[wpIndex + 1]
			and flat(waypoints[wpIndex] - pos).Magnitude < H.ArriveDistance
		do
			wpIndex += 1
		end
		local delta = flat((waypoints[wpIndex] or goal) - pos)
		local angleLeft = turn(delta, H.TurnSpeed * dt)
		-- A big body slows right down while it turns, so it doesn't swing wide into walls.
		local pace = speed * math.max(math.cos(math.min(angleLeft, math.pi / 2)), 0)
		local nextPos =
			clampToNest(pos + root.CFrame.LookVector * math.min(pace * dt, delta.Magnitude))
		root.CFrame = CFrame.new(nextPos) * root.CFrame.Rotation
		return false
	end

	-- A sound reached it (or someone walked into it). Every route to a hunt goes through Alert.
	local function hear(position: Vector3, source: string, player: Player?, points: number)
		local now = os.clock()
		if player then
			heardFrom[player] = { At = now, Source = source }
		end
		suspicion += points
		lastHeardAt, target = now, position
		model:SetAttribute("EarTarget", position)
		if state == "Sleep" or state == "Stir" or state == "Return" then
			if suspicion >= H.AlertThreshold then
				setState("Alert")
			elseif state == "Sleep" and suspicion >= H.StirThreshold then
				setState("Stir")
			end
		elseif state == "Search" then
			setState("Hunt") -- already awake and warned: back after the new sound
		end
	end

	local function knockOut(player: Player, reason: string)
		local hrp, humanoid = bodyOf(player)
		if not hrp or not humanoid then
			return
		end
		caught[player] = true
		heardFrom[player] = nil
		local push = flat(hrp.Position - root.Position)
		push = if push.Magnitude > 0.1 then push.Unit else root.CFrame.LookVector
		local feet = hrp.Position - Vector3.new(0, humanoid.HipHeight + hrp.Size.Y / 2, 0)
		ragdoll(player.Character :: Model)
		caughtSignal:Fire(player, feet)
		HushCaught:FireAllClients(player.UserId, feet, push, reason)
		target = hrp.Position
		setState("Search") -- it sniffs at the spot, then loses interest
		task.delay(H.CaughtSeconds, function()
			caught[player] = nil
			if player.Parent then
				player:LoadCharacter() -- LairService puts you back at your lair's mouth
			end
		end)
	end

	-- Wind-up, then the blow lands only if you're still in reach (a dodge window).
	local function swat(player: Player, reason: string)
		swatPlayer = player
		model:SetAttribute("SwatAt", workspace:GetServerTimeNow())
		task.delay(H.SwatWindup, function()
			swatPlayer = nil
			swatReadyAt = os.clock() + H.SwatCooldown
			local hrp = bodyOf(player)
			if not alive or not hrp or hidden(hrp.Position) then
				return
			end
			local dHead = flat(hrp.Position - ears()).Magnitude
			local dBody = flat(hrp.Position - root.Position).Magnitude
			if dHead <= H.SwatReach or dBody <= H.TouchRadius then
				knockOut(player, reason)
			end
		end)
	end

	-- Hunts by sound: only players it heard recently can be caught at reach; bumping into it always counts.
	local function tryCatch(now: number)
		if scripted or swatPlayer or now < swatReadyAt then
			return
		end
		local earsAt = ears()
		for _, player in ipairs(Players:GetPlayers()) do
			local hrp = bodyOf(player)
			if hrp and not hidden(hrp.Position) then
				local heard = heardFrom[player]
				local noisy = heard ~= nil and now - heard.At <= H.NoisyMemorySeconds
				local dHead = flat(hrp.Position - earsAt).Magnitude
				local dBody = flat(hrp.Position - root.Position).Magnitude
				if dBody <= H.TouchRadius then
					swat(player, if noisy and heard then heard.Source else "Touch")
					return
				elseif noisy and heard and dHead <= H.CatchRadius then
					swat(player, heard.Source)
					return
				end
			end
		end
	end

	-- Walking into a sleeping beast wakes it, like any loud noise.
	local function checkBumps()
		for _, player in ipairs(Players:GetPlayers()) do
			local hrp = bodyOf(player)
			if
				hrp
				and not hidden(hrp.Position)
				and flat(hrp.Position - root.Position).Magnitude <= H.TouchRadius
			then
				hear(hrp.Position, "Touch", player, math.max(H.AlertThreshold - suspicion, 0))
				return
			end
		end
	end

	local function update(dt: number)
		local now = os.clock()
		suspicion = math.max(suspicion - H.SuspicionDecay * dt, 0)
		local elapsed = now - stateAt
		if state == "Sleep" or state == "Stir" or state == "Return" then
			checkBumps()
		end
		if state == "Stir" then
			if now - lastHeardAt >= H.BackToSleepSeconds then
				setState("Sleep")
			end
		elseif state == "Alert" then
			turn(target - root.Position, H.AlertTurnSpeed * dt)
			if elapsed >= (if scripted then H.ScriptedAlertSeconds else H.AlertSeconds) then
				setState("Hunt")
			end
		elseif state == "Hunt" or state == "Search" then
			local victim = swatPlayer
			if victim then
				local hrp = victim.Character
					and victim.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					turn(hrp.Position - root.Position, H.AlertTurnSpeed * dt)
				end
			elseif state == "Hunt" then
				local speed = if scripted then H.ScriptedHuntSpeed else H.HuntSpeed
				if follow(clampToNest(target), speed, dt) then
					setState("Search")
				end
			elseif elapsed >= H.LoseInterestSeconds then
				suspicion = 0
				setState("Return")
			end
			tryCatch(now)
		elseif state == "Return" then
			if
				follow(home.Position, H.ReturnSpeed, dt)
				and turn(home.LookVector, H.TurnSpeed * dt) < 0.05
			then
				suspicion = 0
				setState("Sleep")
			end
		end
		model:SetAttribute("Suspicion", math.floor(suspicion * 10) / 10)
	end

	local self: Hush
	self = {
		Hear = function(position: Vector3, radius: number, source: string, player: Player?)
			local points = Hearing.Points(ears(), position, radius, source)
			if points > 0 then
				hear(position, source, player, points)
			end
		end,
		-- Stage 4: the short scripted stir and chase on a player's first run, so run 1 almost
		-- always escapes. It plays the full warning and hunt toward the spot, slower, and never catches.
		ScriptedChase = function(position: Vector3)
			if state ~= "Sleep" and state ~= "Stir" then
				return
			end
			scripted = true
			suspicion = H.AlertThreshold
			lastHeardAt, target = os.clock(), position
			model:SetAttribute("EarTarget", position)
			setState("Alert")
		end,
		Destroy = function()
			alive = false
			active[self] = nil
			model:Destroy()
		end,
	}

	model:SetAttribute("EarTarget", ears() + home.LookVector * 10)
	model.Parent = workspace
	setState("Sleep")
	active[self] = true
	task.spawn(function()
		while alive do
			update(RunService.Heartbeat:Wait())
		end
	end)
	return self
end

function HushService.Start(noiseSignal: RBXScriptSignal)
	noiseSignal:Connect(function(position: Vector3, radius: number, source: string, player: Player?)
		for hush in pairs(active) do
			hush.Hear(position, radius, source, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		caught[player] = nil
	end)
end

return HushService
