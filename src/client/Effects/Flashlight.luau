--!strict
-- Crew flashlight (Stage 1). Every character gets an amber spotlight; only the local
-- player's casts shadows unless Config says otherwise. Light language: amber = us.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))

local Flashlight = {}

local function attach(character: Model, isLocal: boolean)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") or root:FindFirstChild("SFTBFlashlight") then
		return
	end
	local settings = Config.Flashlight
	local attachment = Instance.new("Attachment")
	attachment.Name = "SFTBFlashlight"
	attachment.Position = Vector3.new(0, 1.5, -0.5)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Color = settings.Color
	light.Brightness = settings.Brightness
	light.Range = settings.Range
	light.Angle = settings.Angle
	light.Shadows = isLocal or settings.ShadowsForOthers
	light.Parent = attachment
	attachment.Parent = root
end

local function watch(player: Player)
	local isLocal = player == Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		attach(character, isLocal)
	end)
	if player.Character then
		task.spawn(attach, player.Character, isLocal)
	end
end

function Flashlight.Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return Flashlight
