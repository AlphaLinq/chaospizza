--!strict
-- Only known, serializable fields survive migration; callers keep their input.
export type Profile = {
	version: number,
	claims: { [string]: number },
	progressRewards: { book: { [string]: boolean }, level: number },
	likes: { day: number, from: { [string]: boolean } },
	tips: number,
	xp: number,
	deliveries: number,
	customerBook: { [string]: { served: number, stars: number, quirk: boolean? } },
	pizzeriaLevel: number,
	regulars: { string },
	movementTier: number,
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	purchases: { [string]: number },
	lastSeen: number,
	firstSeen: number,
	weeklyDeliveries: { week: number, count: number },
	weekly: {
		week: number,
		lastUpdate: number,
		selected: { [string]: { progress: number, claimed: boolean } },
	},
	dailyLogin: { day: number, lastClaim: number },
	boosts: { [string]: number },
	pendingEffects: { { id: string, kind: string, key: string, eventId: string?, createdAt: number } },
	sessions: { count: number, lastDay: number },
	-- Golden pepperoni (#132): UTC day of `active`, all-time found ids.
	collectibles: { day: number, found: { [string]: boolean }, active: { string } },
	onboardingDone: boolean,
	settings: {
		music: number,
		sfx: number,
		effects: "low" | "normal",
		quality: string?,
		textSize: string,
	},
}
local ProfileSchema = { VERSION = 7 }
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
		claims = {},
		progressRewards = { book = {}, level = 1 },
		likes = { day = 0, from = {} },
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
		firstSeen = 0,
		weeklyDeliveries = { week = 0, count = 0 },
		weekly = { week = 0, lastUpdate = 0, selected = {} },
		dailyLogin = { day = 0, lastClaim = 0 },
		boosts = {},
		pendingEffects = {},
		sessions = { count = 0, lastDay = 0 },
		collectibles = { day = 0, found = {}, active = {} },
		onboardingDone = false,
		settings = { music = 1, sfx = 1, effects = "normal", textSize = "normal" },
	}
end
function ProfileSchema.migrate(raw: any): Profile
	local source = record(raw)
	local profile = ProfileSchema.default()
	for key, timestamp in record(source.claims) do
		if
			id(key)
			and #key <= 160
			and type(timestamp) == "number"
			and timestamp == timestamp
			and timestamp >= 0
			and timestamp < math.huge
		then
			profile.claims[key] = integer(timestamp, 0)
		end
	end
	local likes = record(source.likes)
	profile.likes.day = integer(likes.day, 0)
	local likeCount = 0
	for key, liked in record(likes.from) do
		if likeCount >= 2048 then
			break
		end
		if
			type(key) == "string"
			and string.match(key, "^[1-9]%d*$")
			and #key <= 16
			and liked == true
		then
			profile.likes.from[key] = true
			likeCount += 1
		end
	end
	local rewards = record(source.progressRewards)
	profile.progressRewards.level = integer(rewards.level, 1, 1)
	for key, claimed in record(rewards.book) do
		if id(key) and claimed == true then
			profile.progressRewards.book[key] = true
		end
	end
	profile.tips = integer(source.tips, 0)
	profile.xp = integer(source.xp, 0)
	profile.deliveries = integer(source.deliveries, 0)
	profile.pizzeriaLevel = integer(source.pizzeriaLevel, 1, 1, 6)
	profile.movementTier = integer(source.movementTier, 0, 0, 4)
	profile.lastSeen = integer(source.lastSeen, 0)
	profile.firstSeen = integer(source.firstSeen, 0)
	local deliveries = record(source.weeklyDeliveries)
	profile.weeklyDeliveries =
		{ week = integer(deliveries.week, 0), count = integer(deliveries.count, 0) }
	local weekly = record(source.weekly)
	profile.weekly.week = integer(weekly.week, 0)
	profile.weekly.lastUpdate = integer(weekly.lastUpdate, 0)
	local selectedCount = 0
	for key, entry in record(weekly.selected) do
		if selectedCount >= 3 then
			break
		end
		if id(key) and type(entry) == "table" then
			profile.weekly.selected[key] =
				{ progress = integer(entry.progress, 0), claimed = entry.claimed == true }
			selectedCount += 1
		end
	end
	local daily = record(source.dailyLogin)
	profile.dailyLogin =
		{ day = integer(daily.day, 0, 0, 7), lastClaim = integer(daily.lastClaim, 0) }
	for key, entry in record(source.customerBook) do
		if id(key) and type(entry) == "table" then
			profile.customerBook[key] = {
				served = integer(entry.served, 0),
				stars = integer(entry.stars, 0, 0, 5),
				quirk = if entry.quirk == true then true else nil, -- #139
			}
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
				eventId = if id(effect.eventId) then effect.eventId else nil,
				createdAt = integer(effect.createdAt, 0),
			})
		end
	end
	local sessions = record(source.sessions)
	profile.sessions =
		{ count = integer(sessions.count, 0), lastDay = integer(sessions.lastDay, 0) }
	local collectibles = record(source.collectibles)
	local found: { [string]: boolean } = {}
	for key, value in record(collectibles.found) do
		if id(key) and value == true then
			found[key] = true
		end
	end
	local active: { string } = {}
	for _, value in record(collectibles.active) do
		if id(value) and #active < 30 and not table.find(active, value) then
			table.insert(active, value)
		end
	end
	profile.collectibles = { day = integer(collectibles.day, 0), found = found, active = active }
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
		textSize = if settings.textSize == "large" then "large" else "normal",
		music = volume(settings.music),
		sfx = volume(settings.sfx),
		effects = if settings.effects == "low" then "low" else "normal",
		quality = if settings.quality == "low"
				or settings.quality == "medium"
				or settings.quality == "high"
			then settings.quality
			else nil,
	}
	return profile
end
return ProfileSchema
