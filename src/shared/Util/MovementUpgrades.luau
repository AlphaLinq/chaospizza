--!strict
-- An intent includes its target tier, so a repeated click cannot buy another tier.
type Tier = {
	tier: number,
	displayName: string,
	speedBonus: number,
	cost: number,
	requiredCourierLevel: number,
}
local MovementUpgrades = {}
function MovementUpgrades.new(
	tiers: { Tier },
	maxSpeedBonus: number,
	levelFromXp: (number) -> number
)
	local byTier: { [number]: Tier } = {}
	for _, entry in tiers do
		assert(not byTier[entry.tier], "duplicate movement tier")
		assert(entry.cost >= 0 and entry.cost % 1 == 0, "invalid movement price")
		assert(
			entry.speedBonus >= 0 and entry.speedBonus <= maxSpeedBonus,
			"movement speed exceeds cap"
		)
		byTier[entry.tier] = entry
	end
	assert(byTier[0] ~= nil, "missing base movement tier")
	local api = {}
	function api.get(tier: number): Tier?
		return byTier[tier]
	end
	function api.effective(profile: any, earlyScooter: boolean): Tier
		local tier = if earlyScooter then byTier[4] else byTier[profile.movementTier]
		return tier or byTier[0]
	end
	function api.canBuy(profile: any, target: number, earlyScooter: boolean): (boolean, string)
		local entry = byTier[target]
		if earlyScooter then
			return false, "Your pass already unlocks the E-Scooter."
		end
		if not entry or target ~= profile.movementTier + 1 then
			return false, "Choose your next ride upgrade."
		end
		if levelFromXp(profile.xp) < entry.requiredCourierLevel then
			return false, `Reach courier level {entry.requiredCourierLevel} first.`
		end
		if profile.tips < entry.cost then
			return false, `Save {entry.cost} tips for this ride.`
		end
		return true, "Ready to upgrade."
	end
	function api.buy(profile: any, target: number, earlyScooter: boolean): (boolean, string)
		local allowed, reason = api.canBuy(profile, target, earlyScooter)
		if not allowed then
			return false, reason
		end
		local entry = byTier[target]
		profile.tips -= entry.cost
		profile.movementTier = target
		return true, `{entry.displayName} unlocked!`
	end
	function api.catalog(profile: any, earlyScooter: boolean): { any }
		local result: { any } = {}
		local effective = api.effective(profile, earlyScooter).tier
		for _, entry in tiers do
			local allowed, reason = api.canBuy(profile, entry.tier, earlyScooter)
			table.insert(result, {
				tier = entry.tier,
				name = entry.displayName,
				speedBonus = entry.speedBonus,
				cost = entry.cost,
				level = entry.requiredCourierLevel,
				owned = entry.tier <= profile.movementTier or earlyScooter,
				active = entry.tier == effective,
				available = allowed,
				reason = reason,
			})
		end
		return result
	end
	return api
end
return MovementUpgrades
