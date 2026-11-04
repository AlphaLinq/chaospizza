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
	boosts: { [string]: number },
	pendingEffects: { { id: string, kind: string, key: string, createdAt: number } },
	sessions: { count: number, lastDay: number },
	onboardingDone: boolean,
	settings: { music: number, sfx: number, effects: "low" | "normal" },
}
local ProfileSchema = { VERSION = 2 }
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
		boosts = {},
		pendingEffects = {},
		sessions = { count = 0, lastDay = 0 },
		onboardingDone = false,
		settings = { music = 1, sfx = 1, effects = "normal" },
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
	for key, expires in record(source.boosts) do
		if
			id(key)
			and type(expires) == "number"
			and expires == expires
			and expires >= 0
			and expires < math.huge
		then
			profile.boosts[key] = integer(expires, 0)
		end
	end
	local effectIds: { [string]: boolean } = {}
	for _, effect in ipairs(record(source.pendingEffects)) do
		if #profile.pendingEffects >= 20 then
			break
		end
		if
			type(effect) == "table"
			and id(effect.id)
			and id(effect.kind)
			and id(effect.key)
			and not effectIds[effect.id]
		then
			effectIds[effect.id] = true
			table.insert(profile.pendingEffects, {
				id = effect.id,
				kind = effect.kind,
				key = effect.key,
				createdAt = integer(effect.createdAt, 0),
			})
		end
	end
	local sessions = record(source.sessions)
	profile.sessions =
		{ count = integer(sessions.count, 0), lastDay = integer(sessions.lastDay, 0) }
	profile.onboardingDone = source.onboardingDone == true
	local settings = record(source.settings)
	local function volume(value: any): number
		return if type(value) == "number"
				and value == value
				and math.abs(value) < math.huge
			then math.clamp(value, 0, 1)
			else 1
	end
	profile.settings = {
		music = volume(settings.music),
		sfx = volume(settings.sfx),
		effects = if settings.effects == "low" then "low" else "normal",
	}
	return profile
end
return ProfileSchema
