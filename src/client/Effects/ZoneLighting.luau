--!strict
-- Stage 7: lighting follows where you are. Lairs are cold and foggy; camp is warm and safe
-- (style sheet: creepy in lairs, cozy at camp). Darkness comes from fog, never black surfaces.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local L = Config.Lighting
local Camp = Config.Camp

local ZoneLighting = {}

local function apply(zone: any)
	local info = TweenInfo.new(L.BlendSeconds)
	TweenService
		:Create(Lighting, info, { Ambient = zone.Ambient, OutdoorAmbient = zone.OutdoorAmbient })
		:Play()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService
			:Create(
				atmo,
				info,
				{ Density = zone.Density, Color = zone.FogColor, Decay = zone.Decay }
			)
			:Play()
	end
end

function ZoneLighting.Start()
	local player = Players.LocalPlayer
	local current: string? = nil
	task.spawn(function()
		while true do
			task.wait(0.5)
			local character = player.Character
			if character then
				local pos = character:GetPivot().Position
				local zone = if (Vector3.new(pos.X, 0, pos.Z) - Camp.Centre).Magnitude
						<= Camp.Radius
					then "Camp"
					else "Lair"
				if zone ~= current then
					current = zone
					apply(L[zone])
				end
			end
		end
	end)
end

return ZoneLighting
