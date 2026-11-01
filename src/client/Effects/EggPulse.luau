--!strict
-- Slow loot pulse (Stage 1). Any part tagged "SFTB_Egg" gets its PointLight pulsed,
-- so eggs read by motion as well as colour. Handles streaming (eggs can arrive late).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))

local EggPulse = {}

local TAG = "SFTB_Egg"

local function pulse(egg: Instance)
	local light = egg:FindFirstChildWhichIsA("PointLight")
	if not light then
		return
	end
	local settings = Config.EggPulse
	light.Brightness = settings.MinBrightness
	local info =
		TweenInfo.new(settings.Seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(light, info, { Brightness = settings.MaxBrightness }):Play()
end

function EggPulse.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(pulse)
	for _, egg in ipairs(CollectionService:GetTagged(TAG)) do
		pulse(egg)
	end
end

return EggPulse
