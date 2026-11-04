--!strict
-- Initial tuning: 30 deliveries/hour at 25 XP reaches level 7.
return table.freeze({
	xpBase = 50,
	xpGrowth = 30,
	firstHourDeliveries = 30,
	xpPerDelivery = 25,
	passiveBasePerMinute = 10,
	starBonus = 0.2,
	maxStars = 5,
	offlineSeconds = 2 * 60 * 60,
	offlineRate = 0.5,
	passOfflineSeconds = 8 * 60 * 60,
	passOfflineRate = 1,
	passRegularSlots = 4,
})
