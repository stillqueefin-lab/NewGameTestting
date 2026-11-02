--!strict
-- Stage 10: pings. A client asks for a ping of a kind where it aims; the server checks it
-- (Action Guard, kind, finite position, range), snaps Egg pings to a nearby egg, puts Help on
-- the player, and shows it to their crew and anyone close by.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local Guard = require(
	ServerScriptService:WaitForChild("SFTBServer")
		:WaitForChild("Infrastructure")
		:WaitForChild("ActionGuard")
)
local remotes = ReplicatedStorage:WaitForChild("SFTBRemotes")
local Ping = remotes:WaitForChild("Ping") :: RemoteEvent
local PingShow = remotes:WaitForChild("PingShow") :: RemoteEvent

local P = Config.Pings

local PingService = {}

local kinds: { [string]: boolean } = {}
for _, kind in ipairs(P.Kinds) do
	kinds[kind] = true
end

local lairService: any

local function onPing(player: Player, kind: unknown, aim: unknown)
	if not Guard.Allow(player, "Ping", P.Interval) or not Guard.Alive(player) then
		return
	end
	if type(kind) ~= "string" or not kinds[kind] or typeof(aim) ~= "Vector3" then
		return
	end
	local target = aim :: Vector3
	if
		not Guard.Number(target.X, -1e6, 1e6)
		or not Guard.Number(target.Y, -1e6, 1e6)
		or not Guard.Number(target.Z, -1e6, 1e6)
	then
		return
	end
	local from = (player.Character :: Model):GetPivot().Position
	if kind == "Help" then
		target = from - Vector3.new(0, 3, 0)
	elseif (target - from).Magnitude > P.Range then
		target = from + (target - from).Unit * P.Range
	end
	if kind == "Egg" then
		local best, bestD = nil, P.EggSnap
		for _, egg in ipairs(CollectionService:GetTagged("SFTB_Egg")) do
			if egg:IsA("BasePart") and egg:IsDescendantOf(workspace) then
				local d = (egg.Position - target).Magnitude
				if d <= bestD then
					best, bestD = egg, d
				end
			end
		end
		if best then
			target = best.Position
		end
	end
	local run = lairService.RunOf(player)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local crew = run ~= nil and run.Members[other] == true
		if
			crew
			or (character and (character:GetPivot().Position - from).Magnitude <= P.ShareRadius)
		then
			PingShow:FireClient(other, player.UserId, kind, target)
		end
	end
end

function PingService.Start(lairs: any)
	lairService = lairs
	Ping.OnServerEvent:Connect(onPing)
end

return PingService
