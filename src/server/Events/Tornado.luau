--!strict
-- Event: Tornado (brief 1.0 ch. 11).
-- A funnel travels along one of the predefined routes (MapLayout.tornadoRoutes).
--   * outer zone: the owner's client pulls the courier gently toward the funnel
--     (CityState attribute TornadoPos / TornadoRadius drives it)
--   * inner zone: the server launches the courier on a ballistic arc to a
--     checked landing spot (never off the map, never an endless spin)
--   * shelter: standing under a door awning protects you
-- The order is kept; the box stays welded to the courier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local KnockbackService = require(Services.KnockbackService)
local MapService = require(Services.MapService)

local SPEED = 14 -- studs/s along the route
local INNER_RADIUS = 9
local OUTER_RADIUS = 30
local SHELTER_RADIUS = 6
local FLIGHT_SECONDS = 2.0
local LIFT_COOLDOWN = 6 -- per player, on top of hit protection
local POS_PUBLISH_SECONDS = 0.1 -- TornadoPos replication rate (clients interpolate)

local Tornado = {
	id = "Tornado",
	buildUpSeconds = 4,
}

local function routePoint(route: { { x: number, z: number } }, distance: number): (Vector3, boolean)
	local travelled = 0
	for i = 1, #route - 1 do
		local a, b = route[i], route[i + 1]
		local segment = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		if travelled + segment >= distance then
			local t = (distance - travelled) / segment
			return Vector3.new(a.x + (b.x - a.x) * t, 0.4, a.z + (b.z - a.z) * t), false
		end
		travelled += segment
	end
	local last = route[#route]
	return Vector3.new(last.x, 0.4, last.z), true
end

local function isSheltered(position: Vector3): boolean
	for _, address in MapService.getAddresses() do
		if (address.doorPosition - position).Magnitude < SHELTER_RADIUS then
			return true
		end
	end
	return false
end

-- Landing spot: the safe spot whose direction best matches the launch
-- direction, at least 40 studs away. Always a checked, open position.
local function landingFor(from: Vector3, away: Vector3): Vector3
	local best, bestScore = MapService.getSpawnPosition(), -math.huge
	for _, spot in MapService.getSafeSpots() do
		local offset = Vector3.new(spot.X - from.X, 0, spot.Z - from.Z)
		local distance = offset.Magnitude
		if distance > 40 then
			local score = offset.Unit:Dot(away) * 100 - distance * 0.2
			if score > bestScore then
				best, bestScore = spot, score
			end
		end
	end
	return best
end

local function ballistic(from: Vector3, to: Vector3, seconds: number): Vector3
	local g = Workspace.Gravity
	local horizontal = Vector3.new(to.X - from.X, 0, to.Z - from.Z) / seconds
	local vy = (to.Y - from.Y) / seconds + 0.5 * g * seconds
	return horizontal + Vector3.new(0, vy, 0)
end

function Tornado.warning(ctx: any)
	ctx.announce("🌪️ TORNADO WARNING near Fountain Square! Hide under a door awning!")
end

function Tornado.active(ctx: any)
	local rng: Random = ctx.rng
	local routes = MapLayout.tornadoRoutes
	local route = routes[rng:NextInteger(1, #routes)]
	-- The funnel is drawn by every client from TornadoPos (EventFxController);
	-- the server only moves the centre and decides the launches.
	local distance = 0
	local lastPublish = 0
	local lastLift: { [Player]: number } = {}
	local finished = false

	ctx.setState("TornadoRadius", OUTER_RADIUS)

	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		if finished or ctx.phase() ~= "active" then
			return
		end
		distance += SPEED * dt
		local center, atEnd = routePoint(route, distance)
		if atEnd then
			-- Loop back along the route so it stays busy until the phase ends.
			distance = 0
		end
		local now = os.clock()
		if now - lastPublish >= POS_PUBLISH_SECONDS then
			lastPublish = now
			ctx.setState("TornadoPos", center)
		end

		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if root then
				local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
				if flat.Magnitude < INNER_RADIUS and root.Position.Y < 30 then
					if
						now - (lastLift[player] or -math.huge) > LIFT_COOLDOWN
						and not isSheltered(root.Position)
					then
						local away = if flat.Magnitude > 0.1
							then flat.Unit
							else Vector3.new(1, 0, 0)
						local landing = landingFor(root.Position, away)
						local velocity = ballistic(root.Position, landing, FLIGHT_SECONDS)
						if
							KnockbackService.hit(
								player,
								velocity,
								"Tornado",
								FLIGHT_SECONDS + 0.2,
								400
							)
						then
							lastLift[player] = now
						end
					end
				end
			end
		end
	end)
	ctx.track(heartbeat)
	ctx.track(function()
		finished = true
		ctx.setState("TornadoPos", nil)
		ctx.setState("TornadoRadius", nil)
	end)

	while ctx.phase() == "active" and ctx.isRunning() do
		task.wait(0.2)
	end
end

function Tornado.windDown(ctx: any)
	ctx.announce("🌤️ The tornado is gone. The pizza survived. Probably.")
	ctx.setState("TornadoPos", nil)
	ctx.setState("TornadoRadius", nil)
end

return Tornado
