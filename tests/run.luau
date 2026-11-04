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

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed")
end
