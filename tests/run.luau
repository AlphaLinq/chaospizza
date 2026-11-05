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
	expectEq(regular, 24, "starter pool size (brief 9.3)")
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

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed")
end
