--!strict
-- Customer quirks (#139). Collects the server facts a quirk needs (position
-- history for "stand still" and "come from the Plaza", nearby couriers, style
-- tags, event state) and checks them with the pure Util/CustomerQuirks. The
-- client never reports whether a request was met.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local QuirkConfig = require(ReplicatedStorage.Shared.Config.CustomerQuirks)
local CustomerQuirks = require(ReplicatedStorage.Shared.Util.CustomerQuirks)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local EventService = require(script.Parent.EventService)

export type Result = { met: boolean, title: string, request: string, tipMultiplier: number }

type Sample = { t: number, pos: Vector3 }

local QuirkService = {}

local Quirks = CustomerQuirks.new(QuirkConfig :: any)
local history: { [Player]: { Sample } } = {}
local forced: { [Player]: boolean } = {} -- debug: next check passes/fails

local zones: { [string]: { minX: number, maxX: number, minZ: number, maxZ: number } } = {}
for _, street in MapLayout.streets do
	zones[street.name] = {
		minX = street.x - street.sx / 2,
		maxX = street.x + street.sx / 2,
		minZ = street.z - street.sz / 2,
		maxZ = street.z + street.sz / 2,
	}
end

local function inZone(name: string, pos: Vector3): boolean
	local z = zones[name]
	return z ~= nil and pos.X >= z.minX and pos.X <= z.maxX and pos.Z >= z.minZ and pos.Z <= z.maxZ
end

function QuirkService.describe(customerId: string): CustomerQuirks.Description?
	return Quirks.describe(customerId)
end

local function stillSeconds(samples: { Sample }, now: number, current: Vector3): number
	local oldest = now
	for i = #samples, 1, -1 do
		local s = samples[i]
		if (s.pos - current).Magnitude > QuirkConfig.stillToleranceStuds then
			break
		end
		oldest = s.t
	end
	return now - oldest
end

local function secondsSinceZone(samples: { Sample }, now: number, zone: string): number?
	for i = #samples, 1, -1 do
		if inZone(zone, samples[i].pos) then
			return now - samples[i].t
		end
	end
	return nil
end

local function nearestOther(player: Player, pos: Vector3): number?
	local best: number? = nil
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local root = CharacterService.getRootPart(other)
			if root then
				local d = (root.Position - pos).Magnitude
				if best == nil or d < best then
					best = d
				end
			end
		end
	end
	return best
end

-- Facts for one delivery; `tags` are the style tag ids already evaluated.
function QuirkService.facts(
	player: Player,
	customerId: string,
	tags: { string }
): CustomerQuirks.Facts
	local now = os.clock()
	local samples = history[player] or {}
	local root = CharacterService.getRootPart(player)
	local pos = if root then root.Position else Vector3.zero
	local def = QuirkConfig.quirks[customerId]
	return {
		nearestOtherCourier = nearestOther(player, pos),
		stillSeconds = if root then stillSeconds(samples, now, pos) else 0,
		tags = tags,
		secondsSinceZone = if def and def.zone
			then secondsSinceZone(samples, now, def.zone)
			else nil,
		duringEvent = EventService.isHazardActive(),
	}
end

-- nil when the customer has no quirk; otherwise whether it was met.
function QuirkService.evaluate(player: Player, customerId: string, tags: { string }): Result?
	local description = Quirks.describe(customerId)
	if not description then
		return nil
	end
	local met = Quirks.check(customerId, QuirkService.facts(player, customerId, tags))
	local force = forced[player]
	if force ~= nil then
		forced[player] = nil
		met = force
	end
	return {
		met = met,
		title = description.title,
		request = description.request,
		tipMultiplier = if met then description.tipMultiplier else 1,
	}
end

local function sample()
	local now = os.clock()
	local cutoff = now - QuirkConfig.historySeconds
	for _, player in Players:GetPlayers() do
		local root = CharacterService.getRootPart(player)
		local list = history[player]
		if not list then
			list = {}
			history[player] = list
		end
		if root then
			table.insert(list, { t = now, pos = root.Position })
		end
		while #list > 0 and list[1].t < cutoff do
			table.remove(list, 1)
		end
	end
end

function QuirkService.init()
	DebugService.register(
		"quirk",
		"Customer quirks: list, show facts, force the next result",
		"quirk [list|facts <CustomerId>|pass|fail|clear]",
		function(player, args)
			local sub = args[1]
			if sub == "pass" or sub == "fail" then
				forced[player] = sub == "pass"
				return true, `next quirk check forced to {sub}`
			elseif sub == "clear" then
				forced[player] = nil
				history[player] = nil
				return true, "quirk state cleared"
			elseif sub == "facts" then
				local id = args[2] or "StatueMan"
				local f = QuirkService.facts(player, id, {})
				return true,
					`{id}: still={string.format("%.1f", f.stillSeconds)}s other={if f.nearestOtherCourier
						then math.floor(f.nearestOtherCourier)
						else "none"} zone={if f.secondsSinceZone
						then string.format("%.1f", f.secondsSinceZone)
						else "none"} event={f.duringEvent} met={Quirks.check(id, f)}`
			end
			local parts = {}
			for _, id in Quirks.ids() do
				local d = Quirks.describe(id)
				if d then
					table.insert(parts, `{id}: {d.request}`)
				end
			end
			return true, table.concat(parts, " | ")
		end
	)
end

function QuirkService.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= QuirkConfig.sampleSeconds then
			elapsed = 0
			sample()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		history[player] = nil
		forced[player] = nil
	end)
end

return QuirkService
