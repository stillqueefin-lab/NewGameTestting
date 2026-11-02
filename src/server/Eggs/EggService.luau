--!strict
-- Stage 4: egg grab, carry and escape. Lair parts tagged SFTB_Egg are the eggs
-- (attribute EggSize "Small" or "Big"). Grab with a ProximityPrompt; the egg is welded in
-- front of the carrier, who gets slower (SFTB_CarrySpeed, read by Controls) and louder
-- (SFTB_Carrying, read by NoiseService). The big egg needs two: the front carrier holds and
-- steers, the back carrier must stay close or loses grip. Out past the cave mouth = escaped.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local Guard = require(
	ServerScriptService:WaitForChild("SFTBServer")
		:WaitForChild("Infrastructure")
		:WaitForChild("ActionGuard")
)
local remotes = ReplicatedStorage:WaitForChild("SFTBRemotes")
local Toast = remotes:WaitForChild("Toast") :: RemoteEvent
local EggDropPass = remotes:WaitForChild("EggDropPass") :: RemoteEvent

local E = Config.Egg
local C = Config.Carry
local K = Config.Lair

type Egg = {
	Part: BasePart,
	Size: string,
	Home: CFrame,
	Prompt: ProximityPrompt,
	Front: Player?,
	Back: Player?,
	Weld: WeldConstraint?,
}

local EggService = {}

-- Stage 11 hook: return true to keep the egg when caught (Rescue). Off for now.
EggService.KeepOnCaught = function(_player: Player): boolean
	return false
end

local eggs: { Egg } = {}
local holding: { [Player]: Egg } = {}
local hasRun: { [Player]: boolean } = {} -- this session; Stage 8 saves it
local escapeZ = math.huge
local noise: any -- NoiseService
local hush: any -- HushService

local function hrpOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if hrp and humanoid and humanoid.Health > 0 then hrp else nil
end

local function setCarry(player: Player, size: string?, speed: number?)
	player:SetAttribute("SFTB_Carrying", size)
	player:SetAttribute("SFTB_CarrySpeed", speed)
end

-- Who holds it decides speed and the prompt text.
local function refresh(egg: Egg)
	local front, back = egg.Front, egg.Back
	if egg.Size == "Big" then
		local speed = if back then C.BigSpeedMultiplier else C.BigAloneSpeedMultiplier
		if front then
			setCarry(front, "Big", speed)
		end
		if back then
			setCarry(back, "Big", speed)
		end
		egg.Prompt.ActionText = if front then "Help carry" else "Grab"
		egg.Prompt.Enabled = back == nil
	else
		if front then
			setCarry(front, "Small", C.SmallSpeedMultiplier)
		end
		egg.Prompt.ActionText = "Grab"
		egg.Prompt.Enabled = front == nil
	end
end

local function weldTo(egg: Egg, player: Player)
	local hrp = hrpOf(player)
	if not hrp then
		return
	end
	if egg.Weld then
		egg.Weld:Destroy()
	end
	egg.Part.Anchored = false
	egg.Part.Massless = true
	egg.Part.CFrame = hrp.CFrame * CFrame.new(C.HoldOffset[egg.Size])
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = hrp, egg.Part
	weld.Parent = egg.Part
	egg.Weld = weld
end

local function release(egg: Egg)
	for _, p in ipairs({ egg.Front, egg.Back }) do
		if p then
			holding[p] = nil
			setCarry(p, nil, nil)
		end
	end
	egg.Front, egg.Back = nil, nil
	if egg.Weld then
		egg.Weld:Destroy()
		egg.Weld = nil
	end
end

-- Drop the egg on the floor where it is. It thuds (noise the Hush can hear).
function EggService.Drop(egg: Egg, by: Player?)
	local pos = egg.Part.Position
	release(egg)
	-- One floor for now: it lands at the height it sat on its bed.
	local rest = Vector3.new(pos.X, egg.Home.Y, pos.Z)
	egg.Part.Anchored = true
	egg.Part.CFrame = CFrame.new(rest)
	refresh(egg)
	noise.Emit(rest, E.DropNoiseRadius, "EggDrop", by)
end

local function reset(egg: Egg)
	release(egg)
	egg.Part.Anchored = true
	egg.Part.CFrame = egg.Home
	refresh(egg)
end

local function grab(egg: Egg, player: Player)
	if holding[player] or not Guard.Near(player, egg.Part, E.GrabPromptDistance + 4) then
		return
	end
	if not egg.Front then
		egg.Front = player
		holding[player] = egg
		weldTo(egg, player)
		if egg.Size == "Big" then
			Toast:FireClient(player, E.NeedsTwoText, E.SuccessSeconds)
		end
	elseif egg.Size == "Big" and not egg.Back then
		egg.Back = player
		holding[player] = egg
	else
		return
	end
	refresh(egg)
	if not hasRun[player] then
		hasRun[player] = true
		task.delay(E.FirstRunChaseDelay, function()
			local hrp = hrpOf(player)
			if hrp and holding[player] then
				hush.ScriptedChase(hrp.Position)
			end
		end)
	end
end

-- Drop/Pass: hand a small egg to the nearest free crewmate in reach, else drop it.
local function dropPass(player: Player)
	if not Guard.Allow(player, "EggDropPass", C.DropPassCooldown) then
		return
	end
	local egg = holding[player]
	if not egg then
		return
	end
	if egg.Size == "Small" then
		local hrp = hrpOf(player)
		local best: Player?, bestD = nil, C.PassDistance
		for _, other in ipairs(Players:GetPlayers()) do
			local ohrp = other ~= player and not holding[other] and hrpOf(other)
			if hrp and ohrp then
				local d = (ohrp.Position - hrp.Position).Magnitude
				if d <= bestD then
					best, bestD = other, d
				end
			end
		end
		if best then
			release(egg)
			egg.Front = best
			holding[best] = egg
			weldTo(egg, best)
			refresh(egg)
			return
		end
	end
	EggService.Drop(egg, player)
end

local function onCaught(player: Player, _feet: Vector3)
	local egg = holding[player]
	if egg and E.DropOnCaught and not EggService.KeepOnCaught(player) then
		EggService.Drop(egg, nil)
	end
end

local function update()
	for _, egg in ipairs(eggs) do
		local front, back = egg.Front, egg.Back
		if front then
			local hrp = hrpOf(front)
			local backHrp = back and hrpOf(back)
			if not hrp then
				EggService.Drop(egg, nil) -- died or left mid-carry
			elseif
				back
				and (
					not backHrp
					or (backHrp.Position - egg.Part.Position).Magnitude > C.BigHoldDistance
				)
			then
				EggService.Drop(egg, back) -- the back carrier lost grip: the big egg falls
			elseif hrp.Position.Z > escapeZ then
				for _, p in ipairs({ front, back }) do
					if p then
						Toast:FireClient(p, E.SuccessText, E.SuccessSeconds)
					end
				end
				-- Until hatching exists (Stage 6), the egg goes back to its bed, locked for a moment.
				reset(egg)
				egg.Prompt.Enabled = false
				task.delay(E.ResetSeconds, function()
					refresh(egg)
				end)
			end
		end
	end
end

function EggService.Start(noiseService: any, hushService: any)
	noise, hush = noiseService, hushService
	for _, room in ipairs(K.Rooms) do
		if room.Name == "Mouth" then
			escapeZ = K.Origin.Z + room.Cell[2] * K.CellSize + K.CellSize / 2 + E.EscapeMargin
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "SFTB_Eggs"
	folder.Parent = workspace
	for _, part in ipairs(CollectionService:GetTagged("SFTB_Egg")) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = "Egg"
			prompt.MaxActivationDistance = E.GrabPromptDistance
			prompt.HoldDuration = E.GrabHoldSeconds
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			local egg: Egg = {
				Part = part,
				Size = if part:GetAttribute("EggSize") == "Big" then "Big" else "Small",
				Home = part.CFrame,
				Prompt = prompt,
			}
			part.Parent = folder
			table.insert(eggs, egg)
			refresh(egg)
			prompt.Triggered:Connect(function(player)
				grab(egg, player)
			end)
		end
	end
	EggDropPass.OnServerEvent:Connect(dropPass)
	hushService.Caught:Connect(onCaught)
	Players.PlayerRemoving:Connect(function(player)
		local egg = holding[player]
		if egg then
			EggService.Drop(egg, nil)
		end
		hasRun[player] = nil
	end)
	RunService.Heartbeat:Connect(update)
end

return EggService
