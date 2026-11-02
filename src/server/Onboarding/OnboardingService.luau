--!strict
-- Stage 10: the first two minutes (kickoff). A brand-new player (no hatchlings, first run not
-- done) skips camp: a solo run starts right away, spawning just inside the nest door with the
-- sleeping Hush and the egg in view. One objective line at a time (player attribute
-- SFTB_Objective, shown by the client), and each step goes to the Analytics onboarding funnel.
-- Steps are read off attributes other systems already set, so nothing else depends on this.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local DataService = require(
	ServerScriptService:WaitForChild("SFTBServer"):WaitForChild("Data"):WaitForChild("DataService")
)

local O = Config.Onboarding

type Progress = {
	Step: number,
	Hatchlings: number,
	Runs: number,
	WasInRun: boolean,
	HintAt: number?,
	LeftAt: number?,
}

local OnboardingService = {}

local progress: { [Player]: Progress } = {}
local lairService: any

local function funnel(player: Player, step: number)
	pcall(
		AnalyticsService.LogOnboardingFunnelStepEvent,
		AnalyticsService,
		player,
		step,
		O.Funnel[step]
	)
end

local function objective(player: Player, key: string?)
	player:SetAttribute("SFTB_Objective", if key then O.Objective[key] else nil)
end

-- Advance a player to a funnel step (each step logs once, in order).
local function reach(player: Player, p: Progress, step: number)
	while p.Step < step do
		p.Step += 1
		funnel(player, p.Step)
	end
end

local function update(player: Player, p: Progress)
	local now = os.clock()
	local inRun = player:GetAttribute("SFTB_InRun") == true
	local hatchlings = player:GetAttribute("SFTB_HatchlingCount") :: number? or 0
	if inRun and not p.WasInRun then
		p.Runs += 1
		if p.Runs >= 2 then
			reach(player, p, 7) -- started a crew run: onboarding done
			objective(player, nil)
			progress[player] = nil
			return
		end
	end
	if p.WasInRun and not inRun then
		p.LeftAt = now
	end
	p.WasInRun = inRun
	if p.Step < 2 and player:GetAttribute("SFTB_Carrying") then
		reach(player, p, 2)
		objective(player, "GetOut")
	end
	if p.Step < 4 and hatchlings > p.Hatchlings then
		reach(player, p, 4) -- escaped and hatched
		objective(player, "Listen")
	elseif
		p.Step < 4
		and not inRun
		and p.LeftAt
		and now - p.LeftAt > Config.Hatch.RevealSeconds + 1 -- not just hatching
	then
		objective(player, "Crew") -- left without an egg: the pads take you back in
	end
	if p.Step == 4 and player:GetAttribute("SFTB_PowerReadyAt") then
		reach(player, p, 5)
		p.HintAt = now + O.CrewHintDelay
	end
	if p.Step == 5 and p.HintAt and now >= p.HintAt then
		reach(player, p, 6)
		objective(player, "Crew")
		task.delay(O.ObjectiveSeconds, function()
			if player.Parent and progress[player] == p then
				objective(player, nil)
			end
		end)
	end
end

-- Call after a profile loads (Bootstrap). Only brand-new players are onboarded.
function OnboardingService.Loaded(player: Player)
	local data = DataService.Get(player)
	if data and (#data.Hatchlings > 0 or data.FirstRunDone) then
		return
	end
	local p: Progress = { Step = 0, Hatchlings = 0, Runs = 0, WasInRun = false }
	progress[player] = p
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	if lairService.StartRun({ player }, "NestDoor") then
		reach(player, p, 1)
		objective(player, "Grab")
	end
end

function OnboardingService.Start(lairs: any)
	lairService = lairs
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, p in pairs(progress) do
				update(player, p)
			end
		end
	end)
end

return OnboardingService
