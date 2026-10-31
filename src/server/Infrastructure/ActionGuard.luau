-- Per-player, per-action rate limiter plus alive/near checks (from Grow a Golem).
-- Every remote handler calls Allow before doing anything.
local Guard = {}
local buckets = setmetatable({}, { __mode = "k" })

function Guard.Allow(player, action, interval)
	if not player or not player.Parent or player:GetAttribute("SessionClosing") then
		return false
	end
	local now = os.clock()
	local actions = buckets[player]
	if not actions then
		actions = {}
		buckets[player] = actions
	end
	if now < (actions[action] or 0) then
		return false
	end
	actions[action] = now + (interval or 0.25)
	return true
end

-- Rejects NaN, infinity and non-numbers before any remote uses a number.
function Guard.Number(value, min, max)
	return type(value) == "number" and value == value and value >= min and value <= max
end

function Guard.Alive(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and humanoid and humanoid.Health > 0 and not player:GetAttribute("SessionClosing")
end

function Guard.Near(player, part, distance)
	if not Guard.Alive(player) or not part or not part:IsDescendantOf(workspace) then
		return false
	end
	local delta = (player.Character.HumanoidRootPart.Position - part.Position).Magnitude
	return delta == delta and delta <= (distance or 14)
end

function Guard.Cleanup(player)
	buckets[player] = nil
end
return Guard
