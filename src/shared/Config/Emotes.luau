--!strict
return table.freeze({
	durationSeconds = 3,
	cooldownSeconds = 4,
	cancelMoveThreshold = 0.05,
	items = table.freeze({
		{ id = "WaveEmote", name = "Wave" },
		{ id = "DanceEmote", name = "Dance" },
		{ id = "PizzaPoseEmote", name = "Pizza pose" },
	}),
})
