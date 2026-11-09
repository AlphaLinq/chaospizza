--!nonstrict
-- Pure-logic tests, run outside Roblox with the Luau CLI:  luau tests/run.luau
-- Covers Config consistency and pure Util modules. Modules tested here must
-- not use Roblox APIs or `script` requires.

local Validate = require("../src/shared/Util/Validate")
local RateLimiter = require("../src/shared/Util/RateLimiter")
local Tuning = require("../src/shared/Config/Tuning")
local Rarities = require("../src/shared/Config/Rarities")
local Customers = require("../src/shared/Config/Customers")
local Events = require("../src/shared/Config/Events")
local Pizzeria = require("../src/shared/Config/Pizzeria")
local Movement = require("../src/shared/Config/Movement")
local Products = require("../src/shared/Config/Products")
local MapLayout = require("../src/shared/Config/MapLayout")
local MapGeometry = require("../src/shared/Util/MapGeometry")
local OrderLogic = require("../src/shared/Util/OrderLogic")
local Season = require("../src/shared/Util/Season")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print(`FAIL  {name}\n      {err}`)
	end
end

local function expectEq(actual, expected, msg: string?)
	if actual ~= expected then
		error(`{msg or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function expectTrue(value, msg: string)
	if not value then
		error(msg, 2)
	end
end

-- ── Validate ────────────────────────────────────────────────────────────
test("Validate.string", function()
	expectEq(Validate.string("abc", 5), "abc")
	expectEq(Validate.string("", 5), nil, "empty rejected")
	expectEq(Validate.string("abcdef", 5), nil, "too long rejected")
	expectEq(Validate.string(5, 5), nil, "number rejected")
	expectEq(Validate.string(nil, 5), nil, "nil rejected")
end)

test("Validate.optionalString", function()
	expectEq(Validate.optionalString(nil, 5), "")
	expectEq(Validate.optionalString("", 5), "")
	expectEq(Validate.optionalString("abcdef", 5), nil)
	expectEq(Validate.optionalString({}, 5), nil)
end)

test("Validate.number rejects NaN / inf / out of range", function()
	expectEq(Validate.number(0 / 0, -10, 10), nil, "NaN")
	expectEq(Validate.number(math.huge, -math.huge, math.huge), nil, "+inf")
	expectEq(Validate.number(-math.huge, -math.huge, math.huge), nil, "-inf")
	expectEq(Validate.number(11, 0, 10), nil, "above max")
	expectEq(Validate.number(-1, 0, 10), nil, "below min")
	expectEq(Validate.number("5", 0, 10), nil, "string")
	expectEq(Validate.number(5.5, 0, 10), 5.5)
end)

test("Validate.integer", function()
	expectEq(Validate.integer(3, 1, 5), 3)
	expectEq(Validate.integer(3.2, 1, 5), nil)
	expectEq(Validate.integer(0 / 0, 1, 5), nil)
end)

test("Validate.boolean and oneOf", function()
	expectEq(Validate.boolean(true), true)
	expectEq(Validate.boolean(false), false)
	expectEq(Validate.boolean("true"), nil)
	local set = { HorseRace = true, Tornado = true }
	expectEq(Validate.oneOf("Tornado", set), "Tornado")
	expectEq(Validate.oneOf("Meteor", set), nil)
	expectEq(Validate.oneOf(1, set), nil)
end)

-- ── RateLimiter ─────────────────────────────────────────────────────────
test("RateLimiter burst then refill", function()
	local now = 0
	local limiter = RateLimiter.new(2, 3, function()
		return now
	end)
	local key = {}
	expectTrue(limiter:allow(key), "1st in burst")
	expectTrue(limiter:allow(key), "2nd in burst")
	expectTrue(limiter:allow(key), "3rd in burst")
	expectTrue(not limiter:allow(key), "4th blocked")
	now = 0.5 -- +1 token at 2/s
	expectTrue(limiter:allow(key), "refilled one")
	expectTrue(not limiter:allow(key), "then blocked again")
	now = 100
	for i = 1, 3 do
		expectTrue(limiter:allow(key), `capped at burst {i}`)
	end
	expectTrue(not limiter:allow(key), "burst cap respected")
end)

test("RateLimiter keys are independent and removable", function()
	local now = 0
	local limiter = RateLimiter.new(1, 1, function()
		return now
	end)
	local a, b = {}, {}
	expectTrue(limiter:allow(a), "a ok")
	expectTrue(not limiter:allow(a), "a blocked")
	expectTrue(limiter:allow(b), "b unaffected")
	limiter:remove(a)
	expectTrue(limiter:allow(a), "a reset after remove")
end)

-- ── Config consistency ──────────────────────────────────────────────────
local rarityById = {}
for _, r in Rarities do
	rarityById[r.id] = r
end
local eventById = {}
for _, e in Events do
	eventById[e.id] = e
end

test("Rarity weights sum to 100 per table", function()
	for _, column in { "weightNormal", "weightEvent", "weightMega" } do
		local sum = 0
		for _, r in Rarities do
			expectTrue(r[column] >= 0, `{r.id}.{column} negative`)
			sum += r[column]
		end
		expectEq(sum, 100, `{column} sum`)
	end
end)

test("Rarity order is unique and contiguous", function()
	local seen = {}
	for _, r in Rarities do
		expectTrue(not seen[r.order], `duplicate order {r.order}`)
		seen[r.order] = true
	end
	for i = 1, #Rarities do
		expectTrue(seen[i], `missing order {i}`)
	end
end)

test("Customers: unique ids, valid rarity and event", function()
	local ids = {}
	for _, c in Customers do
		expectTrue(not ids[c.id], `duplicate customer id {c.id}`)
		ids[c.id] = true
		expectTrue(rarityById[c.rarity] ~= nil, `{c.id}: unknown rarity {c.rarity}`)
		if c.event ~= nil then
			expectTrue(eventById[c.event] ~= nil, `{c.id}: unknown event {c.event}`)
		end
		expectTrue(#c.line > 0 and #c.line <= 80, `{c.id}: line length`)
	end
	local regular, seasonal = 0, 0
	for _, c in Customers do
		if c.seasonal then
			seasonal += 1
			expectEq(c.event, "Blizzard", `{c.id}: seasonal customers belong to the Blizzard`)
		else
			regular += 1
		end
	end
	expectEq(
		regular,
		24 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + 4,
		"starter pool (brief 9.3: 24) + cheese wheel (#140) + blackout (#131) + bubble storm (#161) + lowgravity (#180) + meteorshower (#181) + pizzarain (#182) + ufoabduction (#183) + giantcat (#184) + windgust (#230) + floorislava (#244) + night (#258)"
	)
	expectEq(seasonal, 5, "Christmas customers (brief M9)")
end)

test("Every rarity with weight in a table has at least one customer", function()
	-- Normal table: customers without event. Event table: customers of each event
	-- (+ normal ones when the event has none for that rarity is allowed).
	for _, r in Rarities do
		if r.weightNormal > 0 then
			local found = false
			for _, c in Customers do
				if c.event == nil and c.rarity == r.id then
					found = true
				end
			end
			expectTrue(found, `no normal-time customer for rarity {r.id}`)
		end
	end
end)

test("Each enabled non-seasonal event has 4 customers incl. a Legendary", function()
	for _, e in Events do
		if e.enabled and not e.seasonal then
			local count, legendary = 0, false
			for _, c in Customers do
				if c.event == e.id then
					count += 1
					legendary = legendary or c.rarity == "Legendary"
				end
			end
			expectEq(count, 4, `{e.id} customer count`)
			expectTrue(legendary, `{e.id} has no Legendary customer`)
		end
	end
end)

test("Event mega combos reference known events and are symmetric", function()
	for _, e in Events do
		for _, other in e.megaCombos do
			expectTrue(eventById[other] ~= nil, `{e.id}: unknown combo {other}`)
			expectTrue(other ~= e.id, `{e.id}: combo with itself`)
		end
	end
end)

test("Event timing ranges are valid", function()
	local t = Tuning.Events
	expectTrue(t.calmMinSeconds <= t.calmMaxSeconds, "calm range")
	expectTrue(t.warningMinSeconds <= t.warningMaxSeconds, "warning range")
	expectTrue(t.activeMinSeconds <= t.activeMaxSeconds, "active range")
	expectTrue(t.cleanupMinSeconds <= t.cleanupMaxSeconds, "cleanup range")
	expectTrue(t.warningMinSeconds >= 3, "warning must give reaction time")
end)

test("Pizzeria levels: sequential, costs and slots non-decreasing", function()
	for i, lvl in Pizzeria do
		expectEq(lvl.level, i, "level index")
		if i > 1 then
			local prev = Pizzeria[i - 1]
			expectTrue(lvl.cost > prev.cost, `level {i} cost must increase`)
			expectTrue(lvl.regularSlots >= prev.regularSlots, `level {i} slots must not decrease`)
		end
	end
	expectEq(Pizzeria[1].cost, 0, "level 1 is free")
	expectEq(#Pizzeria, 6, "6 levels (brief ch. 11)")
end)

test("Movement tiers respect the speed cap", function()
	for i, tier in Movement do
		expectEq(tier.tier, i - 1, "tier index")
		expectTrue(tier.speedBonus <= Tuning.Movement.maxSpeedBonus, `tier {tier.tier} above cap`)
		if i > 1 then
			expectTrue(
				tier.speedBonus > Movement[i - 1].speedBonus,
				`tier {tier.tier} must be faster`
			)
		end
	end
end)

test("Products: unique keys, positive prices, integer ids", function()
	local keys = {}
	for _, list in { Products.Gamepasses, Products.Products } do
		for _, p in list do
			expectTrue(not keys[p.key], `duplicate product key {p.key}`)
			keys[p.key] = true
			expectTrue(
				p.priceRobux > 0 and p.priceRobux == math.floor(p.priceRobux),
				`{p.key} price`
			)
			local id = p.gamepassId or p.productId
			expectTrue(id ~= nil and id == math.floor(id) and id >= 0, `{p.key} id`)
		end
	end
end)

test("Config tables are frozen", function()
	for name, tbl in
		{ Tuning = Tuning, Rarities = Rarities, Customers = Customers, Events = Events }
	do
		expectTrue(table.isfrozen(tbl), `{name} not frozen`)
	end
	expectTrue(table.isfrozen(Rarities[1]), "rarity entries frozen")
	expectTrue(table.isfrozen(Customers[1]), "customer entries frozen")
end)

-- ── OrderLogic ──────────────────────────────────────────────────────────
local function seqRng(values)
	local i = 0
	return function()
		i = i % #values + 1
		return values[i]
	end
end

test("OrderLogic.pickAddress uses starters first and never repeats", function()
	local addresses = {
		{ id = "A", starter = true },
		{ id = "B", starter = false },
		{ id = "C", starter = true },
	}
	for _ = 1, 50 do
		local id = OrderLogic.pickAddress(addresses, 0, 2, nil, math.random)
		expectTrue(id == "A" or id == "C", `starter expected, got {id}`)
	end
	for _ = 1, 50 do
		expectTrue(
			OrderLogic.pickAddress(addresses, 5, 2, "B", math.random) ~= "B",
			"repeat of last address"
		)
	end
	-- single starter: repeat allowed instead of failing
	local single = { { id = "S", starter = true }, { id = "X", starter = false } }
	expectEq(OrderLogic.pickAddress(single, 0, 2, "S", math.random), "S")
	-- rng edge: 0.999.. must stay in range
	expectTrue(OrderLogic.pickAddress(addresses, 5, 2, nil, function()
		return 0.99999
	end) ~= nil, "edge rng")
end)

test("OrderLogic.pickCustomer prefers event customers", function()
	local customers = {
		{ id = "n1" },
		{ id = "t1", event = "Tornado" },
		{ id = "n2" },
	}
	expectEq(OrderLogic.pickCustomer(customers, "Tornado", math.random), "t1")
	for _ = 1, 20 do
		local id = OrderLogic.pickCustomer(customers, nil, math.random)
		expectTrue(id == "n1" or id == "n2", "normal-time customer")
	end
	-- event with no customers falls back to normal ones
	local id = OrderLogic.pickCustomer(customers, "Flood", seqRng({ 0 }))
	expectEq(id, "n1")
end)

test("OrderLogic.tip caps the bonus and rounds", function()
	expectEq(OrderLogic.tip(25, 0, 1.5), 25)
	expectEq(OrderLogic.tip(25, 0.5, 1.5), 38)
	expectEq(OrderLogic.tip(25, 10, 1.5), 63)
	expectEq(OrderLogic.tip(25, -1, 1.5), 25)
end)

-- ── Map layout ──────────────────────────────────────────────────────────
test("Map: 14 unique addresses, at least 2 starters", function()
	local ids, starters, count = {}, 0, 0
	for _, b in MapLayout.buildings do
		if b.address then
			count += 1
			expectTrue(not ids[b.address.id], `duplicate address {b.address.id}`)
			ids[b.address.id] = true
			if b.address.starter then
				starters += 1
			end
		end
	end
	expectEq(count, 14, "address count")
	expectTrue(starters >= 2, "need >= 2 starter addresses")
end)

test("Map: buildings do not overlap each other", function()
	for i, a in MapLayout.buildings do
		for j, b in MapLayout.buildings do
			if j > i then
				expectTrue(not MapGeometry.overlaps(a, b), `buildings {i} and {j} overlap`)
			end
		end
	end
end)

test("Map: doors, spawn and safe spots are inside bounds", function()
	local bounds = MapLayout.bounds
	local function inside(p, what)
		expectTrue(p.x > bounds.minX + 2 and p.x < bounds.maxX - 2, `{what} x out of bounds`)
		expectTrue(p.z > bounds.minZ + 2 and p.z < bounds.maxZ - 2, `{what} z out of bounds`)
	end
	for i, b in MapLayout.buildings do
		inside(MapGeometry.doorPoint(b, 0.4), `door of building {i}`)
		expectTrue(
			b.x - b.sx / 2 > bounds.minX and b.x + b.sx / 2 < bounds.maxX,
			`building {i} x footprint`
		)
		expectTrue(
			b.z - b.sz / 2 > bounds.minZ and b.z + b.sz / 2 < bounds.maxZ,
			`building {i} z footprint`
		)
	end
	inside(MapLayout.spawn, "spawn")
	inside(MapLayout.counter, "counter")
	for i, s in MapLayout.safeSpots do
		inside(s, `safe spot {i}`)
	end
end)

test("Map: starter addresses are close to the counter", function()
	for _, b in MapLayout.buildings do
		if b.address and b.address.starter then
			local d = MapGeometry.distance2D(MapGeometry.doorPoint(b, 0.4), MapLayout.counter)
			expectTrue(d < 160, `{b.address.id} is {math.floor(d)} studs from the counter`)
		end
	end
end)

test("Map: doors are not inside another building", function()
	for i, b in MapLayout.buildings do
		local door = MapGeometry.doorPoint(b, 0.4)
		for j, other in MapLayout.buildings do
			if i ~= j then
				local inX = math.abs(door.x - other.x) < other.sx / 2
				local inZ = math.abs(door.z - other.z) < other.sz / 2
				expectTrue(not (inX and inZ), `door of building {i} is inside building {j}`)
			end
		end
	end
end)

-- C1: profile migration contracts.
local ProfileSchema = require("../src/shared/Util/ProfileSchema")
test("Profile: defaults are independent", function()
	local a, b = ProfileSchema.default(), ProfileSchema.default()
	a.cosmetics.owned.hat = true
	expectEq(b.cosmetics.owned.hat, nil)
end)
for _, value in { false, 42, "bad" } do
	test("Profile: non-table " .. tostring(value), function()
		expectEq(ProfileSchema.migrate(value).version, ProfileSchema.VERSION)
	end)
end
test("Profile: nil and v0", function()
	expectEq(ProfileSchema.migrate(nil).pizzeriaLevel, 1)
	expectEq(ProfileSchema.migrate({}).version, ProfileSchema.VERSION)
end)
for _, field in { "tips", "xp", "deliveries", "lastSeen" } do
	test("Profile: sanitize " .. field, function()
		for _, value in { -1, 0 / 0, math.huge, -math.huge, "bad", false, {} } do
			expectEq(ProfileSchema.migrate({ [field] = value })[field], 0)
		end
		expectEq(ProfileSchema.migrate({ [field] = 2.9 })[field], 2)
	end)
end
test("Profile: level bounds", function()
	expectEq(ProfileSchema.migrate({ pizzeriaLevel = 99 }).pizzeriaLevel, 6)
	expectEq(ProfileSchema.migrate({ pizzeriaLevel = -1 }).pizzeriaLevel, 1)
end)
test("Profile: movement bounds", function()
	expectEq(ProfileSchema.migrate({ movementTier = 99 }).movementTier, 4)
end)
test("Profile: customer entries", function()
	local p = ProfileSchema.migrate({
		customerBook = { a = { served = -1, stars = 99 }, b = false, [3] = {} },
	})
	expectEq(p.customerBook.a.stars, 5)
	expectEq(p.customerBook.a.served, 0)
	expectEq(p.customerBook.b, nil)
end)
test("Profile: regular deduplication and dangling ids", function()
	local p =
		ProfileSchema.migrate({ customerBook = { a = {} }, regulars = { "a", "a", "missing", 7 } })
	expectEq(#p.regulars, 1)
end)
test("Profile: cosmetics ownership", function()
	local p = ProfileSchema.migrate({
		cosmetics = {
			owned = { hat = true, bad = 1 },
			equipped = { head = "hat", body = "missing" },
		},
	})
	expectEq(p.cosmetics.equipped.head, "hat")
	expectEq(p.cosmetics.equipped.body, nil)
	expectEq(p.cosmetics.owned.bad, nil)
end)
test("Profile: receipt timestamps", function()
	local p = ProfileSchema.migrate({ purchases = { a = 123.9, b = -1, c = 0 / 0, d = "bad" } })
	expectEq(p.purchases.a, 123)
	expectEq(p.purchases.b, nil)
	expectEq(p.purchases.c, nil)
	expectEq(p.purchases.d, nil)
end)
test("Profile: daily bounds", function()
	local p = ProfileSchema.migrate({ dailyLogin = { day = 99, lastClaim = -5 } })
	expectEq(p.dailyLogin.day, 7)
	expectEq(p.dailyLogin.lastClaim, 0)
end)
test("Profile: drops unknown fields", function()
	expectEq(ProfileSchema.migrate({ secret = 1 }).secret, nil)
end)
test("Profile: nested wrong types", function()
	local p = ProfileSchema.migrate({
		customerBook = false,
		regulars = 3,
		cosmetics = "bad",
		purchases = false,
		dailyLogin = 7,
	})
	expectEq(#p.regulars, 0)
	expectEq(p.dailyLogin.day, 0)
end)
test("Profile: migration does not alias input", function()
	local raw = { customerBook = { a = { stars = 2 } } }
	ProfileSchema.migrate(raw).customerBook.a.stars = 5
	expectEq(raw.customerBook.a.stars, 2)
end)
test("Profile: current migration is stable", function()
	local p = ProfileSchema.default()
	p.tips = 123
	expectEq(ProfileSchema.migrate(ProfileSchema.migrate(p)).tips, 123)
end)

-- C3: deterministic, stratified 10,000-roll distribution tests.
local CustomerOdds = require("../src/shared/Util/CustomerOdds")
for _, mode in { "normal", "event", "mega" } do
	test("Odds: 10000 rolls " .. mode, function()
		local counts = {}
		local n = 0
		local function rng()
			n += 1
			return (n - 0.5) / 10000
		end
		for _ = 1, 10000 do
			local id = CustomerOdds.rollRarity(mode, Rarities, {}, rng)
			counts[id] = (counts[id] or 0) + 1
		end
		local expected = CustomerOdds.describe(mode, Rarities, {})
		for id, percent in expected do
			expectTrue(math.abs((counts[id] or 0) / 100 - percent) <= 1, id .. " distribution")
		end
	end)
end
for _, mods in
	{
		{},
		{ rarePlusMultiplier = 2 },
		{ rarePlusMultiplier = 2, pizzeriaLevelBonus = 0.2 },
		{ rarePlusMultiplier = 0 / 0, pizzeriaLevelBonus = -1 },
	}
do
	test("Odds: modifiers normalize", function()
		local odds = CustomerOdds.describe("normal", Rarities, mods)
		local total = 0
		for _, percent in odds do
			total += percent
		end
		expectTrue(math.abs(total - 100) < 1e-9, "sum 100")
		expectEq(odds.Legendary, 0)
	end)
end
test("Odds: boost doubles relative Rare weight", function()
	local odds = CustomerOdds.describe("normal", Rarities, { rarePlusMultiplier = 2 })
	expectTrue(math.abs(odds.Rare / odds.Common - 14 / 70) < 1e-9, "ratio")
end)
test("Odds: endpoints avoid impossible rarity", function()
	expectEq(
		CustomerOdds.rollRarity("normal", Rarities, {}, function()
			return 0
		end),
		"Common"
	)
	expectEq(
		CustomerOdds.rollRarity("normal", Rarities, {}, function()
			return 1
		end),
		"Epic"
	)
end)
test("Odds: event eligibility and nearest fallback", function()
	local function rng()
		return 0
	end
	expectEq(CustomerOdds.pickCustomer(Customers, "Legendary", nil, rng), "EscalatorBot")
	expectEq(CustomerOdds.pickCustomer(Customers, "Legendary", "Flood", rng), "TheShark")
	expectEq(CustomerOdds.pickCustomer(Customers, "Mythic", "Tornado", rng), "TornadoKid")
	expectEq(CustomerOdds.pickCustomer({}, "Common", nil, rng), nil)
	expectEq(CustomerOdds.pickCustomer({ { id = "high", rarity = "Epic" } }, "Rare", nil, rng), nil)
end)

-- C4: production progression tables injected into the pure calculator.
local ProgressionConfig = require("../src/shared/Config/Progression")
local Progression =
	require("../src/shared/Util/Progression").new(ProgressionConfig, Rarities, Pizzeria)
test("Progression: XP boundaries and inverse", function()
	expectEq(Progression.xpForLevel(1), 0)
	expectEq(Progression.levelFromXp(-1), 1)
	expectEq(Progression.levelFromXp(0 / 0), 1)
	for level = 2, 100 do
		local xp = Progression.xpForLevel(level)
		expectEq(Progression.levelFromXp(xp), level)
		expectEq(Progression.levelFromXp(xp - 1), level - 1)
	end
	local firstHour = Progression.levelFromXp(
		ProgressionConfig.firstHourDeliveries * ProgressionConfig.xpPerDelivery
	)
	expectTrue(firstHour >= 5 and firstHour <= 8, "first hour target")
end)
test("Progression: passive rarity and five stars", function()
	expectEq(Progression.passivePerMinute("Rare", 0), 5)
	expectEq(Progression.passivePerMinute("Epic", 5), 30)
	expectEq(Progression.passivePerMinute("Legendary", 5), 80)
	expectEq(Progression.passivePerMinute("Rare", 99), 10)
	expectEq(Progression.passivePerMinute("Common", 5), 0)
	expectEq(Progression.passivePerMinute("missing", 5), 0)
end)
test("Progression: offline zero, negative and unset clock", function()
	for _, times in { { 100, 100 }, { 101, 100 }, { 0, 100 }, { 0 / 0, 100 } } do
		local amount, seconds = Progression.offlineEarnings(10, times[1], times[2], false)
		expectEq(amount, 0)
		expectEq(seconds, 0)
	end
end)
test("Progression: offline minute and annual cap", function()
	local amount, seconds = Progression.offlineEarnings(10, 100, 160, false)
	expectEq(amount, 5)
	expectEq(seconds, 60)
	amount, seconds = Progression.offlineEarnings(10, 100, 100 + 365 * 86400, false)
	expectEq(amount, 600)
	expectEq(seconds, 7200)
	amount, seconds = Progression.offlineEarnings(10, 100, 100 + 365 * 86400, true)
	expectEq(amount, 4800)
	expectEq(seconds, 28800)
	expectEq(Progression.offlineEarnings(math.huge, 100, 160, true), 0)
end)
test("Progression: upgrades exact balance and max", function()
	expectEq(Progression.canUpgradePizzeria(1, Pizzeria[2].cost - 1), false)
	expectEq(Progression.canUpgradePizzeria(1, Pizzeria[2].cost), true)
	expectEq(Progression.canUpgradePizzeria(6, 1e9), false)
	expectEq(Progression.canUpgradePizzeria(0, 1e9), false)
	expectEq(Progression.canUpgradePizzeria(1, 0 / 0), false)
end)
test("Progression: seats and pass", function()
	expectEq(Progression.regularSlots(1, false), 1)
	expectEq(Progression.regularSlots(6, false), 8)
	expectEq(Progression.regularSlots(6, true), 12)
	expectEq(Progression.regularSlots(99, true), 0)
end)

-- C5: atomic profile+ledger snapshots model the server persistence contract.
local ReceiptLedger = require("../src/shared/Util/ReceiptLedger")
test("Receipts: duplicate grants once", function()
	local p = ProfileSchema.default()
	local calls = 0
	local function grant()
		calls += 1
		p.tips += 100
		return true
	end
	expectTrue(ReceiptLedger.apply(p.purchases, "one", 123, grant), "first")
	expectTrue(ReceiptLedger.apply(p.purchases, "one", 124, grant), "duplicate")
	expectEq(calls, 1)
	expectEq(p.tips, 100)
	expectEq(p.purchases.one, 123)
end)
test("Receipts: failed handler remains retryable", function()
	local ledger = {}
	expectEq(
		ReceiptLedger.apply(ledger, "one", 123, function()
			return false
		end),
		false
	)
	expectEq(ledger.one, nil)
	expectEq(
		ReceiptLedger.apply(ledger, "one", 124, function()
			return true
		end),
		true
	)
end)
test("Receipts: restart after durable grant", function()
	local persisted = ProfileSchema.default()
	local draft = ProfileSchema.migrate(persisted)
	ReceiptLedger.apply(draft.purchases, "one", 123, function()
		draft.tips += 100
		return true
	end)
	persisted = ProfileSchema.migrate(draft)
	local restarted = ProfileSchema.migrate(persisted)
	local calls = 0
	ReceiptLedger.apply(restarted.purchases, "one", 124, function()
		calls += 1
		restarted.tips += 100
		return true
	end)
	expectEq(calls, 0)
	expectEq(restarted.tips, 100)
end)
test("Receipts: crash before save retries discarded draft", function()
	local persisted = ProfileSchema.default()
	local draft = ProfileSchema.migrate(persisted)
	ReceiptLedger.apply(draft.purchases, "one", 123, function()
		draft.tips += 100
		return true
	end)
	-- Crash: discard draft, reload last durable snapshot.
	local restarted = ProfileSchema.migrate(persisted)
	ReceiptLedger.apply(restarted.purchases, "one", 124, function()
		restarted.tips += 100
		return true
	end)
	expectEq(restarted.tips, 100)
	expectEq(persisted.tips, 0)
end)
test("Receipts: throwing grant never marks processed", function()
	local ledger = {}
	expectEq(
		pcall(function()
			ReceiptLedger.apply(ledger, "one", 123, function()
				error("failure")
			end)
		end),
		false
	)
	expectEq(ledger.one, nil)
end)
test("Receipts: invalid identifiers and time", function()
	for _, timestamp in { -1, 0 / 0, math.huge } do
		expectEq(
			ReceiptLedger.apply({}, "one", timestamp, function()
				return true
			end),
			false
		)
	end
	expectEq(
		ReceiptLedger.apply({}, "", 123, function()
			return true
		end),
		false
	)
end)

test("Map: tornado routes stay on open ground", function()
	for r, route in MapLayout.tornadoRoutes do
		expectTrue(#route >= 2, `route {r} needs >= 2 points`)
		for i = 1, #route - 1 do
			local a, b = route[i], route[i + 1]
			for k = 0, 20 do
				local t = k / 20
				local px, pz = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
				for j, bld in MapLayout.buildings do
					local inside = math.abs(px - bld.x) < bld.sx / 2 + 4
						and math.abs(pz - bld.z) < bld.sz / 2 + 4
					expectTrue(not inside, `route {r} segment {i} passes through building {j}`)
				end
			end
		end
	end
end)

test("Map: safe spots are outside the flood zone and buildings", function()
	local z = MapLayout.zones.LowerTown
	for i, s in MapLayout.safeSpots do
		local inFlood = math.abs(s.x - z.x) < z.sx / 2 and math.abs(s.z - z.z) < z.sz / 2
		expectTrue(not inFlood, `safe spot {i} is in the flood zone`)
		for j, bld in MapLayout.buildings do
			local inside = math.abs(s.x - bld.x) < bld.sx / 2 + 2
				and math.abs(s.z - bld.z) < bld.sz / 2 + 2
			expectTrue(not inside, `safe spot {i} is inside building {j}`)
		end
	end
end)

-- Final consistency and seeded-simulation checks for C2-C4.
test("Progression: shared tuning agrees", function()
	expectEq(ProgressionConfig.xpPerDelivery, Tuning.Orders.baseXp)
	expectEq(ProgressionConfig.passiveBasePerMinute, Tuning.Regulars.basePassiveTipsPerMinute)
	expectEq(ProgressionConfig.starBonus, Tuning.Regulars.starBonusPerStar)
	expectEq(ProgressionConfig.maxStars, Tuning.Regulars.maxStars)
	expectEq(ProgressionConfig.offlineSeconds, Tuning.Regulars.offlineMaxHours * 3600)
	expectEq(ProgressionConfig.passOfflineSeconds, Tuning.Regulars.offlineMaxHoursPass * 3600)
	expectEq(ProgressionConfig.persistence.autosaveSeconds, 60)
	expectTrue(
		ProgressionConfig.persistence.leaseSeconds
			> ProgressionConfig.persistence.autosaveSeconds * 2,
		"lease margin"
	)
end)
for _, mode in { "normal", "event", "mega" } do
	test("Odds: seeded 10000 draws " .. mode, function()
		local state = 12345
		local function rng()
			state = (state * 16807) % 2147483647
			return state / 2147483647
		end
		local counts = {}
		for _ = 1, 10000 do
			local rarity = CustomerOdds.rollRarity(mode, Rarities, {}, rng)
			counts[rarity] = (counts[rarity] or 0) + 1
		end
		for rarity, percent in CustomerOdds.describe(mode, Rarities, {}) do
			expectTrue(
				math.abs((counts[rarity] or 0) / 100 - percent) <= 1,
				rarity .. " seeded distribution"
			)
		end
	end)
end

test("Progression: one-minute and two-minute delivery pacing", function()
	for _, deliveries in { 30, 60 } do
		local level = Progression.levelFromXp(deliveries * Tuning.Orders.baseXp)
		expectTrue(level >= 5 and level <= 8, "first-hour pacing")
	end
end)

-- C8: v2 migrations preserve all v1 fields and isolate new nested data.
test("Profile v2: v1 migration preserves progress", function()
	local raw = ProfileSchema.default()
	raw.version = 1
	raw.tips = 999
	raw.xp = 300
	raw.purchases.receipt = 123
	raw.customerBook.agent = { served = 4, stars = 3 }
	raw.regulars = { "agent" }
	local p = ProfileSchema.migrate(raw)
	expectEq(p.version, ProfileSchema.VERSION)
	expectEq(p.tips, 999)
	expectEq(p.xp, 300)
	expectEq(p.purchases.receipt, 123)
	expectEq(p.customerBook.agent.stars, 3)
	expectEq(p.regulars[1], "agent")
	expectEq(p.sessions.count, 0)
end)
test("Profile v2: settings sanitize finite fractional volumes", function()
	local p = ProfileSchema.migrate({
		settings = { music = 0.25, sfx = 9, effects = "low" },
		onboardingDone = true,
	})
	expectEq(p.settings.music, 0.25)
	expectEq(p.settings.sfx, 1)
	expectEq(p.settings.effects, "low")
	expectEq(p.onboardingDone, true)
	p = ProfileSchema.migrate({
		settings = { music = 0 / 0, sfx = -5, effects = "bad" },
		onboardingDone = 1,
	})
	expectEq(p.settings.music, 1)
	expectEq(p.settings.sfx, 0)
	expectEq(p.settings.effects, "normal")
	expectEq(p.onboardingDone, false)
end)
test("Profile v2: corrupt boosts and sessions", function()
	local p = ProfileSchema.migrate({
		boosts = { scent = 123.9, bad = -1, nan = 0 / 0, infinite = math.huge },
		sessions = { count = -1, lastDay = 12.8 },
	})
	expectEq(p.boosts.scent, 123)
	expectEq(p.boosts.bad, nil)
	expectEq(p.boosts.nan, nil)
	expectEq(p.boosts.infinite, nil)
	expectEq(p.sessions.count, 0)
	expectEq(p.sessions.lastDay, 12)
end)
test("Profile v2: outbox deduplicates, validates and caps at 20", function()
	local effects = {
		{ id = "a", kind = "event", key = "Tornado", createdAt = -1 },
		{ id = "a", kind = "event", key = "Flood" },
		false,
		{ id = "bad", key = "missing kind" },
	}
	for i = 1, 30 do
		table.insert(effects, { id = tostring(i), kind = "event", key = "Flood", createdAt = 123 })
	end
	local p = ProfileSchema.migrate({ pendingEffects = effects })
	expectEq(#p.pendingEffects, 20)
	expectEq(p.pendingEffects[1].createdAt, 0)
	p.pendingEffects[1].key = "changed"
	expectEq(effects[1].key, "Tornado")
end)
test("Profile v2: independent defaults and nested invalid types", function()
	local a, b = ProfileSchema.default(), ProfileSchema.default()
	a.boosts.scent = 99
	a.settings.music = 0
	expectEq(b.boosts.scent, nil)
	expectEq(b.settings.music, 1)
	local p = ProfileSchema.migrate({
		boosts = false,
		pendingEffects = 42,
		sessions = "bad",
		settings = false,
	})
	expectEq(#p.pendingEffects, 0)
	expectEq(p.sessions.count, 0)
	expectEq(p.settings.music, 1)
end)

-- C11: style facts and population-scaled delivery meter.
local StyleConfig = require("../src/shared/Config/Style")
local StyleLogic = require("../src/shared/Util/StyleLogic")
local ChaosMeterLogic = require("../src/shared/Util/ChaosMeterLogic")
test("Style: all tags and cap", function()
	local result = StyleLogic.evaluate({
		airborne = true,
		secondsSinceSharkZone = 5,
		secondsSinceHorseLane = 0,
		hadAccident = false,
		seconds = 20,
		targetSeconds = 30,
		giantOrderClean = true,
	}, StyleConfig.style, Tuning.Style.maxTotalBonus)
	expectEq(#result.tags, 6)
	expectEq(result.bonus, 1.5)
end)
test("Style: unknown, negative, NaN facts award nothing", function()
	local result = StyleLogic.evaluate({
		secondsSinceSharkZone = -1,
		secondsSinceHorseLane = 0 / 0,
		seconds = math.huge,
		targetSeconds = 10,
	}, StyleConfig.style, 1.5)
	expectEq(#result.tags, 0)
	expectEq(result.bonus, 0)
end)
test("Style: time boundaries and accident", function()
	local result =
		StyleLogic.new(StyleConfig.style, 1.5)
			.evaluate({ secondsSinceSharkZone = 5.01, seconds = 30, targetSeconds = 30, hadAccident = true })
	expectEq(#result.tags, 0)
	result = StyleLogic.evaluate({ hadAccident = false }, StyleConfig.style, 1.5)
	expectEq(result.tags[1], "Flawless")
	expectEq(result.bonus, 0.2)
end)
test("Chaos: 8-12 players fill in target time", function()
	for count = 8, 12 do
		local state = ChaosMeterLogic.new(StyleConfig.chaos, count, 0)
		local deliveries =
			math.ceil(StyleConfig.chaos.targetSeconds * count / StyleConfig.chaos.deliverySeconds)
		for i = 1, deliveries do
			ChaosMeterLogic.addDelivery(state, false, i)
		end
		expectTrue(ChaosMeterLogic.isFull(state), "target reached")
		local seconds = deliveries / count * StyleConfig.chaos.deliverySeconds
		expectTrue(seconds >= 8 * 60 and seconds <= 12 * 60, "8-12 minute target")
	end
end)
test("Chaos: event double, cap, reset and backwards clock", function()
	local a, b =
		ChaosMeterLogic.new(StyleConfig.chaos, 8, 100),
		ChaosMeterLogic.new(StyleConfig.chaos, 8, 100)
	ChaosMeterLogic.addDelivery(a, false, 101)
	ChaosMeterLogic.addDelivery(b, true, 101)
	expectEq(b.value, a.value * 2)
	local old = b.value
	ChaosMeterLogic.addDelivery(b, true, 99)
	expectEq(b.value, old)
	for i = 1, 1000 do
		ChaosMeterLogic.addDelivery(b, true, 102 + i)
	end
	expectEq(b.value, 1)
	ChaosMeterLogic.reset(b, 2000)
	expectEq(b.value, 0)
	ChaosMeterLogic.setPlayers(b, 0)
	expectEq(b.players, 0)
end)

test("Season windows, including the new-year wrap", function()
	local xmas = { fromMonth = 12, fromDay = 1, toMonth = 1, toDay = 6 }
	expectTrue(Season.isActive(xmas, 12, 1), "Dec 1")
	expectTrue(Season.isActive(xmas, 12, 31), "Dec 31")
	expectTrue(Season.isActive(xmas, 1, 6), "Jan 6")
	expectTrue(not Season.isActive(xmas, 1, 7), "Jan 7")
	expectTrue(not Season.isActive(xmas, 11, 30), "Nov 30")
	local summer = { fromMonth = 6, fromDay = 1, toMonth = 8, toDay = 31 }
	expectTrue(Season.isActive(summer, 7, 15), "July")
	expectTrue(not Season.isActive(summer, 9, 1), "Sept")
	expectTrue(Season.isActive(nil, 3, 3), "no window = always")
	for _, e in Events do
		if e.seasonal then
			expectTrue(e.season ~= nil, `{e.id} is seasonal but has no season window`)
		end
	end
end)

-- C12: UTC calendar, skipped days, rollback clocks and weekly claims.
local RewardConfig = require("../src/shared/Config/DailyRewards")
local DailyLogin = require("../src/shared/Util/DailyLogin").new(RewardConfig)
local WeeklyChallenges = require("../src/shared/Util/WeeklyChallenges").new(RewardConfig)
test("Daily: first claim, duplicate and UTC boundary", function()
	local reward, state = DailyLogin.claim({ day = 0, lastClaim = 0 }, 86399)
	expectEq(reward.tips, RewardConfig.daily[1].tips)
	expectEq(state.day, 1)
	local duplicate = DailyLogin.claim(state, 86399)
	expectEq(duplicate, nil)
	reward, state = DailyLogin.claim(state, 86400)
	expectEq(state.day, 2)
end)
test("Daily: skipped days preserve day and seven wraps", function()
	local reward, state = DailyLogin.claim({ day = 3, lastClaim = 86400 }, 86400 * 50)
	expectEq(state.day, 4)
	expectEq(reward.tips, RewardConfig.daily[4].tips)
	reward, state = DailyLogin.claim({ day = 7, lastClaim = 86400 }, 86400 * 2)
	expectEq(state.day, 1)
end)
test("Daily: clock rewind, NaN and epoch duplicate", function()
	local original = { day = 2, lastClaim = 100000 }
	for _, now in { -1, 0 / 0, math.huge, 99999 } do
		local reward, state = DailyLogin.claim(original, now)
		expectEq(reward, nil)
		expectEq(state.lastClaim, 100000)
	end
	local reward, state = DailyLogin.claim({ day = 0, lastClaim = 0 }, 0)
	expectTrue(reward ~= nil, "epoch claim")
	expectEq(DailyLogin.claim(state, 0), nil)
	expectEq(original.day, 2)
end)
test("Weekly: choose three, count matching server events and claim once", function()
	local state = WeeklyChallenges.start(0)
	for _, id in { "CityCourier", "ChaosCourier", "NewFaces" } do
		local ok
		ok, state = WeeklyChallenges.select(state, id, 0)
		expectEq(ok, true)
	end
	local ok
	ok, state = WeeklyChallenges.select(state, "LongRoute", 0)
	expectEq(ok, false)
	state = WeeklyChallenges.record(state, "delivery", 20, 1)
	expectEq(state.selected.CityCourier.progress, 20)
	expectEq(state.selected.ChaosCourier.progress, 0)
	local reward
	reward, state = WeeklyChallenges.claim(state, "CityCourier", 2)
	expectEq(reward.tips, 250)
	reward, state = WeeklyChallenges.claim(state, "CityCourier", 3)
	expectEq(reward, nil)
	expectEq(WeeklyChallenges.claim(state, "ChaosCourier", 3), nil)
end)
test("Weekly: Monday rollover resets, rewind leaves original intact", function()
	local sunday = 3 * 86400
	local state = WeeklyChallenges.start(sunday)
	local ok
	ok, state = WeeklyChallenges.select(state, "NewFaces", sunday)
	state = WeeklyChallenges.record(state, "newCustomer", 99, sunday + 1)
	expectEq(state.selected.NewFaces.progress, 3)
	local rewind = WeeklyChallenges.record(state, "newCustomer", 1, sunday - 1)
	expectEq(rewind.lastUpdate, state.lastUpdate)
	local nextWeek = WeeklyChallenges.refresh(state, 4 * 86400)
	expectEq(next(nextWeek.selected), nil)
	expectEq(nextWeek.week, state.week + 1)
	expectEq(state.selected.NewFaces.progress, 3)
end)
test("Weekly: bad events and amounts ignored, copies isolated", function()
	local state = WeeklyChallenges.start(100)
	local ok
	ok, state = WeeklyChallenges.select(state, "CityCourier", 100)
	for _, amount in { -1, 0 / 0, math.huge, 0.5 } do
		expectEq(
			WeeklyChallenges.record(state, "delivery", amount, 101).selected.CityCourier.progress,
			0
		)
	end
	expectEq(WeeklyChallenges.record(state, "bad", 1, 101).selected.CityCourier.progress, 0)
	local choices = WeeklyChallenges.choices()
	choices[1].tips = 9999
	expectEq(WeeklyChallenges.choices()[1].tips, 250)
end)

test("GiantOrder config: Rare+ weights, sane carriers, free plaza spot", function()
	local g = Tuning.GiantOrder
	for _, weights in { g.rarityWeights, g.eventRarityWeights } do
		local sum = 0
		for rarity, w in weights do
			expectTrue(
				rarity == "Rare" or rarity == "Epic" or rarity == "Legendary",
				`bad rarity {rarity}`
			)
			expectTrue(w >= 0, "negative weight")
			sum += w
		end
		expectEq(sum, 100)
	end
	expectTrue(g.minCarriers >= 2 and g.minCarriers <= g.maxCarriers, "carrier bounds")
	expectTrue(g.leashStuds > g.grabRadiusStuds, "leash must exceed grab radius")
	local spot = MapLayout.giantOrder
	expectTrue(math.abs(spot.x) < 40 and math.abs(spot.z) < 40, "giant spot outside the plaza")
	for _, p in MapLayout.plots do
		expectTrue(
			math.sqrt((p.x - spot.x) ^ 2 + (p.z - spot.z) ^ 2) > 14,
			"giant spot overlaps a plot"
		)
	end
	local m = MapLayout.chaosMeter
	expectTrue(
		math.sqrt((m.x - spot.x) ^ 2 + (m.z - spot.z) ^ 2) > 10,
		"giant spot overlaps the meter"
	)
end)

-- C14: paid effects share the profile/receipt transaction.
local Boosts = require("../src/shared/Util/Boosts").new(Products)
local productByKey = {}
for _, product in Products.Products do
	productByKey[product.key] = product
end
test("Boosts: expiry, stacking, clock rewind and unknown key", function()
	local boosts = {}
	expectTrue(Boosts.extend(boosts, "TipBoost", 900, 100), "extend")
	expectEq(Boosts.isActive(boosts, "TipBoost", 100), true)
	expectEq(Boosts.isActive(boosts, "TipBoost", 1000), false)
	expectTrue(Boosts.extend(boosts, "TipBoost", 900, 200), "stack")
	expectEq(boosts.TipBoost, 1900)
	expectEq(Boosts.isActive(boosts, "TipBoost", 99), false)
	expectEq(Boosts.extend(boosts, "TipBoost", 60, 99), false)
	expectEq(Boosts.extend(boosts, "unknown", 60, 200), false)
	expectEq(Boosts.extend(boosts, "TipBoost", 0 / 0, 200), false)
end)
test("Boosts: multipliers and cap", function()
	local boosts = {}
	Boosts.extend(boosts, "TipBoost", 900, 100)
	Boosts.extend(boosts, "PizzaScentCloud", 600, 100)
	expectEq(
		Boosts.tipMultiplier({ DoubleTips = true }, boosts, 100),
		Products.Limits.maxTipMultiplier
	)
	expectEq(Boosts.tipMultiplier({}, boosts, 100), 2)
	expectEq(Boosts.oddsModifiers({}, boosts, 100).rarePlusMultiplier, 2)
	expectEq(Boosts.oddsModifiers({}, boosts, 700).rarePlusMultiplier, 1)
	expectEq(Boosts.tipMultiplier({ DoubleTips = true }, boosts, 1000), 2)
	Boosts.extend(boosts, "TipBoost", 1e12, 100)
	expectEq(boosts.TipBoost, 100 + Products.Limits.maxDurationSeconds)
end)
test("Products: tips and starter profile grants", function()
	local p = ProfileSchema.default()
	for _, key in { "TipsSmall", "TipsMedium", "TipsLarge" } do
		expectTrue(Boosts.apply(p, productByKey[key], key, 100), key)
	end
	expectEq(
		p.tips,
		Products.Products[5].effect.tips
			+ Products.Products[6].effect.tips
			+ Products.Products[7].effect.tips
	)
	expectTrue(Boosts.apply(p, productByKey.StarterPack, "starter", 100), "starter")
	expectTrue(p.cosmetics.owned.StarterPizzaBox, "cosmetic")
	expectEq(Boosts.apply(p, productByKey.StarterPack, "starter2", 100), false)
end)
test("Products: event outbox capacity and exact consumption", function()
	local p = ProfileSchema.default()
	for i = 1, Products.Limits.maxPending do
		expectTrue(Boosts.apply(p, productByKey.OrderDisaster, tostring(i), 100), "outbox")
	end
	expectEq(Boosts.apply(p, productByKey.MegaChaosNow, "overflow", 100), false)
	expectEq(#Boosts.takePending(p, "other"), 0)
	expectEq(#Boosts.takePending(p, "event", "1"), 1)
	expectEq(#Boosts.takePending(p, "event", "1"), 0)
	expectEq(#Boosts.takePending(p, "event"), Products.Limits.maxPending - 1)
end)
test("Products: failed receipt transaction discards full outbox", function()
	local p = ProfileSchema.default()
	for i = 1, 20 do
		Boosts.apply(p, productByKey.OrderDisaster, tostring(i), 100)
	end
	local draft = ProfileSchema.migrate(p)
	expectEq(
		ReceiptLedger.apply(draft.purchases, "overflow", 100, function()
			return Boosts.apply(draft, productByKey.OrderDisaster, "overflow", 100)
		end),
		false
	)
	expectEq(draft.purchases.overflow, nil)
	expectEq(#p.pendingEffects, 20)
end)

-- C15: v3 weekly state is durable, bounded and isolated.
test("Profile v3: migration preserves v2 and sanitizes weekly", function()
	local p = ProfileSchema.migrate({
		version = 2,
		tips = 321,
		weekly = {
			week = 12,
			lastUpdate = 999,
			selected = {
				A = { progress = -1, claimed = 1 },
				B = { progress = 0 / 0, claimed = true },
				C = { progress = 9, claimed = false },
			},
		},
	})
	expectEq(p.version, ProfileSchema.VERSION)
	expectEq(p.tips, 321)
	expectEq(p.weekly.week, 12)
	expectEq(p.weekly.selected.A.progress, 0)
	expectEq(p.weekly.selected.A.claimed, false)
	expectEq(p.weekly.selected.B.claimed, true)
end)
test("Profile v3: weekly survives a full transaction snapshot", function()
	local p = ProfileSchema.default()
	p.weekly = WeeklyChallenges.start(100)
	local ok
	ok, p.weekly = WeeklyChallenges.select(p.weekly, "CityCourier", 100)
	expectEq(ok, true)
	p.weekly = WeeklyChallenges.record(p.weekly, "delivery", 20, 101)
	local restored = ProfileSchema.migrate(p)
	expectEq(restored.weekly.selected.CityCourier.progress, 20)
	restored.weekly.selected.CityCourier.progress = 0
	expectEq(p.weekly.selected.CityCourier.progress, 20)
end)
test("Daily: reward and calendar commit together and duplicate never pays", function()
	local p = ProfileSchema.default()
	local reward, state = DailyLogin.claim(p.dailyLogin, 100)
	p.dailyLogin = state
	p.tips += reward.tips
	local restored = ProfileSchema.migrate(p)
	expectEq(DailyLogin.claim(restored.dailyLogin, 100), nil)
	expectEq(restored.tips, reward.tips)
end)

-- C16: rank counters migrate independently from weekly challenge choices.
local LeaderboardConfig = require("../src/shared/Config/Leaderboards")
test("Leaderboard: weekly counter persists and sanitizes", function()
	local p = ProfileSchema.migrate({ weeklyDeliveries = { week = 100, count = 12 } })
	expectEq(p.weeklyDeliveries.count, 12)
	expectEq(p.weeklyDeliveries.week, 100)
	expectEq(
		ProfileSchema.migrate({ weeklyDeliveries = { week = -1, count = 0 / 0 } }).weeklyDeliveries.count,
		0
	)
	expectEq(LeaderboardConfig.refreshSeconds, 60)
	expectEq(LeaderboardConfig.x, -22)
	expectEq(LeaderboardConfig.z, 2)
end)

-- C17: quality defaults and particle budgets are pure data.
local SettingsConfig = require("../src/shared/Config/Settings")
local Settings = require("../src/shared/Util/Settings").new(SettingsConfig)
test("Settings: mobile and desktop defaults", function()
	expectEq(Settings.default(true, 390), "low")
	expectEq(Settings.default(false, 390), "high")
	expectEq(Settings.default(true, 1200), "high")
end)
test("Settings: particle scales and invalid input", function()
	expectEq(Settings.particleScale("low"), 0.25)
	expectEq(Settings.particleScale("medium"), 0.6)
	expectEq(Settings.particleScale("high"), 1)
	expectEq(Settings.isQuality("ultra"), false)
	expectEq(Settings.isQuality({}), false)
	expectEq(Settings.particleScale(nil), 0.25)
end)
test("Settings: profile round trip and corrupt quality", function()
	local p = ProfileSchema.migrate({ settings = { quality = "medium", music = 0.4 } })
	expectEq(p.settings.quality, "medium")
	expectEq(p.settings.music, 0.4)
	expectEq(ProfileSchema.migrate({ settings = { quality = "invalid" } }).settings.quality, nil)
end)

test("StarterPack: eligibility expires and respects first-seen clock", function()
	local p = ProfileSchema.default()
	p.firstSeen = 100
	expectEq(Boosts.canGrant(p, productByKey.StarterPack, 100), true)
	expectEq(Boosts.canGrant(p, productByKey.StarterPack, 99), false)
	expectEq(Boosts.canGrant(p, productByKey.StarterPack, 100 + 4 * 86400), false)
end)

test("Products: catalog contract and pending peek copy", function()
	local passes, items = Boosts.catalog(function()
		return false
	end, function()
		return false
	end, function()
		return nil
	end)
	expectEq(#passes, #Products.Gamepasses)
	expectEq(#items, #Products.Products)
	expectEq(items[1].key, Products.Products[1].key)
	expectEq(items[1].available, false)
	expectEq(Boosts.find("missing"), nil)
	local p = ProfileSchema.default()
	Boosts.apply(p, productByKey.OrderDisaster, "event", 100)
	local effect = Boosts.peekPending(p, "event")
	expectEq(effect.eventId, "Tornado")
	effect.key = "changed"
	expectEq(p.pendingEffects[1].key, "OrderDisaster")
end)

-- Backlog M4/M5: automatic rewards and their durable claim ledger.
local ProgressRewardConfig = require("../src/shared/Config/ProgressRewards")
local ProgressRewards = require("../src/shared/Util/ProgressRewards").new(
	ProgressRewardConfig,
	Customers,
	Progression.levelFromXp
)
test("Progress rewards: exact book thresholds and duplicate claims", function()
	local p = ProfileSchema.default()
	for i = 1, 4 do
		p.customerBook[Customers[i].id] = { served = 1, stars = 0 }
	end
	expectEq(ProgressRewards.claim(p).changed, false)
	p.customerBook[Customers[5].id] = { served = 1, stars = 0 }
	local award = ProgressRewards.claim(p)
	expectEq(award.tips, ProgressRewardConfig.book[1].tips)
	expectEq(p.cosmetics.owned.ExtraCheeseBox, true)
	expectEq(ProgressRewards.claim(p).tips, 0)
	expectEq(ProgressRewards.claim(p).changed, false)
end)
test("Progress rewards: ignores unknown and unserved customers", function()
	local p = ProfileSchema.default()
	p.customerBook.fake = { served = 999, stars = 5 }
	p.customerBook[Customers[1].id] = { served = 0, stars = 0 }
	expectEq(ProgressRewards.plan(p).discovered, 0)
end)
test("Progress rewards: catch up book milestones, persist, award title", function()
	local p = ProfileSchema.default()
	for i = 1, 24 do
		p.customerBook[Customers[i].id] = { served = 1, stars = 0 }
	end
	expectEq(#ProgressRewards.claim(p).milestones, 5)
	expectEq(ProgressRewards.title(p), "Hospitality Legend")
	local restored = ProfileSchema.migrate(p)
	expectEq(ProgressRewards.claim(restored).changed, false)
	expectEq(restored.progressRewards.book["24"], true)
end)
test("Progress rewards: level rewards sum and never repay XP rewind", function()
	local p = ProfileSchema.default()
	p.xp = Progression.xpForLevel(5)
	local award = ProgressRewards.claim(p)
	expectEq(award.levelTo, 5)
	expectEq(award.tips, 25 + 35 + 45 + 55)
	p.xp = 0
	expectEq(ProgressRewards.claim(p).changed, false)
	p.xp = Progression.xpForLevel(6)
	expectEq(ProgressRewards.claim(p).tips, 65)
end)
test("Progress rewards: tip cap still records claims", function()
	local p = ProfileSchema.default()
	p.tips = ProgressRewardConfig.maxTips - 1
	p.xp = Progression.xpForLevel(2)
	expectEq(ProgressRewards.claim(p).tips, 1)
	expectEq(p.tips, ProgressRewardConfig.maxTips)
	expectEq(ProgressRewards.claim(p).changed, false)
end)
test("Profile v4: reward ledger migration and copy", function()
	local p = ProfileSchema.migrate({
		version = 3,
		progressRewards = { level = -2, book = { ["5"] = true, ["10"] = 1 } },
	})
	expectEq(p.version, ProfileSchema.VERSION)
	expectEq(p.progressRewards.level, 1)
	expectEq(p.progressRewards.book["10"], nil)
	local q = ProfileSchema.migrate(p)
	q.progressRewards.book["5"] = false
	expectEq(p.progressRewards.book["5"], true)
end)

-- Backlog M8: owned looks, atomic purchase and equip only change cosmetic fields.
local CosmeticConfig = require("../src/shared/Config/Cosmetics")
local Cosmetics = require("../src/shared/Util/Cosmetics").new(CosmeticConfig)
test("Cosmetics: classic defaults are available and persist when equipped", function()
	local p = ProfileSchema.default()
	expectEq(Cosmetics.effective(p, "box").id, "ClassicBox")
	expectEq(Cosmetics.equip(p, "ClassicBox"), true)
	expectEq(ProfileSchema.migrate(p).cosmetics.equipped.box, "ClassicBox")
end)
test("Cosmetics: locked equip, insufficient funds and unknown ids fail", function()
	local p = ProfileSchema.default()
	expectEq(Cosmetics.equip(p, "ExtraCheeseBox"), false)
	expectEq(Cosmetics.buy(p, "ExtraCheeseBox"), false)
	expectEq(Cosmetics.buy(p, "missing"), false)
	expectEq(Cosmetics.equip(p, "missing"), false)
	expectEq(p.tips, 0)
	expectEq(p.cosmetics.equipped.box, nil)
end)
test("Cosmetics: exact funds, duplicate purchase and slot validation", function()
	local p = ProfileSchema.default()
	p.tips = Cosmetics.get("ExtraCheeseBox").price
	expectEq(Cosmetics.buy(p, "ExtraCheeseBox"), true)
	expectEq(p.tips, 0)
	expectEq(Cosmetics.buy(p, "ExtraCheeseBox"), false)
	expectEq(Cosmetics.equip(p, "ExtraCheeseBox"), true)
	p.cosmetics.equipped.bag = "ExtraCheeseBox"
	expectEq(Cosmetics.effective(p, "bag").id, "ClassicBag")
	expectEq(p.xp, 0)
	expectEq(p.movementTier, 0)
	expectEq(p.pizzeriaLevel, 1)
end)
test("Cosmetics: earned and starter items equip without buying", function()
	local p = ProfileSchema.default()
	p.cosmetics.owned.StarterPizzaBox = true
	expectEq(Cosmetics.equip(p, "StarterPizzaBox"), true)
	expectEq(Cosmetics.buy(p, "StarterPizzaBox"), false)
	p.cosmetics.owned.HospitalityLegend = true
	expectEq(Cosmetics.equip(p, "HospitalityLegend"), true)
	expectEq(#Cosmetics.catalog(p), #CosmeticConfig.items)
end)

-- Backlog M5 daily calendar: day seven includes an earned cosmetic.
test("Daily: seventh-day cosmetic and eight-day reset", function()
	local state = { day = 0, lastClaim = 0 }
	local seventh
	for day = 1, 7 do
		local reward
		reward, state = DailyLogin.claim(state, day * 86400)
		if day == 7 then
			seventh = reward
		else
			expectEq(reward.cosmetic, nil)
		end
	end
	expectEq(seventh.cosmetic, "WeekOneJar")
	expectTrue(Cosmetics.get(seventh.cosmetic) ~= nil, "reward exists in catalog")
	expectEq(DailyLogin.claim(state, 7 * 86400), nil)
	local nextReward
	nextReward, state = DailyLogin.claim(state, 8 * 86400)
	expectEq(state.day, 1)
	expectEq(nextReward.cosmetic, nil)
end)

-- Backlog M5: ride upgrades use profile XP and target-specific purchase intents.
local RideConfig = require("../src/shared/Config/MovementUpgrades")
local Rides = require("../src/shared/Util/MovementUpgrades").new(
	Movement,
	Tuning.Movement.maxSpeedBonus,
	Progression.levelFromXp
)
test("Rides: exact funds, duplicate target and schema roundtrip", function()
	local p = ProfileSchema.default()
	p.tips = Movement[2].cost
	expectEq(Rides.buy(p, 1, false), true)
	expectEq(p.tips, 0)
	expectEq(p.movementTier, 1)
	p.tips = 99999
	expectEq(Rides.buy(p, 1, false), false)
	expectEq(p.tips, 99999)
	expectEq(ProfileSchema.migrate(p).movementTier, 1)
	expectEq(p.xp, 0)
	expectEq(p.pizzeriaLevel, 1)
end)
test("Rides: no skipping or malformed tiers and no negative funds", function()
	local p = ProfileSchema.default()
	p.tips = Movement[2].cost - 1
	expectEq(Rides.buy(p, 1, false), false)
	expectEq(Rides.buy(p, 2, false), false)
	expectEq(Rides.buy(p, -1, false), false)
	expectEq(Rides.buy(p, 1.5, false), false)
	expectEq(Rides.buy(p, 0 / 0, false), false)
	expectEq(p.movementTier, 0)
	expectEq(p.tips, Movement[2].cost - 1)
end)
test("Rides: XP gate reads exact courier level boundary", function()
	local p = ProfileSchema.default()
	p.movementTier = 1
	p.tips = Movement[3].cost
	p.xp = Progression.xpForLevel(Movement[3].requiredCourierLevel) - 1
	expectEq(Rides.buy(p, 2, false), false)
	expectEq(p.tips, Movement[3].cost)
	p.xp += 1
	expectEq(Rides.buy(p, 2, false), true)
	expectEq(p.tips, 0)
end)
test("Rides: five tiers obey cap and max tier cannot charge again", function()
	local p = ProfileSchema.default()
	p.tips = 100000
	p.xp = Progression.xpForLevel(20)
	local spent = 0
	for tier = 1, 4 do
		local entry = Rides.get(tier)
		spent += entry.cost
		expectEq(Rides.buy(p, tier, false), true)
		expectTrue(
			Rides.effective(p, false).speedBonus <= Tuning.Movement.maxSpeedBonus,
			"speed cap"
		)
	end
	expectEq(p.tips, 100000 - spent)
	expectEq(Rides.buy(p, 5, false), false)
	expectEq(Rides.buy(p, 4, false), false)
	expectEq(Rides.effective(p, false).speedBonus, 0.30)
	expectEq(#Rides.catalog(p, false), 5)
	expectTrue(
		RideConfig.skateboardJumpBonus > 0 and RideConfig.skateboardJumpBonus <= 0.1,
		"small jump bonus"
	)
end)
test("Rides: early access grants same capped ride without erasing earned progress", function()
	local p = ProfileSchema.default()
	p.movementTier = 1
	p.tips = 50000
	expectEq(Rides.effective(p, true).tier, 4)
	expectEq(Rides.buy(p, 2, true), false)
	expectEq(p.tips, 50000)
	expectEq(p.movementTier, 1)
	expectEq(Rides.effective(p, false).tier, 1)
	local list = Rides.catalog(p, true)
	for _, entry in list do
		expectEq(entry.owned, true)
		expectEq(entry.available, false)
	end
	expectEq(list[5].active, true)
	expectEq(Rides.effective({ movementTier = 99 }, false).tier, 0)
end)
test("Cosmetics: every earned or bundled look explains its unlock", function()
	for _, item in Cosmetics.catalog(ProfileSchema.default()) do
		if not item.owned and item.price == nil then
			expectTrue(type(item.unlockHint) == "string" and #item.unlockHint > 0, item.id)
		end
	end
end)

-- Backlog M5: one persisted daily like per visitor and pizzeria.
local LikeConfig = require("../src/shared/Config/PizzeriaLikes")
local Likes = require("../src/shared/Util/PizzeriaLikes").new(LikeConfig)
test("Likes: one per visitor per UTC day, survives save and reconnect", function()
	local p = ProfileSchema.default()
	local now = LikeConfig.secondsPerDay + 1
	expectEq(Likes.apply(p, 10, 20, now, LikeConfig.minimumSessionSeconds), true)
	expectEq(Likes.count(p.likes, now), 1)
	p = ProfileSchema.migrate(p)
	expectEq(Likes.apply(p, 10, 20, now, LikeConfig.minimumSessionSeconds), false)
	expectEq(Likes.apply(p, 11, 20, now, LikeConfig.minimumSessionSeconds), true)
	expectEq(Likes.count(p.likes, now), 2)
	expectEq(Likes.count(p.likes, LikeConfig.secondsPerDay * 2), 0)
	expectEq(
		Likes.apply(p, 10, 20, LikeConfig.secondsPerDay * 2, LikeConfig.minimumSessionSeconds),
		true
	)
	expectEq(Likes.count(p.likes, LikeConfig.secondsPerDay * 2), 1)
	expectEq(p.likes.from["11"], nil)
end)
test("Likes: own pizzeria, invalid identity and insufficient playtime reject", function()
	local p = ProfileSchema.default()
	local now = LikeConfig.secondsPerDay
	expectEq(Likes.apply(p, 10, 10, now, 999), false)
	expectEq(Likes.apply(p, 0, 20, now, 999), false)
	expectEq(Likes.apply(p, 1.5, 20, now, 999), false)
	expectEq(Likes.apply(p, math.huge, 20, now, 999), false)
	expectEq(Likes.apply(p, 1e20, 20, now, 999), false)
	expectEq(Likes.apply(p, 10, 20, now, LikeConfig.minimumSessionSeconds - 0.001), false)
	expectEq(Likes.apply(p, 10, 20, now, 0 / 0), false)
	expectEq(Likes.count(p.likes, now), 0)
	expectEq(Likes.apply(p, 10, 20, now, LikeConfig.minimumSessionSeconds), true)
	expectEq(p.tips, 0)
	expectEq(p.xp, 0)
end)
test("Likes: clock rewind, negative and nonfinite time never grant", function()
	local p = ProfileSchema.default()
	expectEq(Likes.apply(p, 10, 20, LikeConfig.secondsPerDay * 3, 120), true)
	for _, now in { LikeConfig.secondsPerDay * 2, -1, 0 / 0, math.huge } do
		expectEq(Likes.apply(p, 11, 20, now, 120), false)
	end
	expectEq(Likes.count(p.likes, LikeConfig.secondsPerDay * 3), 1)
end)
test("Likes: daily ledger bound and new day frees capacity", function()
	local p = ProfileSchema.default()
	for id = 1, LikeConfig.maxDailyLikes do
		p.likes.from[tostring(id)] = true
	end
	expectEq(Likes.apply(p, 3000, 4000, 1, 120), false)
	local q = ProfileSchema.migrate(p)
	expectEq(Likes.count(q.likes, 1), LikeConfig.maxDailyLikes)
	expectEq(Likes.apply(q, 3000, 4000, LikeConfig.secondsPerDay, 120), true)
	expectEq(Likes.count(q.likes, LikeConfig.secondsPerDay), 1)
end)
test("Likes: positive leaders, ties and refresh after owner leaves", function()
	expectEq(next(Likes.leaders({ [1] = 0, [2] = 0 })), nil)
	local leaders = Likes.leaders({ [1] = 5, [2] = 3, [3] = 5 })
	expectEq(leaders[1], true)
	expectEq(leaders[2], nil)
	expectEq(leaders[3], true)
	expectEq(Likes.leaders({ [2] = 3 })[2], true)
end)
test("Profile v5: safe like-ledger migration and v4 preservation", function()
	local p = ProfileSchema.migrate({
		version = 4,
		tips = 700,
		movementTier = 3,
		progressRewards = { book = { ["5"] = true }, level = 4 },
		likes = {
			day = 5,
			from = {
				["10"] = true,
				["abc"] = true,
				["0"] = true,
				["-1"] = true,
				["1.5"] = true,
				["11"] = 1,
			},
		},
	})
	expectEq(p.version, ProfileSchema.VERSION)
	expectEq(p.tips, 700)
	expectEq(p.movementTier, 3)
	expectEq(p.progressRewards.book["5"], true)
	expectEq(Likes.count(p.likes, LikeConfig.secondsPerDay * 5), 1)
	expectEq(p.likes.from["10"], true)
	local q = ProfileSchema.migrate(p)
	q.likes.from["10"] = nil
	expectEq(p.likes.from["10"], true)
	expectEq(ProfileSchema.migrate({ likes = { day = 0 / 0, from = "bad" } }).likes.day, 0)
end)

-- Backlog M8: only known, active boosts appear in stable, copied timer data.
test("Boost status: active catalog, expiry boundary, unknown keys and clock rewind", function()
	local state = {}
	expectEq(Boosts.extend(state, "TipBoost", 900, 100), true)
	expectEq(Boosts.extend(state, "PizzaScentCloud", 600, 100), true)
	state.fake = 1000
	local list = Boosts.active(state, 100)
	expectEq(#list, 2)
	expectEq(list[1].key, "PizzaScentCloud")
	expectEq(list[2].expiresAt, 1000)
	expectEq(#Boosts.active(state, 99), 0)
	expectEq(#Boosts.active(state, 700), 1)
	expectEq(#Boosts.active(state, 1000), 0)
	expectEq(#Boosts.active(state, math.huge), 0)
	list[2].expiresAt = 0
	expectEq(state.TipBoost, 1000)
end)
test("Boost status: saved offline time elapses instead of restarting", function()
	local p = ProfileSchema.default()
	Boosts.extend(p.boosts, "TipBoost", 900, 100)
	p = ProfileSchema.migrate(p)
	expectEq(Boosts.active(p.boosts, 400)[1].expiresAt, 1000)
	expectEq(#Boosts.active(p.boosts, 1001), 0)
end)

-- Reward caps must never debit old balances or acknowledge partial paid grants.
test("Paid tips: whole grant fits exactly or makes no changes", function()
	local p = ProfileSchema.default()
	local price = productByKey.TipsSmall.effect.tips
	p.tips = Products.Limits.maxTips - price
	expectEq(Boosts.canGrant(p, productByKey.TipsSmall, 100), true)
	expectEq(Boosts.apply(p, productByKey.TipsSmall, "full", 100), true)
	expectEq(p.tips, Products.Limits.maxTips)
	expectEq(Boosts.canGrant(p, productByKey.TipsSmall, 100), false)
	expectEq(Boosts.apply(p, productByKey.TipsSmall, "overflow", 100), false)
	expectEq(p.tips, Products.Limits.maxTips)
	p.tips = Products.Limits.maxTips + 100
	expectEq(Boosts.apply(p, productByKey.TipsSmall, "legacy", 100), false)
	expectEq(p.tips, Products.Limits.maxTips + 100)
end)
test("Starter bundle: insufficient room cannot partially extend boost or grant cosmetic", function()
	local p = ProfileSchema.default()
	p.tips = Products.Limits.maxTips - 1
	expectEq(Boosts.apply(p, productByKey.StarterPack, "overflow", 100), false)
	expectEq(p.boosts.TipBoost, nil)
	expectEq(p.cosmetics.owned.StarterPizzaBox, nil)
	expectEq(p.tips, Products.Limits.maxTips - 1)
end)
test("Starter bundle: late paid receipt still fulfills after offer expires", function()
	local p = ProfileSchema.default()
	p.firstSeen = 100
	local now = 100 + 4 * Products.Limits.secondsPerDay
	expectEq(Boosts.canGrant(p, productByKey.StarterPack, now), false)
	expectEq(Boosts.apply(p, productByKey.StarterPack, "late-paid", now), true)
	expectEq(p.cosmetics.owned.StarterPizzaBox, true)
	expectEq(p.tips, productByKey.StarterPack.effect.tips)
	expectEq(Boosts.apply(p, productByKey.StarterPack, "duplicate", now), false)
end)
test("Progress rewards: legacy above-cap balance is preserved", function()
	local p = ProfileSchema.default()
	p.tips = ProgressRewardConfig.maxTips + 100
	p.xp = Progression.xpForLevel(2)
	expectEq(ProgressRewards.claim(p).tips, 0)
	expectEq(p.tips, ProgressRewardConfig.maxTips + 100)
	expectEq(p.progressRewards.level, 2)
end)

local CodeConfig = require("../src/shared/Config/Codes")
local Grant = require("../src/shared/Util/RewardGrant")
local Codes =
	require("../src/shared/Util/Codes").new(CodeConfig, Progression.levelFromXp, Grant.apply)
test("Codes: normalize, durable once-only grant and cosmetic", function()
	local p = ProfileSchema.default()
	expectEq(Codes.redeem(p, " welcome ", 100), true)
	expectEq(p.tips, 150)
	p = ProfileSchema.migrate(p)
	expectEq(Codes.redeem(p, "WELCOME", 100), false)
	expectEq(p.tips, 150)
	p.xp = Progression.xpForLevel(2)
	expectEq(Codes.redeem(p, "pizzaparty", 100), true)
	expectEq(p.cosmetics.owned.ExtraCheeseBox, true)
end)
test("Codes: expiry, minimum level and malformed input", function()
	local p = ProfileSchema.default()
	expectEq(Codes.redeem(p, "PIZZAPARTY", 100), false)
	p.xp = Progression.xpForLevel(2)
	expectEq(Codes.redeem(p, "PIZZAPARTY", CodeConfig.codes.PIZZAPARTY.expiresAt), false)
	for _, v in { false, {}, "", string.rep("X", 200), "???", "UNKNOWN" } do
		expectEq(Codes.redeem(p, v, 100), false)
	end
	expectEq(next(p.claims), nil)
end)
test("Codes: cap never removes existing money; schema sanitizes ledger", function()
	local p = ProfileSchema.default()
	p.tips = CodeConfig.maxTips + 50
	expectEq(Codes.redeem(p, "WELCOME", 100), true)
	expectEq(p.tips, CodeConfig.maxTips + 50)
	local q = ProfileSchema.migrate({ claims = { ok = 100, bad = 0 / 0, negative = -1 } })
	expectEq(q.claims.ok, 100)
	expectEq(q.claims.bad, nil)
	expectEq(q.claims.negative, nil)
end)

local BadgeConfig = require("../src/shared/Config/Badges")
local Achievements = require("../src/shared/Util/Achievements")
test("Badges: config stays disabled until real IDs; durable event milestones", function()
	local p = ProfileSchema.default()
	for _, badge in BadgeConfig.items do
		expectEq(badge.badgeId, 0)
		expectEq(Achievements.met(p, badge, Customers), false)
	end
	p.claims["achievement.FirstMega"] = 100
	expectEq(Achievements.met(ProfileSchema.migrate(p), BadgeConfig.items[3], Customers), true)
end)
test("Badges: server profile thresholds, known book entries only", function()
	local p = ProfileSchema.default()
	p.deliveries = 1
	p.pizzeriaLevel = 6
	expectEq(Achievements.met(p, BadgeConfig.items[1], Customers), true)
	expectEq(Achievements.met(p, BadgeConfig.items[6], Customers), true)
	p.customerBook.fake = { served = 10, stars = 0 }
	for i = 1, 10 do
		p.customerBook[Customers[i].id] = { served = 1, stars = 0 }
	end
	expectEq(Achievements.met(p, BadgeConfig.items[4], Customers), true)
	expectEq(Achievements.met(p, BadgeConfig.items[5], Customers), false)
end)

local Community = require("../src/shared/Config/Community")
local Referrals = require("../src/shared/Util/Referrals").new(Community, Grant.apply)
test("Friends: actual friendship, age, time, self and daily pair limits", function()
	local p = ProfileSchema.default()
	local f = { friends = true, secondsA = 120, secondsB = 120, ageA = 7, ageB = 7 }
	f.friends = false
	expectEq(Referrals.apply(p, 1, 2, 100, f), false)
	f.friends = true
	f.ageA = 6
	expectEq(Referrals.apply(p, 1, 2, 100, f), false)
	f.ageA = 7
	f.secondsB = 119
	expectEq(Referrals.apply(p, 1, 2, 100, f), false)
	f.secondsB = 120
	expectEq(Referrals.apply(p, 1, 1, 100, f), false)
	expectEq(Referrals.apply(p, 1, 2, 100, f), true)
	p = ProfileSchema.migrate(p)
	expectEq(Referrals.apply(p, 1, 2, 100, f), false)
	expectEq(Referrals.apply(p, 1, 3, 100, f), true)
	expectEq(Referrals.apply(p, 1, 4, 100, f), true)
	expectEq(Referrals.apply(p, 1, 5, 100, f), false)
	expectEq(p.tips, 3 * Community.friendTips)
	expectEq(Referrals.apply(p, 1, 2, 86400, f), true)
	expectEq(Referrals.apply(p, 1, 6, 100, f), false)
end)

local GroupReward = require("../src/shared/Util/GroupReward")
test("Group: ID0 disabled; membership required; cosmetic is durable and once-only", function()
	local p = ProfileSchema.default()
	expectEq(GroupReward.apply(p, Community, true, 100), false)
	local c = { groupId = 123, groupCosmetic = "CommunityBag" }
	expectEq(GroupReward.apply(p, c, false, 100), false)
	expectEq(GroupReward.apply(p, c, true, 100), true)
	p = ProfileSchema.migrate(p)
	expectEq(GroupReward.apply(p, c, true, 200), false)
	expectEq(p.cosmetics.owned.CommunityBag, true)
	expectEq(p.tips, 0)
	expectEq(p.xp, 0)
end)

local Summarize =
	require("../src/shared/Util/CourierProfile").new(Customers, Rarities, Progression.levelFromXp)
test(
	"Profile: read-only public summary uses known served customers and hides private fields",
	function()
		local p = ProfileSchema.default()
		p.tips = 999
		p.deliveries = 10
		p.xp = 50
		p.customerBook.fake = { served = 1, stars = 0 }
		p.customerBook[Customers[1].id] = { served = 1, stars = 0 }
		local s = Summarize(p, 4, "Legend")
		expectEq(s.discovered, 1)
		expectEq(s.level, 2)
		expectEq(s.likes, 4)
		expectEq(s.title, "Legend")
		expectEq(s.tips, nil)
		expectEq(s.claims, nil)
		expectEq(s.purchases, nil)
		expectEq(p.tips, 999)
	end
)

local VisitPolicy = require("../src/shared/Util/VisitPolicy")
test("Visits: all hazard phases, death, giant carrying and cooldown are blocked", function()
	for _, phase in { "warning", "buildUp", "active", "windDown", "reset" } do
		expectEq(VisitPolicy.check(phase, 100, 0, true, false), false)
	end
	expectEq(VisitPolicy.check("calm", 100, 101, true, false), false)
	expectEq(VisitPolicy.check("calm", 100, 0, false, false), false)
	expectEq(VisitPolicy.check("calm", 100, 0, true, true), false)
	expectEq(VisitPolicy.check("calm", 100, 100, true, false), true)
end)

local Emotes = require("../src/shared/Util/Emotes")
test("Emotes: free and owned only; paid pose is cosmetic and slot-checked", function()
	local p = ProfileSchema.default()
	expectEq(Emotes.allowed(p, "WaveEmote", Cosmetics), true)
	expectEq(Emotes.allowed(p, "DanceEmote", Cosmetics), true)
	expectEq(Emotes.allowed(p, "PizzaPoseEmote", Cosmetics), false)
	expectEq(Emotes.allowed(p, "ClassicBox", Cosmetics), false)
	p.tips = 500
	expectEq(Cosmetics.buy(p, "PizzaPoseEmote"), true)
	expectEq(Emotes.allowed(p, "PizzaPoseEmote", Cosmetics), true)
	expectEq(p.movementTier, 0)
	expectEq(p.xp, 0)
	expectEq(p.deliveries, 0)
end)

local WeeklyAwardConfig = require("../src/shared/Config/WeeklyRewards")
local Awards = require("../src/shared/Util/WeeklyAwards")
local SnapshotStore = require("../src/server/Util/SnapshotStore")
test("Weekly awards: positive top10, once-only durable title and skin", function()
	local p = ProfileSchema.default()
	local snap =
		Awards.snapshot(2966, { { key = "1", value = 5 }, { key = "2", value = 0 } }, 100, 10)
	expectEq(#snap.winners, 1)
	expectEq(Awards.claim(p, 2, snap, WeeklyAwardConfig, 200), false)
	expectEq(Awards.claim(p, 1, snap, WeeklyAwardConfig, 200), true)
	p = ProfileSchema.migrate(p)
	expectEq(Awards.claim(p, 1, snap, WeeklyAwardConfig, 201), false)
	expectEq(p.cosmetics.owned.WeeklyChampionJar, true)
	expectEq(p.cosmetics.equipped.title, "WeeklyTop10")
end)
test("Weekly awards: snapshot first writer wins and copies stay isolated", function()
	local shared
	local function storeFor()
		return {
			UpdateAsync = function(_, _, fn)
				shared = fn(shared)
				return shared
			end,
			GetAsync = function()
				return shared
			end,
		}
	end
	local function retry(fn)
		return pcall(fn)
	end
	local a = SnapshotStore.new(storeFor, function()
		return true
	end, retry)
	local b = SnapshotStore.new(storeFor, function()
		return true
	end, retry)
	local one = a("awards", "week", { winners = { 1 } })
	one.winners[1] = 99
	local two = b("awards", "week", { winners = { 2 } })
	expectEq(two.winners[1], 1)
	expectEq(a("awards", "week", nil).winners[1], 1)
end)

local SimConfig = require("../src/shared/Config/EconomySimulation")
local Sim = require("../src/shared/Util/EconomySimulator")
test("Economy simulator: deterministic seeded real-Config model and early upgrade", function()
	local m = {
		schema = ProfileSchema,
		daily = require("../src/shared/Config/DailyRewards"),
		boosts = Boosts,
		progression = Progression,
		progressionConfig = table.clone(require("../src/shared/Config/Progression")),
		pizzeria = Pizzeria,
		rarities = Rarities,
		customers = Customers,
		config = SimConfig,
		tuning = Tuning,
		events = Events,
		season = Season,
		odds = CustomerOdds,
		style = require("../src/shared/Util/StyleLogic"),
		styleConfig = require("../src/shared/Config/Style"),
		rewards = ProgressRewards,
	}
	m.progressionConfig.pizzeriaOddsBonusPerLevel = SimConfig.pizzeriaOddsBonusPerLevel
	local originalPrice = Pizzeria[2].cost
	local a = Sim.run(m, SimConfig.scenarios[1], 123, 600)
	local b = Sim.run(m, SimConfig.scenarios[1], 123, 600)
	expectEq(a.firstUpgrade, b.firstUpgrade)
	expectEq(a.finalBook, b.finalBook)
	expectTrue(a.firstUpgrade < 180, "first upgrade under three minutes")
	expectEq(Pizzeria[2].cost, originalPrice)
end)

local SmokeConfig = require("../src/shared/Config/Smoke")
test("Smoke: bounded under two minutes, cooperative polling and rollback copies", function()
	expectTrue(
		SmokeConfig.maxSeconds < 120
			and SmokeConfig.maxSeconds > Tuning.ChaosMeter.megaDurationSeconds,
		"bounded smoke"
	)
	expectTrue(SmokeConfig.pollSeconds > 0, "cooperative loop")
	local a = { one = { 2 } }
	local b = SnapshotStore.copy(a)
	b.one[1] = 3
	expectEq(a.one[1], 2)
end)

local RarityLabel = require("../src/shared/Util/RarityLabel")
test("Accessibility: rarity codes unique without color; large text migrates safely", function()
	local seen = {}
	for _, r in Rarities do
		local s = RarityLabel.text(r.id)
		local code = string.sub(s, 1, 3)
		expectEq(seen[code], nil)
		seen[code] = true
	end
	expectEq(Settings.textScale("normal"), 1)
	expectEq(Settings.textScale("large"), 1.25)
	expectEq(
		Settings.textScale({
			GetAttribute = function()
				return "large"
			end,
		}),
		1.25
	)
	expectEq(
		ProfileSchema.migrate({ settings = { textSize = "large" } }).settings.textSize,
		"large"
	)
	expectEq(ProfileSchema.migrate({ settings = { textSize = "bad" } }).settings.textSize, "normal")
end)

local Localize = require("../src/shared/Util/Localize")
local Strings = require("../src/shared/Config/Strings")
local Translate = Localize.new(Strings)
test("Localization: Hungarian account locale, English fallback, digits and player names", function()
	expectEq(Localize.locale("hu-HU"), "hu")
	expectEq(Localize.locale("de-DE"), "en")
	expectEq(Translate("Settings", "hu-HU"), "Beállítások")
	expectEq(Translate("Settings", "en-US"), "Settings")
	expectEq(Translate("unknown text", "hu"), "unknown text")
	expectEq(Translate("View Common", "hu"), "Profil: Common")
	local odds = Translate("[R] Rare 12.50% · 250 tips", "hu")
	expectTrue(string.find(odds, "12.50%%") ~= nil, "odds unchanged")
	expectTrue(string.find(odds, "250") ~= nil, "amount unchanged")
	expectEq(Translate("Normal text", "hu"), "Normál betűméret")
end)

local FocusOrder = require("../src/shared/Util/FocusOrder")
test("Gamepad: deterministic visual ordering without mutating input", function()
	local input = {
		{ key = "c", x = 20, y = 100 },
		{ key = "b", x = 90, y = 10 },
		{
			key = "a",
			x = 0,
			y = 10,
		},
	}
	local ordered = FocusOrder.sort(input)
	expectEq(ordered[1].key, "a")
	expectEq(ordered[2].key, "b")
	expectEq(ordered[3].key, "c")
	expectEq(input[1].key, "c")
	expectEq(#FocusOrder.sort({}), 0)
end)

test("HazardZones: event zones, tornado radius, safe spot pick", function()
	local HazardZones = require("../src/shared/Util/HazardZones")
	local zones = MapLayout.zones :: any
	local none = { events = {} }
	expectTrue(not HazardZones.isUnsafe(0, -110, none, zones, 8), "no event, no danger")
	local race = { events = { "HorseRace" } }
	expectTrue(HazardZones.isUnsafe(0, -110, race, zones, 8), "track is unsafe during the race")
	expectTrue(
		not HazardZones.isUnsafe(0, 26, race, zones, 8),
		"plaza spawn is safe during the race"
	)
	local tornado = { events = { "Tornado" }, tornadoX = 0, tornadoZ = 20, tornadoRadius = 30 }
	expectTrue(HazardZones.isUnsafe(0, 26, tornado, zones, 8), "near the funnel is unsafe")
	local spot = HazardZones.pickSafe(MapLayout.safeSpots :: any, tornado, zones, 8)
	expectTrue(
		spot ~= nil and not HazardZones.isUnsafe(spot.x, spot.z, tornado, zones, 8),
		"picked spot is safe"
	)
	-- every event alone leaves at least one safe spot
	for _, id in { "HorseRace", "Flood", "Tornado", "Blizzard" } do
		local h = { events = { id }, tornadoX = -160, tornadoZ = 0, tornadoRadius = 40 }
		expectTrue(
			HazardZones.pickSafe(MapLayout.safeSpots :: any, h, zones, 8) ~= nil,
			`no safe spot during {id}`
		)
	end
end)

test("OrderKinds: unlocks, onboarding, weighted pick, rewards", function()
	local OrderKinds = require("../src/shared/Util/OrderKinds")
	local cfg = Tuning.OrderKinds :: any
	expectEq(#OrderKinds.available(6, 0, 2, cfg), 1, "onboarding is normal-only")
	expectEq(#OrderKinds.available(1, 10, 2, cfg), 1, "level 1 is normal-only")
	expectEq(#OrderKinds.available(2, 10, 2, cfg), 3, "level 2: normal, double, rush")
	expectEq(#OrderKinds.available(3, 10, 2, cfg), 4, "level 3 adds fragile")
	expectEq(
		OrderKinds.pick(1, 10, 2, cfg, function()
			return 0.99
		end),
		"normal"
	)
	local seen = {}
	for i = 0, 99 do
		seen[OrderKinds.pick(3, 10, 2, cfg, function()
			return i / 100
		end)] = true
	end
	expectTrue(seen.normal and seen.double and seen.rush and seen.fragile, "every kind reachable")
	local b, m, labels = OrderKinds.reward("double", {}, cfg)
	expectEq(b, 0)
	expectEq(m, cfg.double.tipMultiplier)
	expectEq(labels[1], "Double order")
	b = OrderKinds.reward("rush", { onTime = true }, cfg)
	expectEq(b, cfg.rush.bonus)
	b = OrderKinds.reward("rush", { onTime = false }, cfg)
	expectEq(b, 0)
	b = OrderKinds.reward("fragile", { intact = true }, cfg)
	expectEq(b, cfg.fragile.bonus)
	b = OrderKinds.reward("fragile", { intact = false }, cfg)
	expectEq(b, 0)
end)

local SoundPolicy = require("../src/shared/Util/SoundPolicy")
local Sounds = require("../src/shared/Config/Sounds")
test("Audio: volume validation, steps and independent persisted channels", function()
	for _, invalid in { -1, 101, 0.5, math.huge, 0 / 0, "50" } do
		expectEq(SoundPolicy.percent(invalid), nil)
	end
	local channel, value = SoundPolicy.action("music.0")
	expectEq(channel, "music")
	expectEq(value, 0)
	channel, value = SoundPolicy.action("sfx.100")
	expectEq(channel, "sfx")
	expectEq(value, 100)
	channel, value = SoundPolicy.action("sfx.101")
	expectEq(value, nil)
	channel = SoundPolicy.action("master.25")
	expectEq(channel, nil)
	expectEq(SoundPolicy.step(50, 1, Sounds.volumeSteps), 75)
	expectEq(SoundPolicy.step(50, -1, Sounds.volumeSteps), 25)
	expectEq(SoundPolicy.step(0, -1, Sounds.volumeSteps), 0)
	expectEq(SoundPolicy.step(100, 1, Sounds.volumeSteps), 100)
	local p = ProfileSchema.migrate({ settings = { music = 0, sfx = 0.5 } })
	expectEq(p.settings.music, 0)
	expectEq(p.settings.sfx, 0.5)
	local resumed = ProfileSchema.migrate(p)
	expectEq(resumed.settings.music, 0)
	expectEq(resumed.settings.sfx, 0.5)
end)
test("Audio: bundled assets, visual pairs and synchronized bounded music", function()
	for key, clip in Sounds.clips do
		expectTrue(string.match(clip.asset, "^rbxasset://sounds/") ~= nil, key)
		expectTrue(clip.volume >= 0 and clip.volume <= 1, key)
		expectTrue(clip.seconds > 0 and clip.cooldown >= 0, key)
		if clip.channel ~= "music" and key ~= "Ui" and not clip.loop then
			expectTrue(type(clip.caption) == "string" and #clip.caption > 0, key)
		end
	end
	local beat, note = SoundPolicy.note(Sounds.music.Mega, 10)
	local otherBeat, otherNote = SoundPolicy.note(Sounds.music.Mega, 10)
	expectEq(beat, otherBeat)
	expectEq(note, otherNote)
	expectTrue(#Sounds.music.Mega.notes > 0 and Sounds.maxVoices <= 16, "bounded audio")
end)

local EventAudioPlan = require("../src/shared/Util/EventAudioPlan")
test("Event audio: distinct warnings, two bounded MEGA loops, join and cleanup", function()
	for _, id in { "HorseRace", "Tornado", "Flood", "Blizzard" } do
		local state = { id = id, phase = "warning", endsAt = 42 }
		local plan = EventAudioPlan.get(Sounds, state)
		expectEq(plan.warning, Sounds.events[id].warning)
		expectEq(#plan.ambience, 0)
		state.phase = "active"
		plan = EventAudioPlan.get(Sounds, state)
		expectEq(plan.ambience[1], Sounds.events[id].ambience)
		expectEq(plan.music, nil)
	end
	local plan = EventAudioPlan.get(
		Sounds,
		{ id = "Tornado", combo = "Flood", phase = "active", mega = true }
	)
	expectEq(plan.music, "Mega")
	expectEq(#plan.ambience, 2)
	for _, phase in { "windDown", "reset", "calm" } do
		plan = EventAudioPlan.get(
			Sounds,
			{ id = "Tornado", combo = "Flood", phase = phase, mega = true }
		)
		expectEq(plan.music, nil)
		expectEq(#plan.ambience, 0)
	end
	plan = EventAudioPlan.get(Sounds, { id = "unknown", phase = "active", mega = true })
	expectEq(plan.music, nil)
	expectEq(#plan.ambience, 0)
end)

local PerfMetrics = require("../src/shared/Util/PerfMetrics")
local PerfConfig = require("../src/shared/Config/Perf")
test("Perf: enabled emission, maximum live estimate, exact budget boundary", function()
	local metrics = PerfMetrics.empty()
	PerfMetrics.add(metrics, { part = true, anchored = false })
	PerfMetrics.add(metrics, { emitter = true, enabled = true, rate = 40, lifetime = 5 })
	PerfMetrics.add(metrics, { emitter = true, enabled = false, rate = 10000, lifetime = 20 })
	expectEq(metrics.parts, 1)
	expectEq(metrics.unanchoredParts, 1)
	expectEq(metrics.emitters, 2)
	expectEq(metrics.enabledEmitters, 1)
	expectEq(metrics.particlesPerSecond, 40)
	expectEq(metrics.estimatedAliveParticles, 200)
	expectEq(#PerfMetrics.overBudget(metrics, { parts = 1, estimatedAliveParticles = 200 }), 0)
	expectEq(#PerfMetrics.overBudget(metrics, { parts = 0, estimatedAliveParticles = 199 }), 2)
	expectTrue(
		PerfConfig.scanIntervalSeconds >= 10 and PerfConfig.maxTrackedParts <= 2000,
		"bounded observation"
	)
end)
test("Perf: frame percentiles include stalls, bounded ring and empty capture", function()
	local frames = PerfMetrics.frames(20, 30)
	expectEq(frames.report().frames, 0)
	for _ = 1, 19 do
		frames.add(1 / 60)
	end
	frames.add(0.5)
	local report = frames.report()
	expectEq(report.frames, 20)
	expectEq(report.worstFrameMs, 500)
	expectEq(report.framesOver33ms, 1)
	expectTrue(report.averageFps < 30, "stalls must not be clamped away")
	frames.add(1 / 30)
	report = frames.report()
	expectEq(report.frames, 20)
	expectEq(report.observedFrames, 21)
	expectEq(report.truncated, true)
	frames.add(0 / 0)
	frames.add(-1)
	frames.add(math.huge)
	expectEq(frames.report().observedFrames, 21)
end)

local VisualBudget = require("../src/shared/Util/VisualBudget")
test("Mobile budgets: proportional continuous particles, live bound and quality restore", function()
	local requests = {
		{ key = 1, rate = 400, lifetime = 6, enabled = true },
		{ key = 2, rate = 900, lifetime = 10, enabled = true },
		{ key = 3, rate = 100000, lifetime = 100, enabled = false },
	}
	for _, quality in { "low", "medium", "high" } do
		local budget = PerfConfig.visualProfiles[quality]
		local rates = VisualBudget.allocate(requests, budget, PerfConfig.allocationHeadroom)
		expectTrue(rates[1] + rates[2] <= budget.particlesPerSecond, quality)
		expectTrue(rates[1] * 6 + rates[2] * 10 <= budget.estimatedAliveParticles, quality)
		expectEq(rates[3], 0)
		expectTrue(math.abs(rates[1] / 400 - rates[2] / 900) < 0.000001, "fair allocation")
	end
	expectEq(requests[1].rate, 400)
	local fits = VisualBudget.allocate(
		{ { key = 1, rate = 55, lifetime = 6, enabled = true } },
		PerfConfig.visualProfiles.low,
		PerfConfig.allocationHeadroom
	)
	expectEq(fits[1], 55)
	expectEq(next(VisualBudget.allocate({}, PerfConfig.visualProfiles.low, 1)), nil)
end)
test("Mobile LOD: hysteresis, near return and quality thresholds", function()
	expectEq(VisualBudget.visible(100, true, 80, 20), true)
	expectEq(VisualBudget.visible(100.01, true, 80, 20), false)
	expectEq(VisualBudget.visible(90, false, 80, 20), false)
	expectEq(VisualBudget.visible(80, false, 80, 20), true)
	expectTrue(
		PerfConfig.visualProfiles.high.regularDistance
			> PerfConfig.visualProfiles.low.regularDistance,
		"quality LOD"
	)
end)

test("Perf: foreground, background and unknown focus are reported without hiding frames", function()
	local frames = PerfMetrics.frames(10, 30)
	frames.add(1 / 60, true)
	frames.add(1 / 15, false)
	frames.add(1 / 60)
	local report = frames.report()
	expectEq(report.frames, 3)
	expectEq(report.backgroundFrames, 1)
	expectEq(report.unknownFocusFrames, 1)
	expectTrue(report.worstFrameMs > 60, "background throttle remains in raw timing")
end)

test("Audio: unknown or loading volume stays silent until saved preferences arrive", function()
	expectEq(SoundPolicy.volume(nil), 0)
	expectEq(SoundPolicy.volume("1"), 0)
	expectEq(SoundPolicy.volume(0 / 0), 0)
	expectEq(SoundPolicy.volume(0), 0)
	expectEq(SoundPolicy.volume(0.5), 0.5)
	expectEq(SoundPolicy.volume(1), 1)
end)

local DisasterProducts = require("../src/shared/Util/DisasterProducts").new(
	require("../src/shared/Config/Events"),
	require("../src/shared/Util/Season").isActive
)
test("Disaster picker: seasonal visibility and immutable receipt event after migration", function()
	local boosts =
		require("../src/shared/Util/Boosts").new(require("../src/shared/Config/Products"))
	local legacy = boosts.find("OrderDisaster")
	expectEq(DisasterProducts.visible(legacy, 12, 15), false)
	local winter = boosts.find("DisasterBlizzard")
	expectEq(DisasterProducts.visible(winter, 11, 5), false)
	expectEq(DisasterProducts.visible(winter, 12, 1), true)
	expectEq(DisasterProducts.visible(winter, 1, 6), true)
	expectEq(DisasterProducts.visible(winter, 1, 7), false)
	for _, event in { "HorseRace", "Tornado", "Flood", "Blizzard" } do
		local p = ProfileSchema.default()
		local definition = boosts.find("Disaster" .. event)
		expectTrue(boosts.apply(p, definition, "receipt-" .. event, 100), event)
		expectEq(p.pendingEffects[1].eventId, event)
		p = ProfileSchema.migrate(p)
		expectEq(p.pendingEffects[1].eventId, event)
		local effect = boosts.peekPending(p, "event")
		expectEq(effect.key, "OrderDisaster")
		expectEq(effect.eventId, event)
		expectEq(effect.productKey, "Disaster" .. event)
	end
end)

test(
	"Disaster picker: queue/MEGA gate before purchase and winter hidden without gate calls",
	function()
		local b = require("../src/shared/Util/Boosts").new(require("../src/shared/Config/Products"))
		for _, key in { "DisasterHorseRace", "DisasterTornado", "DisasterFlood", "MegaChaosNow" } do
			local requested
			local ok, reason = DisasterProducts.check(b.find(key), 11, 5, function(id)
				requested = id
				return false, "queue full"
			end)
			expectEq(ok, false)
			expectEq(reason, "queue full")
			expectTrue(requested ~= nil, key)
		end
		local called = false
		local ok = DisasterProducts.check(b.find("DisasterBlizzard"), 11, 5, function(_)
			called = true
			return true, ""
		end)
		expectEq(ok, false)
		expectEq(called, false)
	end
)

test("Santa looks: winter-only tips purchase, permanent ownership and no stat benefit", function()
	local cfg = require("../src/shared/Config/Cosmetics")
	local logic = require("../src/shared/Util/Cosmetics").new(cfg)
	local p = ProfileSchema.default()
	p.tips = 10000
	local before = p.tips
	expectEq(logic.buy(p, "SantaUniform", { month = 11, day = 5 }), false)
	expectEq(logic.buy(p, "SantaUniform"), false)
	expectEq(p.tips, before)
	for _, id in { "SantaBox", "SantaBag", "SantaUniform", "SantaDecor" } do
		expectTrue(logic.canBuy(id, { month = 12, day = 1 }), id)
		expectTrue(logic.buy(p, id, { month = 1, day = 6 }), id)
		expectEq(logic.buy(p, id, { month = 1, day = 6 }), false)
		expectEq(logic.canBuy(id, { month = 1, day = 7 }), false)
	end
	p = ProfileSchema.migrate(p)
	expectTrue(logic.equip(p, "SantaUniform"), "year-round equip")
	expectEq(logic.effective(p, "uniform").style, "santa")
	for _, item in logic.catalog(p, { month = 7, day = 1 }) do
		if item.seasonal then
			expectEq(item.purchaseAllowed, false)
			expectEq(item.owned, true)
			expectTrue(type(item.seasonLabel) == "string", "season notice")
		end
	end
	expectEq(p.xp, 0)
	expectEq(p.deliveries, 0)
	expectEq(p.movementTier, 0)
end)

test("Santa wardrobe: complete dynamic Hungarian wardrobe hint preserves balance", function()
	local translate =
		require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	local text = translate("25 tips · Preview any look. Equip the ones you own.", "hu")
	expectTrue(string.find(text, "25", 1, true) ~= nil, "balance")
	expectEq(string.find(text, "look", 1, true), nil)
	expectEq(string.find(text, "own", 1, true), nil)
end)

test("Help: six concise illustrated steps and complete Hungarian text", function()
	local help = require("../src/shared/Config/Help")
	local translate =
		require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	expectEq(#help.pages, 6)
	local words = 0
	local ids = {}
	for _ in string.gmatch(help.summary, "%S+") do
		words += 1
	end
	for _, page in help.pages do
		expectEq(ids[page.id], nil)
		ids[page.id] = true
		expectTrue(translate(page.title, "hu") ~= page.title, page.title)
		expectTrue(translate(page.body, "hu") ~= page.body, page.id)
		for _ in string.gmatch(page.title .. " " .. page.body, "%S+") do
			words += 1
		end
	end
	expectTrue(words <= 100, "quick overview")
end)

test("Streak: growth, cap, timeout, reset", function()
	local Streak = require("../src/shared/Util/Streak")
	local cfg = Tuning.Streak
	local s = Streak.new()
	local count, mult = Streak.deliver(s, 0, cfg)
	expectEq(count, 1)
	expectEq(mult, 1)
	count, mult = Streak.deliver(s, 10, cfg)
	expectEq(count, 2)
	expectEq(mult, 1 + cfg.step)
	for i = 1, 50 do
		Streak.deliver(s, 10 + i, cfg)
	end
	expectEq(Streak.multiplier(s.count, cfg), cfg.max, "capped")
	count = Streak.deliver(s, 100 + cfg.timeoutSeconds + 1, cfg)
	expectEq(count, 1, "pause resets")
	Streak.reset(s)
	expectEq(s.count, 0)
end)

test("RoutePath + cheese routes: sampling, reverse, routes on streets", function()
	local RoutePath = require("../src/shared/Util/RoutePath")
	local route = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 20 } }
	expectEq(RoutePath.length(route), 30)
	local x, z, hx, hz, done = RoutePath.sample(route, 5)
	expectTrue(x == 5 and z == 0 and hx == 1 and hz == 0 and not done, "first leg")
	x, z, hx, hz, done = RoutePath.sample(route, 20)
	expectTrue(x == 10 and z == 10 and hx == 0 and hz == 1 and not done, "turned the corner")
	x, z, _, _, done = RoutePath.sample(route, 99)
	expectTrue(x == 10 and z == 20 and done, "end")
	local back = RoutePath.oriented(route, true)
	expectEq(back[1].z, 20)
	expectEq(route[1].x, 0, "original untouched")
	-- every waypoint and segment midpoint of every cheese route lies on a street
	local function onStreet(px: number, pz: number): boolean
		for _, s in MapLayout.streets do
			if math.abs(px - s.x) <= s.sx / 2 + 1 and math.abs(pz - s.z) <= s.sz / 2 + 1 then
				return true
			end
		end
		return false
	end
	for i, r in MapLayout.cheeseRoutes do
		expectTrue(#r >= 2, `route {i} has two points`)
		local len = RoutePath.length(r :: any)
		for d = 0, len, 5 do
			local px, pz = RoutePath.sample(r :: any, d)
			expectTrue(onStreet(px, pz), `route {i} leaves the streets at {px},{pz}`)
			for _, spot in MapLayout.safeSpots do
				local dist = math.sqrt((spot.x - px) ^ 2 + (spot.z - pz) ^ 2)
				expectTrue(dist > 12, `route {i} passes safe spot {spot.x},{spot.z}`)
			end
		end
	end
	local StyleLogic = require("../src/shared/Util/StyleLogic")
	local StyleConfig = require("../src/shared/Config/Style")
	local result = StyleLogic.evaluate({ secondsSinceCheeseJump = 1 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "CheeseJump") ~= nil, "cheese jump tag")
end)

test("CustomerQuirks: describe, checks, profile field", function()
	local QuirkConfig = require("../src/shared/Config/CustomerQuirks")
	local Quirks = require("../src/shared/Util/CustomerQuirks").new(QuirkConfig :: any)
	local known: { [string]: boolean } = {}
	for _, c in Customers do
		known[c.id] = true
	end
	for _, id in Quirks.ids() do
		expectTrue(known[id] == true, `quirk for unknown customer {id}`)
		local d = Quirks.describe(id)
		expectTrue(d ~= nil and #d.title > 0 and #d.request > 0, `description for {id}`)
	end
	expectEq(Quirks.describe("SleepyStudent"), nil)
	local base = { stillSeconds = 0, tags = {}, duringEvent = false }
	local function facts(extra: { [string]: any }): any
		local f = table.clone(base) :: { [string]: any }
		for k, v in extra do
			f[k] = v
		end
		return f
	end
	expectTrue(Quirks.check("SecretAgent", facts({})), "alone counts as unseen")
	expectTrue(not Quirks.check("SecretAgent", facts({ nearestOtherCourier = 10 })), "seen")
	expectTrue(Quirks.check("SecretAgent", facts({ nearestOtherCourier = 40 })), "far enough")
	expectTrue(not Quirks.check("StatueMan", facts({ stillSeconds = 1.5 })), "too short")
	expectTrue(Quirks.check("StatueMan", facts({ stillSeconds = 2.1 })), "still")
	expectTrue(Quirks.check("GamerKid", facts({ tags = { "AirDelivery" } })), "air")
	expectTrue(not Quirks.check("GamerKid", facts({ tags = { "Lightning" } })), "not air")
	expectTrue(Quirks.check("JoggingGrandpa", facts({ tags = { "Lightning" } })), "fast")
	expectTrue(Quirks.check("LostTourist", facts({ secondsSinceZone = 4 })), "from plaza")
	expectTrue(not Quirks.check("LostTourist", facts({ secondsSinceZone = 30 })), "too long ago")
	expectTrue(not Quirks.check("LostTourist", facts({})), "never on plaza")
	expectTrue(Quirks.check("TheMayor", facts({ duringEvent = true })), "event")
	expectTrue(not Quirks.check("TheMayor", facts({})), "no event")
	expectTrue(not Quirks.check("SleepyStudent", facts({ duringEvent = true })), "no quirk")
	local migrated = ProfileSchema.migrate({
		customerBook = {
			StatueMan = { served = 3, stars = 3, quirk = true },
			GamerKid = { served = 1, stars = 0, quirk = "yes" },
		},
	})
	expectEq(migrated.customerBook.StatueMan.quirk, true)
	expectEq(migrated.customerBook.GamerKid.quirk, nil)
end)

local AchievementBook = require("../src/shared/Util/AchievementBook")
test("Achievement book: known progress only, earned milestone differs from Roblox badge", function()
	local customers = require("../src/shared/Config/Customers")
	local p = ProfileSchema.default()
	for i = 1, 5 do
		p.customerBook[customers[i].id] = { served = 1, stars = 0 }
	end
	p.customerBook.Forged = { served = 100, stars = 5 }
	local defs = { { key = "Book10", book = 10, badgeId = 123 } }
	local rows = AchievementBook.snapshot(p, defs, customers)
	expectEq(rows[1].current, 5)
	expectEq(rows[1].target, 10)
	expectEq(rows[1].earned, false)
	expectEq(rows[1].awarded, false)
	p.claims["achievement.Book10"] = 100
	rows = AchievementBook.snapshot(p, defs, customers)
	expectEq(rows[1].earned, true)
	expectEq(rows[1].current, 10)
	expectEq(rows[1].awarded, false)
	p.claims["badge.123"] = 100
	rows = AchievementBook.snapshot(p, defs, customers)
	expectEq(rows[1].awarded, true)
	expectEq(rows[1].claims, nil)
	expectEq(rows[1].tips, nil)
end)
test("Achievement book: complete bilingual metadata for every configured badge", function()
	local metadata = require("../src/shared/Config/AchievementBook")
	for _, badge in require("../src/shared/Config/Badges").items do
		for _, locale in { "en", "hu" } do
			expectTrue(#metadata.entries[badge.key][locale][1] > 0, badge.key)
			expectTrue(#metadata.entries[badge.key][locale][2] > 0, badge.key)
		end
	end
end)

local AdventConfig = require("../src/shared/Config/Advent")
local AdventBoosts = require("../src/shared/Util/Boosts").new(Products)
local Advent =
	require("../src/shared/Util/Advent").new(AdventConfig, AdventBoosts, Products.Limits.maxTips)
test("Advent: exact UTC opening, one-day catch-up and Christmas closing boundaries", function()
	local p = ProfileSchema.default()
	local start, day = AdventConfig.startsAt, AdventConfig.secondsPerDay
	expectEq(Advent.state(p, 1, start - 1), "locked")
	expectEq(Advent.state(p, 1, start), "claimable")
	expectEq(Advent.state(p, 1, start + day - 1), "claimable")
	expectEq(Advent.state(p, 1, start + day), "catchup")
	expectEq(Advent.state(p, 1, start + 2 * day - 1), "catchup")
	expectEq(Advent.state(p, 1, start + 2 * day), "missed")
	expectEq(Advent.state(p, 24, start + 23 * day), "claimable")
	expectEq(Advent.state(p, 24, start + 24 * day), "catchup")
	expectEq(Advent.state(p, 24, start + 25 * day), "missed")
	expectEq(Advent.snapshot(p, start + 25 * day).active, false)
end)
test(
	"Advent: previous-day catch-up, independent windows, duplicate and reconnect ledger",
	function()
		local p = ProfileSchema.default()
		local now = AdventConfig.startsAt + AdventConfig.secondsPerDay
		expectTrue(Advent.claim(p, 2, now))
		expectTrue(Advent.claim(p, 1, now))
		expectEq(p.tips, 65)
		p = ProfileSchema.migrate(p)
		expectEq(Advent.claim(p, 1, now), false)
		expectEq(Advent.claim(p, 2, now), false)
		expectEq(Advent.claim(p, 3, now), false)
		expectEq(p.tips, 65)
		expectEq(Advent.snapshot(p, now).rows[1].state, "claimed")
		local nextSeason = table.clone(AdventConfig)
		nextSeason.season = "2027"
		local nextCalendar = require("../src/shared/Util/Advent").new(
			nextSeason,
			AdventBoosts,
			Products.Limits.maxTips
		)
		expectTrue(nextCalendar.claim(p, 1, now))
		expectTrue(p.claims["advent.2026.1"] ~= nil, "previous ledger preserved")
	end
)
test("Advent: real boost policy, active extension, no second grant after migration", function()
	local p = ProfileSchema.default()
	local now = AdventConfig.startsAt + 3 * AdventConfig.secondsPerDay
	expectTrue(AdventBoosts.extend(p.boosts, "TipBoost", 120, now))
	expectTrue(Advent.claim(p, 4, now))
	expectEq(p.boosts.TipBoost, now + 720)
	expectEq(AdventBoosts.tipMultiplier({}, p.boosts, now), 2)
	p = ProfileSchema.migrate(p)
	expectEq(Advent.claim(p, 4, now), false)
	expectEq(p.boosts.TipBoost, now + 720)
	expectEq(AdventBoosts.tipMultiplier({}, p.boosts, now + 720), 1)
end)
test("Advent: Santa day 24, duplicate look compensation and wallet capacity", function()
	local p = ProfileSchema.default()
	local now = AdventConfig.startsAt + 24 * AdventConfig.secondsPerDay
	expectTrue(Advent.claim(p, 24, now))
	expectEq(p.cosmetics.owned.SantaUniform, true)
	expectEq(p.tips, 200)
	p = ProfileSchema.default()
	p.cosmetics.owned.SantaUniform = true
	p.tips = Products.Limits.maxTips - 449
	expectEq(Advent.claim(p, 24, now), false)
	expectEq(p.claims["advent.2026.24"], nil)
	p.tips -= 1
	expectTrue(Advent.claim(p, 24, now))
	expectEq(p.tips, Products.Limits.maxTips)
	expectEq(Advent.claim(p, 24, now), false)
end)
test("Advent: invalid client days and clocks never mutate a profile", function()
	local p = ProfileSchema.default()
	for _, invalid in { 0, 25, -1, 1.5, "1", false, 0 / 0, math.huge } do
		expectEq(Advent.claim(p, invalid, AdventConfig.startsAt), false)
	end
	for _, invalid in { -1, 0 / 0, math.huge, 0 } do
		expectEq(Advent.claim(p, 1, invalid), false)
	end
	expectEq(p.tips, 0)
	expectEq(next(p.claims), nil)
	expectEq(next(p.boosts), nil)
end)
test(
	"Advent: 24 valid gifts, existing cosmetics, bilingual copy and public snapshot only",
	function()
		expectEq(#AdventConfig.rewards, 24)
		local looks = {}
		for _, item in CosmeticConfig.items do
			looks[item.id] = true
		end
		for _, gift in AdventConfig.rewards do
			expectTrue(gift.tips ~= nil or gift.cosmetic ~= nil or gift.boost ~= nil, "gift")
			if gift.cosmetic then
				expectTrue(looks[gift.cosmetic], gift.cosmetic)
			end
			if gift.boost then
				expectTrue(AdventBoosts.find(gift.boost) ~= nil, gift.boost)
			end
		end
		for key in AdventConfig.labels.en do
			expectTrue(type(AdventConfig.labels.hu[key]) == "string", key)
		end
		local snapshot = Advent.snapshot(ProfileSchema.default(), AdventConfig.startsAt)
		expectEq(#snapshot.rows, 24)
		expectEq(snapshot.claims, nil)
		expectEq(snapshot.purchases, nil)
		expectEq(snapshot.tips, nil)
	end
)

test("Blackout: config, customers and tip bonus override", function()
	local def
	for _, e in Events do
		if e.id == "Blackout" then
			def = e
		end
	end
	expectTrue(def ~= nil and def.enabled, "Blackout event defined")
	expectTrue(
		Tuning.Events.tipBonusByEvent.Blackout < Tuning.Events.tipBonusDuringEvent,
		"harmless event pays less"
	)
	expectTrue(Tuning.Blackout.waveMinSeconds <= Tuning.Blackout.waveMaxSeconds, "wave range")
	local ids: { [string]: boolean } = {}
	for _, e in Events do
		ids[e.id] = true
	end
	for _, e in Events do
		for _, other in e.megaCombos do
			expectTrue(ids[other] == true and other ~= e.id, `{e.id}: bad combo {other}`)
		end
	end
end)

test("CityGoal: scaling, completion, one reward per window", function()
	local CityGoal = require("../src/shared/Util/CityGoal")
	local cfg = Tuning.CityGoal :: any
	expectEq(CityGoal.target(1, cfg), cfg.minTarget, "small server floor")
	expectEq(CityGoal.target(100, cfg), cfg.maxTarget, "cap")
	expectEq(CityGoal.target(5, cfg) % cfg.roundTo, 0, "rounded")
	expectEq(CityGoal.window(3599, cfg), 0)
	expectEq(CityGoal.window(3600, cfg), 1)
	local s = CityGoal.new(7, 1, cfg)
	CityGoal.observePlayers(s, 8, cfg)
	expectEq(s.target, CityGoal.target(8, cfg), "grows with players")
	CityGoal.observePlayers(s, 2, cfg)
	expectEq(s.target, CityGoal.target(8, cfg), "never shrinks")
	s.target = 5
	for _ = 1, 3 do
		CityGoal.record(s, 1)
	end
	CityGoal.record(s, 2)
	expectEq(#CityGoal.claimable(s, cfg), 0, "nothing before completion")
	expectTrue(CityGoal.record(s, 2), "fifth delivery completes")
	expectTrue(not CityGoal.record(s, 3), "completes only once")
	local first = CityGoal.claimable(s, cfg)
	expectEq(#first, 1, "only the 3+ helper")
	expectEq(first[1], 1)
	expectEq(#CityGoal.claimable(s, cfg), 0, "no double reward")
	CityGoal.record(s, 2) -- user 2 reaches 3 after completion
	local late = CityGoal.claimable(s, cfg)
	expectEq(#late, 1, "late helper")
	expectEq(late[1], 2)
end)

test("Pizza cannons: arcs land on open streets, bounded impulse", function()
	local Ballistic = require("../src/shared/Util/Ballistic")
	local g = 196.2
	local from = { x = 0, y = 4, z = 0 }
	local to = { x = 100, y = 3, z = 50 }
	local v = Ballistic.velocity(from, to, 2, g)
	local landed = Ballistic.at(from, v, 2, g)
	expectTrue(math.abs(landed.x - 100) < 1e-6 and math.abs(landed.y - 3) < 1e-6, "lands on target")
	local function onStreet(px: number, pz: number): boolean
		for _, s in MapLayout.streets do
			if math.abs(px - s.x) <= s.sx / 2 - 2 and math.abs(pz - s.z) <= s.sz / 2 - 2 then
				return true
			end
		end
		return false
	end
	for _, c in MapLayout.cannons do
		expectTrue(onStreet(c.x, c.z), `{c.name}: cannon off the street`)
		expectTrue(onStreet(c.to.x, c.to.z), `{c.name}: lands off the street`)
		local b = MapLayout.bounds
		expectTrue(
			c.to.x > b.minX and c.to.x < b.maxX and c.to.z > b.minZ and c.to.z < b.maxZ,
			"in bounds"
		)
		local vel = Ballistic.velocity(
			{ x = c.x, y = 4.6, z = c.z },
			{ x = c.to.x, y = 3.6, z = c.to.z },
			Tuning.Cannon.flightSeconds,
			g
		)
		local mag = math.sqrt(vel.x ^ 2 + vel.y ^ 2 + vel.z ^ 2)
		expectTrue(mag <= Tuning.Cannon.maxImpulse, `{c.name}: impulse {math.floor(mag)} above cap`)
		expectTrue(
			Tuning.Cannon.flightSeconds + 0.2 <= Tuning.Events.maxRagdollSeconds,
			"flight fits ragdoll cap"
		)
		-- the arc clears every building on the way (sampled)
		for i = 1, 19 do
			local t = Tuning.Cannon.flightSeconds * i / 20
			local p = Ballistic.at({ x = c.x, y = 4.6, z = c.z }, vel, t, g)
			for _, bld in MapLayout.buildings do
				local inside = math.abs(p.x - bld.x) < bld.sx / 2
					and math.abs(p.z - bld.z) < bld.sz / 2
				expectTrue(not inside or p.y > bld.h + 1, `{c.name}: arc hits a building at t={t}`)
			end
			local o = MapLayout.overpass
			local onOverpass = math.abs(p.x - o.x) < o.width / 2 + 2
				and p.z > o.zNorth - o.rampLength - 2
				and p.z < o.zSouth + o.rampLength + 2
			expectTrue(
				not onOverpass or p.y > o.deckY + 6,
				`{c.name}: arc hits the overpass at t={t}`
			)
		end
	end
end)

local TickerConfig = require("../src/shared/Config/Ticker")
local TickerLogic = require("../src/shared/Util/Ticker")
test("Ticker: three fresh rows, bounded history and exact expiry", function()
	local feed = TickerLogic.new(TickerConfig)
	for i = 1, 4 do
		expectTrue(feed.push("giant", "g" .. i, { "Dani" }, nil, nil, i * 2))
	end
	local rows = feed.rows(8)
	expectEq(#rows, 3)
	expectEq(rows[1].id, 2)
	expectEq(rows[3].id, 4)
	expectEq(#feed.rows(16), 0)
end)
test("Ticker: global cooldown, order dedupe, MEGA pair dedupe and invalid events", function()
	local feed = TickerLogic.new(TickerConfig)
	expectTrue(feed.push("mega", "mega", {}, nil, nil, 100))
	expectEq(feed.push("mega", "mega", {}, nil, nil, 100), false)
	expectEq(feed.push("giant", "g", { "Dani" }, nil, nil, 101), false)
	expectTrue(feed.push("giant", "g", { "Dani" }, nil, nil, 102))
	expectEq(feed.push("giant", "g", { "Dani" }, nil, nil, 104), false)
	expectEq(feed.push("rare", "r", { "Dani" }, "Pizza Fan", "Common", 106), false)
	expectEq(feed.push("forged", "x", {}, nil, nil, 106), false)
	expectEq(feed.push("mega", "x", {}, nil, nil, 0 / 0), false)
	expectEq(#feed.rows(106), 2)
end)
test("Ticker: only rare-plus milestones, bounded names and safe Unicode", function()
	local feed = TickerLogic.new(TickerConfig)
	expectTrue(
		feed.push("rare", "r", { "Árvíztűrő\nFutár", "B", "C", "D" }, "Santa", "Legendary", 0)
	)
	local row = feed.rows(0)[1]
	expectEq(#row.names, 3)
	expectEq(string.find(row.names[1], "\n", 1, true), nil)
	expectEq(TickerLogic.clip("ŐőŐőŐő", 3), "ŐőŐ…")
	expectEq(utf8.len(TickerLogic.clip("Mikulás", 4)), 5)
	for _, locale in { "en", "hu" } do
		expectTrue(#TickerLogic.format(row, TickerConfig.labels[locale], false, TickerConfig) > 0)
		expectTrue(#TickerLogic.format(row, TickerConfig.labels[locale], true, TickerConfig) > 0)
	end
end)
test(
	"Ticker: opt-out uses the existing persistent claims ledger without altering rewards",
	function()
		local p = ProfileSchema.default()
		p.claims[TickerConfig.settingKey] = 100
		p.claims["achievement.FirstDelivery"] = 50
		p = ProfileSchema.migrate(p)
		expectEq(p.claims[TickerConfig.settingKey], 100)
		expectEq(p.claims["achievement.FirstDelivery"], 50)
		p.claims[TickerConfig.settingKey] = nil
		p = ProfileSchema.migrate(p)
		expectEq(p.claims[TickerConfig.settingKey], nil)
		expectEq(p.tips, 0)
	end
)

test("Golden pepperoni: spots, daily roll, collect once, profile field", function()
	local Collectibles = require("../src/shared/Util/Collectibles")
	local Config = require("../src/shared/Config/Collectibles")
	expectEq(#Config.spots, 30)
	local ids, seen = {}, {}
	for _, s in Config.spots do
		expectTrue(not seen[s.id], `duplicate {s.id}`)
		seen[s.id] = true
		table.insert(ids, s.id)
		local b = MapLayout.bounds
		expectTrue(
			s.x > b.minX and s.x < b.maxX and s.z > b.minZ and s.z < b.maxZ,
			`{s.id} in bounds`
		)
		for _, bld in MapLayout.buildings do
			local inside = math.abs(s.x - bld.x) < bld.sx / 2 and math.abs(s.z - bld.z) < bld.sz / 2
			expectTrue(not inside or s.y > bld.h, `{s.id} inside a building`)
		end
		expectTrue(#s.hint > 0, `{s.id} hint`)
	end
	local n = 0
	local function pick(k: number): number
		n += 1
		return (n % k) + 1
	end
	local state = { day = 0, found = {}, active = {} }
	expectTrue(Collectibles.roll(state :: any, 5, ids, 10, pick), "rolled")
	expectEq(#state.active, 10)
	expectTrue(not Collectibles.roll(state :: any, 5, ids, 10, pick), "same day keeps the list")
	local first = state.active[1]
	expectEq(Collectibles.collect(state :: any, first), "new")
	expectEq(Collectibles.collect(state :: any, first), nil, "only once per day")
	expectEq(Collectibles.collect(state :: any, "GP99"), nil, "inactive id")
	expectEq(#state.active, 9)
	-- next day: unfound first, never the found one while unfound remain
	Collectibles.roll(state :: any, 6, ids, 10, pick)
	expectTrue(table.find(state.active, first) == nil, "found spot not reactivated early")
	for _, id in ids do
		state.found[id] = true
	end
	Collectibles.roll(state :: any, 7, ids, 10, pick)
	expectEq(#state.active, 10, "refills with found spots")
	expectEq(Collectibles.collect(state :: any, state.active[1]), "repeat")
	expectEq(Collectibles.foundCount(state :: any, ids), 30)
	local p = ProfileSchema.migrate({
		collectibles = {
			day = 3,
			found = { GP01 = true, GP02 = "x" },
			active = { "GP03", "GP03", 7 },
		},
	})
	expectEq(p.collectibles.day, 3)
	expectEq(p.collectibles.found.GP01, true)
	expectEq(p.collectibles.found.GP02, nil)
	expectEq(#p.collectibles.active, 1, "deduped, strings only")
	expectEq(#ProfileSchema.default().collectibles.active, 0)
end)

test("Rival race: eta and eligibility", function()
	local RivalRace = require("../src/shared/Util/RivalRace")
	local cfg = Tuning.Rival :: any
	local eta = RivalRace.eta(0, 0, 100, 60, 20, cfg)
	expectTrue(
		math.abs(eta - (cfg.revSeconds + 160 / 20 * cfg.paceFactor)) < 1e-6,
		"manhattan pace"
	)
	expectEq(
		RivalRace.eta(0, 0, 1, 1, 20, cfg),
		cfg.revSeconds + cfg.minFlightSeconds,
		"short trips get the minimum"
	)
	local yes = function()
		return 0
	end
	local no = function()
		return 0.99
	end
	expectTrue(RivalRace.eligible(cfg.minLevel, "normal", 1e9, cfg, yes), "eligible")
	expectTrue(RivalRace.eligible(cfg.minLevel, "fragile", 1e9, cfg, yes), "fragile ok")
	expectTrue(not RivalRace.eligible(cfg.minLevel - 1, "normal", 1e9, cfg, yes), "too low level")
	expectTrue(not RivalRace.eligible(cfg.minLevel, "double", 1e9, cfg, yes), "no doubles")
	expectTrue(not RivalRace.eligible(cfg.minLevel, "rush", 1e9, cfg, yes), "no rush")
	expectTrue(not RivalRace.eligible(cfg.minLevel, "normal", 5, cfg, yes), "cooldown")
	expectTrue(not RivalRace.eligible(cfg.minLevel, "normal", 1e9, cfg, no), "roll")
	expectTrue(cfg.winTipMultiplier >= 1, "win never costs tips")
end)

test("Wishing well: odds shown, weighted roll, tiers", function()
	local Wish = require("../src/shared/Util/Wish")
	local Config = require("../src/shared/Config/Wish")
	local outcomes = Config.outcomes :: any
	local sum = 0
	for _, o in Wish.odds(outcomes) do
		sum += o.percent
		expectTrue(#o.text > 0, "every outcome is described")
	end
	expectEq(sum, 100, "odds add up to 100%")
	expectEq(Wish.roll(outcomes, 0).id, outcomes[1].id)
	expectEq(Wish.roll(outcomes, 0.999999).id, outcomes[#outcomes].id)
	local counts: { [string]: number } = {}
	for i = 0, 999 do
		local id = Wish.roll(outcomes, i / 1000).id
		counts[id] = (counts[id] or 0) + 1
	end
	local total = Wish.totalWeight(outcomes)
	for _, o in outcomes do
		expectTrue(math.abs(counts[o.id] - o.weight / total * 1000) <= 1, `{o.id} frequency`)
	end
	for i = 2, #Config.tiers do
		expectTrue(Config.tiers[i].amount > Config.tiers[i - 1].amount, "tiers grow")
		expectTrue(Config.tiers[i].minutes >= Config.tiers[i - 1].minutes, "longer buffs")
	end
	-- the expected tips back never beats the toss (it's a sink)
	local back = 0
	for _, o in outcomes do
		local mult = if o.id == "Jackpot"
			then Config.jackpotMultiplier
			elseif o.id == "Splash" then Config.splashRefund
			else 0
		back += o.weight / total * mult
	end
	expectTrue(back < 1, "average refund below the toss")
end)

test("Bubble Storm: motion, lifetime, config", function()
	local Bubbles = require("../src/shared/Util/Bubbles")
	local cfg = Tuning.BubbleStorm
	local b = { id = 1, x = 0, z = 0, y0 = 4, t0 = 100, vx = 2, vz = -1, r = 4 }
	local x, y, z = Bubbles.position(b, 105, cfg.riseSpeed, cfg.maxHeight)
	expectTrue(
		x == 10 and z == -5 and math.abs(y - (4 + cfg.riseSpeed * 5)) < 1e-6,
		"rises and drifts"
	)
	local _, top = Bubbles.position(b, 100 + 1000, cfg.riseSpeed, cfg.maxHeight)
	expectEq(top, 4 + cfg.maxHeight, "height capped")
	local _, before = Bubbles.position(b, 90, cfg.riseSpeed, cfg.maxHeight)
	expectEq(before, 4, "never below the spawn")
	expectTrue(Bubbles.alive(b, 100, cfg.lifeSeconds), "alive at spawn")
	expectTrue(not Bubbles.alive(b, 100 + cfg.lifeSeconds, cfg.lifeSeconds), "pops at end of life")
	expectTrue(
		cfg.lowQualityBubbles <= 15 and cfg.lowQualityBubbles <= cfg.maxBubbles,
		"mobile cap (issue: Low <= 15)"
	)
	expectTrue(cfg.minRadius <= cfg.maxRadius and cfg.catchMargin < cfg.minRadius, "radii")
	local StyleLogic = require("../src/shared/Util/StyleLogic")
	local StyleConfig = require("../src/shared/Config/Style")
	local result = StyleLogic.evaluate({ secondsSinceBubbleRide = 0.5 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "BubbleRider") ~= nil, "bubble rider tag")
end)

test("New chaos audio: all live events mapped, localized warnings, MEGA and cleanup", function()
	local tr = require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	for _, id in { "CheeseWheel", "Blackout", "BubbleStorm" } do
		local entry = Sounds.events[id]
		expectTrue(entry ~= nil, id)
		local warning = Sounds.clips[entry.warning]
		expectTrue(tr(warning.caption, "hu") ~= warning.caption, id)
		expectTrue(Sounds.clips[entry.ambience].loop, id)
		local plan = EventAudioPlan.get(Sounds, { id = id, phase = "warning", endsAt = 123 })
		expectEq(plan.warning, entry.warning)
		plan = EventAudioPlan.get(
			Sounds,
			{ id = id, combo = "Tornado", phase = "active", mega = true }
		)
		expectEq(#plan.ambience, 2)
		expectEq(plan.music, "Mega")
		for _, phase in { "calm", "windDown", "reset" } do
			plan = EventAudioPlan.get(
				Sounds,
				{ id = id, combo = "Tornado", phase = phase, mega = true }
			)
			expectEq(#plan.ambience, 0)
			expectEq(plan.music, nil)
		end
	end
	for _, event in Events do
		expectTrue(Sounds.events[event.id] ~= nil, event.id)
	end
end)
test("New chaos products: exact queued event, persisted variant and server gate", function()
	local b = require("../src/shared/Util/Boosts").new(Products)
	local tr = require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	for _, id in { "CheeseWheel", "Blackout", "BubbleStorm" } do
		local product = b.find("Disaster" .. id)
		expectEq(product.productId, 0)
		expectTrue(DisasterProducts.visible(product, 11, 6), id)
		expectTrue(tr(product.displayName, "hu") ~= product.displayName, id)
		local called = nil
		local ok = DisasterProducts.check(product, 11, 6, function(requested)
			called = requested
			return false, "queue full"
		end)
		expectEq(ok, false)
		expectEq(called, id)
		local p = ProfileSchema.default()
		expectTrue(b.apply(p, product, id, 100))
		p = ProfileSchema.migrate(p)
		local pending = b.peekPending(p, "event")
		expectEq(pending.eventId, id)
		expectEq(pending.key, "OrderDisaster")
		expectEq(pending.productKey, product.key)
	end
end)
test("Blackout cricket: sparse triplet pattern uses the bounded SFX pool", function()
	local pattern = Sounds.clips.BlackoutAmbience.detail
	local chirps = 0
	for i = 0, #pattern.beats - 1 do
		local cue, beat = SoundPolicy.detail(pattern, (i + 0.25) * pattern.stepSeconds)
		expectEq(beat, i)
		if cue then
			chirps += 1
			expectEq(cue, "BlackoutCricket")
			expectEq(Sounds.clips[cue].channel, "sfx")
			expectTrue(Sounds.clips[cue].seconds < pattern.stepSeconds, "brief chirp")
		end
	end
	expectEq(chirps, 3)
	expectEq(select(2, SoundPolicy.detail(pattern, 1000)), math.floor(1000 / pattern.stepSeconds))
end)

test("Time trial: checkpoints, impossible legs, scores", function()
	local Trial = require("../src/shared/Util/Trial")
	local cfg = Tuning.Trial :: any
	expectEq(#MapLayout.trialCourse, 6, "six checkpoints")
	local all = table.clone(MapLayout.trialCourse)
	table.insert(all, MapLayout.trialGate)
	for i, c in all do
		for _, bld in MapLayout.buildings do
			local inside = math.abs(c.x - bld.x) < bld.sx / 2 + 2
				and math.abs(c.z - bld.z) < bld.sz / 2 + 2
			expectTrue(not inside, `checkpoint {i} inside a building`)
		end
	end
	local cp = { x = 0, y = 3, z = 0 }
	expectTrue(Trial.hits({ x = 5, y = 4, z = 5 }, cp, cfg), "inside radius")
	expectTrue(not Trial.hits({ x = 20, y = 3, z = 0 }, cp, cfg), "outside radius")
	expectTrue(
		not Trial.hits({ x = 0, y = 30, z = 0 }, cp, cfg),
		"too high (under/over the overpass)"
	)
	local fastest = Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
	expectTrue(Trial.impossibleLeg(200, 1, fastest, cfg), "200 studs in 1 s is impossible")
	expectTrue(not Trial.impossibleLeg(200, 200 / fastest, fastest, cfg), "top speed is fine")
	expectEq(Trial.msFromScore(Trial.score(83450, cfg), cfg), 83450)
	expectTrue(Trial.score(60000, cfg) > Trial.score(90000, cfg), "faster scores higher")
	expectEq(Trial.score(cfg.maxScoreMs + 5, cfg), 0)
	expectEq(Trial.format(83450), "1:23.45")
	expectEq(Trial.week(7 * 86400 * 3 + 5), 3)
end)

test("Dive: Superman tag and sane tuning", function()
	local StyleLogic = require("../src/shared/Util/StyleLogic")
	local StyleConfig = require("../src/shared/Config/Style")
	local result = StyleLogic.evaluate({ secondsSinceDive = 0.4 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "Superman") ~= nil, "Superman tag")
	local d = Tuning.Dive
	expectTrue(
		d.speed * 0.1 < Tuning.Trial.jumpStuds,
		"a dive never looks like a teleport to the time trial"
	)
	expectTrue(d.cooldownSeconds >= 1, "dive cooldown")
	expectTrue(d.freshPressGap > 0 and d.minAirSeconds > 0, "needs a fresh press in the air")
end)

test("Party tower: reward per box, wobble, drops", function()
	local OrderKinds = require("../src/shared/Util/OrderKinds")
	local Tower = require("../src/shared/Util/Tower")
	local kinds = Tuning.OrderKinds :: any
	local _, full, labels = OrderKinds.reward("party", { boxes = 5 }, kinds)
	expectEq(full, kinds.party.tipMultiplier, "full tower pays the whole multiplier")
	expectEq(labels[1], "Tower of Power")
	local _, three = OrderKinds.reward("party", { boxes = 3 }, kinds)
	expectTrue(math.abs(three - kinds.party.tipMultiplier * 3 / 5) < 1e-9, "per box")
	local _, none = OrderKinds.reward("party", { boxes = 0 }, kinds)
	expectEq(none, 0, "empty tower pays nothing extra")
	local avail = OrderKinds.available(kinds.party.minLevel, 100, 5, kinds)
	expectTrue(table.find(avail, "party") ~= nil, "unlocked at its level")
	expectTrue(
		table.find(OrderKinds.available(kinds.party.minLevel - 1, 100, 5, kinds), "party") == nil,
		"locked below"
	)
	local cfg = Tuning.Tower :: any
	local still = { vx = 16, vy = 0, vz = 0 }
	local tilt = 0
	for _ = 1, 50 do
		tilt = Tower.step(tilt, still, still, 0.1, cfg)
	end
	expectEq(tilt, 0, "a steady walk never tips it")
	local t2, dropped = Tower.step(0.5, still, { vx = -16, vy = 0, vz = 0 }, 0.1, cfg)
	expectTrue(t2 > 0.5 and not dropped, "a hard U-turn adds tilt")
	local _, dropJump = Tower.step(0.9, still, { vx = 16, vy = 25, vz = 0 }, 0.1, cfg)
	expectTrue(dropJump, "jumping near the limit drops a box")
	local settled = Tower.step(0.5, still, still, 1, cfg)
	expectTrue(math.abs(settled - (0.5 - cfg.settlePerSecond)) < 1e-9, "settles over time")
end)

local ComfortConfig = require("../src/shared/Config/Comfort")
local Comfort = require("../src/shared/Util/Comfort").new(ComfortConfig)
test("Comfort: independent persistent preferences, defaults and migration", function()
	local p = ProfileSchema.default()
	expectEq(Comfort.read(p).ReduceMotion, false)
	expectEq(Comfort.read(p).ReduceFlashes, false)
	p.tips = 123
	p.claims["achievement.FirstDelivery"] = 5
	expectTrue(Comfort.apply(p, "motion", true, 100))
	p = ProfileSchema.migrate(p)
	expectEq(Comfort.read(p).ReduceMotion, true)
	expectEq(Comfort.read(p).ReduceFlashes, false)
	expectTrue(Comfort.apply(p, "flashes", true, 101))
	expectTrue(Comfort.apply(p, "motion", false, 102))
	p = ProfileSchema.migrate(p)
	expectEq(Comfort.read(p).ReduceMotion, false)
	expectEq(Comfort.read(p).ReduceFlashes, true)
	expectEq(p.tips, 123)
	expectEq(p.claims["achievement.FirstDelivery"], 5)
end)
test("Comfort: strict actions, booleans and clocks cannot change unknown settings", function()
	local key, value = Comfort.action("motion.on")
	expectEq(key, "motion")
	expectEq(value, true)
	key, value = Comfort.action("flashes.off")
	expectEq(key, "flashes")
	expectEq(value, false)
	for _, raw in
		{ "motion.true", "motion.ON", "other.on", "motion.on.extra", "motion.1", "motion.on " }
	do
		expectEq(Comfort.action(raw), nil)
	end
	local p = ProfileSchema.default()
	expectEq(Comfort.apply(p, "other", true, 10), false)
	for _, bad in { "true", 0, 1, {} } do
		expectEq(Comfort.apply(p, "motion", bad, 10), false)
	end
	for _, bad in { -1, math.huge, 0 / 0 } do
		expectEq(Comfort.apply(p, "motion", true, bad), false)
	end
	expectEq(next(p.claims), nil)
end)
test("Comfort: every control and state has English and Hungarian copy", function()
	for _, item in ComfortConfig.items do
		for _, locale in { "en", "hu" } do
			expectTrue(#ComfortConfig.labels[locale][item.key] > 0, item.key)
		end
	end
	for key in ComfortConfig.labels.en do
		expectTrue(type(ComfortConfig.labels.hu[key]) == "string", key)
	end
end)

local BookExtrasLogic = require("../src/shared/Util/BookExtras")
local BookExtrasConfig = require("../src/shared/Config/BookExtras")
test("Book extras: known requests only, completion and exact golden slots", function()
	local spots = require("../src/shared/Config/Collectibles").spots
	local book = {
		customers = {
			{
				id = "Known",
				known = true,
				quirk = { title = "Wait", request = "Stand still" },
				quirkDone = true,
			},
			{
				id = "Hidden",
				known = false,
				quirk = { title = "Secret", request = "Do not reveal" },
				quirkDone = true,
			},
		},
	}
	local golden = {
		day = 3,
		foundIds = { [spots[1].id] = true, Fake = true },
		active = { spots[2].id, "Fake" },
	}
	local snapshot = BookExtrasLogic.snapshot(book, golden, spots)
	expectEq(snapshot.customers.Known.done, true)
	expectEq(snapshot.customers.Hidden.title, nil)
	expectEq(snapshot.customers.Hidden.request, nil)
	expectEq(#snapshot.rows, 30)
	expectEq(snapshot.found, 1)
	expectEq(snapshot.remaining, 1)
	expectEq(snapshot.rows[1].found, true)
	expectEq(snapshot.rows[2].active, true)
	expectEq(snapshot.claims, nil)
end)
test("Book extras: complete Hungarian hints and existing quirk translations", function()
	local spots = require("../src/shared/Config/Collectibles").spots
	expectEq(#BookExtrasConfig.hintsHu, #spots)
	for i, spot in spots do
		expectTrue(#BookExtrasConfig.hintsHu[i] > 0, spot.id)
	end
	for id in require("../src/shared/Config/CustomerQuirks").quirks do
		expectTrue(#BookExtrasConfig.quirksHu[id][1] > 0, id)
		expectTrue(#BookExtrasConfig.quirksHu[id][2] > 0, id)
	end
	for key in BookExtrasConfig.labels.en do
		expectTrue(type(BookExtrasConfig.labels.hu[key]) == "string", key)
	end
end)
test("Book extras: collectible schema migration preserves known and active spots", function()
	local p = ProfileSchema.default()
	p.collectibles = { day = 123, found = { GP01 = true }, active = { "GP02", "GP03" } }
	p.customerBook.StatueMan = { served = 1, stars = 1, quirk = true }
	local q = ProfileSchema.migrate(p)
	expectEq(q.collectibles.day, 123)
	expectEq(q.collectibles.found.GP01, true)
	expectEq(q.collectibles.active[1], "GP02")
	expectEq(q.customerBook.StatueMan.quirk, true)
	q.collectibles.active[1] = "GP04"
	expectEq(p.collectibles.active[1], "GP02")
end)

test("Perf: specific budgets cover new local roots and reject unanchored event parts", function()
	for _, root in { "LocalCheese", "LocalBlackout", "LocalBubbles" } do
		local id = PerfConfig.localEventRoots[root]
		local budget = PerfConfig.eventBudgets[id]
		expectTrue(budget ~= nil, root)
		expectTrue(budget.parts > 0 and budget.parts < PerfConfig.eventBudget.parts, id)
		local metrics = PerfMetrics.empty()
		metrics.parts = budget.parts
		expectEq(#PerfMetrics.overBudget(metrics, budget), 0)
		metrics.unanchoredParts = 1
		expectEq(#PerfMetrics.overBudget(metrics, budget), 1)
	end
end)

test("Moon Walk: tuning and Moonwalk tag", function()
	local cfg = Tuning.LowGravity
	expectTrue(cfg.gravityFactor > 0.15 and cfg.gravityFactor < 1, "gravity factor")
	expectTrue(cfg.easeSeconds < 5, "eases within the build-up / wind-down")
	local StyleLogic = require("../src/shared/Util/StyleLogic")
	local StyleConfig = require("../src/shared/Config/Style")
	local result = StyleLogic.evaluate({ secondsSinceMoonJump = 1 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "Moonwalk") ~= nil, "Moonwalk tag")
end)

test("Meteor Shower: tuning and Close call tag", function()
	local cfg = Tuning.MeteorShower
	expectTrue(cfg.telegraphSeconds >= 1.5, "readable telegraph (mobile)")
	expectTrue(cfg.knockSeconds <= Tuning.Events.maxRagdollSeconds, "ragdoll cap")
	expectTrue(cfg.avoidSafeSpotStuds > cfg.radius, "safe spots stay safe")
	local StyleLogic = require("../src/shared/Util/StyleLogic")
	local StyleConfig = require("../src/shared/Config/Style")
	local result = StyleLogic.evaluate({ secondsSinceNearMiss = 1 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "CloseCall") ~= nil, "Close call tag")
end)

test("Pizza Rain: reward event tuning", function()
	local cfg = Tuning.PizzaRain
	expectTrue(cfg.fallSeconds >= 1.5, "time to run under it")
	expectTrue(cfg.catchRadius >= 3, "catchable on mobile")
	expectTrue(cfg.goalMin > 0 and cfg.goalPerPlayer > 0, "shared goal")
	expectTrue(
		Tuning.Events.tipBonusByEvent.PizzaRain < Tuning.Events.tipBonusDuringEvent,
		"reward event pays its own way"
	)
end)

test("UFO Abduction: loops, beam cycle, tag", function()
	local Ufo = require("../src/shared/Util/Ufo")
	local RoutePath = require("../src/shared/Util/RoutePath")
	local cfg = Tuning.Ufo :: any
	for i, route in MapLayout.ufoRoutes do
		local first, last = route[1], route[#route]
		expectTrue(first.x == last.x and first.z == last.z, `route {i} is closed`)
	end
	local s = { id = 1, route = 1, t0 = 0, offset = 0 }
	local route = MapLayout.ufoRoutes[1] :: any
	local len = RoutePath.length(route)
	local x0, z0 = Ufo.position(RoutePath, route, s, 0, cfg)
	local x1, z1 = Ufo.position(RoutePath, route, s, len / cfg.speed, cfg)
	expectTrue(
		math.abs(x0 - x1) < 1e-6 and math.abs(z0 - z1) < 1e-6,
		"one lap returns to the start"
	)
	expectEq(Ufo.beam(s, 0, cfg), "warn")
	expectEq(Ufo.beam(s, cfg.beamWarnSeconds + 0.1, cfg), "on")
	expectEq(Ufo.beam(s, cfg.beamWarnSeconds + cfg.beamOnSeconds + 0.1, cfg), "rest")
	expectTrue(cfg.beamWarnSeconds + cfg.beamOnSeconds < cfg.beamCycleSeconds, "rest phase exists")
	local StyleLogic = require("../src/shared/Util/StyleLogic")
	local StyleConfig = require("../src/shared/Config/Style")
	local result = StyleLogic.evaluate({ secondsSinceAbduction = 1 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "Abducted") ~= nil, "Abducted tag")
end)

test("Giant Cat: boss tuning, square stays off-limits for respawns", function()
	local cfg = Tuning.GiantCat
	expectTrue(cfg.swipeWarnSeconds >= 1, "readable paw telegraph")
	expectTrue(cfg.knockSeconds <= Tuning.Events.maxRagdollSeconds, "ragdoll cap")
	expectTrue(cfg.feedMin > 0 and cfg.feedPerPlayer > 0, "feeding goal")
	-- a solo courier can fill the bowl inside the shortest active window
	expectTrue(
		cfg.feedMin * cfg.bowlCooldownSeconds < Tuning.Events.activeMinSeconds * 0.7,
		"solo-feedable"
	)
	expectTrue(math.abs(cfg.bowlOffsetZ) < cfg.reach, "the bowl is inside paw reach")
	expectTrue(cfg.deliveryTreats > 1, "a delivery is worth more than a toss")
	local HazardZones = require("../src/shared/Util/HazardZones")
	expectTrue(
		HazardZones.isUnsafe(cfg.x, cfg.z, { events = { "GiantCat" } }, MapLayout.zones :: any, 0),
		"respawns avoid the cat"
	)
end)

test("Expanded chaos audio: dedicated translated warnings and bounded MEGA lifecycle", function()
	local tr = require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	local keys = {}
	for _, id in { "LowGravity", "MeteorShower", "PizzaRain", "UfoAbduction", "GiantCat" } do
		local entry = Sounds.events[id]
		local warning, ambience = Sounds.clips[entry.warning], Sounds.clips[entry.ambience]
		expectTrue(not keys[entry.warning] and not keys[entry.ambience], id)
		keys[entry.warning], keys[entry.ambience] = true, true
		expectTrue(type(warning.caption) == "string" and #warning.caption > 0, id)
		expectTrue(tr(warning.caption, "hu") ~= warning.caption, id)
		expectEq(warning.channel, "sfx")
		expectTrue(ambience.loop and ambience.volume <= 0.1, id)
		expectEq(
			EventAudioPlan.get(Sounds, { id = id, phase = "warning", endsAt = 42 }).warning,
			entry.warning
		)
		for _, other in Events do
			local plan = EventAudioPlan.get(
				Sounds,
				{ id = id, combo = other.id, phase = "active", mega = true }
			)
			expectTrue(#plan.ambience <= Sounds.maxAmbientVoices, id .. ":" .. other.id)
			expectEq(plan.music, "Mega")
			for _, phase in { "calm", "windDown", "reset" } do
				local stopped = EventAudioPlan.get(
					Sounds,
					{ id = id, combo = other.id, phase = phase, mega = true }
				)
				expectEq(#stopped.ambience, 0)
				expectEq(stopped.music, nil)
			end
		end
	end
end)
test("Expanded chaos products: exact immutable variant survives retries and migration", function()
	local boosts = require("../src/shared/Util/Boosts").new(Products)
	local tr = require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	local profile = ProfileSchema.default()
	for _, id in { "LowGravity", "MeteorShower", "PizzaRain", "UfoAbduction", "GiantCat" } do
		local item = boosts.find("Disaster" .. id)
		expectTrue(item ~= nil, id)
		expectTrue(table.isfrozen(item) and table.isfrozen(item.effect), id)
		expectEq(item.productId, 0)
		expectEq(item.priceRobux, 49)
		expectTrue(not item.changesOdds, id)
		expectTrue(tr(item.displayName, "hu") ~= item.displayName, id)
		local checked = nil
		local allowed = DisasterProducts.check(item, 11, 6, function(eventId)
			checked = eventId
			return false, "busy"
		end)
		expectEq(allowed, false)
		expectEq(checked, id)
		expectTrue(boosts.apply(profile, item, "expanded:" .. id, 100))
		boosts.apply(profile, item, "expanded:" .. id, 101)
		profile = ProfileSchema.migrate(profile)
	end
	expectEq(#profile.pendingEffects, 5)
	for _ = 1, 5 do
		local effect = boosts.peekPending(profile, "event")
		expectEq(effect.key, "OrderDisaster")
		expectEq(effect.productKey, "Disaster" .. effect.eventId)
		expectTrue(Sounds.events[effect.eventId] ~= nil, effect.eventId)
		boosts.takePending(profile, "event", effect.id)
	end
	expectEq(boosts.peekPending(profile, "event"), nil)
end)
test("Expanded ambient details: sparse bounded one-shots with no new looping voices", function()
	for _, id in { "MeteorShower", "UfoAbduction", "GiantCat" } do
		local ambient = Sounds.clips[Sounds.events[id].ambience]
		local pattern = ambient.detail
		local clip = Sounds.clips[pattern.cue]
		expectTrue(clip ~= nil and not clip.loop, id)
		expectEq(clip.channel, "sfx")
		expectTrue(clip.seconds < pattern.stepSeconds, id)
		expectTrue(clip.cooldown <= pattern.stepSeconds, id)
		local count = 0
		for beat = 0, #pattern.beats - 1 do
			local cue, index = SoundPolicy.detail(pattern, (beat + 0.25) * pattern.stepSeconds)
			expectEq(index, beat)
			if cue then
				expectEq(cue, pattern.cue)
				count += 1
			end
		end
		expectTrue(count > 0 and count < #pattern.beats, id)
		expectEq(
			select(2, SoundPolicy.detail(pattern, 10000)),
			math.floor(10000 / pattern.stepSeconds)
		)
	end
end)

local OrderOffers = require("../src/shared/Util/OrderOffers")
test("Order offers: near/far split, daredevil zone, estimate, choice validation", function()
	local cfg = Tuning.Offers
	local addresses = {
		{ id = "A", x = 10, z = 0 },
		{ id = "B", x = 20, z = 0 },
		{ id = "C", x = 50, z = 0 },
		{ id = "D", x = 100, z = 0 },
		{ id = "E", x = 200, z = 0 },
		{ id = "F", x = 300, z = 0 },
	}
	local sorted = OrderOffers.byDistance(addresses, { x = 0, z = 0 })
	expectEq(sorted[1].id, "A")
	expectEq(sorted[6].id, "F")
	local first = function()
		return 0
	end
	local last = function()
		return 0.999
	end
	expectEq(OrderOffers.pickNear(sorted, 1 / 3, {}, first), "A")
	expectEq(OrderOffers.pickNear(sorted, 1 / 3, {}, last), "B")
	expectEq(OrderOffers.pickFar(sorted, 1 / 3, {}, first), "E")
	expectEq(OrderOffers.pickFar(sorted, 1 / 3, { E = true }, first), "F")
	-- everything avoided: still returns something
	expectTrue(
		OrderOffers.pickNear(sorted, 1 / 3, { A = true, B = true }, first) ~= nil,
		"fallback"
	)
	-- the real map: every zone an event dares has addresses, near and far differ
	local MapGeometry = require("../src/shared/Util/MapGeometry")
	local real = {}
	for _, b in MapLayout.buildings do
		if b.address then
			local d = MapGeometry.doorPoint(b, MapLayout.streetY)
			table.insert(real, { id = b.address.id, x = d.x, z = d.z })
		end
	end
	local HazardZones = require("../src/shared/Util/HazardZones")
	for event, zoneName in HazardZones.EVENT_ZONE do
		local inside =
			OrderOffers.inZone(real, (MapLayout.zones :: any)[zoneName], cfg.daredevilZoneMargin)
		expectTrue(#inside > 0, `daredevil addresses for {event}`)
	end
	local realSorted = OrderOffers.byDistance(real, MapLayout.counter)
	local nearN = math.floor(#realSorted * cfg.nearShare + 0.5)
	local farN = math.floor(#realSorted * cfg.farShare + 0.5)
	expectTrue(nearN + farN <= #realSorted, "near and far thirds do not overlap")
	-- estimate: capped bonus, multiplier after
	expectEq(OrderOffers.estimate(25, 0, 1, 1), 25)
	expectEq(OrderOffers.estimate(25, 5, 1, 2), 100)
	-- best-of rarity keeps the higher rank
	local rolls = { "Common", "Rare" }
	local i = 0
	local best = OrderOffers.bestRarity(function()
		i += 1
		return rolls[i]
	end, function(id)
		return if id == "Rare" then 3 else 1
	end, 2)
	expectEq(best, "Rare")
	-- choice validation
	expectEq(OrderOffers.validIndex(2, 3), 2)
	expectEq(OrderOffers.validIndex(4, 3), nil)
	expectEq(OrderOffers.validIndex(1.5, 3), nil)
	expectEq(OrderOffers.validIndex(0 / 0, 3), nil)
	expectEq(OrderOffers.validIndex("1", 3), nil)
	-- tuning: the event bonus went to the brave
	expectTrue(cfg.daredevilMultiplier > 1 + Tuning.Events.tipBonusDuringEvent, "daredevil pays")
	expectTrue(Tuning.Events.tipBonusDuringEvent <= 0.3, "general event bonus lowered")
	expectTrue(cfg.choiceSeconds >= 8 and cfg.choiceSeconds <= 20, "choice window")
	expectTrue(cfg.farTipMultiplier > 1 and cfg.farRarityRolls >= 2, "far is worth it")
end)

local EventVote = require("../src/shared/Util/EventVote")
test("Event vote + chaos finale: ballot, tally, winner, finale stages", function()
	local cfg = Tuning.Vote
	local fin = Tuning.Finale
	local seq = { 0, 0, 0 }
	local i = 0
	local opts = EventVote.pickOptions({ "A", "B", "C", "D" }, 3, function()
		i += 1
		return seq[i] or 0
	end)
	expectEq(#opts, 3)
	expectEq(opts[1], "A")
	expectEq(opts[2], "B")
	expectEq(#EventVote.pickOptions({ "A", "B" }, 3, math.random), 2)
	-- opens in the second part of the calm, never with too little left
	expectTrue(not EventVote.shouldOpen(120, 110, cfg), "too early")
	expectTrue(EventVote.shouldOpen(120, 60, cfg), "mid-calm")
	expectTrue(not EventVote.shouldOpen(120, cfg.minOpenSeconds - 1, cfg), "too late")
	-- the shortest normal calm still gets a ballot window
	local calmMin = Tuning.Events.calmMinSeconds
	expectTrue(calmMin * (1 - cfg.openAtCalmFraction) > cfg.minOpenSeconds + 10, "vote window")
	-- tally ignores junk, one vote per key
	local counts = EventVote.tally({ [1] = 2, [2] = 2, [3] = 1, [4] = 9, [5] = 1.5 }, 3)
	expectEq(counts[1], 1)
	expectEq(counts[2], 2)
	expectEq(counts[3], 0)
	expectEq(EventVote.winner(counts, math.random), 2)
	expectEq(EventVote.winner({ 0, 0, 0 }, math.random), nil)
	expectEq(
		EventVote.winner({ 2, 2, 0 }, function()
			return 0.99
		end),
		2
	)
	-- finale clock
	expectEq(EventVote.finaleStage(fin.noticeSeconds + 1, fin), "none")
	expectEq(EventVote.finaleStage(fin.noticeSeconds, fin), "notice")
	expectEq(EventVote.finaleStage(fin.countdownSeconds, fin), "countdown")
	expectEq(EventVote.finaleStage(0, fin), "due")
	expectEq(EventVote.clock(185), "3:05")
	expectEq(EventVote.clock(-4), "0:00")
	expectTrue(
		fin.intervalSeconds > fin.noticeSeconds + Tuning.ChaosMeter.megaDurationSeconds,
		"finale spacing"
	)
	expectTrue(fin.bonusTips > 0 and fin.countdownSeconds < fin.noticeSeconds, "finale tuning")
	-- the board does not sit on another plaza object
	local b = MapLayout.voteBoard
	for _, other in
		{
			MapLayout.cityGoalBoard,
			MapLayout.chaosMeter,
			MapLayout.counter,
			MapLayout.spawn,
			MapLayout.giantOrder,
		}
	do
		expectTrue(math.abs(b.x - other.x) + math.abs(b.z - other.z) > 12, "vote board clear")
	end
	for _, plot in MapLayout.plots do
		expectTrue(
			math.abs(b.x - plot.x) + math.abs(b.z - plot.z) > 12,
			"vote board clear of plots"
		)
	end
end)

local MicroChaos = require("../src/shared/Util/MicroChaos")
test("Micro-chaos: kinds, street paths and spots off the overpass, movers", function()
	local cfg = Tuning.MicroChaos
	local seq = 0
	local function rng()
		seq = (seq * 7919 + 104729) % 1000003
		return seq / 1000003
	end
	local seen = {}
	for _ = 1, 400 do
		seen[MicroChaos.pickKind(cfg.kinds, rng)] = true
	end
	for id in cfg.kinds do
		expectTrue(seen[id], `kind {id} can come up`)
	end
	local byName = {}
	for _, s in MapLayout.streets do
		byName[s.name] = s
	end
	for _, name in cfg.streets do
		local street = byName[name]
		expectTrue(street ~= nil, `street {name} exists`)
		for _ = 1, 20 do
			local spot = MicroChaos.spot(street, cfg.edgeMargin, cfg.avoid, rng)
			if spot then
				expectTrue(not MicroChaos.blocked(spot, cfg.avoid), "spot off the overpass")
				expectTrue(math.abs(spot.x - street.x) <= street.sx / 2, "spot on the street (x)")
				expectTrue(math.abs(spot.z - street.z) <= street.sz / 2, "spot on the street (z)")
			end
			local a, b =
				MicroChaos.path(street, cfg.kinds.Cart.length, cfg.edgeMargin, cfg.avoid, rng)
			if a and b then
				for _, p in { a, b, { x = (a.x + b.x) / 2, z = (a.z + b.z) / 2 } } do
					expectTrue(not MicroChaos.blocked(p, cfg.avoid), "path off the overpass")
					expectTrue(
						math.abs(p.x - street.x) <= street.sx / 2 + 0.01,
						"path on the street"
					)
					expectTrue(
						math.abs(p.z - street.z) <= street.sz / 2 + 0.01,
						"path on the street"
					)
				end
			end
		end
	end
	-- every listed street can host something
	local placed = 0
	for _, name in cfg.streets do
		if MicroChaos.spot(byName[name], cfg.edgeMargin, cfg.avoid, rng) then
			placed += 1
		end
	end
	expectEq(placed, #cfg.streets)
	-- mover sampling
	local from, to = { x = 0, z = 0 }, { x = 20, z = 0 }
	expectEq(MicroChaos.moverAt(from, to, 100, 10, 99, 0), nil)
	local mid = MicroChaos.moverAt(from, to, 100, 10, 101, 0) :: any
	expectTrue(math.abs(mid.x - 10) < 1e-6, "head at 10")
	local tail = MicroChaos.moverAt(from, to, 100, 10, 101, 5) :: any
	expectTrue(math.abs(tail.x - 5) < 1e-6, "goose behind")
	expectEq(MicroChaos.moverAt(from, to, 100, 10, 103, 0), nil)
	expectTrue(math.abs(MicroChaos.duration(from, to, 10, 5) - 2.5) < 1e-6, "duration with tail")
	local boxes =
		MicroChaos.scatter({ x = 0, z = 0 }, cfg.kinds.Boxes.count, cfg.kinds.Boxes.spread, rng)
	expectEq(#boxes, cfg.kinds.Boxes.count)
	for _, b in boxes do
		expectTrue(
			math.sqrt(b.x * b.x + b.z * b.z) <= cfg.kinds.Boxes.spread + 1e-6,
			"box near the pile"
		)
	end
	-- pacing: never more often than the calm can hold, harmless sizes
	expectTrue(cfg.minGapSeconds >= 15 and cfg.maxGapSeconds <= 60, "gap")
	expectTrue(cfg.kinds.Sprinkler.warnSeconds >= 1, "the geyser is telegraphed")
	expectTrue(
		cfg.kinds.Boxes.tips * cfg.kinds.Boxes.count <= Tuning.Orders.baseTip,
		"boxes are a snack"
	)
end)

test("Comfort flags: missing counts as reduced (#177)", function()
	local ComfortFlags = require("../src/shared/Util/ComfortFlags")
	expectEq(ComfortFlags.reduced(nil), true)
	expectEq(ComfortFlags.reduced(true), true)
	expectEq(ComfortFlags.reduced(false), false)
	expectEq(ComfortFlags.reduced("no"), true)
end)

test("Daredevil danger areas for route and live-position events (#199)", function()
	local cfg = Tuning.Offers
	local MapGeometry = require("../src/shared/Util/MapGeometry")
	local real = {}
	for _, b in MapLayout.buildings do
		if b.address then
			local d = MapGeometry.doorPoint(b, MapLayout.streetY)
			table.insert(real, { id = b.address.id, x = d.x, z = d.z })
		end
	end
	for id, def in cfg.daredevil do
		expectTrue(Events ~= nil, "events config")
		if def.routes then
			local routes = (MapLayout :: any)[def.routes]
			expectTrue(routes ~= nil, `{id} routes exist`)
			local near = OrderOffers.nearRoutes(real, routes, def.radius)
			expectTrue(#near >= 2, `{id}: at least 2 daredevil addresses ({#near})`)
		else
			expectTrue(
				def.radius > 0 and (def.stateVector or def.stateJson) ~= nil,
				`{id} live state`
			)
		end
	end
	-- helpers
	local addrs = { { id = "A", x = 0, z = 10 }, { id = "B", x = 0, z = 100 } }
	local onRoute = OrderOffers.nearRoutes(addrs, { { { x = -50, z = 0 }, { x = 50, z = 0 } } }, 15)
	expectEq(#onRoute, 1)
	expectEq(onRoute[1].id, "A")
	local nearP = OrderOffers.nearPoints(addrs, { { x = 0, z = 90 } }, 15)
	expectEq(#nearP, 1)
	expectEq(nearP[1].id, "B")
	expectEq(#OrderOffers.nearPoints(addrs, {}, 15), 0)
end)

test("Event challenges: config covers the events, progress and throttling (#200)", function()
	local Challenges = require("../src/shared/Config/EventChallenges")
	local EventChallenge = require("../src/shared/Util/EventChallenge")
	local Strings = require("../src/shared/Config/Strings")
	local ids = {}
	for _, e in Events do
		ids[e.id] = true
	end
	local kinds = {
		hazard = true,
		custom = true,
		deliver = true,
		deliverZone = true,
		near = true,
		rooftop = true,
	}
	for id, c in Challenges do
		expectTrue(ids[id], `{id} is a real event`)
		expectTrue(kinds[c.kind], `{id} kind`)
		expectTrue(c.goal >= 1 and #c.text > 0, `{id} goal/text`)
		if c.kind == "deliverZone" then
			expectTrue((MapLayout.zones :: any)[c.zone] ~= nil, `{id} zone exists`)
		end
		local hu = (Strings :: any).hu or Strings
		expectTrue(typeof(hu) == "table", "strings table")
	end
	for _, e in Events do
		if e.id ~= "Blizzard" or Challenges.Blizzard then
			expectTrue(Challenges[e.id] ~= nil, `{e.id} has a challenge`)
		end
	end
	local s = EventChallenge.new("PizzaRain", 3)
	expectEq(EventChallenge.add(s, 1), false)
	expectEq(EventChallenge.add(s, 1), false)
	expectEq(EventChallenge.add(s, 1), true)
	expectEq(EventChallenge.add(s, 1), false) -- once only
	expectEq(EventChallenge.shown(s), 3)
	local h = EventChallenge.new("HorseRace", 2)
	expectEq(EventChallenge.hazard(h, 10, 2.5), false)
	expectEq(EventChallenge.hazard(h, 11, 2.5), false) -- throttled
	expectEq(h.progress, 1)
	expectEq(EventChallenge.hazard(h, 13, 2.5), true)
	local n = EventChallenge.new("Tornado", 10)
	for _ = 1, 19 do
		EventChallenge.add(n, 0.5)
	end
	expectEq(EventChallenge.shown(n), 9)
	expectEq(n.done, false)
	expectEq(EventChallenge.add(n, 0.5), true)
	expectTrue(EventChallenge.overStreet(0, -110, MapLayout.streets), "main street is a street")
	expectTrue(
		not EventChallenge.overStreet(-180, -150, MapLayout.streets),
		"a building block is not"
	)
	expectTrue(
		Tuning.Challenges.tips <= Tuning.Orders.baseTip * 2,
		"a challenge is a bonus, not a jackpot"
	)
end)

local ProfileActivity = require("../src/client/Util/ProfileActivity")
local ProfileActivityConfig = require("../src/shared/Config/ProfileActivity")
test("Profile activity: server facts format the viewed courier without mutating them", function()
	local facts = { best = 83450, gold = 7, wins = 3, buff = "LuckyTips", untilAt = 190 }
	local rows = ProfileActivity.rows(
		facts,
		100,
		#require("../src/shared/Config/Collectibles").spots,
		ProfileActivityConfig.labels.en,
		require("../src/shared/Util/Trial").format
	)
	expectEq(#rows, 4)
	expectEq(rows[1].text, "Best time trial\n1:23.45")
	expectEq(rows[2].text, "Golden pepperonis\n7 / 30")
	expectEq(rows[3].text, "Wins against Sal\n3")
	expectEq(rows[4].text, "Wishing well\nLucky Tips · 1:30 remaining")
	expectEq(facts.untilAt, 190)
	local other = ProfileActivity.rows(
		{ gold = 30, wins = 0 },
		100,
		30,
		ProfileActivityConfig.labels.en,
		require("../src/shared/Util/Trial").format
	)
	expectEq(other[2].text, "Golden pepperonis\n30 / 30")
	expectEq(other[3].text, "Wins against Sal\n0")
	expectTrue(string.find(other[4].text, "No active wish", 1, true) ~= nil)
end)
test("Profile activity: missing and invalid attributes never invent records or wins", function()
	for _, facts in
		{
			{},
			{ best = 0 / 0, gold = math.huge, wins = -1, buff = "unknown", untilAt = 999 },
			{ best = -1, gold = 31, wins = "3" },
			{ best = 20.5, gold = -1, untilAt = math.huge, buff = "LuckyTips" },
		}
	do
		local rows = ProfileActivity.rows(
			facts,
			100,
			30,
			ProfileActivityConfig.labels.en,
			function()
				error("invalid best formatted")
			end
		)
		expectEq(#rows, 3)
		expectEq(rows[1].text, "Best time trial\nNo completed run yet")
		expectEq(rows[2].text, "Golden pepperonis\nLoading…")
		expectEq(rows[3].text, "Wishing well\nNo active wish")
	end
end)
test("Profile activity: server-clock expiry and complete Hungarian copy", function()
	local facts = { best = 20579, gold = 1, wins = 1, buff = "GoldenCompass", untilAt = 160 }
	local format = require("../src/shared/Util/Trial").format
	local hu = ProfileActivityConfig.labels.hu
	local rows = ProfileActivity.rows(facts, 159.2, 30, hu, format)
	expectEq(rows[1].text, "Legjobb időfutam\n0:20.58")
	expectEq(rows[4].text, "Kívánságkút\nArany iránytű · 0:01 van hátra")
	expectEq(
		ProfileActivity.rows(facts, 160, 30, hu, format)[4].text,
		"Kívánságkút\nNincs aktív kívánság"
	)
	expectEq(
		ProfileActivity.rows(facts, 161, 30, hu, format)[4].text,
		"Kívánságkút\nNincs aktív kívánság"
	)
	for key, value in ProfileActivityConfig.labels.en do
		expectTrue(hu[key] ~= nil, key)
		if type(value) == "table" then
			for buff in value do
				expectTrue(type(hu[key][buff]) == "string", buff)
			end
		end
	end
end)

local LoopAudio = require("../src/shared/Util/LoopAudio")
local LoopAudioConfig = require("../src/shared/Config/LoopAudio")
test("Loop audio: finale thresholds, jitter and skipped ticks never burst or replay", function()
	local state = LoopAudio.new()
	local function step(now, at, running)
		return LoopAudio.finale(state, now, at or 200, running == true, 180, LoopAudioConfig)
	end
	expectEq(#step(0), 0)
	expectEq(step(20)[1], "FinaleNotice")
	expectEq(#step(20.1, 200.05), 0)
	expectEq(step(190)[1], "FinaleTick")
	expectEq(#step(190.2), 0)
	expectEq(#step(193.2), 1, "only current tick after a stalled frame")
	expectEq(#step(193.3, 200.4), 0, "deadline jitter cannot replay a higher tick")
	expectEq(#step(200), 0)
	expectEq(step(201, 201, true)[1], "FinaleStart")
	expectEq(#step(202, 202, true), 0)
	expectEq(#step(203, 1403, false), 0)
	expectEq(step(1223, 1403, false)[1], "FinaleNotice")
end)
test("Loop audio: a late join during finale does not replay its start", function()
	local s = LoopAudio.new()
	expectEq(#LoopAudio.finale(s, 100, 100, true, 180, LoopAudioConfig), 0)
	expectEq(#LoopAudio.finale(s, 101, 101, true, 180, LoopAudioConfig), 0)
	local c = LoopAudio.finale(LoopAudio.new(), 194, 200, false, 180, LoopAudioConfig)
	expectEq(#c, 1)
	expectEq(c[1], "FinaleTick")
	expectEq(#LoopAudio.finale(s, 0 / 0, 200, false, 180, LoopAudioConfig), 0)
	expectEq(#LoopAudio.finale(s, 100, nil, false, 180, LoopAudioConfig), 0)
end)
test("Loop audio: geese require proximity and never backfill honks", function()
	local s = LoopAudio.new()
	local d = { id = 1, kind = "Geese", t0 = 100, endsAt = 140 }
	expectEq(#LoopAudio.micro(s, d, 100, false, LoopAudioConfig), 0)
	expectEq(LoopAudio.micro(s, d, 101, true, LoopAudioConfig)[1], "GeeseHonk")
	expectEq(#LoopAudio.micro(s, d, 102, true, LoopAudioConfig), 0)
	expectEq(#LoopAudio.micro(s, d, 130, true, LoopAudioConfig), 1)
	expectEq(#LoopAudio.micro(s, d, 130.1, true, LoopAudioConfig), 0)
	expectEq(#LoopAudio.micro(s, d, 140, true, LoopAudioConfig), 0)
	expectEq(#LoopAudio.micro(s, d, 0 / 0, true, LoopAudioConfig), 0)
end)
test("Loop audio: geyser warning and launch are once per visible stage", function()
	local s = LoopAudio.new()
	local d = { id = 1, kind = "Sprinkler", t0 = 100, endsAt = 110, warn = 3 }
	expectEq(LoopAudio.micro(s, d, 100, true, LoopAudioConfig)[1], "GeyserWarning")
	expectEq(#LoopAudio.micro(s, d, 101, true, LoopAudioConfig), 0)
	expectEq(LoopAudio.micro(s, d, 103, true, LoopAudioConfig)[1], "GeyserLaunch")
	expectEq(#LoopAudio.micro(s, d, 104, true, LoopAudioConfig), 0)
	expectEq(#LoopAudio.micro(LoopAudio.new(), d, 104, true, LoopAudioConfig), 0, "no late launch")
	local far = LoopAudio.new()
	LoopAudio.micro(far, d, 101, false, LoopAudioConfig)
	LoopAudio.micro(far, d, 103, false, LoopAudioConfig)
	expectEq(#LoopAudio.micro(far, d, 104, true, LoopAudioConfig), 0, "no missed launch replay")
	expectEq(#LoopAudio.micro(s, nil, 104, true, LoopAudioConfig), 0)
end)
test("Loop audio: server hint cues, localized visual pairs and bounded spatial loop", function()
	expectEq(LoopAudio.hint("🗳️ The city voted: Tornado!", LoopAudioConfig), "VoteWinner")
	expectEq(LoopAudio.hint("📦 Free pizza box! +5 tips", LoopAudioConfig), "BoxPickup")
	expectEq(LoopAudio.hint("🎆 Finale survived! +100 tips", LoopAudioConfig), "FinaleSurvived")
	expectEq(LoopAudio.hint("other message", LoopAudioConfig), nil)
	expectEq(LoopAudio.hint({}, LoopAudioConfig), nil)
	local tr = require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	for _, key in
		{
			"CartRattle",
			"GeeseHonk",
			"GeyserWarning",
			"GeyserLaunch",
			"BoxPickup",
			"VoteCast",
			"VoteWinner",
			"FinaleNotice",
			"FinaleTick",
			"FinaleStart",
			"FinaleSurvived",
		}
	do
		local clip = Sounds.clips[key]
		expectEq(clip.channel, "sfx")
		expectTrue(tr(clip.caption, "hu") ~= clip.caption, key)
		expectTrue(string.match(clip.asset, "^rbxasset://sounds/") ~= nil, key)
	end
	expectTrue(Sounds.clips.CartRattle.spatial and Sounds.clips.CartRattle.loop)
	expectTrue(Sounds.clips.CartRattle.minDistance < Sounds.clips.CartRattle.maxDistance)
	expectEq(Sounds.clips.CartRattle.maxDistance, LoopAudioConfig.hearingStuds)
	expectEq(Sounds.maxVoices, 12)
	expectEq(Sounds.maxAmbientVoices, 2)
end)

test("Weekly challenges for the new loop count their own facts (#207)", function()
	local state = WeeklyChallenges.start(0)
	local ok
	for _, id in { "DaredevilCourier", "ChallengeHunter", "FinaleSurvivor" } do
		ok, state = WeeklyChallenges.select(state, id, 0)
		expectEq(ok, true)
	end
	state = WeeklyChallenges.record(state, "daredevil", 2, 1)
	state = WeeklyChallenges.record(state, "eventChallenge", 3, 1)
	state = WeeklyChallenges.record(state, "delivery", 5, 1)
	expectEq(state.selected.DaredevilCourier.progress, 2)
	expectEq(state.selected.ChallengeHunter.progress, 3)
	expectEq(state.selected.FinaleSurvivor.progress, 0)
	state = WeeklyChallenges.record(state, "finale", 1, 2)
	local reward
	reward, state = WeeklyChallenges.claim(state, "FinaleSurvivor", 3)
	expectTrue(reward ~= nil and reward.tips > 0, "finale weekly pays")
	-- #240: toss and convoy weeklies
	local s2 = WeeklyChallenges.start(0)
	ok, s2 = WeeklyChallenges.select(s2, "Yeeter", 0)
	expectEq(ok, true)
	ok, s2 = WeeklyChallenges.select(s2, "ConvoyCrew", 0)
	expectEq(ok, true)
	s2 = WeeklyChallenges.record(s2, "toss", 4, 1)
	s2 = WeeklyChallenges.record(s2, "convoy", 1, 1)
	expectEq(s2.selected.Yeeter.progress, 4)
	expectEq(s2.selected.ConvoyCrew.progress, 1)
end)

test("Finale hero: most deliveries, ties to the earlier (#208)", function()
	local EV = require("../src/shared/Util/EventVote")
	expectEq(EV.hero({}), nil)
	expectEq(EV.hero({ { id = "a", count = 0, at = 1 } }), nil)
	expectEq(EV.hero({ { id = "a", count = 2, at = 5 }, { id = "b", count = 3, at = 9 } }), "b")
	expectEq(EV.hero({ { id = "a", count = 3, at = 5 }, { id = "b", count = 3, at = 4 } }), "b")
	expectTrue(Tuning.Finale.heroTips > 0 and Tuning.Finale.heroCrownSeconds > 0, "hero tuning")
end)

test("First-time tips: every tip has text, used ids exist (#211)", function()
	local FeatureTips = require("../src/shared/Config/FeatureTips")
	for _, id in
		{
			"OfferBoard",
			"Vote",
			"Challenge",
			"Finale",
			"MicroChaos",
			"Toss",
			"Wind",
			"Convoy",
			"Story",
		}
	do
		local tip = FeatureTips[id]
		expectTrue(tip ~= nil, `tip {id}`)
		expectTrue(
			#tip.title > 0 and #tip.text > 0 and #tip.text <= 140,
			`tip {id} text fits the card`
		)
	end
	expectTrue(Tuning.FeatureTips.showSeconds >= 6, "long enough to read")
end)

test("Day/night cycle: phases, clock, daylight, lamps (#217)", function()
	local DayCycle = require("../src/shared/Util/DayCycle")
	local cfg = Tuning.DayCycle
	expectTrue(
		math.abs(cfg.dawnShare + cfg.dayShare + cfg.duskShare + cfg.nightShare - 1) < 1e-9,
		"shares sum to 1"
	)
	expectEq((DayCycle.phase(0.01, cfg)), "dawn")
	expectEq((DayCycle.phase(0.3, cfg)), "day")
	expectEq((DayCycle.phase(cfg.dawnShare + cfg.dayShare + 0.01, cfg)), "dusk")
	expectEq((DayCycle.phase(0.95, cfg)), "night")
	expectTrue(math.abs(DayCycle.clockTime(0, cfg) - 5) < 1e-6, "dawn starts at 5")
	expectTrue(
		DayCycle.clockTime(0.3, cfg) > 7 and DayCycle.clockTime(0.3, cfg) < 17.5,
		"day clock"
	)
	expectTrue(DayCycle.clockTime(0.99, cfg) < 5, "night wraps past midnight")
	expectEq(DayCycle.daylight(0.3, cfg), 1)
	expectEq(DayCycle.daylight(0.95, cfg), 0)
	expectTrue(DayCycle.lampsOn(0.95, cfg) and not DayCycle.lampsOn(0.3, cfg), "lamps at night")
	for _, phase in { "dawn", "day", "dusk", "night" } do
		local now = 123456.7
		local off = DayCycle.offsetFor(phase :: any, now, cfg)
		expectEq((DayCycle.phase(DayCycle.fraction(now, off, cfg), cfg)), phase)
	end
	expectTrue(cfg.nightShare * cfg.periodSeconds >= 120, "nights last at least 2 minutes")
	expectTrue(cfg.nightTipBonus > 0 and cfg.nightTipBonus <= 0.25, "night shift bonus is modest")
	-- lamps sit inside their street and stay off the overpass ramps
	local streets = {}
	for _, s in MapLayout.streets do
		if s.name ~= "Plaza" and s.name ~= "Fountain" then
			table.insert(streets, s)
		end
	end
	local spots = DayCycle.lampSpots(streets, cfg.lampSpacing, 1.2)
	expectTrue(#spots > 40 and #spots < 220, `lamp count {#spots}`)
	for _, p in spots do
		local onStreet = false
		for _, s in streets do
			if math.abs(p.x - s.x) <= s.sx / 2 and math.abs(p.z - s.z) <= s.sz / 2 then
				onStreet = true
			end
		end
		expectTrue(onStreet, "lamp on a street")
		expectTrue(
			not (math.abs(p.x) < 8 and p.z > -136 and p.z < -84),
			"lamp off the overpass ramps"
		)
	end
end)

test("Errands: shops on open streets, the least detour, sane limits (#218)", function()
	local Errand = require("../src/shared/Util/Errand")
	local cfg = Tuning.Errand
	local avoid = Tuning.MicroChaos.avoid
	for _, shop in MapLayout.errandShops do
		local onStreet = false
		for _, s in MapLayout.streets do
			if
				math.abs(shop.x - s.x) <= s.sx / 2 - 2
				and math.abs(shop.z - s.z) <= s.sz / 2 - 2
			then
				onStreet = true
			end
		end
		expectTrue(onStreet, `{shop.name} is on a street`)
		for _, r in avoid do
			expectTrue(
				not (math.abs(shop.x - r.x) <= r.sx / 2 and math.abs(shop.z - r.z) <= r.sz / 2),
				`{shop.name} off the overpass`
			)
		end
		expectTrue(#shop.item > 0 and #shop.icon > 0, "item + icon")
	end
	local shops = {
		{ name = "A", item = "x", icon = "x", x = 50, z = 5 },
		{ name = "B", item = "x", icon = "x", x = 50, z = 80 },
		{ name = "C", item = "x", icon = "x", x = 2, z = 2 },
	}
	local pick = Errand.pick(shops, { x = 0, z = 0 }, { x = 100, z = 0 }, cfg) :: any
	expectEq(pick.name, "A") -- the least detour; C is too close to the start
	expectEq(
		Errand.pick(
			shops,
			{ x = 0, z = 0 },
			{ x = 5, z = 0 },
			{ maxDetourStuds = 10, minGapStuds = 25 }
		),
		nil
	)
	expectTrue(
		math.abs(Errand.detour({ x = 0, z = 0 }, { x = 50, z = 0 }, { x = 100, z = 0 })) < 1e-9,
		"on the way = 0"
	)
	expectTrue(Errand.reached({ x = 0, z = 0 }, { x = 3, z = 4 }, 5), "reached at 5")
	-- from the counter to every address, most routes get an errand
	local MapGeometry = require("../src/shared/Util/MapGeometry")
	local hits, total = 0, 0
	for _, b in MapLayout.buildings do
		if b.address then
			local d = MapGeometry.doorPoint(b, MapLayout.streetY)
			total += 1
			if
				Errand.pick(
					MapLayout.errandShops :: any,
					MapLayout.counter,
					{ x = d.x, z = d.z },
					cfg
				)
			then
				hits += 1
			end
		end
	end
	expectTrue(hits >= total * 0.6, `errand fits {hits}/{total} routes`)
	expectTrue(cfg.tipMultiplier > 1 and cfg.tipMultiplier <= 1.5, "errand pays a little")
end)

test("City Rush: needs two couriers, grows, pays everyone, expires (#219)", function()
	local CityRush = require("../src/shared/Util/CityRush")
	local cfg = Tuning.CityRush
	local s = CityRush.new()
	expectEq(CityRush.deliver(s, 1, 0, cfg), nil) -- one courier alone: no rush
	expectEq(CityRush.deliver(s, 1, 5, cfg), nil)
	expectEq(CityRush.deliver(s, 2, 10, cfg), "start")
	expectEq(CityRush.deliver(s, 1, 15, cfg), "grow")
	expectEq(s.combo, 4)
	expectTrue(not CityRush.expired(s, 15 + cfg.windowSeconds, cfg), "still on at the edge")
	expectTrue(CityRush.expired(s, 15 + cfg.windowSeconds + 0.1, cfg), "expired")
	local pay, fresh = CityRush.finish(s, cfg)
	expectEq(pay[1], 4 * cfg.perComboTips)
	expectEq(pay[2], 4 * cfg.perComboTips)
	expectEq(fresh.combo, 0)
	local solo = CityRush.new()
	CityRush.deliver(solo, 7, 0, cfg)
	local soloPay = CityRush.finish(solo, cfg)
	expectEq(next(soloPay), nil) -- a lone courier never gets rush tips
	local big = CityRush.new()
	for i = 1, 100 do
		CityRush.deliver(big, i % 3, i, cfg)
	end
	expectEq(big.combo, cfg.maxCombo)
	expectTrue(
		cfg.maxCombo * cfg.perComboTips <= Tuning.Orders.baseTip * 5,
		"rush payout is capped"
	)
end)

test("Golden pizza tuning stays rare and fair (#223)", function()
	local g = Tuning.Golden
	expectTrue(g.chance > 0 and g.chance <= 0.05, "rare")
	expectTrue(
		g.tipMultiplier > g.scuffedMultiplier and g.scuffedMultiplier > 1,
		"scuffed still pays"
	)
	-- expected extra tips per order stay small
	expectTrue(g.chance * (g.tipMultiplier - 1) <= 0.08, "under +8% on average")
end)

test("Disaster of the week: stable per week, rotates, weighted pick (#224)", function()
	local F = require("../src/shared/Util/FeaturedEvent")
	local ids = { "Tornado", "Flood", "HorseRace" }
	expectEq(F.pick(ids, 10), F.pick({ "HorseRace", "Tornado", "Flood" }, 10)) -- order-proof
	local seen = {}
	for w = 0, 2 do
		seen[F.pick(ids, w) :: string] = true
	end
	expectEq(
		#ids,
		(function()
			local n = 0
			for _ in seen do
				n += 1
			end
			return n
		end)()
	)
	expectEq(F.pick({}, 3), nil)
	-- Monday 2026-11-09 00:00 UTC and Sunday 23:59 belong to different weeks
	local monday = 1794182400
	expectTrue(F.week(monday) == F.week(monday - 1) + 1, "weeks turn on Monday")
	expectEq(F.week(monday), F.week(monday + 6 * 86400 + 86399))
	local count = 0
	for i = 0, 999 do
		if F.weightedPick(ids, "Flood", 2, i / 1000) == "Flood" then
			count += 1
		end
	end
	expectTrue(count >= 480 and count <= 520, `featured ~half with weight 2 of 4 ({count})`)
	expectEq(F.weightedPick({}, "Flood", 2, 0.5), nil)
end)

test("Loop titles: every title is a real title cosmetic with an unlock hint (#227)", function()
	local byId = {}
	for _, item in CosmeticConfig.items do
		byId[item.id] = item
	end
	for _, def in Tuning.LoopTitles do
		local item = byId[def.cosmetic]
		expectTrue(item ~= nil, `{def.cosmetic} exists`)
		expectEq(item.slot, "title")
		expectTrue(item.price == nil and not item.free, `{def.cosmetic} is earned, not bought`)
		expectTrue(CosmeticConfig.unlockHints[def.cosmetic] ~= nil, `{def.cosmetic} hint`)
		expectTrue(def.goal >= 1 and #def.counter > 0, "goal + counter")
	end
end)

test("Gale Force (#230): gust schedule, push cap, ride check, arrow", function()
	local Wind = require("../src/shared/Util/Wind")
	local cfg = Tuning.WindGust :: any
	expectTrue(cfg.telegraphSeconds >= 2, "readable telegraph (mobile)")
	expectTrue(cfg.calmMinSeconds <= cfg.calmMaxSeconds, "calm range")
	-- anti-teleport travel check: the wind never makes you faster than allowed
	local fastest = Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
	expectTrue(cfg.maxWindSpeed < fastest / Tuning.Orders.minTravelTimeFactor, "wind cap")
	expectTrue(cfg.shoveSpeed <= cfg.maxWindSpeed, "shove under the cap")
	expectEq(#Wind.directions, 8)
	for _, d in Wind.directions do
		expectTrue(math.abs(d.x * d.x + d.z * d.z - 1) < 1e-6, d.name)
	end
	-- never the same direction twice in a row
	local seq = { 1, 7, 3 }
	local i = 0
	local function rnd(a: number, b: number): number
		i += 1
		return math.clamp(seq[(i - 1) % #seq + 1], a, b)
	end
	local last = Wind.pickIndex(rnd, nil)
	for _ = 1, 20 do
		local nextIndex = Wind.pickIndex(rnd, last)
		expectTrue(nextIndex ~= last and nextIndex >= 1 and nextIndex <= 8, "fresh direction")
		last = nextIndex
	end
	local g = Wind.schedule(100, 7, cfg) -- west wind pushes +X
	expectEq(g.name, "west")
	expectEq(g.x, 1)
	expectEq(Wind.phase(g, 100), "telegraph")
	expectEq(Wind.phase(g, g.startsAt + 0.1), "blowing")
	expectEq(Wind.phase(g, g.endsAt + 0.1), "calm")
	expectEq(Wind.phase(nil, 100), "calm")
	local c = Wind.calmSeconds(function()
		return 0.5
	end, cfg)
	expectTrue(c >= cfg.calmMinSeconds and c <= cfg.calmMaxSeconds, "calm seconds")
	-- the air pushes harder than the ground, and the cap holds
	local gx = Wind.push(g, 0, 0, true, 0.1, cfg)
	local ax = Wind.push(g, 0, 0, false, 0.1, cfg)
	expectTrue(ax > gx and gx > 0, "air > ground")
	local capped = Wind.push(g, cfg.maxWindSpeed - 0.5, 0, false, 1, cfg)
	expectTrue(math.abs(capped - 0.5) < 1e-6, "tops up to the cap only")
	expectEq((Wind.push(g, cfg.maxWindSpeed + 5, 0, false, 1, cfg)), 0)
	-- riding: high enough and moving with the wind
	expectTrue(Wind.riding(g, cfg.rideSpeed + 1, 0, cfg.rideFeet + 1, cfg), "riding")
	expectTrue(not Wind.riding(g, cfg.rideSpeed + 1, 0, 0, cfg), "on the ground")
	expectTrue(not Wind.riding(g, -(cfg.rideSpeed + 1), 0, cfg.rideFeet + 1, cfg), "against it")
	-- arrow: camera looking -Z, a west wind pushes right (+90°)
	expectEq(Wind.arrowRotation(g, 0, -1), 90)
	local north = Wind.schedule(0, 1, cfg) -- pushes +Z = towards the camera
	expectEq(math.abs(Wind.arrowRotation(north, 0, -1)), 180)
	-- Tailwind style tag
	local result = StyleLogic.evaluate({ secondsSinceGustRide = 1 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "Tailwind") ~= nil, "Tailwind tag")
end)

test("Convoy (#232): close + recent pairs, caps, no self-convoy", function()
	local Convoy = require("../src/shared/Util/Convoy")
	local cfg = Tuning.Convoy :: any
	expectTrue(cfg.tips > 0 and cfg.tips <= 25, "small flat bonus")
	local log = {}
	Convoy.record(log, 1, "Ann", 0, 0, 100)
	-- myself: nothing
	expectEq(#Convoy.match(log, 1, 1, 1, 101, cfg), 0)
	-- too far / too late: nothing
	expectEq(#Convoy.match(log, 2, cfg.radius + 5, 0, 101, cfg), 0)
	expectEq(#Convoy.match(log, 2, 1, 1, 100 + cfg.windowSeconds + 1, cfg), 0)
	-- close and recent: Ann is the partner
	local m = Convoy.match(log, 2, 10, 0, 105, cfg)
	expectEq(#m, 1)
	expectEq(m[1].name, "Ann")
	Convoy.record(log, 2, "Bob", 10, 0, 105)
	-- a third courier gets both, nearest first
	local m3 = Convoy.match(log, 3, 12, 0, 106, cfg)
	expectEq(#m3, 2)
	expectEq(m3[1].name, "Bob")
	-- Ann's entry has paid out maxCredits times now: no more
	expectEq(log[1].credits, cfg.maxCredits)
	local m4 = Convoy.match(log, 4, 0, 0, 107, cfg)
	expectEq(#m4, 1)
	expectEq(m4[1].name, "Bob")
	-- one entry per courier (the nearest)
	local log2 = {}
	Convoy.record(log2, 1, "Ann", 50, 0, 100)
	Convoy.record(log2, 1, "Ann", 5, 0, 101)
	local m5 = Convoy.match(log2, 2, 0, 0, 102, cfg)
	expectEq(#m5, 1)
	expectEq(m5[1].x, 5)
	-- pruning drops old entries
	Convoy.prune(log2, 100 + cfg.windowSeconds + 0.5, cfg)
	expectEq(#log2, 1)
end)

test("Shift report (#234): round stats, headline priority, nothing to report", function()
	local Recap = require("../src/shared/Util/Recap")
	local s = Recap.new()
	expectEq(Recap.report(s, false, 0, 5), nil)
	Recap.addDelivery(s, 40.7, 2, false, 2, "Uncommon", "Kite Kid")
	Recap.addDelivery(s, 25, 3, true, 1, "Common", "Bob")
	expectEq(s.deliveries, 2)
	expectEq(s.tips, 65)
	expectEq(s.bestStreak, 3)
	expectEq(s.daredevils, 1)
	expectEq(s.rarestName, "Kite Kid") -- a later Common doesn't replace it
	local r = Recap.report(s, false, 1, 5) :: any
	expectEq(r.headline, "🍕 Solid Shift!")
	expectEq(r.challenges, 1)
	expectEq((Recap.report(s, true, 0, 5) :: any).headline, "🏆 Finale Hero!")
	Recap.addDelivery(s, 10, 0, false, 5, "Legendary", "The North Wind")
	expectEq(Recap.headline(s, false, 0, 5), "🌟 Legend Whisperer")
	local t = Recap.new()
	for _ = 1, 3 do
		Recap.addDelivery(t, 1, 0, true, nil, nil, nil)
	end
	expectEq(Recap.headline(t, false, 0, 5), "🔥 Certified Daredevil")
	local u = Recap.new()
	Recap.addDelivery(u, -5, 9, false, nil, nil, nil)
	expectEq(u.tips, 0)
	expectEq(Recap.headline(u, false, 0, 5), "⚡ Unstoppable")
	expectEq(Recap.headline(Recap.new(), false, 3, 5), "🎯 Challenge Hunter")
	expectTrue(Tuning.Recap.showSeconds >= 6, "readable")
end)

test("Pizza toss (#236): kinds, range, height, arc, Yeet tag", function()
	local Toss = require("../src/shared/Util/Toss")
	local cfg = Tuning.Toss :: any
	local r = Tuning.Orders.deliveryRadiusStuds
	expectTrue(cfg.maxStuds > r, "a toss reaches past the door radius")
	expectTrue(cfg.maxStuds <= 32, "but not across the street")
	local ok, why = Toss.check("fragile", 20, 0, r, cfg)
	expectTrue(not ok and why:find("Cakes") ~= nil, "cakes don't fly")
	expectTrue(not (Toss.check("party", 20, 0, r, cfg)), "party tower stays in hand")
	expectTrue((Toss.check("normal", 20, 0, r, cfg)), "normal at 20")
	expectTrue((Toss.check(nil, cfg.maxStuds + 3, 0, r, cfg, 4)), "latency slack")
	expectTrue(not (Toss.check(nil, cfg.maxStuds + 5, 0, r, cfg, 4)), "too far")
	expectTrue(not (Toss.check(nil, 20, cfg.maxHeightDiff + 1, r, cfg)), "not from a roof")
	expectTrue(Toss.inRange("rush", 20, 0, r, cfg), "button at 20")
	expectTrue(not Toss.inRange("rush", r - 1, 0, r, cfg), "no button at the door")
	expectTrue(not Toss.inRange("fragile", 20, 0, r, cfg), "no button for a cake")
	local a, b = { x = 0, y = 0, z = 0 }, { x = 10, y = 2, z = 0 }
	expectEq(Toss.arc(a, b, 0, 7).x, 0)
	expectEq(Toss.arc(a, b, 1, 7).y, 2)
	local mid = Toss.arc(a, b, 0.5, 7)
	expectEq(mid.x, 5)
	expectEq(mid.y, 1 + 7)
	local result = StyleLogic.evaluate({ secondsSinceToss = 0 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "Yeet") ~= nil, "Yeet tag")
end)

test("Adaptive Daredevil (#242): pick rate → multiplier, bounds, format", function()
	local OO = require("../src/shared/Util/OrderOffers")
	local a = Tuning.Offers.daredevilAdaptive :: any
	local base = Tuning.Offers.daredevilMultiplier
	expectEq(OO.daredevilMultiplier(0, a.minSamples - 1, base, a), base) -- too few samples
	expectEq(OO.daredevilMultiplier(0, 40, base, a), a.max) -- nobody dares
	expectEq(OO.daredevilMultiplier(40, 40, base, a), a.min) -- everybody dares
	expectEq(OO.daredevilMultiplier(12, 40, base, a), base) -- the target share
	local mid = OO.daredevilMultiplier(9, 40, base, a) -- 22.5%: between max and base
	expectTrue(mid > base and mid < a.max, "between")
	expectEq(mid * 20, math.floor(mid * 20)) -- 0.05 steps
	for picks = 0, 40 do
		local m = OO.daredevilMultiplier(picks, 40, base, a)
		expectTrue(m >= a.min and m <= a.max, `bounded at {picks}`)
	end
	expectEq(OO.formatMultiplier(2), "2")
	expectEq(OO.formatMultiplier(2.3), "2.3")
	expectEq(OO.formatMultiplier(2.25), "2.25")
	expectEq(OO.formatMultiplier(1.75), "1.75")
end)

test("Floor Is Lava (#244): tiles keep doors clear, waves, phases, push-out", function()
	local LF = require("../src/shared/Util/LavaFloor")
	local ML = require("../src/shared/Config/MapLayout")
	local MG = require("../src/shared/Util/MapGeometry")
	local cfg = Tuning.FloorIsLava :: any
	expectTrue(cfg.telegraphSeconds >= 2, "readable warning (mobile)")
	local keep = LF.keepClear(ML, function(b)
		local p = MG.doorPoint(b, ML.streetY)
		return { x = p.x, z = p.z }
	end)
	expectTrue(#keep > 10, "doors + counter + spawn + safe spots")
	local tiles = LF.tiles(ML.streets :: any, keep, cfg)
	expectTrue(#tiles > 50 and #tiles < 600, `tile count {#tiles}`)
	-- every address door, the counter and the spawn stay off the lava
	for _, p in keep do
		local all = {}
		for i = 1, #tiles do
			all[i] = i
		end
		expectEq(LF.tileAt(tiles, all, p.x, p.z), nil)
	end
	-- no two tiles share a centre area (no overlapping slabs drawn twice)
	for i = 1, #tiles do
		for j = i + 1, #tiles do
			local a, b = tiles[i], tiles[j]
			local overlap = math.abs(a.x - b.x) < (a.sx + b.sx) / 2 - 1
				and math.abs(a.z - b.z) < (a.sz + b.sz) / 2 - 1
			if overlap then
				expectTrue(false, `tiles {i} and {j} overlap`)
			end
		end
	end
	-- waves: unique, sorted, the right share
	local seq = 0
	local wave = LF.pickWave(#tiles, cfg, function(a, b)
		seq += 7
		return a + seq % (b - a + 1)
	end)
	expectEq(#wave, math.floor(#tiles * cfg.waveShare + 0.5))
	for k = 2, #wave do
		expectTrue(wave[k] > wave[k - 1], "unique + sorted")
	end
	expectEq(#LF.pickWave(0, cfg, math.random), 0)
	local w = LF.schedule({ 1 }, 10, cfg)
	expectEq(LF.phase(w, 10), "telegraph")
	expectEq(LF.phase(w, w.lavaAt + 0.1), "lava")
	expectEq(LF.phase(w, w.endsAt), "cool")
	expectEq(LF.phase(nil, 10), "cool")
	local t = { x = 0, z = 0, sx = 16, sz = 16 }
	local out = LF.pushOut(t, 6, 1)
	expectEq(out.x, 1)
	expectEq(out.z, 0)
	out = LF.pushOut(t, -1, -7)
	expectEq(out.z, -1)
	local result = StyleLogic.evaluate({ secondsSinceLavaHop = 1 }, StyleConfig.style, 5)
	expectTrue(table.find(result.tags, "LavaHopper") ~= nil, "Lava hopper tag")
end)

test("High five (#246): match in range and window, pair cooldown, prune", function()
	local HF = require("../src/shared/Util/HighFive")
	local cfg = Tuning.HighFive :: any
	expectTrue(cfg.radius >= cfg.buttonRadius, "server slack ≥ button range")
	expectTrue(cfg.tips <= 10, "token tip")
	local req = { [1] = { t = 10, x = 0, z = 0 } }
	expectEq(HF.match(req, 1, 0, 0, 11, cfg), nil) -- not with myself
	expectEq(HF.match(req, 2, cfg.radius + 1, 0, 11, cfg), nil) -- too far
	expectEq(HF.match(req, 2, 1, 0, 10 + cfg.windowSeconds + 0.1, cfg), nil) -- too late
	expectEq(HF.match(req, 2, 3, 0, 11, cfg), 1)
	req[3] = { t = 10.5, x = 1, z = 0 }
	expectEq(HF.match(req, 2, 2, 0, 11, cfg), 3) -- the nearest
	expectEq(HF.pairKey(5, 2), "2:5")
	expectEq(HF.pairKey(2, 5), "2:5")
	local paid = {}
	expectTrue(HF.claimPair(paid, 1, 2, 100, cfg), "first pays")
	expectTrue(not HF.claimPair(paid, 2, 1, 101, cfg), "same pair waits")
	expectTrue(HF.claimPair(paid, 1, 3, 101, cfg), "another pair pays")
	expectTrue(HF.claimPair(paid, 2, 1, 100 + cfg.pairCooldownSeconds, cfg), "after the cooldown")
	HF.prune(req, 10 + cfg.windowSeconds + 0.2, cfg)
	expectEq(req[1], nil)
	expectTrue(req[3] ~= nil, "fresh one stays")
end)

test("Shift report compare (#248)", function()
	local Recap = require("../src/shared/Util/Recap")
	local a = Recap.new()
	Recap.addDelivery(a, 100, 0, false, nil, nil, nil)
	local ra = Recap.report(a, false, 0, 5) :: any
	expectEq(Recap.compare(ra, nil), nil)
	local b = Recap.new()
	for _ = 1, 4 do
		Recap.addDelivery(b, 55, 0, false, nil, nil, nil)
	end
	local rb = Recap.report(b, false, 0, 5) :: any
	expectEq(Recap.compare(rb, ra), "📈 +3 deliveries, +120 tips vs last round")
	expectEq(Recap.compare(ra, rb), "📉 -3 deliveries, -120 tips vs last round")
	expectEq(Recap.compare(ra, ra), "➖ +0 deliveries, +0 tips vs last round")
end)

test("Story orders (#254): config uses everyday customers and real addresses", function()
	local Stories = require("../src/shared/Config/Stories")
	local Story = require("../src/shared/Util/Story")
	local ML = require("../src/shared/Config/MapLayout")
	local addresses = {}
	for _, b in ML.buildings do
		if b.address then
			addresses[b.address.id] = true
		end
	end
	local customerById = {}
	for _, c in Customers do
		customerById[c.id] = c
	end
	local ids = {}
	for _, s in Stories do
		expectTrue(not ids[s.id], `unique {s.id}`)
		ids[s.id] = true
		expectEq(#s.chapters, 3)
		expectTrue(#s.ending > 0, s.id)
		for i, c in s.chapters do
			local def = customerById[c.customer]
			expectTrue(def ~= nil, `{s.id}/{i} customer {c.customer}`)
			expectTrue(
				def.rarity == "Common" or def.rarity == "Uncommon",
				`{s.id}/{i} everyday customer`
			)
			expectTrue(def.event == nil, `{s.id}/{i} not an event customer`)
			expectTrue(not def.night, `{s.id}/{i} not a night-only customer (#266)`)
			expectTrue(addresses[c.address] == true, `{s.id}/{i} address {c.address}`)
			expectTrue(#c.line > 0 and #c.line <= 90, `{s.id}/{i} line fits a hint`)
		end
	end
	-- progress
	local first, ch = Story.next(Stories :: any, {})
	expectEq(first and first.id, Stories[1].id)
	expectEq(ch, 1)
	local p = { [Stories[1].id] = 3, [Stories[2].id] = 1 }
	local s2, ch2 = Story.next(Stories :: any, p)
	expectEq(s2 and s2.id, Stories[2].id)
	expectEq(ch2, 2)
	local all = {}
	for _, s in Stories do
		all[s.id] = 3
	end
	expectEq((Story.next(Stories :: any, all)), nil)
	expectTrue(
		Story.isLast(Stories[1] :: any, 3) and not Story.isLast(Stories[1] :: any, 2),
		"last chapter"
	)
	expectEq(Story.label(Stories[1] :: any, 2), `{Stories[1].title} · 2/3`)
	local fromClaims =
		Story.fromClaims({ [`story.{Stories[1].id}`] = 2, junk = "x" }, Stories :: any)
	expectEq(fromClaims[Stories[1].id], 2)
	expectEq(fromClaims[Stories[2].id], 0)
	expectTrue(Tuning.Stories.tipMultiplier > 1 and Tuning.Stories.completeTips > 0, "rewards")
end)

local DecorConfig = require("../src/shared/Config/Decorations")
local Decor = require("../src/shared/Util/Decorations").new(DecorConfig)
test("Decorations: fixed slots, valid catalog and bounded static geometry", function()
	local ids, slots, parts = {}, {}, 0
	expectEq(#DecorConfig.slots, 4)
	for _, slot in DecorConfig.slots do
		expectTrue(not slots[slot.id], slot.id)
		slots[slot.id] = true
		expectEq(#slot.offset, 3)
		parts += #DecorConfig.pieces[slot.id]
		for _, piece in DecorConfig.pieces[slot.id] do
			expectEq(#piece.size, 3)
			for _, n in piece.size do
				expectTrue(n > 0 and n < 10, piece.name)
			end
		end
	end
	expectTrue(parts <= DecorConfig.maxPartsPerPlot, "per-plot part budget")
	for _, item in DecorConfig.items do
		expectTrue(not ids[item.id] and slots[item.slot], item.id)
		ids[item.id] = true
		expectTrue(#item.en > 0 and #item.hu > 0 and item.en ~= item.hu, item.id)
		expectTrue(item.price >= 0 and item.price % 1 == 0, item.id)
		expectTrue(string.match(item.color, "^#%x%x%x%x%x%x$") ~= nil, item.id)
	end
	for key in DecorConfig.labels.en do
		expectTrue(type(DecorConfig.labels.hu[key]) == "string", key)
	end
end)
test("Decorations: buys deduct once and reject insufficient or malformed wallets", function()
	local p = ProfileSchema.default()
	p.tips = 1000
	expectTrue(Decor.apply(p, "buy.PlotFlagCheese"))
	expectEq(p.tips, 750)
	expectEq(p.cosmetics.owned.PlotFlagCheese, true)
	expectEq(Decor.apply(p, "buy.PlotFlagCheese"), false)
	expectEq(p.tips, 750)
	for _, balance in { 249, -1, 0 / 0, math.huge, "1000" } do
		local q = ProfileSchema.default();
		(q :: any).tips = balance
		expectEq(Decor.apply(q, "buy.PlotFlagCheese"), false)
		expectEq(q.cosmetics.owned.PlotFlagCheese, nil)
	end
end)
test(
	"Decorations: free placement, clear and independent cosmetic ledgers survive migration",
	function()
		local p = ProfileSchema.default()
		p.tips = 1000
		p.cosmetics.owned.ClassicDecor = true
		p.cosmetics.equipped.decor = "ClassicDecor"
		p.cosmetics.owned.ClassicBox = true
		p.cosmetics.equipped.box = "ClassicBox"
		expectTrue(Decor.apply(p, "place.flag.PlotFlagClassic"))
		expectEq(p.tips, 1000)
		expectTrue(Decor.apply(p, "buy.PlotPlantMint"))
		expectTrue(Decor.apply(p, "place.plant.PlotPlantMint"))
		local q = ProfileSchema.migrate(p)
		expectEq(Decor.selected(q, "flag"), "PlotFlagClassic")
		expectEq(Decor.selected(q, "plant"), "PlotPlantMint")
		expectEq(q.cosmetics.equipped.decor, "ClassicDecor")
		expectEq(q.cosmetics.equipped.box, "ClassicBox")
		expectEq(q.tips, 600)
		expectTrue(Decor.apply(q, "clear.plant"))
		expectEq(Decor.selected(q, "plant"), nil)
		expectEq(q.cosmetics.owned.PlotPlantMint, true)
		expectEq(Decor.selected(p, "plant"), "PlotPlantMint", "migration copies the ledger")
	end
)
test("Decorations: malformed intents cannot select another slot, catalog or owner", function()
	local p = ProfileSchema.default()
	p.tips = 5000
	for _, action in
		{
			"place.flag.PlotPlantBasil",
			"place.flag.ClassicBox",
			"place.flag.PlotFlagClassic.123",
			"clear.unknown",
			"clear.flag.extra",
			"buy.Unknown",
			"place.123.PlotFlagClassic",
			"buy.PlotFlagCheese.extra",
			"",
			123,
			{},
		}
	do
		expectEq(Decor.apply(p, action), false, tostring(action))
	end
	expectEq(Decor.apply(p, "place.flag.PlotFlagCheese"), false, "unowned decoration")
	expectEq(p.tips, 5000)
	expectEq(next(p.cosmetics.equipped), nil)
end)
test("Decorations: snapshots whitelist inventory and ignore corrupt placements", function()
	local p = ProfileSchema.default()
	p.tips = 80
	p.cosmetics.owned.SecretThing = true
	p.claims.secret = 123
	p.cosmetics.equipped.decor_flag = "PlotFlagCheese"
	local dto = Decor.snapshot(p, false)
	expectEq(dto.ready, false)
	expectEq(dto.slots.flag, nil, "forged unowned slot is hidden")
	expectEq(dto.owned.PlotFlagClassic, true)
	expectEq(dto.owned.PlotFlagCheese, false)
	expectEq(dto.owned.SecretThing, nil)
	expectEq(dto.claims, nil)
	local count = 0
	for _ in dto.owned do
		count += 1
	end
	expectEq(count, #DecorConfig.items)
end)

-- #229: audio follows published state without replaying earlier rewards.
local BatchAudio = require("../src/shared/Util/BatchAudio")
local BatchAudioConfig = require("../src/shared/Config/BatchAudio")
test("Batch audio: rush baseline, combo jumps, reset and end are bounded", function()
	local s = BatchAudio.new()
	expectEq(#BatchAudio.rush(s, 3, false), 0)
	expectEq(#BatchAudio.rush(s, 3, true), 0)
	expectEq(BatchAudio.rush(s, 6, true)[1], "RushTick")
	expectEq(#BatchAudio.rush(s, 6, true), 0)
	expectEq(BatchAudio.rush(s, nil, true)[1], "RushEnd")
	expectEq(#BatchAudio.rush(s, nil, true), 0)
	expectEq(BatchAudio.rush(s, 2, true)[1], "RushStart")
	expectEq(BatchAudio.rush(s, 1, true)[1], "RushStart")
end)
test("Batch audio: errands ring and pick up once, cancellation stays quiet", function()
	local s = BatchAudio.new()
	local e = { name = "Bakery", item = "bread", done = false }
	expectEq(#BatchAudio.errand(s, nil, false), 0)
	expectEq(BatchAudio.errand(s, e, true)[1], "ErrandRing")
	expectEq(#BatchAudio.errand(s, e, true), 0)
	e.done = true
	expectEq(BatchAudio.errand(s, e, true)[1], "ErrandPickup")
	expectEq(#BatchAudio.errand(s, e, true), 0)
	expectEq(#BatchAudio.errand(s, nil, true), 0)
	expectEq(#BatchAudio.errand(s, e, true), 0, "completed errand does not ring")
	e.done = false
	BatchAudio.errand(s, e, false)
	expectEq(#BatchAudio.errand(s, e, true), 0, "late join does not ring")
	expectEq(#BatchAudio.errand(s, { name = 1 }, true), 0)
end)
test("Batch audio: hero deadlines reject expiry and suppress late join", function()
	local s = BatchAudio.new()
	expectEq(#BatchAudio.hero(s, 100, 50, false), 0)
	expectEq(#BatchAudio.hero(s, 100, 51, true), 0)
	expectEq(BatchAudio.hero(s, 200, 52, true)[1], "HeroChime")
	expectEq(#BatchAudio.hero(s, 200, 53, true), 0)
	expectEq(#BatchAudio.hero(s, 40, 54, true), 0)
	for _, bad in { 0, -1, math.huge, 0 / 0, "future", {} } do
		expectEq(#BatchAudio.hero(s, bad, 55, true), 0)
	end
end)
test("Batch audio: only authoritative golden and title hints announce rewards", function()
	expectEq(
		BatchAudio.hint("✨ Courier is carrying a GOLDEN PIZZA to the Bakery!", BatchAudioConfig),
		"GoldenJingle"
	)
	expectEq(
		BatchAudio.hint(
			"🏷️ New title unlocked: Night Owl! Equip it in Cosmetics.",
			BatchAudioConfig
		),
		"TitleUnlock"
	)
	for _, raw in { "GOLDEN PIZZA", "title unlocked", "✨ Other message", "delivered", 7, {} } do
		expectEq(BatchAudio.hint(raw, BatchAudioConfig), nil)
	end
end)
test("Batch audio: captions translate, spatial slots and night bed stay bounded", function()
	local strings = require("../src/shared/Config/Strings")
	for _, cue in
		{
			"GoldenJingle",
			"RushStart",
			"RushDrum",
			"RushTick",
			"RushEnd",
			"ErrandRing",
			"ErrandPickup",
			"TitleUnlock",
			"HeroChime",
			"NightChirp",
		}
	do
		local clip = Sounds.clips[cue]
		expectEq(clip.channel, "sfx")
		expectTrue(type(strings.hu[clip.caption]) == "string", cue)
	end
	local scopes = 0
	for _ in Sounds.spatialScopes do
		scopes += 1
	end
	expectEq(scopes, 2)
	expectTrue(Sounds.spatialScopes.micro and Sounds.spatialScopes.golden)
	expectTrue(Sounds.clips.GoldenSparkLoop.spatial and Sounds.clips.GoldenSparkLoop.loop)
	expectEq(Sounds.clips.GoldenSparkLoop.maxDistance, BatchAudioConfig.hearingStuds)
	expectTrue(Sounds.clips.NightAmbience.bed and Sounds.clips.NightAmbience.loop)
	expectEq(Sounds.clips.NightAmbience.detail.cue, "NightChirp")
	expectEq(Sounds.maxVoices, 12)
	expectEq(Sounds.maxAmbientVoices, 2)
end)

test("Night-only customers (#258): never by day, possible at night", function()
	local Odds = require("../src/shared/Util/CustomerOdds")
	local night = {}
	for _, c in Customers do
		if c.night then
			expectEq(c.event, nil, `{c.id}: night customers are normal-time`)
			night[c.id] = true
		end
	end
	local count = 0
	for _ in night do
		count += 1
	end
	expectEq(count, 4)
	local seen = false
	for _, rarity in { "Uncommon", "Rare", "Epic", "Legendary" } do
		for i = 1, 60 do
			local r = (i - 0.5) / 60
			local day = Odds.pickCustomer(Customers :: any, rarity, nil, function()
				return r
			end)
			expectTrue(
				day ~= nil and not night[day :: string],
				`{rarity}: no night customer by day`
			)
			local atNight = Odds.pickCustomer(Customers :: any, rarity, nil, function()
				return r
			end, true)
			seen = seen or night[atNight :: string] == true
		end
	end
	expectTrue(seen, "a night customer can come at night")
end)

test("What's new (#268): version, short lines, Hungarian for every line", function()
	local WN = require("../src/shared/Config/WhatsNew")
	local tr = require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	expectTrue(#WN.version > 0, "version")
	expectTrue(WN.minDeliveries >= 1, "not for brand-new couriers")
	expectTrue(#WN.lines >= 3 and #WN.lines <= 9, "fits the panel")
	expectTrue(tr(WN.title, "hu") ~= WN.title, "title HU")
	for _, line in WN.lines do
		expectTrue(#line.text <= 80, `short: {line.text}`)
		expectTrue(tr(line.text, "hu") ~= line.text, `HU: {line.text}`)
	end
end)

test("MEGA combo names (#270): every combo pair has a name in both languages", function()
	local Names = require("../src/shared/Config/ComboNames")
	local CN = require("../src/shared/Util/ComboName")
	local tr = require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	expectEq(CN.key("Tornado", "Flood"), "Flood+Tornado")
	expectEq(CN.get(Names, "MeteorShower", "FloorIsLava"), "Volcano Day")
	expectEq(CN.get(Names, "FloorIsLava", "MeteorShower"), "Volcano Day")
	for _, e in Events do
		for _, other in e.megaCombos do
			local name = CN.get(Names, e.id, other)
			expectTrue(name ~= nil, `{e.id}+{other} has a name`)
			if name then
				expectTrue(#name <= 26, `{name} fits the banner`)
				expectTrue(tr(name, "hu") ~= name, `{name} HU`)
			end
		end
	end
end)

-- #276: captions remain readable when rewards arrive together.
local CaptionQueue = require("../src/shared/Util/CaptionQueue")
local CaptionConfig = require("../src/shared/Config/AudioCaptions")
test("Caption queue: overlapping rewards retain reading time and FIFO order", function()
	local q = CaptionQueue.new(CaptionConfig, 2.5)
	expectEq(q.push("New title", "TitleUnlock", 0).text, "New title")
	expectEq(q.push("Hero", "HeroChime", 0).text, "New title")
	expectEq(q.push("Survived", "FinaleSurvived", 0).text, "New title")
	expectEq(q.tick(2.49).text, "New title")
	expectEq(q.tick(2.5).text, "Hero")
	expectEq(q.tick(5).text, "Survived")
	expectEq(q.tick(7.5), nil)
end)
test("Caption queue: danger preempts rewards and duplicates never extend it", function()
	local q = CaptionQueue.new(CaptionConfig, 2.5)
	q.push("Delivered", "Delivery", 0)
	expectEq(q.push("Tornado!", "TornadoWarning", 0.2).text, "Tornado!")
	expectEq(q.push("Tornado!", "TornadoWarning", 2).untilAt, 2.7)
	expectEq(q.tick(2.7), nil)
	q.push("Rush", "RushStart", 3)
	q.push("Rush", "RushDrum", 3)
	expectEq(q.pendingCount(), 0)
	expectEq(q.tick(5.5), nil)
end)
test("Caption queue: bounded overflow drops oldest lowest priority, keeps danger", function()
	local q = CaptionQueue.new(CaptionConfig, 2.5)
	q.push("Danger", "MegaWarning", 0)
	q.push("One", "TitleUnlock", 0)
	q.push("Two", "HeroChime", 0)
	q.push("Three", "FinaleSurvived", 0)
	expectEq(q.pendingCount(), 3)
	q.push("Quiet", "NightChirp", 0)
	expectEq(q.pendingCount(), 3)
	q.push("Golden", "GoldenJingle", 0)
	expectEq(q.pendingCount(), 3)
	expectEq(q.tick(2.5).text, "Golden")
	expectEq(q.tick(5).text, "Two")
	expectEq(q.tick(7.5).text, "Three")
end)
test("Caption queue: suspension expires pending work without replay, clear resets", function()
	local q = CaptionQueue.new(CaptionConfig, 2.5)
	q.push("A", "TitleUnlock", 0)
	q.push("B", "HeroChime", 0)
	expectEq(q.tick(100), nil)
	expectEq(q.pendingCount(), 0)
	expectEq(q.push("Fresh", "ErrandRing", 100).untilAt, 102.5)
	q.clear()
	expectEq(q.tick(100), nil)
	expectEq(q.pendingCount(), 0)
	expectEq(q.push("", nil, 100), nil)
end)
test("Caption queue: all event warnings have urgency and mass bursts stay capped", function()
	for _, event in Sounds.events do
		expectEq(
			CaptionConfig.priorities[event.warning],
			CaptionConfig.urgentPriority,
			event.warning
		)
	end
	local q = CaptionQueue.new(CaptionConfig, 2.5)
	for i = 1, 1000 do
		q.push(tostring(i), "TitleUnlock", 0)
		expectTrue(q.pendingCount() <= CaptionConfig.maxPending)
	end
	expectEq(q.tick(2.5).text, "998")
	expectEq(q.tick(5).text, "999")
	expectEq(q.tick(7.5).text, "1000")
	expectEq(q.tick(10), nil)
end)

-- #278: distinctive audio for the two new disasters.
test("Wind/lava audio: separate profiles, bilingual urgent warnings, bounded details", function()
	local strings = require("../src/shared/Config/Strings")
	for _, id in { "WindGust", "FloorIsLava" } do
		local profile = Sounds.events[id]
		expectTrue(profile.warning ~= "TornadoWarning" and profile.warning ~= "MeteorWarning")
		expectTrue(profile.ambience ~= "TornadoAmbience" and profile.ambience ~= "MeteorAmbience")
		expectEq(CaptionConfig.priorities[profile.warning], CaptionConfig.urgentPriority)
		for _, key in
			{ profile.warning, profile.ambience, Sounds.clips[profile.ambience].detail.cue }
		do
			local clip = Sounds.clips[key]
			expectEq(clip.channel, "sfx")
			expectTrue(clip.volume <= 0.3)
			if clip.caption then
				expectTrue(type(strings.hu[clip.caption]) == "string", key)
			end
		end
		expectTrue(Sounds.clips[profile.ambience].loop)
		expectTrue(Sounds.clips[profile.ambience].detail.stepSeconds >= 1)
	end
	expectTrue(Sounds.events.WindGust.warning ~= Sounds.events.FloorIsLava.warning)
end)
test("Wind/lava audio: warning, late join, MEGA and cleanup retain the existing plan", function()
	for _, id in { "WindGust", "FloorIsLava" } do
		local warning = EventAudioPlan.get(Sounds, { id = id, phase = "warning", endsAt = 10 })
		expectEq(warning.warning, Sounds.events[id].warning)
		expectEq(#warning.ambience, 0)
		local active = EventAudioPlan.get(Sounds, { id = id, phase = "active" })
		expectEq(active.ambience[1], Sounds.events[id].ambience)
		expectEq(active.warning, nil)
	end
	local mega = EventAudioPlan.get(
		Sounds,
		{ id = "WindGust", combo = "FloorIsLava", phase = "active", mega = true }
	)
	expectEq(#mega.ambience, 2)
	expectEq(mega.ambience[1], "GaleAmbience")
	expectEq(mega.ambience[2], "LavaAmbience")
	expectEq(mega.music, "Mega")
	for _, phase in { "windDown", "reset", "calm" } do
		local clean = EventAudioPlan.get(
			Sounds,
			{ id = "WindGust", combo = "FloorIsLava", phase = phase, mega = true }
		)
		expectEq(#clean.ambience, 0)
		expectEq(clean.music, nil)
	end
	expectEq(Sounds.maxAmbientVoices, 2)
	expectEq(Sounds.maxVoices, 12)
end)

-- #280: a permanent, non-economic exploration goal.
local RoutePassport = require("../src/shared/Util/RoutePassport")
local PassportConfig = require("../src/shared/Config/RoutePassport")
local RouteRegistry = RoutePassport.registry(MapLayout.buildings, PassportConfig)
test("Route passport: registry follows map addresses, deduplicates and is bounded", function()
	local count = 0
	for _, building in MapLayout.buildings do
		if building.address then
			expectTrue(RouteRegistry.known[building.address.id])
			count += 1
		end
	end
	expectEq(#RouteRegistry.ids, count)
	expectTrue(count > 0 and count <= PassportConfig.maxAddresses)
	local r = RoutePassport.registry({
		{ address = { id = "B" } },
		{ address = { id = "A" } },
		{ address = { id = "A" } },
		{},
		{ address = { id = "bad.id" } },
		{ address = { id = 1 } },
	}, PassportConfig)
	expectEq(#r.ids, 2)
	expectEq(r.ids[1], "A")
	expectEq(r.ids[2], "B")
end)
test("Route passport: first delivery stamps once without any reward or other mutation", function()
	local p = ProfileSchema.default()
	local tips, xp, deliveries = p.tips, p.xp, p.deliveries
	local first, second = RouteRegistry.ids[1], RouteRegistry.ids[2]
	expectTrue(RoutePassport.stamp(p, RouteRegistry, first, 100, PassportConfig))
	expectEq(RoutePassport.stamp(p, RouteRegistry, first, 200, PassportConfig), false)
	expectEq(p.claims[PassportConfig.claimPrefix .. first], 100)
	local count, total, nextId = RoutePassport.summary(p, RouteRegistry, PassportConfig)
	expectEq(count, 1)
	expectEq(total, #RouteRegistry.ids)
	expectEq(nextId, second)
	expectEq(p.tips, tips)
	expectEq(p.xp, xp)
	expectEq(p.deliveries, deliveries)
	expectEq(next(p.cosmetics.owned), nil)
end)
test("Route passport: malformed ids and stamps cannot inflate public progress", function()
	local p = ProfileSchema.default()
	for _, id in { "Unknown", "", 123, {} } do
		expectEq(RoutePassport.stamp(p, RouteRegistry, id, 100, PassportConfig), false)
	end
	local first = RouteRegistry.ids[1]
	for _, at in { 0, -1, 1.5, math.huge, 0 / 0, "now", {} } do
		expectEq(RoutePassport.stamp(p, RouteRegistry, first, at, PassportConfig), false)
	end
	p.claims[PassportConfig.claimPrefix .. "Unknown"] = 100
	p.claims[PassportConfig.claimPrefix .. first] = 0
	expectEq(RoutePassport.summary(p, RouteRegistry, PassportConfig), 0)
	expectTrue(RoutePassport.stamp(p, RouteRegistry, first, 100, PassportConfig))
	expectEq(RoutePassport.summary(p, RouteRegistry, PassportConfig), 1)
end)
test("Route passport: migration retains all stamps and completed album has no next", function()
	local p = ProfileSchema.default()
	p.claims["unrelated"] = 77
	for _, id in RouteRegistry.ids do
		expectTrue(RoutePassport.stamp(p, RouteRegistry, id, 100, PassportConfig))
	end
	local restored = ProfileSchema.migrate(p)
	local count, total, nextId = RoutePassport.summary(restored, RouteRegistry, PassportConfig)
	expectEq(count, #RouteRegistry.ids)
	expectEq(count, total)
	expectEq(nextId, nil)
	expectEq(restored.claims.unrelated, 77)
	expectEq(
		RoutePassport.stamp(restored, RouteRegistry, RouteRegistry.ids[1], 200, PassportConfig),
		false
	)
end)
test(
	"Route passport: profile rows respect selected courier, localization and incomplete attributes",
	function()
		local Activity = require("../src/client/Util/ProfileActivity")
		local cfg = require("../src/shared/Config/ProfileActivity")
		local function row(facts, language)
			for _, r in
				Activity.rows(facts, 0, 30, cfg.labels[language], function(n)
					return tostring(n)
				end)
			do
				if r.key == "RoutePassport" then
					return r.text
				end
			end
			return nil
		end
		expectEq(
			row({ stamps = 3, totalRoutes = 24 }, "en"),
			"City passport\n3 / 24 addresses stamped"
		)
		expectEq(
			row({ stamps = 9, totalRoutes = 24 }, "hu"),
			"Városi futárútlevél\n9 / 24 cím bejárva"
		)
		expectEq(
			row({ stamps = 0, totalRoutes = 24 }, "hu"),
			"Városi futárútlevél\n0 / 24 cím bejárva"
		)
		for _, facts in
			{
				{},
				{ stamps = 25, totalRoutes = 24 },
				{ stamps = 1, totalRoutes = 0 },
				{ stamps = 0 / 0, totalRoutes = 24 },
				{ stamps = 1.5, totalRoutes = 24 },
			}
		do
			expectEq(row(facts, "en"), nil)
		end
	end
)

-- #284: completing the passport earns a cosmetic title, never an advantage.
test("Passport title: only a nonempty complete album earns it, once", function()
	local p = ProfileSchema.default()
	expectEq(RoutePassport.award(p, RouteRegistry, PassportConfig), false)
	for i, id in RouteRegistry.ids do
		RoutePassport.stamp(p, RouteRegistry, id, 100, PassportConfig)
		if i < #RouteRegistry.ids then
			expectEq(RoutePassport.award(p, RouteRegistry, PassportConfig), false)
		end
	end
	local tips, xp, movement = p.tips, p.xp, p.movementTier
	p.cosmetics.equipped.title = "ExistingChoice"
	expectTrue(RoutePassport.award(p, RouteRegistry, PassportConfig))
	expectEq(p.cosmetics.owned[PassportConfig.rewardId], true)
	expectEq(RoutePassport.award(p, RouteRegistry, PassportConfig), false)
	expectEq(p.tips, tips)
	expectEq(p.xp, xp)
	expectEq(p.movementTier, movement)
	expectEq(p.cosmetics.equipped.title, "ExistingChoice", "do not auto-equip")
	local empty = RoutePassport.registry({}, PassportConfig)
	expectEq(RoutePassport.award(ProfileSchema.default(), empty, PassportConfig), false)
end)
test("Passport title: cannot buy or equip early, can equip after the real grant", function()
	local cfg = require("../src/shared/Config/Cosmetics")
	local api = require("../src/shared/Util/Cosmetics").new(cfg)
	local p = ProfileSchema.default()
	p.tips = 99999
	expectEq(api.canBuy(PassportConfig.rewardId), false)
	expectEq(api.buy(p, PassportConfig.rewardId), false)
	expectEq(api.equip(p, PassportConfig.rewardId), false)
	for _, id in RouteRegistry.ids do
		RoutePassport.stamp(p, RouteRegistry, id, 100, PassportConfig)
	end
	expectTrue(RoutePassport.award(p, RouteRegistry, PassportConfig))
	expectTrue(api.equip(p, PassportConfig.rewardId))
	expectEq(p.cosmetics.equipped.title, PassportConfig.rewardId)
	expectEq(p.tips, 99999)
	expectEq(api.get(PassportConfig.rewardId).slot, "title")
end)
test(
	"Passport title: old completed ledger grants on reconciliation, migration never re-awards",
	function()
		local p = ProfileSchema.default()
		for _, id in RouteRegistry.ids do
			RoutePassport.stamp(p, RouteRegistry, id, 100, PassportConfig)
		end
		local old = ProfileSchema.migrate(p)
		expectTrue(RoutePassport.canAward(old, RouteRegistry, PassportConfig))
		expectTrue(RoutePassport.award(old, RouteRegistry, PassportConfig))
		local restored = ProfileSchema.migrate(old)
		expectEq(RoutePassport.canAward(restored, RouteRegistry, PassportConfig), false)
		expectEq(RoutePassport.award(restored, RouteRegistry, PassportConfig), false)
		local expanded =
			RoutePassport.registry({ { address = { id = "NewStreet" } } }, PassportConfig)
		expectEq(RoutePassport.award(restored, expanded, PassportConfig), false)
		expectEq(
			restored.cosmetics.owned[PassportConfig.rewardId],
			true,
			"keep earned title after map expansion"
		)
	end
)
test("Passport title: translated unlock hint and existing authoritative title audio", function()
	local cfg = require("../src/shared/Config/Cosmetics")
	local tr = require("../src/shared/Util/Localize").new(require("../src/shared/Config/Strings"))
	expectTrue(tr("City Explorer", "hu") ~= "City Explorer")
	expectTrue(
		tr(cfg.unlockHints[PassportConfig.rewardId], "hu")
			~= cfg.unlockHints[PassportConfig.rewardId]
	)
	expectTrue(tr(PassportConfig.unlockMessage, "hu") ~= PassportConfig.unlockMessage)
	expectEq(BatchAudio.hint(PassportConfig.unlockMessage, BatchAudioConfig), "TitleUnlock")
end)

-- #286: budgets follow the actual new-event geometry, not the broad fallback.
test("Wind/lava perf: benchmark allowlist and strict anchored geometry budgets", function()
	local cfg = require("../src/shared/Config/Perf")
	expectEq(cfg.localEventRoots.LocalWind, "WindGust")
	expectEq(cfg.localEventRoots.LocalLava, "FloorIsLava")
	local tuning = require("../src/shared/Config/Tuning")
	for _, id in { "WindGust", "FloorIsLava" } do
		expectEq(cfg.benchmarkEvents[id], true)
		expectEq(cfg.eventBudgets[id].unanchoredParts, 0)
		expectEq(cfg.eventBudgets[id].enabledEmitters, 0)
		expectTrue(cfg.eventBudgets[id].parts < cfg.eventBudget.parts)
	end
	expectEq(cfg.benchmarkEvents.Unknown, nil)
	expectTrue(cfg.eventBudgets.WindGust.parts >= tuning.WindGust.streaks)
	local LF = require("../src/shared/Util/LavaFloor")
	local geometry = require("../src/shared/Util/MapGeometry")
	local keep = LF.keepClear(MapLayout, function(b)
		local point = geometry.doorPoint(b, MapLayout.streetY)
		return { x = point.x, z = point.z }
	end)
	local tiles = LF.tiles(MapLayout.streets, keep, tuning.FloorIsLava)
	local wave = LF.pickWave(#tiles, tuning.FloorIsLava, function(first)
		return first
	end)
	expectEq(#wave, 62, "current authored map baseline")
	expectTrue(cfg.eventBudgets.FloorIsLava.parts >= #wave)
end)
test("Wind/lava perf: exact geometry budget boundary and one extra part warn", function()
	local cfg = require("../src/shared/Config/Perf")
	for _, id in { "WindGust", "FloorIsLava" } do
		local budget = cfg.eventBudgets[id]
		local metrics = PerfMetrics.empty()
		for _ = 1, budget.parts do
			PerfMetrics.add(metrics, { part = true, anchored = true })
		end
		expectEq(#PerfMetrics.overBudget(metrics, budget), 0, id)
		PerfMetrics.add(metrics, { part = true, anchored = true })
		expectTrue(#PerfMetrics.overBudget(metrics, budget) > 0, id)
	end
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed")
end
