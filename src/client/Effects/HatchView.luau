--!strict
-- Stage 6: the hatch reveal and the Hushlings. The reveal is the egg build-up from the
-- Animation Style Guide: wobble, harder wobble, swell, white flash, pop (no particles).
-- Every player with a hatchling (attribute SFTB_Hatchling) gets a greybox Hushling that
-- follows them, breathes and blinks. Listen shows the Hush through walls for a few seconds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("SFTBRemotes")
local HatchReveal = remotes:WaitForChild("HatchReveal") :: RemoteEvent
local Listen = remotes:WaitForChild("Listen") :: RemoteEvent

local H = Config.Hatch
local TEAL = Config.Hush.SlimeColor
local EGG_WHITE = Color3.fromHex("F1F4EC")
local BODY = Color3.fromHex("3A4440")
local player = Players.LocalPlayer

local HatchView = {}

local spawnAt: { [number]: Vector3 } = {} -- where a fresh Hushling starts (the reveal spot)
local gui: ScreenGui
local banner: TextLabel
local fade: Frame

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

-- A small Hush: big head, big low eyes, stubby legs, the parent's teal ears. About 2.5 tall.
local function makeHushling(): Model
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
	return m
end

local function say(text: string, seconds: number)
	banner.Text = text
	banner.Visible = true
	task.delay(seconds, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Followers: one Hushling per player who has one.
local function follow(owner: Player)
	local model: Model? = nil
	local pos: Vector3? = nil
	local blinkAt = os.clock() + H.BlinkEvery
	local function clear()
		if model then
			model:Destroy()
			model = nil
		end
		pos = nil
	end
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not owner.Parent then
			clear()
			connection:Disconnect()
			return
		end
		local character = owner.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if owner:GetAttribute("SFTB_Hatchling") ~= "Hushling" or not hrp or not humanoid then
			clear()
			return
		end
		local feetY = hrp.Position.Y - humanoid.HipHeight - hrp.Size.Y / 2
		local goal = (hrp.CFrame * CFrame.new(H.FollowOffset)).Position
		goal = Vector3.new(goal.X, feetY, goal.Z)
		if not model then
			model = makeHushling()
			pos = spawnAt[owner.UserId] or goal
			spawnAt[owner.UserId] = nil
			(model :: Model).Parent = workspace.CurrentCamera
		end
		local current = (pos :: Vector3):Lerp(goal, 1 - math.exp(-dt * H.FollowSharpness))
		local moved = Vector3.new(current.X - (pos :: Vector3).X, 0, current.Z - (pos :: Vector3).Z)
		pos = current
		local face = if moved.Magnitude > 0.02
			then moved.Unit
			else hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
		if face.Magnitude < 0.01 then
			face = Vector3.zAxis
		end
		local bob = math.sin(os.clock() * H.BreatheSpeed) * H.BreatheAmount
		local m = model :: Model
		m:PivotTo(CFrame.lookAt(current, current + face.Unit) * CFrame.new(0, 0.95 + bob, 0))
		-- Blink: eyes vanish for a moment every few seconds.
		local now = os.clock()
		local blinking = now >= blinkAt and now < blinkAt + 0.12
		if now >= blinkAt + 0.12 then
			blinkAt = now + H.BlinkEvery * (0.7 + math.random() * 0.6)
		end
		for _, child in ipairs(m:GetChildren()) do
			if child.Name == "Eye" and child:IsA("BasePart") then
				child.Transparency = if blinking then 1 else 0
			end
		end
	end)
end

---------------------------------------------------------------------------------------------
-- The reveal: a fade hides the trip to camp, then the egg builds up and pops.
local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
)
	local t =
		TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine), goal)
	t:Play()
	return t
end

local function reveal(eggSize: string)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return
	end
	fade.BackgroundTransparency = 0
	tween(fade, H.FadeSeconds, { BackgroundTransparency = 1 })
	task.wait(0.1) -- let the camp position arrive
	local size = Config.Egg[eggSize .. "Size"] or Config.Egg.SmallSize
	local feetY = hrp.Position.Y - humanoid.HipHeight - hrp.Size.Y / 2
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
	local spot = Vector3.new(hrp.Position.X, feetY, hrp.Position.Z) + look * H.RevealDistance
	local holder = Instance.new("Model")
	holder.Name = "HatchReveal"
	holder.Parent = workspace.CurrentCamera
	local base = CFrame.new(spot + Vector3.new(0, size / 2, 0))
	local egg =
		part(holder, "Egg", Vector3.new(size, size, size), base, EGG_WHITE, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = EGG_WHITE
	light.Range = size * 5
	light.Brightness = 1
	light.Parent = egg

	-- Camera looks at the egg from the player's side for the reveal.
	local camera = workspace.CurrentCamera
	local camAt = spot - look * (H.RevealDistance + 5) + Vector3.new(0, 4 + size, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(camAt, spot + Vector3.new(0, size * 0.6, 0))

	-- Wobble, then harder (build-up about 1.4 s).
	for i = 1, 3 do
		tween(egg, 0.12, { CFrame = base * CFrame.Angles(0, 0, (i % 2 == 0 and -1 or 1) * 0.14) }).Completed:Wait()
	end
	for i = 1, 5 do
		tween(egg, 0.07, { CFrame = base * CFrame.Angles(0, 0, (i % 2 == 0 and -1 or 1) * 0.32) }).Completed:Wait()
	end
	egg.CFrame = base
	-- Swell.
	tween(egg, 0.3, { Size = Vector3.one * size * 1.35 }, Enum.EasingStyle.Quad).Completed:Wait()
	-- White flash.
	egg.Material = Enum.Material.Neon
	light.Brightness = 8
	task.wait(0.12)
	-- Pop: the Hushling springs out where the egg was.
	egg:Destroy()
	local baby = makeHushling()
	baby:PivotTo(CFrame.lookAt(spot, spot - look) * CFrame.new(0, 0.95, 0))
	baby.Parent = holder
	local scale = Instance.new("NumberValue")
	scale.Value = 0.3
	scale.Changed:Connect(function(v)
		baby:ScaleTo(math.max(v, 0.05))
	end)
	baby:ScaleTo(0.3)
	tween(scale, 0.35, { Value = 1 }, Enum.EasingStyle.Back)
	local key = H.PowerText[UserInputService.PreferredInput.Name] or "Q"
	say(H.HatchedText .. "\nPress " .. key .. " to Listen for the Hush.", 4)
	task.wait(math.max(H.RevealSeconds - 1.6, 0.6))
	spawnAt[player.UserId] = spot
	holder:Destroy()
	camera.CameraType = Enum.CameraType.Custom
end

---------------------------------------------------------------------------------------------
-- Listen: outline every Hush through walls for a few seconds.
local function listen(seconds: number)
	say(H.ListenText, seconds)
	local lights = {}
	for _, look in ipairs(workspace.CurrentCamera:GetChildren()) do
		if look.Name == "HushLook" then
			local h = Instance.new("Highlight")
			h.FillColor = TEAL
			h.FillTransparency = 0.75
			h.OutlineColor = TEAL
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = look
			table.insert(lights, h)
		end
	end
	task.delay(seconds, function()
		for _, h in ipairs(lights) do
			h:Destroy()
		end
	end)
end

function HatchView.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "SFTB_HatchHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.Parent = gui
	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.fromScale(0.5, 0.2)
	banner.Size = UDim2.fromScale(0.8, 0.1)
	banner.BackgroundTransparency = 1
	banner.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	banner.TextColor3 = Color3.fromRGB(230, 228, 220)
	banner.TextScaled = true
	banner.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.3
	stroke.Parent = banner
	banner.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	HatchReveal.OnClientEvent:Connect(function(eggSize: unknown)
		task.spawn(reveal, if eggSize == "Big" then "Big" else "Small")
	end)
	Listen.OnClientEvent:Connect(function(seconds: unknown)
		if type(seconds) == "number" then
			listen(math.clamp(seconds, 0, 10))
		end
	end)
	Players.PlayerAdded:Connect(follow)
	for _, other in ipairs(Players:GetPlayers()) do
		follow(other)
	end
end

return HatchView
