--!strict
local EconomySimulator = {}
function EconomySimulator.run(m: any, scenario: any, seed: number, horizon: number): any
	local function rng(): number
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local p = m.schema.default()
	p.tips = m.daily.daily[1].tips
	p.firstSeen = 1000
	local passes = { DoubleTips = scenario.paid }
	if scenario.paid then
		m.boosts.apply(p, m.boosts.find("StarterPack"), "sim-starter", 1000)
		m.boosts.apply(p, m.boosts.find("PizzaScentCloud"), "sim-scent", 1000)
	end
	local result: any = { finalBook = 0, finalLevel = 1, deliveries = 0 }
	local function upgrade(seconds: number)
		while p.pizzeriaLevel < #m.pizzeria and p.tips >= m.pizzeria[p.pizzeriaLevel + 1].cost do
			p.tips -= m.pizzeria[p.pizzeriaLevel + 1].cost
			p.pizzeriaLevel += 1
			result.firstUpgrade = result.firstUpgrade or seconds
			if p.pizzeriaLevel == #m.pizzeria then
				result.tower = result.tower or seconds
			end
		end
	end
	upgrade(0)
	local calm = (m.tuning.Events.calmMinSeconds + m.tuning.Events.calmMaxSeconds) / 2
	local warning = (m.tuning.Events.warningMinSeconds + m.tuning.Events.warningMaxSeconds) / 2
	local active = (m.tuning.Events.activeMinSeconds + m.tuning.Events.activeMaxSeconds) / 2
	local cleanup = (m.tuning.Events.cleanupMinSeconds + m.tuning.Events.cleanupMaxSeconds) / 2
	local cycle = calm + warning + active + cleanup
	local events = {}
	for _, event in m.events do
		if event.enabled and m.season.isActive(event.season, m.config.month, m.config.day) then
			table.insert(events, event.id)
		end
	end
	local byId: any = {}
	for _, customer in m.customers do
		byId[customer.id] = customer
	end
	-- Loop extras (#200, #186, #208): event challenges, chaos finale, finale hero.
	local extras = m.config.loopExtras
	local lastChallengeCycle, lastFinale = -1, 0
	for seconds = scenario.deliverySeconds, horizon, scenario.deliverySeconds do
		local rates = {}
		for id, entry in p.customerBook do
			table.insert(rates, m.progression.passivePerMinute(byId[id].rarity, entry.stars))
		end
		table.sort(rates, function(a: number, b: number)
			return a > b
		end)
		local passive = 0
		for i = 1, math.min(#rates, m.progression.regularSlots(p.pizzeriaLevel, false)) do
			passive += rates[i]
		end
		p.tips += passive * scenario.deliverySeconds / 60 * (if scenario.paid then 2 else 1)
		local inEvent = seconds % cycle >= calm + warning
			and seconds % cycle < calm + warning + active
		local mega = seconds >= m.tuning.ChaosMeter.targetMinutesToFill * 60
			and seconds % (m.tuning.ChaosMeter.targetMinutesToFill * 60)
				< m.tuning.ChaosMeter.megaDurationSeconds
		local event = if (inEvent or mega) and #events > 0
			then events[math.floor(seconds / cycle) % #events + 1]
			else nil
		local mode = if mega then "mega" else if inEvent then "event" else "normal"
		if extras then
			local cycleIndex = math.floor(seconds / cycle)
			if inEvent and cycleIndex ~= lastChallengeCycle then
				lastChallengeCycle = cycleIndex
				if rng() < extras.challengeShare then
					p.tips += m.tuning.Challenges.tips
				end
			end
			local finaleIndex = math.floor(seconds / m.tuning.Finale.intervalSeconds)
			if finaleIndex > lastFinale then
				lastFinale = finaleIndex
				if rng() < extras.finaleShare then
					p.tips += m.tuning.Finale.bonusTips
					if rng() < extras.heroShare then
						p.tips += m.tuning.Finale.heroTips or 0
					end
				end
			end
		end
		local modifiers = m.boosts.oddsModifiers({}, p.boosts, 1000 + seconds)
		modifiers.pizzeriaLevelBonus = math.max(0, p.pizzeriaLevel - 3)
			* m.progressionConfig.pizzeriaOddsBonusPerLevel
		-- Order choice board (#185): far = best-of-N rarity and a long-haul tip
		-- spread over a longer trip (fixed steps, so pay per time); Daredevil
		-- only during events.
		local offers = m.config.offers
		local daredevil = offers ~= nil and inEvent and rng() < offers.daredevilShare
		local far = offers ~= nil and not daredevil and rng() < offers.farShare
		local rarity = m.odds.rollRarity(mode, m.rarities, modifiers, rng)
		if far then
			local rank: any = {}
			for _, r in m.rarities do
				rank[r.id] = r.order
			end
			for _ = 2, m.tuning.Offers.farRarityRolls do
				local again = m.odds.rollRarity(mode, m.rarities, modifiers, rng)
				if rank[again] > rank[rarity] then
					rarity = again
				end
			end
		end
		local offerMultiplier = if daredevil
			then m.tuning.Offers.daredevilMultiplier
			elseif far then m.tuning.Offers.farTipMultiplier / offers.farTimeFactor
			else 1
		local id = m.odds.pickCustomer(m.customers, rarity, event, rng)
		if id then
			local entry = p.customerBook[id] or { served = 0, stars = 0 }
			entry.served += 1
			entry.stars = math.min(m.progressionConfig.maxStars, entry.served - 1)
			p.customerBook[id] = entry
		end
		local style = m.style.evaluate({
			airborne = rng() < scenario.airChance,
			hadAccident = rng() < scenario.accidentChance,
			seconds = scenario.deliverySeconds,
			targetSeconds = scenario.deliverySeconds * (if scenario.fast then 1.1 else 0.8),
		}, m.styleConfig.style, m.tuning.Style.maxTotalBonus)
		-- Night shift (#217): the last part of every in-game day.
		local day = m.tuning.DayCycle
		local night = day ~= nil
			and (seconds % day.periodSeconds) / day.periodSeconds
				>= day.dawnShare + day.dayShare + day.duskShare
		local bonus = math.min(
			m.tuning.Style.maxTotalBonus,
			style.bonus
				+ (if inEvent or mega then m.tuning.Events.tipBonusDuringEvent else 0)
				+ (if night then day.nightTipBonus else 0)
		)
		p.tips += math.floor(m.tuning.Orders.baseTip * (1 + bonus) * offerMultiplier + 0.5) * (if mega
			then m.tuning.ChaosMeter.megaTipMultiplier
			else 1) * m.boosts.tipMultiplier(passes, p.boosts, 1000 + seconds)
		p.xp += m.tuning.Orders.baseXp
		p.deliveries += 1
		m.rewards.claim(p)
		upgrade(seconds)
		local known = 0
		for _ in p.customerBook do
			known += 1
		end
		if known == #m.customers then
			result.book = result.book or seconds
		end
		assert(p.tips >= 0 and p.tips == p.tips, "invalid economy balance")
		result.finalBook, result.finalLevel, result.deliveries =
			known, p.pizzeriaLevel, p.deliveries
		if result.tower and result.book then
			break
		end
	end
	return result
end
return EconomySimulator
