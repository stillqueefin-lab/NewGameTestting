--!strict
-- Stage 6: hatching and the Hushling's power. Escape with an egg and the crew is taken to
-- camp, where the egg hatches (client reveal). Each carrier gets a Hushling, saved in the
-- profile. The Hushling's power is Listen: the Hush shows through walls for a few seconds,
-- for you and crewmates nearby. Stage 8 sends later eggs to incubators instead.
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

local H = Config.Hatch
local Camp = Config.Camp

local HatchService = {}

local powerReadyAt: { [Player]: number } = {}

-- Which hatchling follows you (the newest for now). Clients draw it from this attribute.
local function equip(player: Player)
	local data = DataService.Get(player)
	local list = data and data.Hatchlings
	local newest = list and list[#list]
	player:SetAttribute("SFTB_Hatchling", if type(newest) == "table" then newest.Kind else nil)
	player:SetAttribute("SFTB_HatchlingCount", if list then #list else 0)
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

-- The crew got out with an egg: everyone who carried it goes to camp and hatches one.
function HatchService.Escaped(carriers: { Player }, eggSize: string)
	for i, player in ipairs(carriers) do
		HatchService.ToCamp(player, i)
		HatchService.Hatch(player, eggSize)
	end
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
	local origin = (player.Character :: Model):GetPivot().Position
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if
			character
			and (character:GetPivot().Position - origin).Magnitude <= H.ListenShareRadius
		then
			Listen:FireClient(other, H.ListenSeconds, player.UserId)
		end
	end
end

-- Call after a profile loads (Bootstrap).
function HatchService.Loaded(player: Player)
	equip(player)
end

function HatchService.Start()
	UsePower.OnServerEvent:Connect(usePower)
	Players.PlayerRemoving:Connect(function(player)
		powerReadyAt[player] = nil
	end)
end

return HatchService
