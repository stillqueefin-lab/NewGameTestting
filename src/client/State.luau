--!strict
-- The local player's saved state as the server last sent it (DataService.GetClientState):
-- Hatchlings, Incubators, CrewLevel, Escapes. Read-only on the client; the server decides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateChanged =
	ReplicatedStorage:WaitForChild("SFTBRemotes"):WaitForChild("StateChanged") :: RemoteEvent

local State = {}

local current: any = { Hatchlings = {}, Incubators = {}, CrewLevel = 1, Escapes = 0 }
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

function State.Get(): any
	return current
end

StateChanged.OnClientEvent:Connect(function(state: unknown)
	if type(state) == "table" then
		current = state
		changed:Fire(current)
	end
end)

return State
