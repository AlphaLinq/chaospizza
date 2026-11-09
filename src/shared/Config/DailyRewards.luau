--!strict
-- Initial reward tuning; all claims must be committed with their new state.
export type Reward = { tips: number, xp: number, cosmetic: string? }
local function reward(tips: number, xp: number, cosmetic: string?): Reward
	return table.freeze({ tips = tips, xp = xp, cosmetic = cosmetic })
end
return table.freeze({
	requestTimeoutSeconds = 8,
	maxTips = 1e12,
	maxProgressAmount = 1000000,
	secondsPerDay = 86400,
	daysPerWeek = 7,
	mondayOffsetDays = 3,
	daily = table.freeze({
		reward(25, 0, nil),
		reward(50, 0, nil),
		reward(75, 0, nil),
		reward(100, 0, nil),
		reward(125, 0, nil),
		reward(150, 0, nil),
		reward(250, 25, "WeekOneJar"),
	}),
	weekly = table.freeze({
		selectionLimit = 3,
		challenges = table.freeze({
			table.freeze({
				id = "CityCourier",
				name = "Deliver 20 pizzas",
				event = "delivery",
				target = 20,
				tips = 250,
				xp = 50,
			}),
			table.freeze({
				id = "ChaosCourier",
				name = "Deliver 5 pizzas during chaos",
				event = "eventDelivery",
				target = 5,
				tips = 300,
				xp = 50,
			}),
			table.freeze({
				id = "NewFaces",
				name = "Meet 3 new customers",
				event = "newCustomer",
				target = 3,
				tips = 200,
				xp = 50,
			}),
			table.freeze({
				id = "LongRoute",
				name = "Deliver 50 pizzas",
				event = "delivery",
				target = 50,
				tips = 600,
				xp = 100,
			}),
			table.freeze({
				id = "StormShift",
				name = "Deliver 15 pizzas during chaos",
				event = "eventDelivery",
				target = 15,
				tips = 750,
				xp = 100,
			}),
			-- #207: the new loop (daredevil card, event challenges, finale)
			table.freeze({
				id = "DaredevilCourier",
				name = "Deliver 3 Daredevil orders",
				event = "daredevil",
				target = 3,
				tips = 400,
				xp = 75,
			}),
			table.freeze({
				id = "ChallengeHunter",
				name = "Complete 3 event challenges",
				event = "eventChallenge",
				target = 3,
				tips = 350,
				xp = 75,
			}),
			table.freeze({
				id = "FinaleSurvivor",
				name = "Deliver during a chaos finale",
				event = "finale",
				target = 1,
				tips = 300,
				xp = 50,
			}),
			-- #240: the new moves (pizza toss #236, convoy #232)
			table.freeze({
				id = "Yeeter",
				name = "Toss 10 pizzas",
				event = "toss",
				target = 10,
				tips = 300,
				xp = 50,
			}),
			table.freeze({
				id = "ConvoyCrew",
				name = "Make 3 convoys",
				event = "convoy",
				target = 3,
				tips = 300,
				xp = 50,
			}),
		}),
	}),
})
