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
		baseXp = 25, -- must match Config/Progression.xpPerDelivery (tested)
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
		-- Per-event overrides: harmless events pay less (#131 Blackout).
		tipBonusByEvent = table.freeze({ Blackout = 0.3 }) :: { [string]: number },
		hitProtectionSeconds = 2.5, -- no immediate re-hit after a knockdown
		maxRagdollSeconds = 3,
		-- (Re)spawns closer than this to a live hazard are moved to a safe spot.
		safeSpawnMarginStuds = 8,
	}),

	Style = table.freeze({
		maxTotalBonus = 1.5, -- +150% cap (brief ch. 14)
		-- Air delivery: root must be at least this far above the ground below it.
		airborneMinHeight = 6,
		-- Lightning target = straight counter→door distance / base walk speed × this.
		lightningFactor = 1.5,
		-- Near-miss radius (studs) that counts as "escaped the shark" / "crossed the horses".
		sharkNearRadius = 18,
		horseNearStuds = 40,
	}),

	ChaosMeter = table.freeze({
		targetMinutesToFill = 10, -- 8–12 min on an 8–12 player server
		megaDurationSeconds = 75,
		megaTipMultiplier = 3,
		-- Warning before a MEGA starts once the meter is full.
		megaWarningSeconds = 10,
		-- Calm gap before a pending MEGA starts (e.g. right after another event).
		megaCalmSeconds = 3,
		topContributors = 3,
	}),

	-- Giant co-op order (brief ch. 13)
	GiantOrder = table.freeze({
		firstSpawnDelaySeconds = 120,
		intervalSeconds = 240,
		minPlayersOnline = 2,
		minCarriers = 2,
		maxCarriers = 4,
		-- A carrier further than this from the box lets go.
		leashStuds = 12,
		grabRadiusStuds = 10,
		deliveryRadiusStuds = 16,
		timeLimitSeconds = 300,
		-- Box returns to the plaza if nobody touches it for this long.
		abandonSeconds = 60,
		tipMultiplier = 4, -- × Orders.baseTip per carrier, before bonuses
		xp = 80,
		socialBonus = 0.25,
		friendBonus = 0.10,
		boxHeightAboveRoot = 3.4,
		-- Box drops if the carriers' centre moves faster than this × max run speed.
		maxCarrySpeedFactor = 2,
		-- Owners can start one from their pizzeria (brief ch. 13).
		pizzeriaMinLevel = 3,
		pizzeriaCooldownSeconds = 300,
		-- Rarity weights (percent) for the giant order's customer: always Rare+.
		rarityWeights = table.freeze({ Rare = 70, Epic = 25, Legendary = 5 }),
		eventRarityWeights = table.freeze({ Rare = 50, Epic = 35, Legendary = 15 }),
	}),

	-- Order types (brief 8.1), unlocked by pizzeria level. Weights are relative.
	OrderKinds = table.freeze({
		normalWeight = 60,
		double = table.freeze({ minLevel = 2, weight = 15, tipMultiplier = 2 }),
		rush = table.freeze({ minLevel = 2, weight = 20, bonus = 0.4, timeFactor = 1.4 }),
		fragile = table.freeze({ minLevel = 3, weight = 15, bonus = 0.35 }),
	}),

	-- Runaway cheese wheel event (#140). Routes: MapLayout.cheeseRoutes.
	CheeseWheel = table.freeze({
		speed = 32, -- studs/s
		diameter = 6,
		thickness = 3,
		telegraphSeconds = 2,
		pauseMinSeconds = 2,
		pauseMaxSeconds = 4,
		-- Off the ground (feet above this) within jumpLeadStuds of the wheel
		-- = jumping it (Cheese jump, no hit); on the ground when it arrives = hit.
		airborneFeetHeight = 1,
		jumpLeadStuds = 5,
		knockSeconds = 1.3,
		chunkEverySeconds = 1.2, -- cheese chunks fall off while it rolls
		chunkTips = 3,
		chunkMax = 15,
		chunkLifetimeSeconds = 20,
		chunkPickupRadius = 4.5,
	}),

	-- Bubble Storm event (#161): rising soap bubbles carry couriers up.
	BubbleStorm = table.freeze({
		maxBubbles = 24, -- server cap (clients may draw fewer on Low)
		lowQualityBubbles = 15,
		spawnEverySeconds = 1.2,
		lifeSeconds = 14,
		riseSpeed = 3.2, -- studs/s
		maxHeight = 42, -- studs above the street; then it just drifts
		driftSpeed = 4,
		minRadius = 3,
		maxRadius = 5,
		catchMargin = 0.5, -- studs inside the radius that catch you
		releaseMargin = 4, -- leave the bubble by this much = released
		catchCooldownSeconds = 1.5, -- after a pop, before the next catch
	}),

	-- Blackout event (#131): night lighting on the client, neon waves.
	Blackout = table.freeze({
		waveMinSeconds = 7,
		waveMaxSeconds = 11,
	}),

	-- Delivery streak (#138): x1 → x(1 + step·(n−1)), capped; reset on knockback / pause.
	Streak = table.freeze({
		step = 0.05,
		max = 1.5,
		timeoutSeconds = 180,
		announceLossFrom = 3,
	}),

	Regulars = table.freeze({
		basePassiveTipsPerMinute = 5,
		starBonusPerStar = 0.2,
		maxStars = 5,
		offlineMaxHours = 2,
		offlineRate = 0.5,
		offlineMaxHoursPass = 8,
		offlineRatePass = 1.0,
		-- Tip jar (brief ch. 10): passive tips collect here until the owner taps it.
		jarCapacityMinutes = 20, -- jar holds this many minutes of income
		jarMinCapacity = 25,
	}),

	OrderedEvents = table.freeze({
		queueLimit = 3,
		minCalmBetweenSeconds = 60,
		tipBonusForEveryone = 1.0, -- +100% (brief ch. 16)
		-- Buyer perk: their next order is a guaranteed Rare+ customer.
		buyerRarityWeights = table.freeze({ Rare = 75, Epic = 20, Legendary = 5 }),
	}),

	-- Rival courier Speedy Sal (#148): races you to some orders on his
	-- rocket scooter. Beat him and the customer doubles the tips.
	Rival = table.freeze({
		minLevel = 3,
		chance = 0.125, -- per eligible new order (about every 8th)
		cooldownSeconds = 120,
		revSeconds = 3, -- warm-up before he takes off
		-- Sal's arrival: street (Manhattan) distance at the courier's walk
		-- speed times this factor, plus the rev time.
		paceFactor = 1.1,
		minFlightSeconds = 8,
		winTipMultiplier = 2,
		cruiseHeight = 45,
	}),

	-- Dive (#169): press jump again in the air to dive forward and slide.
	Dive = table.freeze({
		speed = 44, -- forward studs/s at the start of the dive
		upBoost = 6, -- small hop so it reads as a leap, not a drop
		minAirSeconds = 0.12, -- after take-off before a dive is allowed
		freshPressGap = 0.12, -- held jump keys repeat; a new press needs a gap
		slideSeconds = 0.5, -- belly slide after landing
		cooldownSeconds = 1.2,
		serverMinFeetHeight = 0.8, -- the server's airborne check for the style tag
	}),

	-- Time trial (#163)
	Trial = table.freeze({
		countdownSeconds = 3,
		checkpointRadius = 9,
		checkpointHeight = 8, -- vertical tolerance
		-- A leg faster than distance / (fastest courier speed * this) is
		-- impossible on foot = teleport/exploit; cannon legs are exempt.
		legSpeedSlack = 1.25,
		jumpStuds = 60, -- moved this far between two checks = teleported
		timeoutSeconds = 300,
		maxScoreMs = 600000, -- ranking score = maxScoreMs - time (higher is better)
		weeklyStorePrefix = "TrialWeek_",
		boardRows = 5,
		finishTips = 40,
		recordTips = 60,
	}),

	-- Pizza cannons (#147)
	Cannon = table.freeze({
		flightSeconds = 2.2,
		cooldownSeconds = 8,
		muzzleHeight = 4,
		maxImpulse = 420,
		landingProtectSeconds = 1.5,
	}),

	Onboarding = table.freeze({
		guaranteedEventOnDelivery = 2,
		noShopPromptsFirstSeconds = 180,
	}),

	-- Hourly city goal (#133): one shared goal per server per hour.
	CityGoal = table.freeze({
		windowSeconds = 3600,
		perPlayer = 12, -- deliveries per (peak) player
		minTarget = 30,
		maxTarget = 150,
		roundTo = 10,
		minContribution = 3, -- own deliveries needed for the reward
		rewardTips = 150,
		rewardXp = 60,
	}),
})
