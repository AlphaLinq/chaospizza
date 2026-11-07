--!strict
return table.freeze({
	runs = 30,
	seed = 75083,
	pizzeriaOddsBonusPerLevel = 0.1,
	maxSeconds = 12 * 3600,
	month = 12,
	day = 15,
	-- Order choice board (#185): how often a modelled courier takes the far
	-- card (best-of-N rarity, long-haul tip, but the trip takes longer) and,
	-- during an event, the Daredevil card.
	offers = table.freeze({ farShare = 0.35, farTimeFactor = 1.4, daredevilShare = 0.3 }),
	-- Loop extras: share of events whose challenge the courier completes, of
	-- finales they deliver in, and of those where they are the hero.
	loopExtras = table.freeze({ challengeShare = 0.4, finaleShare = 0.6, heroShare = 0.15 }),
	scenarios = table.freeze({
		{
			name = "Átlagos",
			deliverySeconds = 70,
			accidentChance = 0.2,
			airChance = 0.02,
			fast = false,
			paid = false,
		},
		{
			name = "Lelkes",
			deliverySeconds = 40,
			accidentChance = 0.05,
			airChance = 0.15,
			fast = true,
			paid = false,
		},
		{
			name = "Költő",
			deliverySeconds = 40,
			accidentChance = 0.05,
			airChance = 0.15,
			fast = true,
			paid = true,
		},
	}),
})
