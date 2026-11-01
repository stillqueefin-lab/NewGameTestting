--!strict
-- Stage 2 noise rings: every noise event draws a flat ring on the ground, sized to its radius,
-- for every player (crews see each other's noise). Your own loud noise buzzes phone/gamepad.
-- Rings are pooled CylinderHandleAdornments (no physics, nothing replicated).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local NoiseEvent =
	ReplicatedStorage:WaitForChild("SFTBRemotes"):WaitForChild("NoiseEvent") :: UnreliableRemoteEvent

local R = Config.NoiseRing
local FLAT = CFrame.Angles(math.pi / 2, 0, 0) -- the adornment's axis is Z; lay it on the floor

local NoiseRings = {}

local anchor: Part
local free: { CylinderHandleAdornment } = {}
local made = 0
local haptic: HapticEffect?

local function take(): CylinderHandleAdornment?
	local ring = table.remove(free)
	if ring or made >= R.PoolSize then
		return ring
	end
	made += 1
	local new = Instance.new("CylinderHandleAdornment")
	new.Name = "NoiseRing"
	new.Adornee = anchor
	new.Color3 = R.Color
	new.Height = 0.05
	new.AlwaysOnTop = false
	new.Visible = false
	new.Parent = anchor
	return new
end

local function show(position: Vector3, radius: number, isTrap: boolean)
	local camera = workspace.CurrentCamera
	if camera and (camera.Focus.Position - position).Magnitude > R.MaxDistance + radius then
		return
	end
	local ring = take()
	if not ring then
		return
	end
	local thickness = if isTrap then R.TrapThickness else R.Thickness
	ring.CFrame = CFrame.new(position + Vector3.new(0, R.Lift, 0)) * FLAT
	ring.Radius = thickness + 0.1
	ring.InnerRadius = 0.1
	ring.Transparency = R.StartTransparency
	ring.Visible = true
	local grow = TweenService:Create(
		ring,
		TweenInfo.new(R.GrowSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Radius = radius, InnerRadius = math.max(radius - thickness, 0) }
	)
	local fade = TweenService:Create(
		ring,
		TweenInfo.new(if isTrap then R.TrapFadeSeconds else R.FadeSeconds),
		{ Transparency = 1 }
	)
	grow.Completed:Once(function()
		fade:Play()
	end)
	fade.Completed:Once(function()
		ring.Visible = false
		table.insert(free, ring)
	end)
	grow:Play()
end

function NoiseRings.Start()
	anchor = Instance.new("Part")
	anchor.Name = "SFTB_NoiseRings"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.identity
	anchor.Parent = workspace.CurrentCamera

	local ok, effect = pcall(function()
		local e = Instance.new("HapticEffect")
		e.Type = Enum.HapticEffectType.GameplayCollision
		e.Parent = anchor
		return e
	end)
	haptic = if ok then effect else nil

	local me = Players.LocalPlayer.UserId
	NoiseEvent.OnClientEvent:Connect(
		function(position: Vector3, radius: number, source: string, userId: number)
			if typeof(position) ~= "Vector3" or type(radius) ~= "number" then
				return
			end
			local isTrap = Config.Noise.Traps[source] ~= nil
			show(position, radius, isTrap)
			if haptic and userId == me and radius >= Config.Haptics.MinRadius then
				pcall(haptic.Play, haptic)
			end
		end
	)
end

return NoiseRings
