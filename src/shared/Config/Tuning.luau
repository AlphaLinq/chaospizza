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

	-- Event vote (#186): in the second half of the calm the server votes on
	-- the next event (paid "order a disaster" still goes first).
	Vote = table.freeze({
		options = 3,
		openAtCalmFraction = 0.4,
		minOpenSeconds = 15,
	}),

	-- Chaos finale (#186): every intervalSeconds a MEGA with two events. HUD
	-- notice noticeSeconds before, a big countdown for the last seconds.
	Finale = table.freeze({
		intervalSeconds = 20 * 60,
		noticeSeconds = 3 * 60,
		countdownSeconds = 30,
		bonusTips = 100, -- to everyone who delivered during the finale
		heroTips = 150, -- the courier with the most finale deliveries (#208)
		heroCrownSeconds = 60, -- the crown over their head
		retrySeconds = 5, -- a MEGA already pending/running: try again shortly
	}),

	-- Order choice board (#185): picking up at the counter offers three orders.
	Offers = table.freeze({
		choiceSeconds = 15, -- then the first offer is taken automatically
		chooseSlackStuds = 30, -- may step away from the counter while choosing
		nearShare = 1 / 3, -- "near" = closest third of the addresses
		farShare = 1 / 3, -- "far" = farthest third
		farTipMultiplier = 1.3, -- long haul (after the style cap)
		farRarityRolls = 2, -- far customers: best of N rarity rolls
		daredevilMultiplier = 2, -- into the live hazard zone, during the event
		daredevilZoneMargin = 20, -- doors this close to the zone count
		-- Danger areas beyond the fixed HazardZones (#199): along a MapLayout
		-- route list, or near live CityState positions (a Vector3, or a JSON
		-- list of { x, z }) at the moment the offer is made.
		daredevil = table.freeze({
			CheeseWheel = table.freeze({ routes = "cheeseRoutes", radius = 22 }),
			UfoAbduction = table.freeze({ routes = "ufoRoutes", radius = 24 }),
			Tornado = table.freeze({ stateVector = "TornadoPos", radius = 70 }),
			MeteorShower = table.freeze({ stateJson = "Meteors", radius = 40 }),
			BubbleStorm = table.freeze({ stateJson = "Bubbles", radius = 40 }),
		}) :: { [string]: { [string]: any } },
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
		-- +30% (brief ch. 12.2 had +50%; #185 moved the rest of the event
		-- reward to the Daredevil offer, so the brave earn it, not everyone).
		tipBonusDuringEvent = 0.3,
		-- Per-event overrides: harmless events pay less (#131 Blackout).
		tipBonusByEvent = table.freeze({ Blackout = 0.2, PizzaRain = 0.1 }) :: { [string]: number },
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
		-- 5-box party tower (#170): full tower pays x3, each lost box less.
		party = table.freeze({ minLevel = 5, weight = 8, boxes = 5, tipMultiplier = 3 }),
	}),

	-- Party tower wobble (#170), sampled by the server from the courier's
	-- movement: sharp speed changes and jumps add tilt, it settles over time.
	Tower = table.freeze({
		sampleSeconds = 0.1,
		accelThreshold = 60, -- studs/s² that a calm walk never reaches
		accelGain = 0.004, -- tilt per (studs/s²) above the threshold per second
		jumpKick = 0.22, -- tilt added by a jump / big upward hop
		jumpSpeed = 18, -- upward studs/s that counts as a jump
		settlePerSecond = 0.35, -- tilt removed per second
		dropAt = 1, -- tilt that topples the top box
		afterDrop = 0.45,
		boxesLostOnHit = 2,
	}),

	-- First-time tips (#211, Config/FeatureTips)
	FeatureTips = table.freeze({
		showSeconds = 10,
	}),

	-- Day/night cycle (#217): one full day every periodSeconds; phase shares
	-- add up to 1 (dawn, day, dusk, night). The clock is computed from server
	-- time on every machine, so nothing replicates but a debug offset.
	DayCycle = table.freeze({
		periodSeconds = 12 * 60,
		dawnShare = 0.08,
		dayShare = 0.55,
		duskShare = 0.1,
		nightShare = 0.27,
		nightTipBonus = 0.15, -- "Night shift", under the style cap
		nightBrightness = 0.45,
		dayBrightness = 2,
		lampSpacing = 40, -- studs between street lamps
		lampLightRange = 18, -- PointLight only on high effect quality
	}),

	-- Loop titles (#227): counter in profile.claims -> threshold -> title.
	LoopTitles = table.freeze({
		table.freeze({ counter = "loop.daredevil", goal = 10, cosmetic = "DaredevilTitle" }),
		table.freeze({ counter = "challenges.done", goal = 25, cosmetic = "ChallengeHunterTitle" }),
		table.freeze({ counter = "loop.finaleHero", goal = 1, cosmetic = "FinaleHeroTitle" }),
		table.freeze({ counter = "loop.night", goal = 25, cosmetic = "NightOwlTitle" }),
		table.freeze({ counter = "loop.golden", goal = 5, cosmetic = "GoldRushTitle" }),
	}),

	-- Disaster of the week (#224)
	Featured = table.freeze({
		pickWeight = 2, -- counts this many times in the random pick
		challengeMultiplier = 2, -- its event challenge pays double
		joinHintDelaySeconds = 12,
	}),

	-- Golden pizza (#223): a rare ×3 order the whole server hears about.
	Golden = table.freeze({
		chance = 0.02,
		tipMultiplier = 3,
		scuffedMultiplier = 2, -- after an accident on the way
		minDeliveries = 3,
	}),

	-- City Rush (#219): a server-wide delivery combo.
	CityRush = table.freeze({
		windowSeconds = 20, -- the next delivery must come within this
		minCouriers = 2, -- different couriers before it counts as a rush
		perComboTips = 5, -- each participant gets combo × this at the end
		maxCombo = 20,
	}),

	-- Errands (#218): a customer calls mid-route and asks for a detour.
	Errand = table.freeze({
		chance = 0.3, -- per eligible order
		minDeliveries = 5, -- not during the first runs
		delayMinSeconds = 5,
		delayMaxSeconds = 14,
		tipMultiplier = 1.4, -- after the style cap, like long haul
		pickupRadius = 8,
		maxDetourStuds = 140, -- extra walking the errand may add
		minGapStuds = 25, -- the shop is not right next to you or the door
	}),

	-- Event challenges (#200, Config/EventChallenges)
	Challenges = table.freeze({
		tips = 30, -- default reward
		hazardCooldownSeconds = 2.5,
		pollSeconds = 0.5, -- near / rooftop checks
		clearDelaySeconds = 4, -- keep the done line visible after the event
	}),

	-- Micro-chaos (#187): small local surprises during the calm, every
	-- minGap..maxGap seconds on a random street. No banner, harmless bumps
	-- (a launch, not an accident: streaks and cakes survive).
	MicroChaos = table.freeze({
		minGapSeconds = 20,
		maxGapSeconds = 40,
		firstDelaySeconds = 15,
		hitCooldownSeconds = 2,
		seenStuds = 90, -- analytics: couriers this close "saw" it (#202)
		streets = table.freeze({
			"MainStreet",
			"NorthAvenue",
			"WestStreet",
			"EastStreet",
			"SouthAvenue",
			"HarborLane",
			"WestConnector",
			"EastConnector",
		}),
		-- Keep movers and spots off the overpass ramps (MapLayout.overpass).
		avoid = table.freeze({ table.freeze({ x = 0, z = -110, sx = 20, sz = 60 }) }),
		edgeMargin = 6,
		kinds = table.freeze({
			Cart = table.freeze({
				weight = 3,
				speed = 22,
				length = 90,
				radius = 3.5,
				push = 45,
				lift = 20,
			}),
			Geese = table.freeze({
				weight = 3,
				count = 5,
				spacing = 2.5,
				speed = 13,
				length = 60,
				radius = 3,
				push = 30,
				lift = 14,
			}),
			Sprinkler = table.freeze({
				weight = 2,
				warnSeconds = 1.5,
				activeSeconds = 6,
				radius = 4,
				launch = 75, -- straight up: a free "Air delivery" chance
				flightSeconds = 1.6,
			}),
			Boxes = table.freeze({
				weight = 2,
				count = 6,
				spread = 6,
				tips = 2,
				lifeSeconds = 20,
				radius = 3.5,
			}),
		}) :: { [string]: { [string]: number } },
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

	-- Giant Cat boss event (#184): sits on Fountain Square, swipes its paw at
	-- couriers nearby; feed it (deliveries during the event) to calm it down.
	GiantCat = table.freeze({
		x = -160,
		z = 0,
		swipeEverySeconds = 2.4,
		swipeWarnSeconds = 1.3,
		swipeRadius = 7,
		reach = 55, -- swipes target couriers within this of the cat
		knockPower = 65,
		knockSeconds = 1.5,
		-- Shared goal = players × feedPerPlayer (min feedMin) treats. A treat is
		-- a toss into the bowl right under its nose (risky: inside paw reach),
		-- and any delivery during the event counts deliveryTreats at once.
		-- Tested: deliveries alone could never fill it in a 30-45 s event, and
		-- a courier who never dodges lands ~4 tosses in 27 s.
		feedPerPlayer = 4,
		feedMin = 5,
		deliveryTreats = 3,
		bowlOffsetZ = -24, -- the cat faces -Z; the bowl sits in front of it
		bowlCooldownSeconds = 2, -- per courier
		fedTips = 40, -- to everyone online when the cat is fed
	}),

	-- UFO Abduction event (#183): saucers cruise loops; green beams lift
	-- couriers and drop them somewhere else (sometimes right at their door).
	Ufo = table.freeze({
		count = 3,
		height = 46,
		speed = 14, -- studs/s along MapLayout.ufoRoutes
		beamRadius = 6,
		beamCycleSeconds = 6, -- per UFO: warn, beam on, rest
		beamWarnSeconds = 1.2,
		beamOnSeconds = 2.6,
		liftSeconds = 1.6, -- carried up before the drop
		dropAtDoorChance = 0.3, -- with an order: dropped near your door
		dropProtectSeconds = 3,
		cooldownSeconds = 8, -- per courier between abductions
	}),

	-- Pizza Rain event (#182): a reward event — catch falling pizzas.
	PizzaRain = table.freeze({
		spawnEverySeconds = 0.45,
		maxLive = 14,
		fallSeconds = 2.2, -- the shadow shows where it lands
		catchRadius = 4.5,
		catchMaxFeet = 7, -- you can jump for it
		targetPlayerChance = 0.65,
		catchTips = 3,
		goalPerPlayer = 12, -- shared goal = players × this (min goalMin)
		goalMin = 20,
		goalTips = 60, -- paid once to everyone who caught at least one
	}),

	-- Meteor Shower event (#181): telegraphed impacts, stardust in the craters.
	MeteorShower = table.freeze({
		spawnEverySeconds = 0.8,
		maxLive = 8,
		telegraphSeconds = 2.2, -- red circle on the ground before the impact
		radius = 7,
		nearMissMargin = 6, -- within radius + this but not hit = Close call
		targetPlayerChance = 0.5, -- else a random street spot
		avoidSafeSpotStuds = 12,
		knockPower = 55,
		knockSeconds = 1.4,
		dustPerImpact = 2,
		dustTips = 2,
		dustLifetimeSeconds = 25,
		dustPickupRadius = 4.5,
		dustMax = 30,
	}),

	-- Moon Walk event (#180): gravity drops to a fraction for big, floaty jumps.
	LowGravity = table.freeze({
		gravityFactor = 0.33,
		easeSeconds = 2.5, -- gravity fades down at the start and back at the end
		moonFeetHeight = 8, -- airborne this high during the event = Moonwalk
	}),

	-- Gale Force event (#230): telegraphed gusts from a random direction.
	-- Grounded couriers get a short shove (unless sheltered behind a wall),
	-- airborne ones are carried, capped so it never stacks into a launch.
	WindGust = table.freeze({
		telegraphSeconds = 2.5, -- HUD arrow + countdown before each gust
		gustSeconds = 3,
		calmMinSeconds = 3.5,
		calmMaxSeconds = 6,
		shoveSpeed = 26, -- studs/s sideways at the gust front
		shoveLift = 14, -- a little hop so the air push takes over
		groundAccel = 25, -- studs/s² (the humanoid brakes most of it)
		airAccel = 55,
		maxWindSpeed = 34, -- the wind stops adding once you move this fast with it
		shelterStuds = 14, -- a wall this close upwind = no shove
		rideFeet = 5, -- airborne this high + with the wind = riding it
		rideSpeed = 14,
		streaks = 36, -- local wind streaks on high quality
		lowQualityStreaks = 10,
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
