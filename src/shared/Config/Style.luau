--!strict
return table.freeze({
	style = table.freeze({
		hazardWindowSeconds = 5,
		tags = table.freeze({
			table.freeze({ id = "AirDelivery", name = "Air delivery", bonus = 0.5 }),
			table.freeze({ id = "SharkEscape", name = "Shark escape", bonus = 0.4 }),
			table.freeze({ id = "Hoofbeat", name = "Hoofbeat", bonus = 0.3 }),
			table.freeze({ id = "Flawless", name = "Flawless", bonus = 0.2 }),
			table.freeze({ id = "Lightning", name = "Lightning", bonus = 0.2 }),
			table.freeze({ id = "Juggler", name = "Juggler", bonus = 0.3 }),
			table.freeze({ id = "CheeseJump", name = "Cheese jump", bonus = 0.3 }),
			table.freeze({ id = "BubbleRider", name = "Bubble rider", bonus = 0.3 }),
		}),
	}),
	chaos = table.freeze({
		targetSeconds = 10 * 60,
		deliverySeconds = 90,
		minPlayers = 8,
		maxPlayers = 12,
		eventMultiplier = 2,
	}),
})
