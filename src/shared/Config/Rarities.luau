--!strict
-- Customer rarities (brief ch. 9.2). Weights are percents; every column must
-- sum to 100 (checked by tests/run.luau). Shape: Types.RarityDef.

return table.freeze({
	table.freeze({
		id = "Common",
		displayName = "Common",
		colorHex = "#9AA0A6",
		order = 1,
		weightNormal = 70,
		weightEvent = 45,
		weightMega = 35,
		passiveMultiplier = 0,
	}),
	table.freeze({
		id = "Uncommon",
		displayName = "Uncommon",
		colorHex = "#34A853",
		order = 2,
		weightNormal = 22,
		weightEvent = 30,
		weightMega = 30,
		passiveMultiplier = 0,
	}),
	table.freeze({
		id = "Rare",
		displayName = "Rare",
		colorHex = "#4285F4",
		order = 3,
		weightNormal = 7,
		weightEvent = 18,
		weightMega = 22,
		passiveMultiplier = 1,
	}),
	table.freeze({
		id = "Epic",
		displayName = "Epic",
		colorHex = "#A142F4",
		order = 4,
		weightNormal = 1,
		weightEvent = 6,
		weightMega = 10,
		passiveMultiplier = 3,
	}),
	table.freeze({
		id = "Legendary",
		displayName = "Legendary",
		colorHex = "#FBBC04",
		order = 5,
		weightNormal = 0,
		weightEvent = 1,
		weightMega = 3,
		passiveMultiplier = 8,
	}),
	table.freeze({
		id = "Mythic",
		displayName = "Mythic",
		colorHex = "#FF4FD8",
		order = 6,
		weightNormal = 0,
		weightEvent = 0,
		weightMega = 0, -- seasonal / special only, added later
		passiveMultiplier = 20,
	}),
})
