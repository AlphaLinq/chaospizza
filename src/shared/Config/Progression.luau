--!strict
-- Initial tuning: 30-60 deliveries/hour at the current 25 XP reaches levels 5-8.
return table.freeze({
	xpBase = 50,
	xpGrowth = 40,
	firstHourDeliveries = 30,
	xpPerDelivery = 25,
	passiveBasePerMinute = 5,
	starBonus = 0.2,
	maxStars = 5,
	offlineSeconds = 2 * 60 * 60,
	offlineRate = 0.5,
	passOfflineSeconds = 8 * 60 * 60,
	passOfflineRate = 1,
	passRegularSlots = 4,
	persistence = table.freeze({
		storeName = "PizzaChaosProfiles_v1",
		autosaveSeconds = 60,
		leaseSeconds = 180,
		retries = 4,
		retryBaseSeconds = 2,
		lockAttempts = 8,
		lockRetrySeconds = 4,
	}),
})
