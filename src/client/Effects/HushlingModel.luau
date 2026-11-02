--!strict
-- The greybox Hushling (Stage 6): a small Hush. Big head, big low eyes, stubby legs and the
-- parent's oversized teal ears. About 2.5 studs tall; pivot at the body centre.
-- Animate(model, t, dt) gives it the idle: breathing bob and a blink every few seconds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local H = Config.Hatch
local TEAL = Config.Hush.SlimeColor
local BODY = Color3.fromHex("3A4440")

local HushlingModel = {}

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Parent = model
	return p
end

function HushlingModel.new(): Model
	local m = Instance.new("Model")
	m.Name = "Hushling"
	local body = part(m, "Body", Vector3.new(1.6, 1.1, 1.8), CFrame.new(0, 0.95, 0), BODY)
	m.PrimaryPart = body
	part(m, "Head", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, 1.75, -0.8), BODY, Enum.PartType.Ball)
	for _, sx in ipairs({ -1, 1 }) do
		local ear = part(
			m,
			"Ear",
			Vector3.new(0.35, 1.5, 0.7),
			CFrame.new(sx * 0.45, 2.85, -0.75) * CFrame.Angles(0, 0, -sx * 0.4),
			TEAL
		)
		ear.Material = Enum.Material.Neon
		part(
			m,
			"Eye",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(sx * 0.38, 1.55, -1.55),
			H.EyeColor,
			Enum.PartType.Ball
		)
		for _, sz in ipairs({ -1, 1 }) do
			part(m, "Leg", Vector3.new(0.4, 0.45, 0.4), CFrame.new(sx * 0.5, 0.22, sz * 0.55), BODY)
		end
	end
	m:SetAttribute("BlinkAt", os.clock() + H.BlinkEvery * math.random())
	return m
end

-- Growth 0..1 from a hatch time (os.time seconds); grows offline too.
function HushlingModel.Growth(born: number?): number
	if type(born) ~= "number" then
		return 0
	end
	return math.clamp((workspace:GetServerTimeNow() - born) / H.GrowSeconds, 0, 1)
end

function HushlingModel.ScaleFor(born: number?): number
	return H.GrowStartScale + (1 - H.GrowStartScale) * HushlingModel.Growth(born)
end

-- Place it standing at feet (Vector3) facing a flat direction, with the breathing bob and blinks.
function HushlingModel.Place(model: Model, feet: Vector3, face: Vector3, scale: number)
	local now = os.clock()
	local bob = math.sin(now * H.BreatheSpeed) * H.BreatheAmount
	model:PivotTo(CFrame.lookAt(feet, feet + face) * CFrame.new(0, (0.95 + bob) * scale, 0))
	local blinkAt = model:GetAttribute("BlinkAt") :: number
	local blinking = now >= blinkAt and now < blinkAt + 0.12
	if now >= blinkAt + 0.12 then
		model:SetAttribute("BlinkAt", now + H.BlinkEvery * (0.7 + math.random() * 0.6))
	end
	for _, child in ipairs(model:GetChildren()) do
		if child.Name == "Eye" and child:IsA("BasePart") then
			child.Transparency = if blinking then 1 else 0
		end
	end
end

return HushlingModel
