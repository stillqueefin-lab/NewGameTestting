--!strict
-- Every tunable in the game lives here (Config Module Pattern). No hardcoded numbers in systems.
-- Values marked "placeholder" are starting guesses; the stage that builds the system tunes them in Play.

local Config = {}

Config.GameName = "Steal From the Beast"
Config.ServerSize = 12 -- kickoff: 12-player servers, crews of 1-4

-- Saving (Data Saving and Session Locking). Stage 8 fills in the profile.
Config.Data = {
	StoreName = "SFTB_Profiles_v1",
	StudioUsesLiveData = false, -- Studio saves to a separate "_Studio" store
	ProfileVersion = 1,
	SessionLeaseSeconds = 300,
	AutosaveSeconds = 120,
}

-- Stage 1: lair kit grid (decided 2026-11-01). Every lair room snaps to this grid so
-- Stage 9 (room shuffle) can swap rooms. A cell is one room footprint.
Config.Lair = {
	GridSnap = 4, -- studs; room edges, doors and big props snap to this
	CellSize = 48, -- studs; one room footprint is CellSize x CellSize
	WallThickness = 2, -- each room owns a 2-stud wall on its side of a shared edge (4 studs total)
	RoomHeight = 24, -- ceiling of a normal room
	NestHeight = 44, -- ceiling of the nest (2 x 2 cells), fits the ~30-stud Hush
	DoorWidth = 8, -- two carriers with a 4-stud big egg fit through
	DoorHeight = 12,
	MouthWidth = 16, -- the cave mouth to the outside
	MouthHeight = 16,
	Origin = Vector3.new(0, 0, 0), -- centre of cell (0, 0) at floor level
	-- Fixed layout for now (no shuffle until Stage 9). Cells are {x, z}; -z is deeper.
	-- Mouth and Nest stay fixed; Path and Side are the two slots Stage 9 will shuffle.
	Rooms = {
		{ Name = "Mouth", Cell = { 0, 0 }, Size = { 1, 1 } },
		{ Name = "Path", Cell = { 0, -1 }, Size = { 1, 1 } },
		{ Name = "Side", Cell = { -1, -1 }, Size = { 1, 1 } },
		{ Name = "Nest", Cell = { -1, -3 }, Size = { 2, 2 } }, -- Cell is the min corner
	},
	-- Doors sit on the shared edge of two cells, centred on that edge.
	-- Route A: Mouth > Path > Nest. Route B: Mouth > Path > Side > Nest.
	Doors = {
		{ { 0, 0 }, { 0, -1 } }, -- Mouth - Path (straight sight line to the Hush)
		{ { 0, -1 }, { 0, -2 } }, -- Path - Nest (route A)
		{ { 0, -1 }, { -1, -1 } }, -- Path - Side
		{ { -1, -1 }, { -1, -2 } }, -- Side - Nest (route B)
	},
}

-- Stage 1: the crew flashlight. Amber is "us"; it is the only shadow-casting light per player.
Config.Flashlight = {
	Color = Color3.fromRGB(255, 179, 71), -- #FFB347, light language: crew
	Brightness = 2.5,
	Range = 60,
	Angle = 55,
	ShadowsForOthers = false, -- other players' lights skip shadows (phone cost)
}

-- Stage 1: loot pulse. Eggs pulse slowly so they read without colour (red-weak players).
Config.EggPulse = {
	Seconds = 1.6, -- one half-cycle
	MinBrightness = 0.3,
	MaxBrightness = 1.4,
}

-- Stage 2: noise model (stick tilt sets speed and noise). Placeholders.
Config.Noise = {
	SneakSpeed = 8,
	WalkSpeed = 12,
	RunSpeed = 18,
	SneakRadius = 6, -- studs of noise ring per step
	WalkRadius = 14,
	RunRadius = 28,
	CarryNoiseMultiplier = 1.5,
	Traps = {
		Bones = { Radius = 30 },
		Roots = { Radius = 20 },
	},
}

-- Stage 3: The Hush (hunts by sound only). Placeholders.
Config.Hush = {
	BodyHeight = 30, -- studs; style sheet scale
	HearingRadius = 60,
	StirThreshold = 1, -- noise events before it stirs
	AlertThreshold = 3,
	AlertSeconds = 2, -- warning before every scare
	HuntSpeed = 20,
	LoseInterestSeconds = 8,
	BackToSleepSeconds = 15,
}

-- Stage 4: eggs. Placeholders.
Config.Egg = {
	SmallSize = 2, -- studs; near-white, slow pulse
	BigSize = 4,
	GrabPromptDistance = 8,
	DropOnCaught = true,
}

-- Stage 4: carrying. Placeholders.
Config.Carry = {
	SmallSpeedMultiplier = 0.8,
	BigSpeedMultiplier = 0.65,
	BigCarriers = 2, -- front player steers, back player holds
	PassDistance = 10,
}

-- Stages 6 and 8: hatching, Listen power, incubators. Placeholders.
Config.Hatch = {
	FreeIncubatorSlots = 2,
	MaxIncubatorSlots = 4,
	HatchSeconds = 600,
	ListenSeconds = 4,
	ListenCooldown = 30,
}

-- Stage 11: shop. Prices are read live from Roblox; only ids live here.
Config.Shop = {
	RescueProductId = 0, -- developer product, about 25-45 Robux
	HatchSkipProductId = 0,
	IncubatorPassId = 0,
	FreeRescuesPerDay = 1,
	NoShopPopupSeconds = 180, -- no shop popups in the first 3 minutes
}

return Config
