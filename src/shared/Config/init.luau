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
