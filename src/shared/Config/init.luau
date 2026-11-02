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

-- Stage 2: noise model (stick tilt sets speed and noise). Starting values; tune in Play.
-- Stick and touch are analog: the Humanoid scales WalkSpeed by tilt, so analog players get
-- RunSpeed and a gentle push is a sneak. Keyboard: walk by default, Shift sneak, Ctrl run.
-- The server never asks the client its tier: it reads real horizontal speed and bands it.
Config.Noise = {
	SneakSpeed = 8, -- keyboard speeds (studs/s); analog players reach any speed up to RunSpeed
	WalkSpeed = 12,
	RunSpeed = 18,
	MinSpeed = 2, -- below this the server counts you as standing still (no steps)
	SneakMaxSpeed = 10, -- server tier bands from measured speed
	WalkMaxSpeed = 15,
	TeleportSpeed = 60, -- a jump faster than this between samples is a respawn/teleport, ignored
	SampleSeconds = 0.1, -- server speed sample rate
	SpeedSmoothing = 0.5, -- 0-1, share of each new sample (stops one laggy sample flipping tiers)
	StepStuds = 6, -- one footstep (noise event) per this many studs moved
	SneakRadius = 6, -- studs of noise ring per step
	WalkRadius = 14,
	RunRadius = 28,
	CarryNoiseMultiplier = 1.5, -- Stage 4 sets the player attribute "SFTB_Carrying"
	TrapTag = "SFTB_NoiseTrap", -- tagged floor parts with a "Trap" attribute naming an entry below
	TrapHeight = 6, -- studs above a trap that still count as standing on it
	Traps = {
		Bones = { Radius = 30, TriggerRadius = 3, Cooldown = 4 },
		Roots = { Radius = 20, TriggerRadius = 3.5, Cooldown = 4 },
	},
}

-- Stage 2: noise rings (client visual). Colour is a neutral stone grey, not a light-language
-- colour yet (proposed for the style sheet): it is not amber, teal or near-white.
Config.NoiseRing = {
	Color = Color3.fromHex("A39F8E"),
	Thickness = 0.5, -- studs; footstep ring width
	TrapThickness = 1.2, -- traps draw a heavier ring
	Lift = 0.15, -- studs above the floor
	StartTransparency = 0.2,
	GrowSeconds = 0.35,
	FadeSeconds = 0.5,
	TrapFadeSeconds = 0.9,
	PoolSize = 32, -- most rings alive at once; extra events are skipped
	MaxDistance = 160, -- skip rings this far from the camera
}

-- Stage 2: haptics for loud noise you make (phone and gamepad).
Config.Haptics = {
	MinRadius = 20, -- buzz for your own noise at least this loud (runs and traps)
}

-- Stage 2: controls. One Input Action System map for a run. No crouch button, no jump.
-- Phone: max 3 buttons in a run (Power, Ping, Drop/Pass only while carrying).
Config.Controls = {
	SneakKeys = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	RunKeys = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
	Power = { Key = Enum.KeyCode.Q, Gamepad = Enum.KeyCode.ButtonR1, Label = "Power" },
	Ping = { Key = Enum.KeyCode.F, Gamepad = Enum.KeyCode.ButtonL1, Label = "Ping" },
	DropPass = { Key = Enum.KeyCode.G, Gamepad = Enum.KeyCode.ButtonY, Label = "Drop" },
	Hint = {
		Touch = "Push the stick gently to sneak",
		Gamepad = "Tilt the stick gently to sneak",
		KeyboardAndMouse = "Hold Shift to sneak, Ctrl to run",
	},
	KeyHint = {
		Gamepad = "RB Power   LB Ping",
		KeyboardAndMouse = "Q Power   F Ping",
	},
	HintSneakSeconds = 3, -- the hint fades after this much sneaking (server-read tier)
	ButtonSize = 0.15, -- phone buttons, share of screen height
	StubToastSeconds = 1.5, -- Power and Ping are stubs until Stages 6 and 10
}

-- Stage 3: The Hush (hunts by sound only). Starting values; tune in Play.
-- Hearing rule players can read: if a noise ring reaches its ears, it heard you.
-- Each heard noise adds suspicion points; enough points stir it, more alert it.
-- It always plays Alert (the warning) before it hunts. It stays in the nest (too big for the doors).
Config.Hush = {
	BodyHeight = 30, -- studs; style sheet scale
	EarForward = 14, -- studs ahead of the body centre where the head and ears are
	EarReach = 3, -- a noise is heard when its ring radius + this reaches the ears
	HeardPoints = { Sneak = 0.5, Walk = 1, Run = 2, Bones = 3, Roots = 2, EggDrop = 3, Default = 1 },
	ScriptedHuntSpeed = 9, -- first-run scripted chase: slow, and it never catches
	ScriptedAlertSeconds = 1.5,
	SuspicionDecay = 0.25, -- points lost per second
	StirThreshold = 1, -- suspicion points to stir (ears turn, glow lifts, no moving)
	AlertThreshold = 3, -- suspicion points to alert, then hunt
	AlertSeconds = 2, -- warning before every scare: glow pulses, ears snap, body turns, no moving
	HuntSpeed = 16, -- studs/s; a runner (18) can outrun it, a walker (12) can't
	ReturnSpeed = 8,
	TurnSpeed = 1.6, -- radians/s while moving; a big body turns slowly
	AlertTurnSpeed = 3,
	LoseInterestSeconds = 8, -- searching at the last noise before it gives up
	BackToSleepSeconds = 15, -- quiet time before a stirred Hush settles back to sleep
	NestInset = 18, -- keeps the body centre this far inside the nest walls
	PathAgentRadius = 6,
	ArriveDistance = 4,
	StuckSeconds = 2.5, -- no progress this long while moving: give up and search there
	CatchRadius = 10, -- from the head, for players it heard in the last NoisyMemorySeconds
	TouchRadius = 13, -- from the body centre; walking into it always counts
	NoisyMemorySeconds = 2.5,
	SwatWindup = 0.5, -- seconds between the wind-up and the blow (dodge window)
	SwatReach = 13, -- still this close to the head when the swat lands
	SwatCooldown = 1.5,
	SwatForce = 55, -- studs/s shove on the ragdoll
	CaughtSeconds = 3, -- ragdoll time before you respawn at the mouth
	SlimeSeconds = 8,
	SlimeColor = Color3.fromHex("4FE3D0"), -- beast-coloured slime (Mild, no blood)
	-- Client look: glow level and ear pitch per state (negative pitch = ears laid back).
	Glow = { Sleep = 0.35, Stir = 0.7, Alert = 1.6, Hunt = 1.3, Search = 1, Return = 0.6 },
	EarPitch = { Sleep = -0.9, Stir = -0.4, Alert = 0.15, Hunt = 0.1, Search = 0, Return = -0.5 },
	PulseStates = { Alert = true, Hunt = true },
	PulseSpeed = 8, -- radians/s of the alert pulse
	PulseAmount = 0.35,
	EarYawMax = 1.0, -- radians the ears can turn toward a noise
	EarSnapSpeed = 14, -- how fast ears follow in Alert/Hunt (others: EarEaseSpeed)
	EarEaseSpeed = 3,
	LightBrightness = 1.5, -- the body glow light at glow level 1
	CaughtText = "Caught! It heard %s.",
	HeardText = {
		Sneak = "you sneak too close",
		Walk = "you walking",
		Run = "you running",
		Bones = "the bones",
		Roots = "the roots",
		Touch = "you bump into it",
		EggDrop = "the egg drop",
	},
}

-- Stage 4: eggs. Lair parts tagged SFTB_Egg are the eggs (attribute EggSize = "Small" | "Big").
Config.Egg = {
	SmallSize = 2, -- studs; near-white, slow pulse, teal markings
	BigSize = 4,
	GrabPromptDistance = 8,
	GrabHoldSeconds = 0.3,
	DropOnCaught = true, -- Stage 11 Rescue can keep it instead (EggService.KeepOnCaught hook)
	DropNoiseRadius = 22, -- a dropped egg thuds
	EscapeMargin = 6, -- studs past the cave mouth that count as out
	ResetSeconds = 5, -- after an escape the egg goes back to its bed (until hatching exists)
	FirstRunChaseDelay = 3, -- seconds after a player's first grab before the scripted stir
	SuccessText = "You got out with the egg!",
	SuccessSeconds = 4,
	NeedsTwoText = "Too heavy alone. A crewmate can help carry it.",
}

-- Stage 4: carrying. Carrying is slower (Controls) and louder (NoiseService).
-- Big egg: the front carrier holds and steers; the back carrier must stay within
-- BigHoldDistance of the egg or loses grip and it drops.
Config.Carry = {
	SmallSpeedMultiplier = 0.8,
	BigSpeedMultiplier = 0.65,
	BigAloneSpeedMultiplier = 0, -- one person can't move the big egg
	BigCarriers = 2, -- front player steers, back player holds
	BigHoldDistance = 10,
	PassDistance = 10, -- Drop/Pass hands a small egg to the nearest free crewmate this close
	HoldOffset = { Small = Vector3.new(0, 0.3, -2.2), Big = Vector3.new(0, 0.5, -3.6) },
	DropPassCooldown = 0.5, -- Action Guard interval on the Drop/Pass remote
}

-- Stages 6 and 8: hatching, Listen power, incubators.
-- Escape with an egg: the crew is taken to camp and it hatches with the egg build-up
-- (wobble, harder wobble, swell, white flash, pop). The Hushling follows its owner.
Config.Hatch = {
	FreeIncubatorSlots = 2,
	MaxIncubatorSlots = 4,
	HatchSeconds = 600,
	ListenSeconds = 4, -- the Hush shows through walls this long
	ListenCooldown = 30,
	ListenShareRadius = 60, -- crewmates this close see it too
	UsePowerInterval = 0.3, -- Action Guard interval on the power remote
	RevealSeconds = 2.6, -- whole hatch reveal; the follower appears after it
	RevealDistance = 7, -- egg sits this far in front of you
	FadeSeconds = 0.35, -- fade that hides the trip to camp
	HatchedText = "A Hushling hatched!",
	PowerText = { KeyboardAndMouse = "Q", Gamepad = "RB", Touch = "Power" },
	ListenText = "Listening...",
	NoPowerText = "Steal an egg and hatch a Hushling to use its power",
	-- Hushling: a small Hush. Big head, big low eyes, stubby legs, the parent's teal ears.
	FollowOffset = Vector3.new(2.5, 0, 3), -- behind and to the right of its owner
	FollowSharpness = 6,
	BreatheSpeed = 2.4, -- radians/s
	BreatheAmount = 0.08, -- studs
	BlinkEvery = 3.2, -- seconds
	EyeColor = Color3.fromHex("151816"),
}

-- Camp (greybox from the block-out at x = 400). Crews arrive here after a run.
Config.Camp = {
	Centre = Vector3.new(400, 0, 0),
	Arrive = Vector3.new(400, 3, -11), -- by the fire, facing it
	ArriveSpread = 4,
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
