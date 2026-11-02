-- Edit-mode preview of the greybox lair (Stage 1 layout and everything added since).
-- Run in Studio's command bar (or via the Studio MCP) with Rojo connected, then save the place.
-- The geometry comes from ServerScriptService.SFTBServer.Lair.LairBuilder, the same module every
-- run uses for its own lair copy (Stage 7), so this preview always matches play. At run time
-- the preview is removed and each crew gets a copy far from camp.
-- Also sets the base lair lighting and applies the block-out fixes from the style sheet.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

-- Fresh copies so Rojo edits are picked up without restarting Studio.
local configModule = ReplicatedStorage.SFTBShared.Config:Clone()
local Config = require(configModule)
local builderModule = ServerScriptService.SFTBServer.Lair.LairBuilder:Clone()
local LairBuilder = require(builderModule)

local BONES = Color3.fromHex("888069")
local CAMP_WARM = Color3.fromHex("FFCF8A")

-- 1. Archive the old mockup (moved, not deleted) and replace any previous preview.
local archive = ServerStorage:FindFirstChild("SFTB_MockupArchive") or Instance.new("Folder")
archive.Name = "SFTB_MockupArchive"
archive.Parent = ServerStorage
local mockup = workspace:FindFirstChild("SFTB_Mockup")
if mockup then
	-- Block-out fixes from the style sheet: bones to #888069, camp torch tips to #FFCF8A.
	for _, d in ipairs(mockup:GetDescendants()) do
		if d:IsA("BasePart") then
			local lname = d.Name:lower()
			if
				(lname:find("bone") or lname:find("skull") or lname:find("rib"))
				and d.Color.R > 0.75
			then
				d.Color = BONES
			elseif
				d.Material == Enum.Material.Neon
				and d.Color.R > 0.95
				and d.Color.G > 0.95
				and d.Color.B > 0.95
			then
				d.Color = CAMP_WARM
			end
		end
	end
	-- Camp stays; the old lair, beast, nest, props and crew dummies are archived.
	for _, name in ipairs({ "Lair", "TheHush", "Nest", "Props", "Crew" }) do
		local child = mockup:FindFirstChild(name)
		if child then
			child.Parent = archive
		end
	end
end
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate.Parent = archive
end
local old = workspace:FindFirstChild("SFTB_Lair")
if old then
	old:Destroy()
end

-- 2. The preview at the origin.
local lair = LairBuilder.Build(Vector3.zero, 1, Config)
lair.Parent = workspace

-- 3. Lighting: darkness from fog, Ambient lifted (never black), no bloom/sun rays/DoF.
-- The client blends between Config.Lighting.Lair and .Camp while playing.
local L = Config.Lighting.Lair
Lighting.ClockTime = 0
Lighting.Brightness = 1.5
Lighting.Ambient = L.Ambient
Lighting.OutdoorAmbient = L.OutdoorAmbient
Lighting.GlobalShadows = true
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
pcall(function()
	Lighting.LightingStyle = Enum.LightingStyle.Soft
end)
for _, fx in ipairs(Lighting:GetChildren()) do
	if fx:IsA("SunRaysEffect") or fx:IsA("BloomEffect") or fx:IsA("DepthOfFieldEffect") then
		fx.Parent = archive
	end
end
local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density = L.Density
atmo.Offset = 0.1
atmo.Color = L.FogColor
atmo.Decay = L.Decay
atmo.Glare = 0
atmo.Haze = 1
atmo.Parent = Lighting

configModule:Destroy()
builderModule:Destroy()
return ("SFTB_Lair preview built: %d parts"):format(#lair:GetDescendants())
