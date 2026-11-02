--!strict
-- Stage 7: the camp hub. Greybox crew pads by a gate: stand on one alone or with friends and a
-- short countdown starts your crew's run (LairService). Plus an empty outfitter stall and a pen
-- sign. The block-out camp (fire, incubators, tents) is already in the place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))

local Camp = Config.Camp
local Cr = Config.Crews

type Pad = { Part: BasePart, Label: TextLabel, EndsAt: number? }

local CampService = {}

local pads: { Pad } = {}
local lairService: any

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function sign(parent: BasePart, text: string, height: number): TextLabel
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(10, 3)
	board.StudsOffset = Vector3.new(0, height, 0)
	board.AlwaysOnTop = false
	board.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	label.TextColor3 = Color3.fromRGB(240, 230, 210)
	label.TextScaled = true
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.3
	stroke.Parent = label
	label.Parent = board
	board.Parent = parent
	return label
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "SFTB_CampHub"
	for i, pos in ipairs(Camp.Pads) do
		local pad = part(
			folder,
			"CrewPad" .. i,
			Vector3.new(Camp.PadSize, 1, Camp.PadSize),
			CFrame.new(pos + Vector3.new(0, Camp.PadLift - 0.5, 0)),
			Camp.WoodColor
		)
		local light = Instance.new("PointLight")
		light.Color = Camp.WarmColor
		light.Range = 12
		light.Brightness = 0.8
		light.Parent = pad
		table.insert(pads, { Part = pad, Label = sign(pad, Cr.PadText, 5) })
	end
	-- The gate: two posts and a beam behind the pads.
	local first, last = Camp.Pads[1], Camp.Pads[#Camp.Pads]
	local mid = (first + last) / 2 + Vector3.new(0, 0, -8)
	local width = (last - first).Magnitude + Camp.PadSize + 6
	for _, sx in ipairs({ -1, 1 }) do
		part(
			folder,
			"GatePost",
			Vector3.new(2, 14, 2),
			CFrame.new(mid + Vector3.new(sx * width / 2, 7, 0)),
			Camp.WoodColor
		)
	end
	local beam = part(
		folder,
		"GateBeam",
		Vector3.new(width + 2, 2, 2),
		CFrame.new(mid + Vector3.new(0, 14, 0)),
		Camp.WoodColor
	)
	sign(beam, "The Hollow Roots", 3)
	-- Outfitter: an empty stall for now (cosmetics later).
	local o = Camp.Outfitter
	part(
		folder,
		"OutfitterCounter",
		Vector3.new(8, 3, 3),
		CFrame.new(o + Vector3.new(0, 1.5, 0)),
		Camp.WoodColor
	)
	local roof = part(
		folder,
		"OutfitterRoof",
		Vector3.new(10, 1, 6),
		CFrame.new(o + Vector3.new(0, 7, -1)),
		Color3.fromHex("915556")
	)
	sign(roof, "Outfitter\n(soon)", 3)
	local penPost = part(
		folder,
		"PenSign",
		Vector3.new(1, 4, 1),
		CFrame.new(Camp.PenSign + Vector3.new(0, 2, 0)),
		Camp.WoodColor
	)
	sign(penPost, "Pen", 3)
	folder.Parent = workspace
end

local function onPad(pad: BasePart, pos: Vector3): boolean
	local offset = pad.CFrame:PointToObjectSpace(pos)
	return math.abs(offset.X) <= pad.Size.X / 2
		and math.abs(offset.Z) <= pad.Size.Z / 2
		and offset.Y > 0
		and offset.Y < 8
end

local function update()
	local now = os.clock()
	for _, pad in ipairs(pads) do
		local crew = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if
				character
				and humanoid
				and humanoid.Health > 0
				and not player:GetAttribute("SFTB_InRun")
				and onPad(pad.Part, character:GetPivot().Position)
				and #crew < Cr.MaxCrew
			then
				table.insert(crew, player)
			end
		end
		if #crew == 0 then
			pad.EndsAt = nil
			pad.Label.Text = Cr.PadText
		else
			pad.EndsAt = pad.EndsAt or now + Cr.CountdownSeconds
			local left = math.ceil((pad.EndsAt :: number) - now)
			if left <= 0 then
				pad.EndsAt = nil
				if not lairService.StartRun(crew) then
					pad.Label.Text = Cr.BusyText
				end
			else
				pad.Label.Text = Cr.StartingText:format(#crew, Cr.MaxCrew, left)
			end
		end
	end
end

function CampService.Start(lairs: any)
	lairService = lairs
	build()
	task.spawn(function()
		while true do
			task.wait(0.25)
			update()
		end
	end)
end

return CampService
