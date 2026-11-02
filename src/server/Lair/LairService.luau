--!strict
-- Stage 7: runs and lair copies. A crew from a camp pad gets its own lair built far from camp
-- (LairBuilder), with its own Hush and eggs. Caught players come back at their lair's mouth.
-- Walking out of the mouth without an egg takes you back to camp; escaping with one hatches
-- it (EggService > HatchService). A lair is cleaned up once nobody from its crew is left in it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local LairBuilder = require(script.Parent:WaitForChild("LairBuilder"))

local Cr = Config.Crews
local Camp = Config.Camp

type Run = {
	Lair: Model,
	Hush: any,
	Spawn: CFrame,
	EscapeZ: number,
	Slot: number,
	Members: { [Player]: boolean },
}

local LairService = {}

local runs: { [Player]: Run } = {}
local slots: { [number]: Run } = {}
local hushService: any
local eggService: any
local hatchService: any

local function atCamp(pos: Vector3): boolean
	return (Vector3.new(pos.X, 0, pos.Z) - Camp.Centre).Magnitude <= Camp.Radius
end

local function leave(player: Player, run: Run)
	run.Members[player] = nil
	runs[player] = nil
	player:SetAttribute("SFTB_InRun", nil)
end

local function cleanup(run: Run)
	slots[run.Slot] = nil
	eggService.RemoveLair(run.Lair)
	if run.Hush then
		run.Hush.Destroy()
	end
	run.Lair:Destroy()
end

local function toSpawn(player: Player, run: Run, index: number)
	local character = player.Character
	if not character then
		return
	end
	pcall(player.RequestStreamAroundAsync, player, run.Spawn.Position)
	character:PivotTo(run.Spawn * CFrame.new((index - 1) * 3 - 4.5, 0, 0))
end

-- Start a run for up to MaxCrew players. Returns false if every lair slot is busy.
-- spawnAt "NestDoor" starts inside the nest door (Stage 10 onboarding) instead of the mouth.
function LairService.StartRun(players: { Player }, spawnAt: string?): boolean
	local slot = nil
	for i = 1, Cr.MaxLairs do
		if not slots[i] then
			slot = i
			break
		end
	end
	if not slot then
		return false
	end
	local origin = Vector3.new(Cr.LairFirstX + (slot - 1) * Cr.LairSpacing, 0, 0)
	-- Stage 9: a shuffled layout; rebuild if it ever fails the fairness check.
	local lair, spawn = LairBuilder.Build(origin, math.random(1, 1e6))
	for _ = 1, 5 do
		local fair, why = LairBuilder.Fair(lair)
		if fair then
			break
		end
		warn("[SFTB] Unfair layout (" .. why .. "): " .. tostring(lair:GetAttribute("Layout")))
		lair:Destroy()
		lair, spawn = LairBuilder.Build(origin, math.random(1, 1e6))
	end
	local standIns = lair:FindFirstChild("ScaleStandIns")
	if standIns then
		standIns:Destroy()
	end
	lair.Name = "SFTB_Lair_" .. slot
	lair.Parent = workspace
	local hush = hushService.new(lair)
	eggService.AddLair(lair, hush)
	local run: Run = {
		Lair = lair,
		Hush = hush,
		Spawn = if spawnAt == "NestDoor"
			then lair:GetAttribute("NestDoorSpawn") :: CFrame
			else spawn,
		EscapeZ = lair:GetAttribute("EscapeZ") :: number,
		Slot = slot,
		Members = {},
	}
	slots[slot] = run
	for i, player in ipairs(players) do
		if i > Cr.MaxCrew then
			break
		end
		run.Members[player] = true
		runs[player] = run
		player:SetAttribute("SFTB_InRun", true)
		task.spawn(toSpawn, player, run, i)
	end
	return true
end

function LairService.RunOf(player: Player): Run?
	return runs[player]
end

local function check()
	for _, run in pairs(slots) do
		for player in pairs(run.Members) do
			local character = player.Character
			local pos = character and character:GetPivot().Position
			-- Left the game, or escaped with an egg (HatchService took them to camp).
			if not player.Parent or (pos and atCamp(pos)) then
				leave(player, run)
			elseif pos and pos.Z > run.EscapeZ and not player:GetAttribute("SFTB_Carrying") then
				leave(player, run) -- walked out without an egg
				hatchService.ToCamp(player, 1)
			end
		end
		if next(run.Members) == nil then
			cleanup(run)
		end
	end
end

function LairService.Start(hush: any, eggs: any, hatch: any)
	hushService, eggService, hatchService = hush, eggs, hatch
	-- The Edit preview lair isn't played in: every run builds its own copy.
	local preview = workspace:FindFirstChild("SFTB_Lair")
	if preview then
		preview:Destroy()
	end
	-- New players and anyone not in a run spawn at camp.
	local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLocation then
		spawnLocation.CFrame =
			CFrame.lookAt(Camp.Spawn, Vector3.new(Camp.Centre.X, Camp.Spawn.Y, Camp.Centre.Z))
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local run = runs[player]
			if run then
				-- Caught: back at your lair's mouth, still in the run.
				character:WaitForChild("HumanoidRootPart", 5)
				task.wait()
				toSpawn(player, run, 1)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	task.spawn(function()
		while true do
			task.wait(Cr.CheckSeconds)
			check()
		end
	end)
end

return LairService
