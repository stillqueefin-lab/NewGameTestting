--!strict
-- Stage 3: draws the Hush over the server's invisible mover (Creature Animation Pipeline).
-- Greybox body for now: the lair's stand-in, cloned and moved each frame. Ears turn toward
-- the noise it heard and stand up as it wakes; the teal glow brightens and pulses in Alert and
-- Hunt (a danger meter with no UI). Also plays the swat: teal slime for everyone, and for the
-- one caught a ragdoll shove and one line saying what it heard.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local HushCaught =
	ReplicatedStorage:WaitForChild("SFTBRemotes"):WaitForChild("HushCaught") :: RemoteEvent

local H = Config.Hush
local player = Players.LocalPlayer

local HushView = {}

type Ear = { Part: BasePart, Rel: CFrame, Base: CFrame, Pitch: number, Yaw: number }

local function slime(position: Vector3)
	local folder = workspace.CurrentCamera
	local parts = {}
	for i = 0, 3 do
		local size = if i == 0 then 7 else math.random(2, 4)
		local offset = if i == 0
			then Vector3.zero
			else Vector3.new(math.random(-40, 40) / 10, 0, math.random(-40, 40) / 10)
		local p = Instance.new("Part")
		p.Name = "HushSlime"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.15, size, size)
		p.CFrame = CFrame.new(position + offset + Vector3.new(0, 0.1 + i * 0.01, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		p.Color = H.SlimeColor
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.15
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Parent = folder
		table.insert(parts, p)
	end
	task.delay(H.SlimeSeconds, function()
		for _, p in ipairs(parts) do
			TweenService:Create(p, TweenInfo.new(1), { Transparency = 1 }):Play()
		end
		task.wait(1)
		for _, p in ipairs(parts) do
			p:Destroy()
		end
	end)
end

local message: TextLabel
local messageToken = 0
local function say(text: string)
	messageToken += 1
	local mine = messageToken
	message.Text = text
	message.Visible = true
	task.delay(H.CaughtSeconds, function()
		if messageToken == mine then
			message.Visible = false
		end
	end)
end

local function onCaught(userId: number, feet: Vector3, push: Vector3, reason: string)
	slime(feet)
	if userId ~= player.UserId then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and hrp then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		hrp.AssemblyLinearVelocity = push * H.SwatForce + Vector3.new(0, H.SwatForce * 0.4, 0)
	end
	say(H.CaughtText:format(H.HeardText[reason] or "you"))
end

local function draw(mover: Model, template: Model)
	local root = mover:WaitForChild("Root") :: BasePart
	local offset = template:GetAttribute("Offset") :: CFrame
	local look = template:Clone()
	look.Name = "HushLook"
	look.Parent = workspace.CurrentCamera

	-- Remember each ear relative to the body pivot, and its base (it bends from there).
	local pivot0 = look:GetPivot()
	local ears: { Ear } = {}
	local glowParts: { BasePart } = {}
	local bodyColor = Color3.new(0, 0, 0)
	for _, part in ipairs(look:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "Ear" then
				table.insert(ears, {
					Part = part,
					Rel = pivot0:ToObjectSpace(part.CFrame),
					Base = CFrame.new(0, -part.Size.Y / 2, 0),
					Pitch = 0,
					Yaw = 0,
				})
			end
			if part.Material == Enum.Material.Neon then
				table.insert(glowParts, part)
			elseif part.Name == "Body" then
				bodyColor = part.Color
			end
		end
	end
	local light = look:FindFirstChildWhichIsA("PointLight", true)

	local glow = H.Glow.Sleep
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not mover.Parent then
			connection:Disconnect()
			look:Destroy()
			return
		end
		local state = mover:GetAttribute("State") or "Sleep"
		local now = workspace:GetServerTimeNow()

		-- Swat: rear back during the wind-up, then lunge.
		local lunge = 0
		local swatAt = mover:GetAttribute("SwatAt")
		if type(swatAt) == "number" then
			local t = (now - swatAt) / H.SwatWindup
			if t >= 0 and t < 1 then
				lunge = -1.5 * t
			elseif t >= 1 and t < 1.8 then
				lunge = 4 * (1 - (t - 1) / 0.8)
			end
		end
		local pivot = root.CFrame * CFrame.new(0, 0, -lunge) * offset
		look:PivotTo(pivot)

		-- Glow: eases to the state's level; Alert and Hunt pulse.
		glow += ((H.Glow[state] or H.Glow.Sleep) - glow) * math.min(dt * 4, 1)
		local level = glow
		if H.PulseStates[state] then
			level *= 1 + H.PulseAmount * math.sin(os.clock() * H.PulseSpeed)
		end
		local teal = H.SlimeColor:Lerp(bodyColor, math.clamp(1 - level, 0, 0.75))
		for _, part in ipairs(glowParts) do
			part.Color = teal
		end
		if light then
			light.Brightness = H.LightBrightness * level
		end

		-- Ears: turn toward the noise (fast once alert) and stand up as it wakes.
		local earTarget = mover:GetAttribute("EarTarget")
		local local_ = if typeof(earTarget) == "Vector3"
			then pivot:PointToObjectSpace(earTarget)
			else Vector3.zAxis
		local yaw = math.clamp(math.atan2(local_.X, local_.Z), -H.EarYawMax, H.EarYawMax)
		if state == "Sleep" then
			yaw = 0
		end
		local pitch = H.EarPitch[state] or 0
		local speed = if H.PulseStates[state] then H.EarSnapSpeed else H.EarEaseSpeed
		local k = math.min(dt * speed, 1)
		for _, ear in ipairs(ears) do
			ear.Yaw += (yaw - ear.Yaw) * k
			ear.Pitch += (pitch - ear.Pitch) * k
			ear.Part.CFrame = pivot
				* ear.Rel
				* ear.Base
				* CFrame.fromEulerAnglesYXZ(ear.Pitch, ear.Yaw, 0)
				* ear.Base:Inverse()
		end
	end)
end

function HushView.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SFTB_HushHUD"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	message = Instance.new("TextLabel")
	message.Name = "Caught"
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.4)
	message.Size = UDim2.fromScale(0.8, 0.06)
	message.BackgroundTransparency = 1
	message.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	message.TextColor3 = Color3.fromRGB(230, 228, 220)
	message.TextScaled = true
	message.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.3
	stroke.Parent = message
	message.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	HushCaught.OnClientEvent:Connect(onCaught)

	task.spawn(function()
		local template = ReplicatedStorage:WaitForChild("SFTBHushLook", math.huge) :: Model -- made when the first run starts
		local function watch(child: Instance)
			if child.Name == "SFTB_Hush" and child:IsA("Model") then
				task.spawn(draw, child, template)
			end
		end
		workspace.ChildAdded:Connect(watch)
		for _, child in ipairs(workspace:GetChildren()) do
			watch(child)
		end
	end)
end

return HushView
