-- Server entry point. One server script: assert remotes, init services, then start.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

if ServerScriptService:GetAttribute("SFTBRunning") then
	warn("[SFTB] Duplicate server ignored. Keep one SFTBServer.")
	return
end
ServerScriptService:SetAttribute("SFTBRunning", true)

local SharedRoot = ReplicatedStorage:WaitForChild("SFTBShared")
local ServerRoot = ServerScriptService:WaitForChild("SFTBServer")

-- Every remote in the Remotes list must exist with the right class, or nothing starts.
local remoteFolder = ReplicatedStorage:WaitForChild("SFTBRemotes")
for _, spec in ipairs(require(SharedRoot:WaitForChild("Remotes"))) do
	local remote = remoteFolder:FindFirstChild(spec.Name)
	assert(
		remote and remote.ClassName == spec.ClassName,
		"[SFTB] Missing or invalid remote: " .. spec.Name
	)
end

local Config = require(SharedRoot:WaitForChild("Config"))
local DataService = require(ServerRoot:WaitForChild("Data"):WaitForChild("DataService"))
local Guard = require(ServerRoot:WaitForChild("Infrastructure"):WaitForChild("ActionGuard"))
local NoiseService = require(ServerRoot:WaitForChild("Noise"):WaitForChild("NoiseService"))
local HushService = require(ServerRoot:WaitForChild("Hush"):WaitForChild("HushService"))
local EggService = require(ServerRoot:WaitForChild("Eggs"):WaitForChild("EggService"))
local HatchService = require(ServerRoot:WaitForChild("Hatch"):WaitForChild("HatchService"))
local LairService = require(ServerRoot:WaitForChild("Lair"):WaitForChild("LairService"))
local CampService = require(ServerRoot:WaitForChild("Camp"):WaitForChild("CampService"))
local PingService = require(ServerRoot:WaitForChild("Pings"):WaitForChild("PingService"))
local OnboardingService =
	require(ServerRoot:WaitForChild("Onboarding"):WaitForChild("OnboardingService"))

LairService.Start(HushService, EggService, HatchService) -- clears the Edit preview lair first
NoiseService.Start()
HushService.Start(NoiseService.Noise)
HatchService.Start()
EggService.Start(NoiseService, HatchService)
CampService.Start(LairService)
PingService.Start(LairService)
OnboardingService.Start(LairService)

local function onPlayerAdded(player)
	if DataService.Load(player) then
		DataService.Push(player)
		HatchService.Loaded(player)
		OnboardingService.Loaded(player) -- brand-new players go straight into a lair
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.Release(player)
	DataService.Unload(player)
	Guard.Cleanup(player)
end)

task.spawn(function()
	while true do
		task.wait(Config.Data.AutosaveSeconds)
		DataService.SaveAll(Players:GetPlayers(), false)
	end
end)

game:BindToClose(function()
	DataService.SaveAll(Players:GetPlayers(), true)
end)

print("[SFTB] Server ready")
