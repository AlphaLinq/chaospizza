--!strict
-- Movement tiers (brief ch. 7). Shape: Types.MovementTierDef.
-- speedBonus must never exceed Tuning.Movement.maxSpeedBonus (checked by tests).

return table.freeze({
	table.freeze({
		tier = 0,
		displayName = "Sneakers",
		speedBonus = 0,
		cost = 0,
		requiredCourierLevel = 1,
	}),
	table.freeze({
		tier = 1,
		displayName = "Running Shoes",
		speedBonus = 0.08,
		cost = 300,
		requiredCourierLevel = 1,
	}),
	table.freeze({
		tier = 2,
		displayName = "Skateboard",
		speedBonus = 0.15,
		cost = 2000,
		requiredCourierLevel = 5,
	}),
	table.freeze({
		tier = 3,
		displayName = "Roller Skates",
		speedBonus = 0.22,
		cost = 8000,
		requiredCourierLevel = 12,
	}),
	table.freeze({
		tier = 4,
		displayName = "E-Scooter",
		speedBonus = 0.30,
		cost = 30000,
		requiredCourierLevel = 20,
	}),
})
