--!strict
-- City events / disasters (brief ch. 12). Shape: Types.EventDef.
-- Timings are global in Tuning.Events; per-event overrides can be added here later.

return table.freeze({
	table.freeze({
		id = "HorseRace",
		displayName = "Surprise Horse Race",
		enabled = true,
		seasonal = false,
		megaCombos = table.freeze({ "Tornado", "Flood", "CheeseWheel" }),
	}),
	table.freeze({
		id = "Tornado",
		displayName = "Tornado",
		enabled = true,
		seasonal = false,
		megaCombos = table.freeze({ "HorseRace", "Flood", "Blackout" }),
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
		enabled = true,
		seasonal = true,
		-- Only scheduled inside this UTC date window (Dec 1 – Jan 6). Debug can force it.
		season = table.freeze({ fromMonth = 12, fromDay = 1, toMonth = 1, toDay = 6 }),
		megaCombos = table.freeze({ "HorseRace", "CheeseWheel" }),
	}),
	table.freeze({
		id = "CheeseWheel",
		displayName = "Runaway Cheese Wheel",
		enabled = true,
		seasonal = false,
		megaCombos = table.freeze({ "HorseRace", "Blizzard" }),
	}),
	table.freeze({
		id = "Blackout",
		displayName = "Blackout",
		enabled = true,
		seasonal = false,
		megaCombos = table.freeze({ "Tornado", "HorseRace" }),
	}),
})
