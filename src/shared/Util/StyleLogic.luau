--!strict
export type Facts = {
	airborne: boolean?,
	secondsSinceSharkZone: number?,
	secondsSinceHorseLane: number?,
	secondsSinceCheeseJump: number?,
	secondsSinceBubbleRide: number?,
	hadAccident: boolean?,
	seconds: number?,
	targetSeconds: number?,
	giantOrderClean: boolean?,
}
type Config = { hazardWindowSeconds: number, tags: { { id: string, name: string, bonus: number } } }
local StyleLogic = {}
local function nonnegative(value: number?): boolean
	return value ~= nil and value == value and value >= 0 and value < math.huge
end
function StyleLogic.evaluate(
	facts: Facts,
	config: Config,
	maxBonus: number
): { tags: { string }, bonus: number }
	local function recent(seconds: number?): boolean
		return nonnegative(seconds) and (seconds :: number) <= config.hazardWindowSeconds
	end
	local active: { [string]: boolean } = {
		AirDelivery = facts.airborne == true,
		SharkEscape = recent(facts.secondsSinceSharkZone),
		Hoofbeat = recent(facts.secondsSinceHorseLane),
		Flawless = facts.hadAccident == false,
		Lightning = nonnegative(facts.seconds)
			and nonnegative(facts.targetSeconds)
			and (facts.seconds :: number) < (facts.targetSeconds :: number),
		Juggler = facts.giantOrderClean == true,
		CheeseJump = recent(facts.secondsSinceCheeseJump),
		BubbleRider = recent(facts.secondsSinceBubbleRide),
	}
	local tags: { string } = {}
	local total = 0
	for _, tag in config.tags do
		if active[tag.id] then
			table.insert(tags, tag.id)
			total += tag.bonus
		end
	end
	return { tags = tags, bonus = math.min(total, if nonnegative(maxBonus) then maxBonus else 0) }
end
function StyleLogic.new(config: Config, maxBonus: number)
	return {
		evaluate = function(facts: Facts)
			return StyleLogic.evaluate(facts, config, maxBonus)
		end,
	}
end
return StyleLogic
