--!strict
-- Stage 8: your side of camp. Your incubator eggs sit on the block-out incubators with a
-- countdown; each incubator's Hatch prompt shows when your egg there is ready (the server
-- checks it). Your hatchlings other than the one following you idle in the pen, sized by how
-- grown they are, with a roster sign.
-- Each player sees their own eggs and roster.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local State = require(script.Parent.Parent:WaitForChild("State"))
local HushlingModel = require(script.Parent:WaitForChild("HushlingModel"))

local H = Config.Hatch
local EGG_WHITE = Color3.fromHex("F1F4EC")
local TEAL = Config.Hush.SlimeColor

local CampView = {}

type Slot = { Egg: Part, Label: TextLabel, Index: number }

local slots: { Slot } = {}
local pen: { Model } = {}
local folder: Folder
local roster: TextLabel

local function billboard(parent: BasePart, height: number): TextLabel
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(6, 2)
	board.StudsOffset = Vector3.new(0, height, 0)
	board.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	label.TextColor3 = Color3.fromRGB(240, 230, 210)
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.3
	stroke.Parent = label
	label.Parent = board
	board.Parent = parent
	return label
end

local function makeSlot(i: number, spot: Vector3): Slot
	local egg = Instance.new("Part")
	egg.Name = "IncubatorEgg" .. i
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.one * Config.Egg.SmallSize
	egg.CFrame = CFrame.new(spot)
	egg.Color = EGG_WHITE
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.CanCollide, egg.CanQuery, egg.CanTouch, egg.CastShadow = false, false, false, false
	local band = egg:Clone()
	band.Name = "Marking"
	band.Shape = Enum.PartType.Cylinder
	band.Color = TEAL
	band.Size = Vector3.new(0.36, 2.04, 2.04)
	band.CFrame = egg.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	band.Parent = egg
	egg.Parent = folder
	return { Egg = egg, Label = billboard(egg, 3), Index = i }
end

-- The shared server prompt on this incubator (HatchService); shown only when your egg is ready.
local function promptOf(slot: Slot): ProximityPrompt?
	local incubators = workspace:FindFirstChild("SFTB_Incubators")
	local anchor = incubators and incubators:FindFirstChild("Incubator" .. slot.Index)
	return anchor and anchor:FindFirstChildOfClass("ProximityPrompt")
end

local function refreshSlots()
	local incubators = State.Get().Incubators or {}
	local now = workspace:GetServerTimeNow()
	for i, slot in ipairs(slots) do
		local egg = incubators[i]
		local prompt = promptOf(slot)
		slot.Egg.Transparency = if egg then 0 else 1
		local band = slot.Egg:FindFirstChild("Marking") :: BasePart
		band.Transparency = slot.Egg.Transparency
		if egg then
			local size = Config.Egg[egg.EggSize .. "Size"] or Config.Egg.SmallSize
			if slot.Egg.Size.X ~= size then
				slot.Egg.Size = Vector3.one * size
				band.Size = Vector3.new(size * 0.18, size * 1.02, size * 1.02)
			end
			band.CFrame = slot.Egg.CFrame * CFrame.Angles(0, 0, math.pi / 2)
			local left = math.max(0, math.ceil(egg.ReadyAt - now))
			slot.Label.Text = if left > 0
				then ("%d:%02d"):format(left // 60, left % 60)
				else H.ReadyText
			if prompt then
				prompt.Enabled = left <= 0
			end
		else
			slot.Label.Text = ""
			if prompt then
				prompt.Enabled = false
			end
		end
	end
end

local function refreshPen()
	local state = State.Get()
	local hatchlings = state.Hatchlings or {}
	-- The newest follows you; the rest idle in the pen.
	local count = math.max(#hatchlings - 1, 0)
	while #pen < count do
		local m = HushlingModel.new()
		m.Parent = folder
		table.insert(pen, m)
	end
	while #pen > count do
		(table.remove(pen) :: Model):Destroy()
	end
	for i, m in ipairs(pen) do
		local scale = HushlingModel.ScaleFor(hatchlings[i] and hatchlings[i].Born)
		if math.abs(m:GetScale() - scale) > 0.01 then
			m:ScaleTo(scale)
		end
	end
	roster.Text = ("Hushlings: %d\nCrew level %d"):format(#hatchlings, state.CrewLevel or 1)
end

function CampView.Start()
	folder = Instance.new("Folder")
	folder.Name = "SFTB_MyCamp"
	folder.Parent = workspace -- created on the client, so only you see it
	for i, spot in ipairs(H.IncubatorSpots) do
		table.insert(slots, makeSlot(i, spot))
	end
	local sign = Instance.new("Part")
	sign.Name = "RosterAnchor"
	sign.Anchored = true
	sign.CanCollide, sign.CanQuery, sign.CanTouch = false, false, false
	sign.Transparency = 1
	sign.Size = Vector3.one
	sign.CFrame = CFrame.new(Config.Camp.PenSign + Vector3.new(0, 4, 0))
	sign.Parent = folder
	roster = billboard(sign, 3)

	State.Changed:Connect(function()
		refreshSlots()
		refreshPen()
	end)
	refreshSlots()
	refreshPen()
	task.spawn(function()
		while true do
			task.wait(0.5)
			refreshSlots()
		end
	end)
	RunService.RenderStepped:Connect(function()
		for i, m in ipairs(pen) do
			local a = i / math.max(#pen, 1) * math.pi * 2
			local feet = H.PenCentre + Vector3.new(math.cos(a), 0, math.sin(a)) * H.PenRadius
			HushlingModel.Place(m, feet, (H.PenCentre - feet) * Vector3.new(1, 0, 1), m:GetScale())
		end
	end)
end

return CampView
