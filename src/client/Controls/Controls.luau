--!strict
-- Stage 2 controls: one Input Action System map for a run, speed from stick tilt, phone buttons.
-- Move is Roblox's built-in character control, which already scales speed by stick tilt. So on
-- a stick or touch thumbstick WalkSpeed = RunSpeed and a gentle push is a sneak. A keyboard has
-- no tilt: walk by default, hold Shift to sneak, hold Ctrl to run. No crouch button, no jump.
-- The server reads the real speed for noise (NoiseService); nothing here is trusted.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local K = Config.Controls
local N = Config.Noise

local player = Players.LocalPlayer
local Controls = {}

local function preferred(): string
	return UserInputService.PreferredInput.Name -- "KeyboardAndMouse" | "Gamepad" | "Touch"
end

---------------------------------------------------------------------------------------------
-- The action map. Move itself is the built-in character control (analog on stick and touch).
local context = Instance.new("InputContext")
context.Name = "SFTB_Run"

local function action(name: string): InputAction
	local a = Instance.new("InputAction")
	a.Name = name
	a.Type = Enum.InputActionType.Bool
	a.Parent = context
	return a
end

local function bind(a: InputAction, key: Enum.KeyCode?, button: GuiButton?)
	local b = Instance.new("InputBinding")
	if key then
		b.KeyCode = key
	end
	if button then
		b.UIButton = button
	end
	b.Parent = a
end

local sneak = action("MoveSneak")
for _, key in ipairs(K.SneakKeys) do
	bind(sneak, key)
end
local run = action("MoveRun")
for _, key in ipairs(K.RunKeys) do
	bind(run, key)
end

---------------------------------------------------------------------------------------------
-- HUD: barely-there (horror). Phone buttons sit bottom-right, max 3 in a run.
local gui = Instance.new("ScreenGui")
gui.Name = "SFTB_RunHUD"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

local function label(name: string): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	t.TextColor3 = Color3.fromRGB(230, 228, 220)
	t.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.4
	stroke.Parent = t
	t.Parent = gui
	return t
end

local hint = label("Hint")
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.fromScale(0.5, 0.12)
hint.Size = UDim2.fromScale(0.8, 0.04)

local keyHint = label("KeyHint")
keyHint.AnchorPoint = Vector2.new(1, 1)
keyHint.Position = UDim2.fromScale(0.98, 0.97)
keyHint.Size = UDim2.fromScale(0.4, 0.028)
keyHint.TextXAlignment = Enum.TextXAlignment.Right
keyHint.TextTransparency = 0.35

local toast = label("Toast")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.18)
toast.Size = UDim2.fromScale(0.6, 0.035)
toast.Visible = false

local function touchButton(
	name: string,
	text: string,
	scale: number,
	x: number,
	y: number
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.fromScale(x, y)
	b.Size = UDim2.fromScale(K.ButtonSize * scale, K.ButtonSize * scale)
	b.SizeConstraint = Enum.SizeConstraint.RelativeYY
	b.BackgroundColor3 = Color3.fromRGB(20, 24, 22)
	b.BackgroundTransparency = 0.35
	b.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	b.TextColor3 = Color3.fromRGB(230, 228, 220)
	b.TextScaled = true
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(230, 228, 220)
	stroke.Transparency = 0.6
	stroke.Thickness = 2
	stroke.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.18, 0)
	pad.PaddingRight = UDim.new(0.18, 0)
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.PaddingBottom = UDim.new(0.3, 0)
	pad.Parent = b
	b.Parent = gui
	return b
end

-- Bottom-right thumb arc: Power biggest, Ping to its left, Drop above (only while carrying).
local powerButton = touchButton("Power", K.Power.Label, 1.1, 0.97, 0.95)
local pingButton = touchButton("Ping", K.Ping.Label, 0.8, 0.82, 0.97)
local dropButton = touchButton("DropPass", K.DropPass.Label, 0.8, 0.95, 0.7)

local power = action("Power")
bind(power, K.Power.Key)
bind(power, K.Power.Gamepad)
bind(power, nil, powerButton)
local ping = action("Ping")
bind(ping, K.Ping.Key)
bind(ping, K.Ping.Gamepad)
bind(ping, nil, pingButton)
local dropPass = action("DropPass")
bind(dropPass, K.DropPass.Key)
bind(dropPass, K.DropPass.Gamepad)
bind(dropPass, nil, dropButton)

local toastToken = 0
local function showToast(text: string, seconds: number?)
	toastToken += 1
	local mine = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(seconds or K.StubToastSeconds, function()
		if toastToken == mine then
			toast.Visible = false
		end
	end)
end

-- Stubs until their stages: Power (Stage 6, Listen), Ping (Stage 10).
power.Pressed:Connect(function()
	showToast("Power: your hatchling's power goes here")
end)
ping.Pressed:Connect(function()
	showToast("Ping: coming soon")
end)
local remotes = ReplicatedStorage:WaitForChild("SFTBRemotes")
local EggDropPass = remotes:WaitForChild("EggDropPass") :: RemoteEvent
dropPass.Pressed:Connect(function()
	if player:GetAttribute("SFTB_Carrying") then
		EggDropPass:FireServer() -- the server decides: pass to a crewmate in reach, else drop
	end
end)
local Toast = remotes:WaitForChild("Toast") :: RemoteEvent
Toast.OnClientEvent:Connect(function(text: unknown, seconds: unknown)
	if type(text) == "string" then
		showToast(text, if type(seconds) == "number" then seconds else nil)
	end
end)

-- UI swaps live by PreferredInput.
local function refresh()
	local input = preferred()
	local carrying = player:GetAttribute("SFTB_Carrying") ~= nil
	local touch = input == "Touch"
	powerButton.Visible = touch
	pingButton.Visible = touch
	dropButton.Visible = touch and carrying
	dropPass.Enabled = carrying
	hint.Text = K.Hint[input] or K.Hint.KeyboardAndMouse
	keyHint.Text = K.KeyHint[input] or ""
	keyHint.Visible = not touch
end

---------------------------------------------------------------------------------------------
-- Speed: keyboard picks a tier, analog gets RunSpeed and the tilt does the rest.
-- Carrying scales it by the server's SFTB_CarrySpeed (0 = the big egg alone won't move).
local function targetSpeed(): number
	local carry = player:GetAttribute("SFTB_CarrySpeed")
	local scale = if type(carry) == "number" then carry else 1
	if preferred() ~= "KeyboardAndMouse" then
		return N.RunSpeed * scale
	elseif sneak:GetState() then
		return N.SneakSpeed * scale
	elseif run:GetState() then
		return N.RunSpeed * scale
	end
	return N.WalkSpeed * scale
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) -- no free jump
	end
end

function Controls.Start()
	context.Parent = script
	gui.Parent = player:WaitForChild("PlayerGui")
	refresh()
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	player:GetAttributeChangedSignal("SFTB_Carrying"):Connect(refresh)

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	-- The hint fades once the server has heard you sneak for a few seconds.
	local sneakSeconds = 0
	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local speed = targetSpeed()
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end
		if hint.Visible and player:GetAttribute("SFTB_NoiseTier") == "Sneak" then
			sneakSeconds += dt
			if sneakSeconds >= K.HintSneakSeconds then
				hint.Visible = false
			end
		end
	end)
end

return Controls
