--!strict
-- Event: Runaway Cheese Wheel (#140).
-- A giant wheel of cheese rolls along a street route (MapLayout.cheeseRoutes),
-- turning at the corners. Before each run the route glows yellow. Get hit and
-- you are knocked over; jump over it for the "Cheese jump" style tag. Chunks
-- fall off as it rolls; walking over one gives a few tips (server-side, once).
--
-- The wheel itself is data only: CityState "CheeseWheel" (JSON: id, route, t0,
-- speed) — every client animates it (CheeseWheelController). The server hit
-- test uses the same RoutePath formula.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Net = require(ReplicatedStorage.Shared.Net)
local RoutePath = require(ReplicatedStorage.Shared.Util.RoutePath)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local EconomyService = require(Services.EconomyService)
local KnockbackService = require(Services.KnockbackService)
local StyleService = require(Services.StyleService)

local GROUND_Y = 0.4
local CHUNK_TAG = "CheeseChunk"

local CheeseWheel = {
	id = "CheeseWheel",
	buildUpSeconds = 3,
}

type Chunk = { part: BasePart, expiresAt: number }

local function strip(parent: Instance, a: RoutePath.Point, b: RoutePath.Point, width: number): Part
	local from = Vector3.new(a.x, GROUND_Y + 0.12, a.z)
	local to = Vector3.new(b.x, GROUND_Y + 0.12, b.z)
	local p = Instance.new("Part")
	p.Name = "CheeseWarning"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromHex("#F2C14E")
	p.Transparency = 1
	p.Size = Vector3.new(width, 0.15, (to - from).Magnitude + width)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = parent
	return p
end

local function makeChunk(parent: Instance, position: Vector3, rng: Random): BasePart
	local p = Instance.new("WedgePart")
	p.Name = "CheeseChunk"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.new(1.4, 1.1, 1.8)
	p.Color = Color3.fromHex("#F7C948")
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = CFrame.new(position + Vector3.new(0, 0.55, 0))
		* CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	CollectionService:AddTag(p, CHUNK_TAG)
	p.Parent = parent
	return p
end

function CheeseWheel.warning(ctx: any)
	ctx.announce("🧀 A GIANT CHEESE WHEEL broke loose! Watch the yellow streets — or jump it!")
end

function CheeseWheel.active(ctx: any)
	local rng: Random = ctx.rng
	local cfg = Tuning.CheeseWheel
	local radius = cfg.diameter / 2
	local chunks: { Chunk } = {}

	type Run = { id: number, route: { RoutePath.Point }, t0: number, length: number }
	local run: Run? = nil
	local nextId = 0
	local jumped: { [Player]: number } = {} -- run id already credited
	local lastChunkAt = 0

	local function publish()
		if run then
			local points = {}
			for _, p in run.route do
				table.insert(points, { p.x, p.z })
			end
			ctx.setState(
				"CheeseWheel",
				HttpService:JSONEncode({
					id = run.id,
					route = points,
					t0 = run.t0,
					speed = cfg.speed,
					diameter = cfg.diameter,
					thickness = cfg.thickness,
				})
			)
		else
			ctx.setState("CheeseWheel", nil)
		end
	end

	local function grantChunk(player: Player, index: number)
		local chunk = table.remove(chunks, index)
		if not chunk then
			return
		end
		chunk.part:Destroy() -- removed first: one chunk pays once
		if EconomyService.addTips(player, cfg.chunkTips, "cheese") then
			Net.event("Hint"):FireClient(player, `🧀 +{cfg.chunkTips} cheese chunk!`)
		end
	end

	local heartbeat = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local clock = os.clock()
		-- Expire old chunks
		for i = #chunks, 1, -1 do
			if clock > chunks[i].expiresAt then
				chunks[i].part:Destroy()
				table.remove(chunks, i)
			end
		end
		local current = run
		local wx, wz, hx, hz, done = 0, 0, 1, 0, true
		if current then
			wx, wz, hx, hz, done = RoutePath.sample(current.route, cfg.speed * (now - current.t0))
			if now < current.t0 then
				done = true -- still telegraphing
			end
			if
				not done
				and clock - lastChunkAt >= cfg.chunkEverySeconds
				and #chunks < cfg.chunkMax
			then
				lastChunkAt = clock
				local side = (if rng:NextNumber() < 0.5 then -1 else 1) * (3 + rng:NextNumber() * 4)
				local at = Vector3.new(wx - hz * side - hx * 4, GROUND_Y, wz + hx * side - hz * 4)
				table.insert(chunks, {
					part = makeChunk(ctx.folder, at, rng),
					expiresAt = clock + cfg.chunkLifetimeSeconds,
				})
			end
		end
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if not root then
				continue
			end
			local p = root.Position
			-- Cheese chunk pickups
			for i = #chunks, 1, -1 do
				local c = chunks[i].part.Position
				if
					((c - p) * Vector3.new(1, 0, 1)).Magnitude < cfg.chunkPickupRadius
					and math.abs(c.Y - p.Y) < 8
				then
					grantChunk(player, i)
				end
			end
			if not current or done then
				continue
			end
			-- Wheel: along = travel axis, across = the wheel's width.
			local dx, dz = p.X - wx, p.Z - wz
			local along = dx * hx + dz * hz
			local across = -dx * hz + dz * hx
			if math.abs(along) < radius + 1 and math.abs(across) < cfg.thickness / 2 + 1 then
				local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
				local legs = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
				local feet = p.Y - legs - GROUND_Y
				if feet > cfg.hitFeetHeight then
					if jumped[player] ~= current.id then
						jumped[player] = current.id
						StyleService.markHazard(player, "cheese")
						Net.event("Hint"):FireClient(player, "🧀 CHEESE JUMP!")
					end
				elseif feet < cfg.diameter and jumped[player] ~= current.id then
					-- (a courier who already cleared this run is not hit on landing)
					local side = if across >= 0 then 1 else -1
					local impulse =
						Vector3.new(hx * 50 - hz * side * 30, 40, hz * 50 + hx * side * 30)
					KnockbackService.hit(player, impulse, "CheeseWheel", cfg.knockSeconds)
				end
			end
		end
	end)
	ctx.track(heartbeat)
	ctx.track(function()
		for _, c in chunks do
			c.part:Destroy()
		end
		table.clear(chunks)
	end)

	while ctx.phase() == "active" and ctx.isRunning() do
		local base = MapLayout.cheeseRoutes[rng:NextInteger(1, #MapLayout.cheeseRoutes)]
		local route = RoutePath.oriented(base :: any, rng:NextNumber() < 0.5)
		local strips = {}
		for i = 1, #route - 1 do
			local s = strip(ctx.folder, route[i], route[i + 1], cfg.thickness + 5)
			s.Transparency = 0.55
			table.insert(strips, s)
		end
		nextId += 1
		local length = RoutePath.length(route)
		run = {
			id = nextId,
			route = route,
			t0 = Workspace:GetServerTimeNow() + cfg.telegraphSeconds,
			length = length,
		}
		publish()
		local untilAt = os.clock() + cfg.telegraphSeconds + length / cfg.speed + 0.5
		local dimmed = false
		while os.clock() < untilAt and ctx.phase() == "active" and ctx.isRunning() do
			if not dimmed and os.clock() > untilAt - length / cfg.speed then
				dimmed = true
				for _, s in strips do
					s.Transparency = 0.8
				end
			end
			task.wait(0.1)
		end
		for _, s in strips do
			s:Destroy()
		end
		run = nil
		publish()
		local pause = cfg.pauseMinSeconds
			+ rng:NextNumber() * (cfg.pauseMaxSeconds - cfg.pauseMinSeconds)
		local pauseUntil = os.clock() + pause
		while os.clock() < pauseUntil and ctx.phase() == "active" and ctx.isRunning() do
			task.wait(0.1)
		end
	end
	run = nil
	publish()
end

function CheeseWheel.windDown(ctx: any)
	ctx.announce("🧀 The cheese wheel finally fell over. Grab the leftover chunks!")
end

function CheeseWheel.cleanup(ctx: any)
	ctx.setState("CheeseWheel", nil)
end

return CheeseWheel
