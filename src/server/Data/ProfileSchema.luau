-- Profile shape and migrations (Stage 8: hatchlings, incubators, escapes, crew level).
-- Normalize must accept anything (nil, old versions, bad values) and return a valid profile.
local Schema = {}

function Schema.Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = Schema.Copy(item)
	end
	return out
end

local function integer(value, default, min, max)
	value = tonumber(value)
	if value == nil or value ~= value or math.abs(value) == math.huge then
		return default
	end
	return math.clamp(math.floor(value), min, max)
end

function Schema.Normalize(source, now)
	local data = type(source) == "table" and Schema.Copy(source) or {}
	data.Version = 1
	-- Stage 8: hatchlings {Id, Kind, FromBig, Born} and incubators {Id, EggSize, ReadyAt};
	-- anything malformed is dropped. Timers are absolute os.time(), so they run offline.
	local hatchlings = {}
	for _, h in ipairs(type(data.Hatchlings) == "table" and data.Hatchlings or {}) do
		if type(h) == "table" and type(h.Id) == "string" and type(h.Kind) == "string" then
			h.Born = integer(h.Born, now, 0, now)
			h.FromBig = h.FromBig == true
			table.insert(hatchlings, h)
		end
	end
	data.Hatchlings = hatchlings
	local incubators = {}
	for _, e in ipairs(type(data.Incubators) == "table" and data.Incubators or {}) do
		if
			type(e) == "table"
			and type(e.Id) == "string"
			and (e.EggSize == "Small" or e.EggSize == "Big")
		then
			e.ReadyAt = integer(e.ReadyAt, now, 0, now + 86400 * 7)
			table.insert(incubators, e)
		end
	end
	data.Incubators = incubators
	data.Escapes = integer(data.Escapes, 0, 0, 1e7)
	data.FirstRunDone = data.FirstRunDone == true
	data.CrewLevel = integer(data.CrewLevel, 1, 1, 1000)
	data.LastFreeRescueDay = integer(data.LastFreeRescueDay, 0, 0, 1000000)
	data.PurchaseReceipts = type(data.PurchaseReceipts) == "table" and data.PurchaseReceipts or {}
	local lastSeen = integer(data.LastSeen, now, 0, now)
	local offline = { Seconds = math.max(0, now - lastSeen) }
	data.LastSeen = now
	return data, offline
end

return Schema
