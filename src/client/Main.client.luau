--!strict
-- Client entry point. One client script: wait for shared code and remotes, then start client systems.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedRoot = ReplicatedStorage:WaitForChild("SFTBShared")
local remoteFolder = ReplicatedStorage:WaitForChild("SFTBRemotes")
for _, spec in ipairs(require(SharedRoot:WaitForChild("Remotes")) :: any) do
	remoteFolder:WaitForChild(spec.Name)
end

local Effects = script.Parent:WaitForChild("Effects")
require(Effects:WaitForChild("Flashlight")).Start()
require(Effects:WaitForChild("EggPulse")).Start()

print("[SFTB] Client ready")
