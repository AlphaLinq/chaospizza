--!strict
return table.freeze({
	maxLength = 32,
	requestTimeoutSeconds = 10,
	rate = 0.5,
	burst = 2,
	maxTips = 1e12,
	codes = table.freeze({
		WELCOME = table.freeze({ tips = 150, expiresAt = 0, minimumLevel = 1 }),
		PIZZAPARTY = table.freeze({
			tips = 250,
			cosmetic = "ExtraCheeseBox",
			expiresAt = 1798761600,
			minimumLevel = 2,
		}),
	}),
})
