-- Profile shape and migrations. Stage 8 adds hatchlings, incubators and crew level.
-- Normalize must accept anything (nil, old versions, bad values) and return a valid profile.
local Schema = {}

function Schema.Copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = Schema.Copy(item) end
	return out
end

local function integer(value, default, min, max)
	value = tonumber(value)
	if value == nil or value ~= value or math.abs(value) == math.huge then return default end
	return math.clamp(math.floor(value), min, max)
end

function Schema.Normalize(source, now)
	local data = type(source) == "table" and Schema.Copy(source) or {}
	data.Version = 1
	data.Hatchlings = type(data.Hatchlings) == "table" and data.Hatchlings or {}
	data.Incubators = type(data.Incubators) == "table" and data.Incubators or {}
	data.CrewLevel = integer(data.CrewLevel, 1, 1, 1000)
	data.LastFreeRescueDay = integer(data.LastFreeRescueDay, 0, 0, 1000000)
	data.PurchaseReceipts = type(data.PurchaseReceipts) == "table" and data.PurchaseReceipts or {}
	local lastSeen = integer(data.LastSeen, now, 0, now)
	local offline = { Seconds = math.max(0, now - lastSeen) }
	data.LastSeen = now
	return data, offline
end

return Schema
