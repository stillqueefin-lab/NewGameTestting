--!strict
-- Stages 6 and 8: hatching, incubators and the Hushling's power. Escape with an egg and the
-- crew is taken to camp. Your very first egg hatches there and then (client reveal); later
-- eggs go into an incubator and hatch when its timer is done (absolute time, so it runs while
-- you're offline). Each carrier gets the egg. Hatchlings are saved in the profile and grow
-- with time. The Hushling's power is Listen: the Hush shows through walls for a few seconds,
-- for you and crewmates nearby; grown Hushlings Listen longer.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local ServerRoot = ServerScriptService:WaitForChild("SFTBServer")
local Guard = require(ServerRoot:WaitForChild("Infrastructure"):WaitForChild("ActionGuard"))
local DataService = require(ServerRoot:WaitForChild("Data"):WaitForChild("DataService"))
local remotes = ReplicatedStorage:WaitForChild("SFTBRemotes")
local HatchReveal = remotes:WaitForChild("HatchReveal") :: RemoteEvent
local UsePower = remotes:WaitForChild("UsePower") :: RemoteEvent
local Listen = remotes:WaitForChild("Listen") :: RemoteEvent
local Toast = remotes:WaitForChild("Toast") :: RemoteEvent

local H = Config.Hatch
local Camp = Config.Camp

local HatchService = {}

local powerReadyAt: { [Player]: number } = {}

-- Which hatchling follows you (the newest for now). Clients draw it from these attributes.
local function equip(player: Player)
	local data = DataService.Get(player)
	local list = data and data.Hatchlings
	local newest = list and list[#list]
	player:SetAttribute("SFTB_Hatchling", if type(newest) == "table" then newest.Kind else nil)
	player:SetAttribute("SFTB_HatchlingBorn", if type(newest) == "table" then newest.Born else nil)
	player:SetAttribute("SFTB_HatchlingCount", if list then #list else 0)
	player:SetAttribute("SFTB_FirstRunDone", data and data.FirstRunDone or nil)
	player:SetAttribute("SFTB_CrewLevel", data and data.CrewLevel or 1)
end

local function growth(born: number?): number
	if not born then
		return 0
	end
	return math.clamp((os.time() - born) / H.GrowSeconds, 0, 1)
end

local function slotsFor(data: any): number
	return H.FreeIncubatorSlots + (if data.CrewLevel >= H.FreeSlotLevel then 1 else 0)
end

local function clock(seconds: number): string
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- Take a player to the camp fire, spread out so a crew doesn't stack.
function HatchService.ToCamp(player: Player, index: number?)
	local character = player.Character
	if not character then
		return
	end
	local angle = (index or 0) * 1.3
	local pos = Camp.Arrive + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Camp.ArriveSpread
	character:PivotTo(CFrame.lookAt(pos, Vector3.new(Camp.Centre.X, pos.Y, Camp.Centre.Z)))
end

-- Hatch an egg for a player now (at camp). Adds a Hushling to their profile.
function HatchService.Hatch(player: Player, eggSize: string)
	local data = DataService.Get(player)
	if data then
		table.insert(data.Hatchlings, {
			Id = HttpService:GenerateGUID(false),
			Kind = "Hushling",
			FromBig = eggSize == "Big",
			Born = os.time(),
		})
		DataService.Push(player)
	end
	HatchReveal:FireClient(player, eggSize)
	task.delay(H.RevealSeconds, function()
		if player.Parent then
			equip(player)
		end
	end)
end

-- The crew got out with an egg: everyone who carried it goes to camp with one.
function HatchService.Escaped(carriers: { Player }, eggSize: string)
	for i, player in ipairs(carriers) do
		HatchService.ToCamp(player, i)
		local data = DataService.Get(player)
		if data then
			data.Escapes += 1
			data.CrewLevel = 1 + data.Escapes // H.EscapesPerLevel
			player:SetAttribute("SFTB_CrewLevel", data.CrewLevel)
		end
		if not data or #data.Hatchlings == 0 then
			HatchService.Hatch(player, eggSize) -- your first egg hatches right away
		elseif #data.Incubators < math.min(slotsFor(data), #H.IncubatorSpots) then
			local seconds = H.HatchSeconds[eggSize] or H.HatchSeconds.Small
			table.insert(data.Incubators, {
				Id = HttpService:GenerateGUID(false),
				EggSize = eggSize,
				ReadyAt = os.time() + seconds,
			})
			DataService.Push(player)
			Toast:FireClient(player, H.IncubatedText:format(clock(seconds)), 4)
		else
			Toast:FireClient(player, H.FullText, 4)
			HatchService.Hatch(player, eggSize)
		end
	end
end

-- Each incubator has one shared server prompt; it hatches *your* egg in that slot if its
-- timer is done (each client hides the prompt when it has nothing ready there).
local function hatchSlot(player: Player, slot: number)
	local data = DataService.Get(player)
	local egg = data and data.Incubators[slot]
	if not egg then
		return
	end
	if os.time() >= egg.ReadyAt then
		table.remove(data.Incubators, slot)
		HatchService.Hatch(player, egg.EggSize)
	else
		local left = egg.ReadyAt - os.time()
		Toast:FireClient(player, H.NotReadyText:format(clock(left)), 2)
	end
end

local function makePrompts()
	local folder = Instance.new("Folder")
	folder.Name = "SFTB_Incubators"
	for i, spot in ipairs(H.IncubatorSpots) do
		local anchor = Instance.new("Part")
		anchor.Name = "Incubator" .. i
		anchor.Size = Vector3.one * 2
		anchor.CFrame = CFrame.new(spot)
		anchor.Anchored = true
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
		anchor.Transparency = 1
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Hatch"
		prompt.ObjectText = "Egg"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player)
			hatchSlot(player, i)
		end)
		anchor.Parent = folder
	end
	folder.Parent = workspace
end

local function usePower(player: Player)
	if not Guard.Allow(player, "UsePower", H.UsePowerInterval) or not Guard.Alive(player) then
		return
	end
	if player:GetAttribute("SFTB_Hatchling") ~= "Hushling" then
		return
	end
	local now = os.clock()
	if now < (powerReadyAt[player] or 0) then
		return
	end
	powerReadyAt[player] = now + H.ListenCooldown
	player:SetAttribute("SFTB_PowerReadyAt", workspace:GetServerTimeNow() + H.ListenCooldown)
	local grown = growth(player:GetAttribute("SFTB_HatchlingBorn") :: number?)
	local seconds = H.ListenSeconds + (H.ListenSecondsGrown - H.ListenSeconds) * grown
	local origin = (player.Character :: Model):GetPivot().Position
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if
			character
			and (character:GetPivot().Position - origin).Magnitude <= H.ListenShareRadius
		then
			Listen:FireClient(other, seconds, player.UserId)
		end
	end
end

-- Call after a profile loads (Bootstrap).
function HatchService.Loaded(player: Player)
	equip(player)
end

-- Stage 4's first-run scripted chase happens once per player, ever.
function HatchService.FirstRunDone(player: Player)
	local data = DataService.Get(player)
	if data then
		data.FirstRunDone = true
	end
	player:SetAttribute("SFTB_FirstRunDone", true)
end

function HatchService.Start()
	UsePower.OnServerEvent:Connect(usePower)
	makePrompts()
	Players.PlayerRemoving:Connect(function(player)
		powerReadyAt[player] = nil
	end)
end

return HatchService
