-- Greybox lair builder (Stage 1 layout, Stage 2 noise traps, Stage 4 eggs, Stage 7 copies).
-- Build(origin, seed) returns a new lair Model built from Config.Lair at that offset, so each
-- crew gets its own copy. Used at run time by LairService and in Edit by
-- tools/BuildLairGreybox.luau (the preview at the origin). Geometry only: lighting lives in
-- Config.Lighting (client) and the tools script.
-- Greybox only: Studio parts, palette B "Mossy Burrow" (cold lair), no meshes.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LairBuilder = {}

local C = {
	RockDark = Color3.fromHex("323B33"),
	RockMid = Color3.fromHex("465047"),
	RockLight = Color3.fromHex("5B675D"),
	Floor = Color3.fromHex("414438"),
	Soil = Color3.fromHex("565B49"),
	Roots = Color3.fromHex("594233"),
	Moss = Color3.fromHex("4D5B40"),
	Bones = Color3.fromHex("888069"),
	HushBody = Color3.fromHex("3A4440"),
	HushTeal = Color3.fromHex("4FE3D0"),
	Egg = Color3.fromHex("F1F4EC"),
	StandIn = Color3.fromHex("7C8A9E"),
}

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function key(x, z)
	return x .. "," .. z
end

-- config: pass a fresh Config table (the tools script requires a clone so edits are picked up).
function LairBuilder.Build(origin: Vector3, seed: number?, config: any?)
	local Config = config
		or require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
	local K = Config.Lair
	local S = K.CellSize
	local T = K.WallThickness
	local rng = Random.new(seed or 1)
	local base = K.Origin + origin

	local function cellCentre(x, z)
		return base + Vector3.new(x * S, 0, z * S)
	end

	-- Which room owns each cell, and which cell edges are doors.
	local owner = {}
	for _, room in ipairs(K.Rooms) do
		for dx = 0, room.Size[1] - 1 do
			for dz = 0, room.Size[2] - 1 do
				owner[key(room.Cell[1] + dx, room.Cell[2] + dz)] = room
			end
		end
	end
	local doorSet = {}
	for _, d in ipairs(K.Doors) do
		doorSet[key(d[1][1], d[1][2]) .. "|" .. key(d[2][1], d[2][2])] = true
		doorSet[key(d[2][1], d[2][2]) .. "|" .. key(d[1][1], d[1][2])] = true
	end

	local rockColors = { C.RockDark, C.RockMid, C.RockLight }

	-- A wall along one cell edge, with an optional centred gap.
	local function wall(parent, centre, dir, height, gapWidth, gapHeight)
		local along = Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
		local mid = centre + dir * (S / 2 - T / 2)
		local function seg(name, len, offset, y0, y1)
			if len <= 0 or y1 <= y0 then
				return
			end
			local size = along * len
				+ Vector3.new(0, y1 - y0, 0)
				+ Vector3.new(math.abs(dir.X), 0, math.abs(dir.Z)) * T
			part(
				parent,
				name,
				size,
				CFrame.new(mid + along * offset + Vector3.new(0, (y0 + y1) / 2, 0)),
				rockColors[rng:NextInteger(1, 3)]
			)
		end
		if not gapWidth then
			seg("Wall", S, 0, 0, height)
		else
			local side = (S - gapWidth) / 2
			seg("Wall", side, -(gapWidth / 2 + side / 2), 0, height)
			seg("Wall", side, gapWidth / 2 + side / 2, 0, height)
			seg("Lintel", gapWidth, 0, gapHeight, height)
		end
		-- Chunky boulders leaning on the wall, kept clear of the gap.
		for _ = 1, 2 do
			local t = rng:NextNumber(-S / 2 + 6, S / 2 - 6)
			if not gapWidth or math.abs(t) > gapWidth / 2 + 6 then
				local sz = Vector3.new(
					rng:NextInteger(4, 8),
					rng:NextInteger(5, 12),
					rng:NextInteger(4, 8)
				)
				local pos = mid - dir * (T / 2 + 2) + along * t + Vector3.new(0, sz.Y / 2 - 1, 0)
				local cf = CFrame.new(pos)
					* CFrame.Angles(
						rng:NextNumber(-0.25, 0.25),
						rng:NextNumber(0, math.pi),
						rng:NextNumber(-0.25, 0.25)
					)
				part(parent, "Boulder", sz, cf, rockColors[rng:NextInteger(1, 3)])
			end
		end
	end

	local function strip(parent, a, b, width)
		local flatA = Vector3.new(a.X, base.Y + 0.1, a.Z)
		local flatB = Vector3.new(b.X, base.Y + 0.1, b.Z)
		local len = (flatB - flatA).Magnitude
		part(
			parent,
			"SoilPath",
			Vector3.new(width, 0.2, len + width),
			CFrame.lookAt((flatA + flatB) / 2, flatB),
			C.Soil,
			{ CanCollide = false }
		)
	end

	-- A hiding hollow: a root-and-rock U with a roof, open on its front (local -Z).
	local function hollow(parent, name, cf)
		local m = Instance.new("Model")
		m.Name = name
		m:SetAttribute("HidingSpot", true)
		part(m, "Back", Vector3.new(10, 9, 2), cf * CFrame.new(0, 4.5, 4), C.Roots)
		part(m, "Left", Vector3.new(2, 9, 8), cf * CFrame.new(-4, 4.5, 0), C.Roots)
		part(m, "Right", Vector3.new(2, 9, 8), cf * CFrame.new(4, 4.5, 0), C.Roots)
		part(
			m,
			"Roof",
			Vector3.new(12, 2, 10),
			cf * CFrame.new(0, 10, 0.5) * CFrame.Angles(0.08, 0, 0),
			C.Moss
		)
		part(
			m,
			"Zone",
			Vector3.new(6, 7, 6),
			cf * CFrame.new(0, 3.5, 0),
			C.Roots,
			{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true }
		)
		m.Parent = parent
		return m
	end

	-- Stage 2: a noise trap is a flat, invisible floor part tagged Config.Noise.TrapTag with a
	-- "Trap" attribute; NoiseService reads its radius and cooldown from Config.Noise.Traps.
	local function trapZone(parent, kind, pos)
		local r = Config.Noise.Traps[kind].TriggerRadius
		local zone = part(
			parent,
			"TrapZone",
			Vector3.new(0.2, r * 2, r * 2),
			CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			C.Floor,
			{
				Shape = Enum.PartType.Cylinder,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			}
		)
		zone:SetAttribute("Trap", kind)
		CollectionService:AddTag(zone, Config.Noise.TrapTag)
	end

	local function rootTangle(parent, pos)
		local m = Instance.new("Model")
		m.Name = "RootTangle"
		for i = 1, 5 do
			local cf = CFrame.new(
				pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.35, rng:NextNumber(-1.5, 1.5))
			) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.15, 0.15))
			part(
				m,
				"Root" .. i,
				Vector3.new(0.7, 0.5, rng:NextNumber(4, 6)),
				cf,
				C.Roots,
				{ CanCollide = false }
			)
		end
		trapZone(m, "Roots", pos)
		m.Parent = parent
	end

	local function bonePile(parent, pos)
		local m = Instance.new("Model")
		m.Name = "BonePile"
		trapZone(m, "Bones", pos)
		for i = 1, 4 do
			local cf = CFrame.new(
				pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.4, rng:NextNumber(-1.5, 1.5))
			) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3))
			part(
				m,
				"Bone" .. i,
				Vector3.new(0.6, 0.6, rng:NextNumber(2.5, 4)),
				cf,
				C.Bones,
				{ CanCollide = false }
			)
		end
		m.Parent = parent
	end

	local function standIn(parent, name, pos, facing)
		part(
			parent,
			name,
			Vector3.new(2, 5, 1),
			CFrame.lookAt(pos + Vector3.new(0, 2.5, 0), pos + Vector3.new(0, 2.5, 0) + facing),
			C.StandIn,
			{ CanCollide = false, CanQuery = false, Transparency = 0.2 }
		)
	end

	local lair = Instance.new("Model")
	lair.Name = "SFTB_Lair"
	lair:SetAttribute("Origin", origin)

	-- Rooms: floor, walls with doors, ceiling, boulders.
	local roomModels = {}
	for _, room in ipairs(K.Rooms) do
		local m = Instance.new("Model")
		m.Name = room.Name
		roomModels[room.Name] = m
		local height = room.Name == "Nest" and K.NestHeight or K.RoomHeight
		local w, d = room.Size[1] * S, room.Size[2] * S
		local minC = cellCentre(room.Cell[1], room.Cell[2])
		local centre = minC + Vector3.new((w - S) / 2, 0, (d - S) / 2)
		m:SetAttribute("Centre", centre)
		part(m, "Floor", Vector3.new(w, 4, d), CFrame.new(centre - Vector3.new(0, 2, 0)), C.Floor)
		part(
			m,
			"Ceiling",
			Vector3.new(w + 4, 4, d + 4),
			CFrame.new(centre + Vector3.new(0, height + 2, 0)),
			C.RockDark
		)
		for dx = 0, room.Size[1] - 1 do
			for dz = 0, room.Size[2] - 1 do
				local cx, cz = room.Cell[1] + dx, room.Cell[2] + dz
				local cc = cellCentre(cx, cz)
				for _, n in ipairs({
					Vector3.new(1, 0, 0),
					Vector3.new(-1, 0, 0),
					Vector3.new(0, 0, 1),
					Vector3.new(0, 0, -1),
				}) do
					local nx, nz = cx + n.X, cz + n.Z
					if owner[key(nx, nz)] ~= room then
						if room.Name == "Mouth" and n.Z == 1 then
							wall(m, cc, n, height, K.MouthWidth, K.MouthHeight)
						elseif doorSet[key(cx, cz) .. "|" .. key(nx, nz)] then
							wall(m, cc, n, height, K.DoorWidth, K.DoorHeight)
						else
							wall(m, cc, n, height)
						end
					end
				end
			end
		end
		m.Parent = lair
	end

	local function centreOf(name)
		return roomModels[name]:GetAttribute("Centre")
	end
	local mouthC, pathC, sideC, nestC =
		centreOf("Mouth"), centreOf("Path"), centreOf("Side"), centreOf("Nest")
	local half = S / 2

	-- Outside approach (where a crew arrives) with low rock edges so nobody wanders off.
	local outside = Instance.new("Model")
	outside.Name = "Approach"
	local approachC = mouthC + Vector3.new(0, 0, S)
	part(
		outside,
		"Ground",
		Vector3.new(S + 32, 4, S),
		CFrame.new(approachC - Vector3.new(0, 2, 0)),
		C.Soil
	)
	part(
		outside,
		"EdgeW",
		Vector3.new(4, 14, S),
		CFrame.new(approachC + Vector3.new(-(S / 2 + 14), 7, 0)),
		C.RockMid
	)
	part(
		outside,
		"EdgeE",
		Vector3.new(4, 14, S),
		CFrame.new(approachC + Vector3.new(S / 2 + 14, 7, 0)),
		C.RockMid
	)
	part(
		outside,
		"EdgeS",
		Vector3.new(S + 32, 14, 4),
		CFrame.new(approachC + Vector3.new(0, 7, S / 2 - 2)),
		C.RockMid
	)
	do -- Rock face around the mouth so it reads as a cave entrance.
		local wTotal, h = S + 32, K.RoomHeight + 16
		local zc = mouthC.Z + half + 3
		local sideW = (wTotal - K.MouthWidth) / 2
		part(
			outside,
			"CliffL",
			Vector3.new(sideW, h, 6),
			CFrame.new(mouthC.X - (K.MouthWidth / 2 + sideW / 2), base.Y + h / 2, zc),
			C.RockMid
		)
		part(
			outside,
			"CliffR",
			Vector3.new(sideW, h, 6),
			CFrame.new(mouthC.X + (K.MouthWidth / 2 + sideW / 2), base.Y + h / 2, zc),
			C.RockMid
		)
		part(
			outside,
			"CliffTop",
			Vector3.new(K.MouthWidth, h - K.MouthHeight, 6),
			CFrame.new(mouthC.X, base.Y + K.MouthHeight + (h - K.MouthHeight) / 2, zc),
			C.RockDark
		)
	end
	outside.Parent = lair

	-- Soil paths along both routes.
	local doorA = Vector3.new(pathC.X, base.Y, pathC.Z - half) -- Path > Nest
	local doorB = Vector3.new(sideC.X, base.Y, sideC.Z - half) -- Side > Nest
	local doorPS = Vector3.new(pathC.X - half, base.Y, pathC.Z) -- Path > Side
	strip(lair, approachC, Vector3.new(mouthC.X, base.Y, mouthC.Z - half), 8)
	strip(lair, Vector3.new(pathC.X, base.Y, pathC.Z + half), doorA, 6) -- route A
	strip(lair, pathC, doorPS, 6)
	strip(lair, doorPS, sideC, 6)
	strip(lair, sideC, doorB, 6) -- route B

	-- One root tangle (noise trap) on each route, on the soil path so it can be stepped round.
	rootTangle(roomModels.Path, Vector3.new(pathC.X, base.Y, pathC.Z - 12)) -- route A
	rootTangle(roomModels.Side, Vector3.new(sideC.X, base.Y, sideC.Z - 12)) -- route B

	-- Hiding spots: one on each route, plus one by each nest door.
	local spots = Instance.new("Folder")
	spots.Name = "HidingSpots"
	hollow(
		spots,
		"Hollow_Path",
		CFrame.lookAt(pathC + Vector3.new(half - 8, 0, 6), pathC + Vector3.new(-100, 0, 6))
	)
	hollow(
		spots,
		"Hollow_Side",
		CFrame.lookAt(sideC + Vector3.new(-half + 8, 0, 4), sideC + Vector3.new(100, 0, 4))
	)
	hollow(
		spots,
		"Hollow_NestA",
		CFrame.lookAt(doorA + Vector3.new(14, 0, -10), doorA + Vector3.new(-100, 0, -10))
	)
	hollow(
		spots,
		"Hollow_NestB",
		CFrame.lookAt(doorB + Vector3.new(-14, 0, -10), doorB + Vector3.new(100, 0, -10))
	)
	spots.Parent = lair

	-- The nest: root pillars for cover, bone piles, the eggs, the Hush stand-in.
	local nest = roomModels.Nest
	local hushPos = nestC + Vector3.new(0, 0, -10) -- just past the middle, facing the doors
	for _, off in ipairs({
		Vector3.new(-30, 0, 4),
		Vector3.new(30, 0, 4),
		Vector3.new(-32, 0, -30),
		Vector3.new(32, 0, -30),
	}) do
		local p = nestC + off
		part(
			nest,
			"RootPillar",
			Vector3.new(6, K.NestHeight, 6),
			CFrame.new(p + Vector3.new(0, K.NestHeight / 2, 0))
				* CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
			C.Roots
		)
	end
	for _, off in ipairs({
		Vector3.new(-12, 0, 8),
		Vector3.new(14, 0, 10),
		Vector3.new(-40, 0, -40),
		Vector3.new(28, 0, -44),
	}) do
		bonePile(nest, nestC + off)
	end

	-- Eggs on twig beds: near-white loot with a band in the parent's colour (teal, the Hush).
	local function eggOnBed(name, pos, kind)
		local size = Config.Egg[kind .. "Size"]
		local bed = Instance.new("Model")
		bed.Name = name
		local r = size * 1.6
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local p = pos + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
			part(
				bed,
				"Twig",
				Vector3.new(1, 1, r * 1.05),
				CFrame.lookAt(p, pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.pi / 2, 0),
				C.Roots,
				{ CanCollide = false }
			)
		end
		local egg = part(
			bed,
			"Egg",
			Vector3.new(size, size, size),
			CFrame.new(pos + Vector3.new(0, size / 2 + 0.3, 0)),
			C.Egg,
			{ Shape = Enum.PartType.Ball, CanCollide = false }
		)
		egg:SetAttribute("EggSize", kind)
		-- The band moves with the egg when it is carried (welded, not anchored).
		local band = part(
			bed,
			"Marking",
			Vector3.new(size * 0.18, size * 1.02, size * 1.02),
			egg.CFrame * CFrame.Angles(0, 0, math.pi / 2),
			C.HushTeal,
			{
				Shape = Enum.PartType.Cylinder,
				Anchored = false,
				Massless = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			}
		)
		band.Parent = egg
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = egg, band
		weld.Parent = band
		local eggLight = Instance.new("PointLight")
		eggLight.Color = C.Egg
		eggLight.Range = size * 4
		eggLight.Brightness = 0.8
		eggLight.Shadows = false
		eggLight.Parent = egg
		CollectionService:AddTag(egg, "SFTB_Egg")
		bed.Parent = nest
	end
	-- Small egg right under the beast's nose; the big two-carrier egg deeper in, behind it.
	eggOnBed("EggBed", hushPos + Vector3.new(0, 0, 22), "Small")
	eggOnBed("BigEggBed", nestC + Vector3.new(-20, 0, -38), "Big")

	-- The Hush stand-in: one chunky mass, eyeless, oversized teal ears, tiny claws (~30 tall).
	-- At run time HushService uses it for the Hush's home and as the look clients draw.
	local hush = Instance.new("Model")
	hush.Name = "HushStandIn"
	hush:SetAttribute("StandIn", true)
	local body = part(
		hush,
		"Body",
		Vector3.new(40, 22, 24),
		CFrame.new(hushPos + Vector3.new(0, 11, -4)),
		C.HushBody
	)
	part(
		hush,
		"Head",
		Vector3.new(16, 12, 12),
		CFrame.new(hushPos + Vector3.new(0, 7, 12)),
		C.HushBody
	)
	for _, sx in ipairs({ -1, 1 }) do
		part(
			hush,
			"Ear",
			Vector3.new(4, 14, 8),
			CFrame.new(hushPos + Vector3.new(sx * 6, 23, 10)) * CFrame.Angles(0, 0, -sx * 0.35),
			C.HushTeal,
			{ Material = Enum.Material.Neon }
		)
		part(
			hush,
			"Claw",
			Vector3.new(2, 1.5, 3),
			CFrame.new(hushPos + Vector3.new(sx * 5, 0.75, 19)),
			C.Bones
		)
	end
	local glow = Instance.new("PointLight")
	glow.Color = C.HushTeal
	glow.Range = 30
	glow.Brightness = 1.5
	glow.Shadows = false
	glow.Parent = body
	hush.PrimaryPart = body
	hush.Parent = nest

	-- 5-stud player stand-ins for scale shots: cave mouth and nest door (route A).
	local scale = Instance.new("Folder")
	scale.Name = "ScaleStandIns"
	standIn(
		scale,
		"Player_Mouth",
		Vector3.new(mouthC.X + 4, base.Y, mouthC.Z + half - 4),
		Vector3.new(0, 0, -1)
	)
	standIn(scale, "Player_NestDoor", doorA + Vector3.new(4, 0, -4), Vector3.new(0, 0, -1))
	scale.Parent = lair

	-- Where a crew arrives (inside the cave mouth, facing in: kickoff "spawn inside the lair
	-- mouth") and the line past the mouth that counts as out.
	local spawn = CFrame.lookAt(mouthC + Vector3.new(0, 3, 12), mouthC + Vector3.new(0, 3, -100))
	lair:SetAttribute("Spawn", spawn)
	lair:SetAttribute("EscapeZ", mouthC.Z + half + Config.Egg.EscapeMargin)
	return lair, spawn
end

return LairBuilder
