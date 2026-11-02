--!strict
-- Stage 10: crew pings. Each ping is an amber marker (light language: amber = us) with its
-- word and who sent it, seen through walls for a few seconds, plus a small flat ring.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local PingShow =
	ReplicatedStorage:WaitForChild("SFTBRemotes"):WaitForChild("PingShow") :: RemoteEvent

local P = Config.Pings

local PingView = {}

local function show(userId: number, kind: string, at: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "Ping"
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow =
		false, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(at)
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = anchor
	ring.Color3 = P.Color
	ring.Radius = 2.5
	ring.InnerRadius = 2.1
	ring.Height = 0.05
	ring.CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	ring.Transparency = 0.2
	ring.Parent = anchor
	local board = Instance.new("BillboardGui")
	board.AlwaysOnTop = true
	board.Size = UDim2.fromOffset(140, 46)
	board.StudsOffset = Vector3.new(0, 3, 0)
	board.LightInfluence = 0
	local word = Instance.new("TextLabel")
	word.Size = UDim2.fromScale(1, 0.65)
	word.BackgroundTransparency = 1
	word.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	word.TextColor3 = P.Color
	word.TextScaled = true
	word.Text = P.Labels[kind] or kind
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.2
	stroke.Parent = word
	word.Parent = board
	local who = Players:GetPlayerByUserId(userId)
	local name = word:Clone()
	name.Position = UDim2.fromScale(0, 0.65)
	name.Size = UDim2.fromScale(1, 0.35)
	name.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	name.Text = if who then who.DisplayName else ""
	name.Parent = board
	board.Parent = anchor
	anchor.Parent = workspace
	task.delay(P.Seconds - 0.5, function()
		TweenService:Create(word, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(name, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(ring, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		task.wait(0.5)
		anchor:Destroy()
	end)
end

function PingView.Start()
	PingShow.OnClientEvent:Connect(function(userId: unknown, kind: unknown, at: unknown)
		if type(userId) == "number" and type(kind) == "string" and typeof(at) == "Vector3" then
			show(userId, kind, at :: Vector3)
		end
	end)
end

return PingView
