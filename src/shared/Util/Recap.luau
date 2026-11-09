--!strict
-- Pure shift-report logic (#234): per-courier stats for one finale round
-- and the card's headline. No Roblox APIs (tests/run.luau).

local Recap = {}

export type Stats = {
	deliveries: number,
	tips: number,
	bestStreak: number,
	daredevils: number,
	events: number,
	rarestOrder: number, -- Config/Rarities order, 0 = none yet
	rarestRarity: string?,
	rarestName: string?,
}

export type Report = {
	headline: string,
	deliveries: number,
	tips: number,
	bestStreak: number,
	daredevils: number,
	events: number,
	challenges: number,
	rarestRarity: string?,
	rarestName: string?,
	hero: boolean,
}

function Recap.new(): Stats
	return {
		deliveries = 0,
		tips = 0,
		bestStreak = 0,
		daredevils = 0,
		events = 0,
		rarestOrder = 0,
	}
end

function Recap.addDelivery(
	stats: Stats,
	tips: number,
	streak: number,
	daredevil: boolean,
	rarityOrder: number?,
	rarity: string?,
	customerName: string?
)
	stats.deliveries += 1
	stats.tips += math.max(0, math.floor(tips))
	stats.bestStreak = math.max(stats.bestStreak, streak)
	if daredevil then
		stats.daredevils += 1
	end
	if rarityOrder and rarityOrder > stats.rarestOrder then
		stats.rarestOrder = rarityOrder
		stats.rarestRarity = rarity
		stats.rarestName = customerName
	end
end

-- Headline from the most remarkable thing this round (first match wins).
-- legendaryOrder = the order of the Legendary rarity.
function Recap.headline(
	stats: Stats,
	hero: boolean,
	challenges: number,
	legendaryOrder: number
): string
	if hero then
		return "🏆 Finale Hero!"
	elseif stats.rarestOrder >= legendaryOrder then
		return "🌟 Legend Whisperer"
	elseif stats.daredevils >= 3 then
		return "🔥 Certified Daredevil"
	elseif stats.bestStreak >= 8 then
		return "⚡ Unstoppable"
	elseif challenges >= 3 then
		return "🎯 Challenge Hunter"
	elseif stats.deliveries >= 15 then
		return "📦 Delivery Machine"
	elseif stats.events >= 4 then
		return "🌪️ Chaos Survivor"
	end
	return "🍕 Solid Shift!"
end

-- nil when there is nothing to report (no deliveries this round).
function Recap.report(
	stats: Stats,
	hero: boolean,
	challenges: number,
	legendaryOrder: number
): Report?
	if stats.deliveries <= 0 then
		return nil
	end
	return {
		headline = Recap.headline(stats, hero, challenges, legendaryOrder),
		deliveries = stats.deliveries,
		tips = stats.tips,
		bestStreak = stats.bestStreak,
		daredevils = stats.daredevils,
		events = stats.events,
		challenges = math.max(0, challenges),
		rarestRarity = stats.rarestRarity,
		rarestName = stats.rarestName,
		hero = hero,
	}
end

return Recap
