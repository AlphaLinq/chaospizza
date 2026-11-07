--!strict
return table.freeze({
	pollSeconds = 0.1,
	hearingStuds = 70,
	gooseIntervalSeconds = 2.4,
	finalTicks = 10,
	deadlineEpsilonSeconds = 1,
	voteKeys = { "Seven", "Eight", "Nine" },
	hints = {
		{ prefix = "🗳️ The city voted:", cue = "VoteWinner" },
		{ prefix = "📦 Free pizza box!", cue = "BoxPickup" },
		{ prefix = "🎆 Finale survived!", cue = "FinaleSurvived" },
	},
})
