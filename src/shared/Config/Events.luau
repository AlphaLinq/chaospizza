--!strict
-- City events / disasters (brief ch. 12). Shape: Types.EventDef.
-- Timings are global in Tuning.Events; per-event overrides can be added here later.

return table.freeze({
	table.freeze({
		id = "HorseRace",
		displayName = "Surprise Horse Race",
		enabled = true,
		seasonal = false,
		megaCombos = table.freeze({ "Tornado", "Flood" }),
	}),
	table.freeze({
		id = "Tornado",
		displayName = "Tornado",
		enabled = true,
		seasonal = false,
		megaCombos = table.freeze({ "HorseRace", "Flood" }),
	}),
	table.freeze({
		id = "Flood",
		displayName = "Shark Flood",
		enabled = true,
		seasonal = false,
		megaCombos = table.freeze({ "HorseRace", "Tornado" }),
	}),
	table.freeze({
		id = "Blizzard",
		displayName = "Blizzard",
		enabled = false, -- switched on for the Christmas season (M9)
		seasonal = true,
		megaCombos = table.freeze({ "HorseRace" }),
	}),
})
