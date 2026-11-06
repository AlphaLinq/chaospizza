--!strict
-- Wishing well (#162): once per UTC day toss tips into the Fountain Square
-- basin for a random, funny buff. Tips only (no Robux), odds shown in the UI.
-- Bigger tosses make the buff last longer and the money-back outcomes bigger.

export type Tier = { amount: number, minutes: number }
export type Outcome = {
	id: "LuckyTips" | "GoldenCompass" | "Jackpot" | "Splash",
	name: string,
	weight: number,
	text: string, -- shown on the result card
}

return table.freeze({
	daySeconds = 86400,
	claimKey = "wish.day", -- profile.claims key (UTC day of the last wish)
	maxDistance = 18, -- studs from the basin centre
	luckyTipsBonus = 0.1, -- +10% delivery tips while active
	jackpotMultiplier = 2, -- tips back
	splashRefund = 0.25, -- tips back
	tiers = table.freeze({
		table.freeze({ amount = 50, minutes = 5 }),
		table.freeze({ amount = 200, minutes = 15 }),
		table.freeze({ amount = 500, minutes = 30 }),
	}) :: { Tier },
	outcomes = table.freeze({
		table.freeze({
			id = "LuckyTips",
			name = "Lucky Tips",
			weight = 50,
			text = "+10% tips on every delivery",
		}),
		table.freeze({
			id = "GoldenCompass",
			name = "Golden Compass",
			weight = 25,
			text = "An arrow points to your nearest golden pepperoni",
		}),
		table.freeze({
			id = "Jackpot",
			name = "Jackpot!",
			weight = 10,
			text = "The fountain spits back double your tips",
		}),
		table.freeze({
			id = "Splash",
			name = "Big Splash",
			weight = 15,
			text = "You get soaked… and a quarter of your tips back",
		}),
	}) :: { Outcome },
})
