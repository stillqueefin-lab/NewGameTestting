--!strict
-- Stage 3 beast sense: hearing. One module per sense, so later beasts mix senses
-- (Glimmer: light, Snuffle: smell) instead of rebuilding the beast.
-- The rule players can read off the noise rings: if a ring reaches the ears, it was heard.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SFTBShared"):WaitForChild("Config"))
local H = Config.Hush

local Hearing = {}

-- Suspicion points a noise adds, or 0 if it didn't reach the ears. Flat distance: one floor.
function Hearing.Points(ears: Vector3, position: Vector3, radius: number, source: string): number
	local d = Vector2.new(position.X - ears.X, position.Z - ears.Z).Magnitude
	if d > radius + H.EarReach then
		return 0
	end
	return H.HeardPoints[source] or H.HeardPoints.Default
end

return Hearing
