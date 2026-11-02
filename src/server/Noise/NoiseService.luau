--!strict
-- Stage 2 noise model. The server reads each character's real horizontal speed (never the
-- client's word), bands it into a tier, and emits a footstep every Config.Noise.StepStuds.
-- Noise traps (tagged floor parts) emit when a player steps onto them, with a per-trap cooldown.
-- Stage 3's Hush listens on NoiseService.Noise; every client gets each event for the rings.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local NoiseEvent =
	ReplicatedStorage:WaitForChild("SFTBRemotes"):WaitForChild("NoiseEvent") :: UnreliableRemoteEvent

local N = Config.Noise

export type Tier = "Still" | "Sneak" | "Walk" | "Run"

type State = {
	LastPos: Vector3?,
	Speed: number,
	Travel: number,
	OnTrap: { [BasePart]: boolean },
}

local NoiseService = {}

-- Fires (position: Vector3, radius: number, source: string, player: Player?) for every noise.
local noiseSignal = Instance.new("BindableEvent")
NoiseService.Noise = noiseSignal.Event

local states: { [Player]: State } = {}
local trapReadyAt: { [BasePart]: number } = {}

function NoiseService.TierFor(speed: number): Tier
	if speed < N.MinSpeed then
		return "Still"
	elseif speed <= N.SneakMaxSpeed then
		return "Sneak"
	elseif speed <= N.WalkMaxSpeed then
		return "Walk"
	end
	return "Run"
end

-- Any system can make noise (Stage 4: a dropped egg). Radius is in studs.
function NoiseService.Emit(position: Vector3, radius: number, source: string, player: Player?)
	noiseSignal:Fire(position, radius, source, player)
	NoiseEvent:FireAllClients(position, radius, source, player and player.UserId or 0)
end

-- Stage 4 hook: carrying an egg makes every step and trap louder.
local function loudness(player: Player): number
	return if player:GetAttribute("SFTB_Carrying") then N.CarryNoiseMultiplier else 1
end

local function checkTraps(player: Player, state: State, feet: Vector3, now: number)
	for _, trap in ipairs(CollectionService:GetTagged(N.TrapTag)) do
		if trap:IsA("BasePart") and trap:IsDescendantOf(workspace) then
			local kind = N.Traps[trap:GetAttribute("Trap") :: any]
			local offset = feet - trap.Position
			local on = kind ~= nil
				and math.abs(offset.Y) <= N.TrapHeight
				and Vector2.new(offset.X, offset.Z).Magnitude <= kind.TriggerRadius
			-- Only stepping on fires it; standing on it doesn't, and the cooldown stops spam.
			if on and not state.OnTrap[trap] and now >= (trapReadyAt[trap] or 0) then
				trapReadyAt[trap] = now + kind.Cooldown
				NoiseService.Emit(
					trap.Position,
					kind.Radius * loudness(player),
					trap:GetAttribute("Trap") :: string,
					player
				)
			end
			state.OnTrap[trap] = on or nil
		end
	end
end

local function sample(player: Player, state: State, dt: number, now: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		state.LastPos, state.Speed, state.Travel = nil, 0, 0
		return
	end
	local pos = root.Position
	local last = state.LastPos
	state.LastPos = pos
	if not last then
		return
	end
	local moved = Vector2.new(pos.X - last.X, pos.Z - last.Z).Magnitude
	if moved / dt > N.TeleportSpeed then
		return
	end
	state.Speed += (moved / dt - state.Speed) * N.SpeedSmoothing
	-- Carrying slows you (SFTB_CarrySpeed); read the tier as if you weren't, so a carried run is still a run.
	local carrySpeed = player:GetAttribute("SFTB_CarrySpeed")
	local scale = if type(carrySpeed) == "number" and carrySpeed > 0 then carrySpeed else 1
	local tier = NoiseService.TierFor(state.Speed / scale)
	if player:GetAttribute("SFTB_NoiseTier") ~= tier then
		player:SetAttribute("SFTB_NoiseTier", tier) -- replicated, for the client hint and tests
	end

	local feet = pos - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	if tier == "Still" then
		state.Travel = 0
	else
		state.Travel += moved
		if state.Travel >= N.StepStuds then
			state.Travel -= N.StepStuds
			if humanoid.FloorMaterial ~= Enum.Material.Air then
				NoiseService.Emit(feet, N[tier .. "Radius"] * loudness(player), tier, player)
			end
		end
	end
	checkTraps(player, state, feet, now)
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		-- The client sets its own speed from input; this is the default the server agrees on.
		humanoid.WalkSpeed = N.WalkSpeed
		humanoid.JumpHeight = 0 -- no free jump
		humanoid.JumpPower = 0
	end
end

local function watch(player: Player)
	states[player] = { Speed = 0, Travel = 0, OnTrap = {} }
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function NoiseService.Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(N.SampleSeconds)
			local now = os.clock()
			local dt = now - last
			last = now
			for player, state in pairs(states) do
				sample(player, state, dt, now)
			end
		end
	end)
end

return NoiseService
