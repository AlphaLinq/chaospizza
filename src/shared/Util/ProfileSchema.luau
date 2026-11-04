--!strict
-- Only known, serializable fields survive migration; callers keep their input.
export type Profile = {
	version: number,
	tips: number,
	xp: number,
	deliveries: number,
	customerBook: { [string]: { served: number, stars: number } },
	pizzeriaLevel: number,
	regulars: { string },
	movementTier: number,
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	purchases: { [string]: number },
	lastSeen: number,
	dailyLogin: { day: number, lastClaim: number },
}
local ProfileSchema = { VERSION = 1 }
local MAX_INTEGER = 9007199254740991
local function integer(value: any, fallback: number, low: number?, high: number?): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.clamp(math.floor(value), low or 0, high or MAX_INTEGER)
end
local function record(value: any): any
	return if type(value) == "table" then value else {}
end
local function id(value: any): boolean
	return type(value) == "string" and #value > 0 and utf8.len(value) ~= nil
end
function ProfileSchema.default(): Profile
	return {
		version = ProfileSchema.VERSION,
		tips = 0,
		xp = 0,
		deliveries = 0,
		customerBook = {},
		pizzeriaLevel = 1,
		regulars = {},
		movementTier = 0,
		cosmetics = { owned = {}, equipped = {} },
		purchases = {},
		lastSeen = 0,
		dailyLogin = { day = 0, lastClaim = 0 },
	}
end
function ProfileSchema.migrate(raw: any): Profile
	local source = record(raw)
	local profile = ProfileSchema.default()
	profile.tips = integer(source.tips, 0)
	profile.xp = integer(source.xp, 0)
	profile.deliveries = integer(source.deliveries, 0)
	profile.pizzeriaLevel = integer(source.pizzeriaLevel, 1, 1, 6)
	profile.movementTier = integer(source.movementTier, 0, 0, 4)
	profile.lastSeen = integer(source.lastSeen, 0)
	local daily = record(source.dailyLogin)
	profile.dailyLogin =
		{ day = integer(daily.day, 0, 0, 7), lastClaim = integer(daily.lastClaim, 0) }
	for key, entry in record(source.customerBook) do
		if id(key) and type(entry) == "table" then
			profile.customerBook[key] =
				{ served = integer(entry.served, 0), stars = integer(entry.stars, 0, 0, 5) }
		end
	end
	local seen: { [string]: boolean } = {}
	for _, key in ipairs(record(source.regulars)) do
		if id(key) and not seen[key] and profile.customerBook[key] then
			seen[key] = true
			table.insert(profile.regulars, key)
		end
	end
	local cosmetics = record(source.cosmetics)
	for key, owned in record(cosmetics.owned) do
		if id(key) and owned == true then
			profile.cosmetics.owned[key] = true
		end
	end
	for slot, key in record(cosmetics.equipped) do
		if id(slot) and id(key) and profile.cosmetics.owned[key] then
			profile.cosmetics.equipped[slot] = key
		end
	end
	for key, timestamp in record(source.purchases) do
		-- Never turn a corrupt entry into a valid receipt, or a purchase could be lost.
		if
			id(key)
			and type(timestamp) == "number"
			and timestamp == timestamp
			and timestamp >= 0
			and timestamp < math.huge
		then
			profile.purchases[key] = integer(timestamp, 0)
		end
	end
	return profile
end
return ProfileSchema
