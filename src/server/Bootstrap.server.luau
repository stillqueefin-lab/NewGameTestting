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
	assert(remote and remote.ClassName == spec.ClassName, "[SFTB] Missing or invalid remote: " .. spec.Name)
end

local Config = require(SharedRoot:WaitForChild("Config"))
local DataService = require(ServerRoot:WaitForChild("Data"):WaitForChild("DataService"))
local Guard = require(ServerRoot:WaitForChild("Infrastructure"):WaitForChild("ActionGuard"))

local function onPlayerAdded(player)
	if DataService.Load(player) then DataService.Push(player) end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

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
