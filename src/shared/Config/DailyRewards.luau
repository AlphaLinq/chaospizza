--!strict
-- Initial reward tuning; all claims must be committed with their new state.
return table.freeze({
	secondsPerDay = 86400,
	daysPerWeek = 7,
	mondayOffsetDays = 3,
	daily = table.freeze({
		table.freeze({ tips = 25, xp = 0 }),
		table.freeze({ tips = 50, xp = 0 }),
		table.freeze({ tips = 75, xp = 0 }),
		table.freeze({ tips = 100, xp = 0 }),
		table.freeze({ tips = 125, xp = 0 }),
		table.freeze({ tips = 150, xp = 0 }),
		table.freeze({ tips = 250, xp = 25 }),
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
		}),
	}),
})
