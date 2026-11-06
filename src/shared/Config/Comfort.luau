--!strict
return table.freeze({
	rate = 1,
	burst = 2,
	requestTimeoutSeconds = 10,
	items = {
		{ key = "motion", attribute = "ReduceMotion", claim = "setting.reduceMotion" },
		{ key = "flashes", attribute = "ReduceFlashes", claim = "setting.reduceFlashes" },
	},
	labels = {
		en = {
			title = "Comfort",
			motion = "Reduce camera motion",
			flashes = "Reduce screen flashes",
			on = "On",
			off = "Off",
			loading = "Loading saved preferences…",
			busy = "Saving…",
			failed = "Could not save. Tap to retry.",
		},
		hu = {
			title = "Komfort",
			motion = "Kamerarázkódás csökkentése",
			flashes = "Képernyővillanások csökkentése",
			on = "Be",
			off = "Ki",
			loading = "A mentett beállítások betöltése…",
			busy = "Mentés…",
			failed = "Nem sikerült menteni. Koppints újra.",
		},
	},
})
