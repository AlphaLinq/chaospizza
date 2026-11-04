--!strict
-- Pizzeria levels (brief ch. 11). Shape: Types.PizzeriaLevelDef.

return table.freeze({
	table.freeze({
		level = 1,
		displayName = "Food Cart",
		cost = 0,
		regularSlots = 1,
		unlocks = table.freeze({}),
	}),
	table.freeze({
		level = 2,
		displayName = "Pizza Stand",
		cost = 500,
		regularSlots = 2,
		unlocks = table.freeze({ "DoubleOrder", "RushOrder" }),
	}),
	table.freeze({
		level = 3,
		displayName = "Little Pizzeria",
		cost = 2500,
		regularSlots = 3,
		unlocks = table.freeze({ "FragileCake", "DecorSlot1", "StartGiantOrder" }),
	}),
	table.freeze({
		level = 4,
		displayName = "Family Pizzeria",
		cost = 10000,
		regularSlots = 4,
		unlocks = table.freeze({ "UpperFloor", "BetterCustomerOdds" }),
	}),
	table.freeze({
		level = 5,
		displayName = "Pizza Palace",
		cost = 40000,
		regularSlots = 6,
		unlocks = table.freeze({ "Terrace" }),
	}),
	table.freeze({
		level = 6,
		displayName = "Neon Pizza Tower",
		cost = 150000,
		regularSlots = 8,
		unlocks = table.freeze({ "RooftopTerrace", "LightShow" }),
	}),
})
