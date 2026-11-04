--!strict
-- Inject Config tables once; this module has no engine or require dependency.
type Config = {
	xpBase: number,
	xpGrowth: number,
	passiveBasePerMinute: number,
	starBonus: number,
	maxStars: number,
	offlineSeconds: number,
	offlineRate: number,
	passOfflineSeconds: number,
	passOfflineRate: number,
	passRegularSlots: number,
}
type Rarity = { id: string, passiveMultiplier: number }
type PizzeriaLevel = { level: number, cost: number, regularSlots: number }
local Progression = {}
local function valid(value: number): boolean
	return value == value and math.abs(value) < math.huge
end
function Progression.new(config: Config, rarities: { Rarity }, levels: { PizzeriaLevel })
	assert(config.xpBase > 0 and config.xpGrowth > 0, "XP curve must increase")
	local api = {}
	function api.xpForLevel(level: number): number
		if not valid(level) or level < 1 then
			return 0
		end
		local steps = math.floor(level) - 1
		return steps * config.xpBase + config.xpGrowth * steps * (steps - 1) / 2
	end
	function api.levelFromXp(xp: number): number
		if not valid(xp) or xp <= 0 then
			return 1
		end
		local b = config.xpBase - config.xpGrowth / 2
		local steps =
			math.floor((-b + math.sqrt(b * b + 2 * config.xpGrowth * xp)) / config.xpGrowth)
		-- Correct floating-point rounding at exact boundaries.
		if api.xpForLevel(steps + 1) > xp then
			steps -= 1
		end
		if api.xpForLevel(steps + 2) <= xp then
			steps += 1
		end
		return steps + 1
	end
	function api.passivePerMinute(rarityId: string, stars: number): number
		local count = if valid(stars) then math.clamp(math.floor(stars), 0, config.maxStars) else 0
		for _, rarity in rarities do
			if rarity.id == rarityId then
				return config.passiveBasePerMinute
					* rarity.passiveMultiplier
					* (1 + config.starBonus * count)
			end
		end
		return 0
	end
	-- Returns whole tips and credited seconds. No rounding up small claims.
	function api.offlineEarnings(
		ratePerMinute: number,
		lastSeen: number,
		now: number,
		hasPass: boolean
	): (number, number)
		if
			not valid(ratePerMinute)
			or ratePerMinute < 0
			or not valid(lastSeen)
			or lastSeen <= 0
			or not valid(now)
			or now < lastSeen
		then
			return 0, 0
		end
		local seconds = math.min(
			now - lastSeen,
			if hasPass then config.passOfflineSeconds else config.offlineSeconds
		)
		local rate = if hasPass then config.passOfflineRate else config.offlineRate
		return math.floor(ratePerMinute * seconds / 60 * rate), seconds
	end
	function api.canUpgradePizzeria(level: number, tips: number): boolean
		if not valid(level) or level % 1 ~= 0 or not valid(tips) or tips < 0 then
			return false
		end
		for _, entry in levels do
			if entry.level == level + 1 and level >= 1 then
				return tips >= entry.cost
			end
		end
		return false
	end
	function api.regularSlots(level: number, hasPass: boolean): number
		for _, entry in levels do
			if entry.level == level then
				return entry.regularSlots + (if hasPass then config.passRegularSlots else 0)
			end
		end
		return 0
	end
	return api
end
return Progression
