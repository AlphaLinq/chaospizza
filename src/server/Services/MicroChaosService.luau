--!strict
-- Micro-chaos (#187, docs/GAMEPLAY_LOOP.md G3). During the calm, every
-- Tuning.MicroChaos.minGap..maxGap seconds a small local surprise happens on
-- a random street, with no banner and no effect on the event schedule:
--   Cart      — a runaway shopping cart rolls down the street, bumps couriers;
--   Geese     — a line of geese waddles along, honking and bumping;
--   Sprinkler — a puddle bubbles, then a geyser launches whoever stands on
--               it (a free "Air delivery" chance);
--   Boxes     — a stack of pizza boxes tumbles over: grab them for tips.
-- Bumps are launches, not accidents (KnockbackService.launch): streaks and
-- fragile cakes survive. The server decides hits and pickups.
--
-- Replication: CityState "MicroChaos" = JSON { id, kind, t0, ... } (server
-- time); MicroChaosController draws it.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local MicroChaos = require(ReplicatedStorage.Shared.Util.MicroChaos)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local KnockbackService = require(script.Parent.KnockbackService)

local MicroChaosService = {}

type Point = MicroChaos.Point
type Active = {
	id: number,
	kind: string,
	t0: number, -- server time
	endsAt: number, -- server time
	data: { [string]: any },
	taken: { [number]: boolean },
}

local cfg = Tuning.MicroChaos
local kinds = cfg.kinds
local streets: { [string]: MicroChaos.Rect } = {}
for _, s in MapLayout.streets do
	streets[s.name] = { x = s.x, z = s.z, sx = s.sx, sz = s.sz }
end

local active: Active? = nil
local nextId = 0
local nextAt = os.clock() + cfg.firstDelaySeconds
local lastBump: { [Player]: number } = {}

local function rng(): number
	return math.random()
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function cityState(): Instance
	return ReplicatedStorage:WaitForChild("CityState")
end

local function publish()
	local a = active
	if not a then
		cityState():SetAttribute("MicroChaos", nil)
		return
	end
	local data = table.clone(a.data)
	data.id = a.id
	data.kind = a.kind
	data.t0 = a.t0
	data.endsAt = a.endsAt
	local taken = {}
	for i in a.taken do
		table.insert(taken, i)
	end
	data.taken = taken
	cityState():SetAttribute("MicroChaos", HttpService:JSONEncode(data))
end

local function stop()
	if active then
		active = nil
		publish()
	end
end

local function randomStreet(): MicroChaos.Rect
	local name = cfg.streets[math.random(1, #cfg.streets)]
	return streets[name]
end

-- Builds the surprise of `kind`; `near` (debug) puts it next to a courier.
local function build(kind: string, near: Point?): { [string]: any }?
	local def = kinds[kind]
	if not def then
		return nil
	end
	if kind == "Cart" or kind == "Geese" then
		local from, to
		if near then
			from = { x = near.x - def.length / 2, z = near.z }
			to = { x = near.x + def.length / 2, z = near.z }
		else
			from, to = MicroChaos.path(randomStreet(), def.length, cfg.edgeMargin, cfg.avoid, rng)
		end
		if not from or not to then
			return nil
		end
		local tail = if kind == "Geese" then (def.count - 1) * def.spacing else 0
		return {
			from = from,
			to = to,
			speed = def.speed,
			count = def.count or 1,
			spacing = def.spacing or 0,
			duration = MicroChaos.duration(from, to, def.speed, tail),
		}
	end
	local spot = near or MicroChaos.spot(randomStreet(), cfg.edgeMargin, cfg.avoid, rng)
	if not spot then
		return nil
	end
	if kind == "Sprinkler" then
		return {
			spot = spot,
			warn = def.warnSeconds,
			duration = def.warnSeconds + def.activeSeconds,
			radius = def.radius,
		}
	end
	return {
		spot = spot,
		boxes = MicroChaos.scatter(spot, def.count, def.spread, rng),
		duration = def.lifeSeconds,
	}
end

function MicroChaosService.spawn(kind: string?, near: Point?): (boolean, string)
	if active then
		return false, "a micro-chaos is already running"
	end
	local chosen = kind or MicroChaos.pickKind(kinds, rng)
	local data = build(chosen, near)
	if not data then
		return false, `could not place {chosen}`
	end
	nextId += 1
	local t = now()
	active = {
		id = nextId,
		kind = chosen,
		t0 = t,
		endsAt = t + data.duration,
		data = data,
		taken = {},
	}
	publish()
	-- #202: who was close enough to notice it.
	local at = data.spot or data.from
	for _, player in Players:GetPlayers() do
		local root = CharacterService.getRootPart(player)
		if
			root
			and MicroChaos.near({ x = root.Position.X, z = root.Position.Z }, at, cfg.seenStuds)
		then
			AnalyticsService.custom(player, `micro_seen_{chosen}`)
		end
	end
	return true,
		`{chosen} at {math.floor((data.spot or data.from).x)},{math.floor(
			(data.spot or data.from).z
		)}`
end

local function bump(player: Player, velocity: Vector3, source: string, flight: number)
	local t = os.clock()
	if t - (lastBump[player] or -math.huge) < cfg.hitCooldownSeconds then
		return
	end
	if player:GetAttribute("Knocked") or KnockbackService.isProtected(player) then
		return
	end
	if KnockbackService.launch(player, velocity, source, flight) then
		lastBump[player] = t
		AnalyticsService.custom(player, `micro_bump_{source}`) -- #202
	end
end

local function step()
	local a = active
	if not a then
		return
	end
	local t = now()
	if t >= a.endsAt then
		stop()
		return
	end
	local def = kinds[a.kind]
	local d = a.data
	for _, player in Players:GetPlayers() do
		local root = CharacterService.getRootPart(player)
		if not root or root.Position.Y > MapLayout.streetY + 8 then
			continue -- on the overpass or flying: out of reach
		end
		local p = { x = root.Position.X, z = root.Position.Z }
		if a.kind == "Cart" or a.kind == "Geese" then
			for i = 1, d.count do
				local at = MicroChaos.moverAt(d.from, d.to, a.t0, d.speed, t, (i - 1) * d.spacing)
				if at and MicroChaos.near(p, at, def.radius) then
					local dir = Vector3.new(d.to.x - d.from.x, 0, d.to.z - d.from.z).Unit
					if a.kind == "Geese" then
						-- geese shove you sideways, out of their way
						local side = Vector3.new(-dir.Z, 0, dir.X)
						local away = Vector3.new(p.x - at.x, 0, p.z - at.z)
						dir = if side:Dot(away) >= 0 then side else -side
					end
					bump(player, dir * def.push + Vector3.new(0, def.lift, 0), a.kind, 0.8)
					break
				end
			end
		elseif a.kind == "Sprinkler" then
			if t >= a.t0 + d.warn and MicroChaos.near(p, d.spot, def.radius) then
				bump(player, Vector3.new(0, def.launch, 0), "Sprinkler", def.flightSeconds)
			end
		elseif a.kind == "Boxes" then
			for i, box in d.boxes do
				if not a.taken[i] and MicroChaos.near(p, box, def.radius) then
					a.taken[i] = true
					EconomyService.addTips(player, def.tips, "micro_boxes")
					AnalyticsService.custom(player, "micro_box")
					Net.event("Hint"):FireClient(player, `📦 Free pizza box! +{def.tips} tips`)
					publish()
				end
			end
		end
	end
	if a.kind == "Boxes" then
		local left = 0
		for i in d.boxes do
			if not a.taken[i] then
				left += 1
			end
		end
		if left == 0 then
			stop()
		end
	end
end

function MicroChaosService.getActive(): string?
	local a = active
	return if a then a.kind else nil
end

function MicroChaosService.init()
	DebugService.register(
		"micro",
		"Micro-chaos: spawn one (random street, or 'here' next to you), stop",
		"micro [cart|geese|sprinkler|boxes|random] [here] | micro stop",
		function(player, args)
			local sub = string.lower(args[1] or "random")
			if sub == "stop" then
				stop()
				return true, "stopped"
			end
			local map = { cart = "Cart", geese = "Geese", sprinkler = "Sprinkler", boxes = "Boxes" }
			local kind = map[sub]
			if sub ~= "random" and not kind then
				return false, "usage: micro [cart|geese|sprinkler|boxes|random] [here] | micro stop"
			end
			local near: Point? = nil
			if args[2] == "here" then
				local root = CharacterService.getRootPart(player)
				if root then
					near = { x = root.Position.X, z = root.Position.Z }
				end
			end
			stop()
			return MicroChaosService.spawn(kind, near)
		end
	)
end

function MicroChaosService.start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			step()
			-- New surprises only in the calm; an event pauses the timer.
			local phase = EventService.getPhase()
			if phase ~= "calm" then
				nextAt = math.max(nextAt, os.clock() + cfg.firstDelaySeconds)
			elseif not active and os.clock() >= nextAt and #Players:GetPlayers() > 0 then
				MicroChaosService.spawn()
				nextAt = os.clock() + MicroChaos.gap(cfg.minGapSeconds, cfg.maxGapSeconds, rng)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBump[player] = nil
	end)
end

return MicroChaosService
