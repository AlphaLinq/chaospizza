--!strict
return table.freeze({
	secondsPerDay = 86400,
	minimumSessionSeconds = 120,
	maxDailyLikes = 2048,
	distance = 12,
	requestRate = 0.5,
	requestBurst = 2,
	refreshSeconds = 30,
	promptHoldSeconds = 0.3,
	signDistance = 60,
})
