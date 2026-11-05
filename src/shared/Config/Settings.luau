--!strict
return table.freeze({
	requestTimeoutSeconds = 8,
	mobileMaxWidth = 900,
	textScales = table.freeze({ normal = 1, large = 1.25 }),
	presets = table.freeze({
		low = table.freeze({
			label = "Low",
			particleScale = 0.25,
			description = "Fewer particles. Best for phones.",
		}),
		medium = table.freeze({
			label = "Medium",
			particleScale = 0.6,
			description = "A balance of detail and performance.",
		}),
		high = table.freeze({
			label = "High",
			particleScale = 1,
			description = "All the pizza-powered spectacle.",
		}),
	}),
})
