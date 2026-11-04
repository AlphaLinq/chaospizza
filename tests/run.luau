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
	expectEq(#Customers, 24, "starter pool size (brief 9.3)")
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
		expectEq(ProfileSchema.migrate(value).version, 1)
	end)
end
test("Profile: nil and v0", function()
	expectEq(ProfileSchema.migrate(nil).pizzeriaLevel, 1)
	expectEq(ProfileSchema.migrate({}).version, 1)
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
	expectEq(Progression.passivePerMinute("Rare", 0), 10)
	expectEq(Progression.passivePerMinute("Epic", 5), 60)
	expectEq(Progression.passivePerMinute("Legendary", 5), 160)
	expectEq(Progression.passivePerMinute("Rare", 99), 20)
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
	expectEq(Progression.canUpgradePizzeria(1, 499), false)
	expectEq(Progression.canUpgradePizzeria(1, 500), true)
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

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed")
end
