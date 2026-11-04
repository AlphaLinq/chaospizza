--!strict
-- Global tunables. Starting values from docs/PIZZA_CHAOS_2_GAME_BRIEF.md;
-- tune from playtests. Replicated to clients: nothing secret here, and the
-- server never trusts a client-reported value from this file.
--
-- Config modules are pure data (no requires, no Roblox types) so they can be
-- validated by tests/run.luau outside Roblox.

return table.freeze({
	Server = table.freeze({
		maxPlayers = 12, -- brief ch. 1 (test 10–16); set in Game Settings too
	}),

	Movement = table.freeze({
		baseWalkSpeed = 20,
		jumpBufferSeconds = 0.12, -- brief ch. 7 (0.10–0.15)
		coyoteTimeSeconds = 0.12,
		maxSpeedBonus = 0.30, -- hard cap so events stay manageable (brief ch. 7)
	}),

	Orders = table.freeze({
		baseTip = 25,
		baseXp = 10,
		deliveryRadiusStuds = 12, -- server-side distance check
		pickupRadiusStuds = 12,
		starterDeliveries = 2, -- first orders go to starter addresses near the counter
		-- Anti-teleport: delivery must take >= factor * (straight distance / max speed)
		minTravelTimeFactor = 0.6,
		targetMinSeconds = 60, -- level-design target for a typical run
		targetMaxSeconds = 120,
	}),

	Events = table.freeze({
		calmMinSeconds = 90,
		calmMaxSeconds = 150,
		warningMinSeconds = 5,
		warningMaxSeconds = 8,
		activeMinSeconds = 30,
		activeMaxSeconds = 45,
		cleanupMinSeconds = 5,
		cleanupMaxSeconds = 10,
		tipBonusDuringEvent = 0.5, -- +50% (brief ch. 12.2)
		hitProtectionSeconds = 2.5, -- no immediate re-hit after a knockdown
		maxRagdollSeconds = 3,
	}),

	Style = table.freeze({
		maxTotalBonus = 1.5, -- +150% cap (brief ch. 14)
	}),

	ChaosMeter = table.freeze({
		targetMinutesToFill = 10, -- 8–12 min on an 8–12 player server
		megaDurationSeconds = 75,
		megaTipMultiplier = 3,
	}),

	Regulars = table.freeze({
		basePassiveTipsPerMinute = 5,
		starBonusPerStar = 0.2,
		maxStars = 5,
		offlineMaxHours = 2,
		offlineRate = 0.5,
		offlineMaxHoursPass = 8,
		offlineRatePass = 1.0,
	}),

	OrderedEvents = table.freeze({
		queueLimit = 3,
		minCalmBetweenSeconds = 60,
		tipBonusForEveryone = 1.0, -- +100% (brief ch. 16)
	}),

	Onboarding = table.freeze({
		guaranteedEventOnDelivery = 2,
		noShopPromptsFirstSeconds = 180,
	}),
})
