--!strict
return table.freeze({
	runs = 30,
	seed = 75083,
	pizzeriaOddsBonusPerLevel = 0.1,
	maxSeconds = 12 * 3600,
	month = 12,
	day = 15,
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
