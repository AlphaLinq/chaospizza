--!strict
-- Event: UFO Abduction (#183). Saucers loop the city (MapLayout.ufoRoutes);
-- every few seconds a UFO's beam flickers (warning) and then shines. A
-- courier inside a shining beam is abducted: carried up (client lift), then
-- dropped elsewhere — a safe spot, or sometimes right next to the door of
-- their current order. Couriers who deliver soon after landing get the
-- "Abducted" style tag. The flight counts as travel time for the order.
--
-- CityState "Ufos": JSON list { id, route, t0, offset }; positions and beam
-- timing come from the shared Util/Ufo. Player attribute "Abducted" = the
-- UFO id while being carried up.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local RoutePath = require(ReplicatedStorage.Shared.Util.RoutePath)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ufo = require(ReplicatedStorage.Shared.Util.Ufo)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local KnockbackService = require(Services.KnockbackService)
local MapService = require(Services.MapService)
local OrderService = require(Services.OrderService)
local StyleService = require(Services.StyleService)

local UfoAbduction = {
	id = "UfoAbduction",
	buildUpSeconds = 3,
}

function UfoAbduction.warning(ctx: any)
	ctx.announce(
		"🛸 Strange lights in the sky… UFOs! Stay out of the green beams — or don't?"
	)
end

local function dropPoint(player: Player, rng: Random): Vector3
	local order = OrderService.getOrder(player)
	if order and rng:NextNumber() < Tuning.Ufo.dropAtDoorChance then
		local address = MapService.getAddress(order.addressId)
		if address then
			local door = OrderService.deliveryPoint(address)
			return door + Vector3.new(rng:NextNumber(-6, 6), 3, rng:NextNumber(-6, 6))
		end
	end
	local spots = MapLayout.safeSpots
	local s = spots[rng:NextInteger(1, #spots)]
	return Vector3.new(s.x, MapLayout.streetY + 4, s.z)
end

function UfoAbduction.active(ctx: any)
	local rng: Random = ctx.rng
	local cfg = Tuning.Ufo
	local now0 = Workspace:GetServerTimeNow()
	local saucers: { Ufo.Saucer } = {}
	for i = 1, math.min(cfg.count, #MapLayout.ufoRoutes) do
		table.insert(saucers, { id = i, route = i, t0 = now0, offset = rng:NextNumber() })
	end
	local list = {}
	for _, s in saucers do
		table.insert(list, { id = s.id, route = s.route, t0 = s.t0, offset = s.offset })
	end
	ctx.setState("Ufos", HttpService:JSONEncode(list))

	local lastAbduction: { [Player]: number } = {}
	local carrying: { [Player]: boolean } = {}

	local function abduct(player: Player, saucer: Ufo.Saucer)
		carrying[player] = true
		lastAbduction[player] = os.clock()
		player:SetAttribute("Abducted", saucer.id)
		Net.event("Hint"):FireClient(player, "🛸 You've been ABDUCTED! Hold on to the pizza…")
		task.delay(cfg.liftSeconds, function()
			carrying[player] = nil
			player:SetAttribute("Abducted", nil)
			if not player.Parent or not ctx.isRunning() then
				return
			end
			local root = CharacterService.getRootPart(player)
			if not root then
				return
			end
			local from = root.Position
			local to = dropPoint(player, rng)
			-- Drop with a soft downward push; the owner's client starts at `to`.
			if not KnockbackService.launch(player, Vector3.new(0, -5, 0), "Ufo", 0.6, 50, to) then
				CharacterService.teleport(player, to) -- protected right now: plain drop
			end
			KnockbackService.protect(player, cfg.dropProtectSeconds)
			StyleService.markHazard(player, "ufo")
			local flat = ((to - from) * Vector3.new(1, 0, 1)).Magnitude
			local fastest = Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
			OrderService.creditTravel(player, flat / fastest * Tuning.Orders.minTravelTimeFactor)
		end)
	end

	local elapsed = 0
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		if ctx.phase() ~= "active" then
			return
		end
		local now = Workspace:GetServerTimeNow()
		for _, saucer in saucers do
			if Ufo.beam(saucer, now, cfg :: any) ~= "on" then
				continue
			end
			local route = MapLayout.ufoRoutes[saucer.route] :: any
			local x, z = Ufo.position(RoutePath :: any, route, saucer, now, cfg :: any)
			for _, player in Players:GetPlayers() do
				if
					carrying[player]
					or os.clock() - (lastAbduction[player] or -math.huge) < cfg.cooldownSeconds
				then
					continue
				end
				if player:GetAttribute("Knocked") then
					continue
				end
				local root = CharacterService.getRootPart(player)
				if root then
					local dx, dz = root.Position.X - x, root.Position.Z - z
					if
						dx * dx + dz * dz <= cfg.beamRadius * cfg.beamRadius
						and root.Position.Y < cfg.height - 4
					then
						abduct(player, saucer)
					end
				end
			end
		end
	end)
	ctx.track(heartbeat)
	while ctx.phase() == "active" and ctx.isRunning() do
		task.wait(0.2)
	end
end

function UfoAbduction.windDown(ctx: any)
	ctx.announce("🛸 The UFOs zoom off. They took notes on our pizza.")
end

function UfoAbduction.cleanup(ctx: any)
	ctx.setState("Ufos", nil)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Abducted", nil)
	end
end

return UfoAbduction
