--!strict
-- Event: Surprise Horse Race (brief 1.0 ch. 13).
-- The main street turns into a race track. Horses run in waves along lanes;
-- before each wave the lanes it will use flash red (readable warning), and
-- the gaps between waves are where couriers cross. The overpass is always safe.
-- Barriers leave crossing gaps so no address is ever cut off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local KnockbackService = require(Services.KnockbackService)
local StyleService = require(Services.StyleService)
local MapService = require(Services.MapService)

local TRACK = MapLayout.zones.MainStreet
local LANES = { TRACK.z - 12, TRACK.z, TRACK.z + 12 }
local START_X = TRACK.x - TRACK.sx / 2 - 10
local END_X = TRACK.x + TRACK.sx / 2 + 10
local HORSE_SPEED = 75 -- studs/s → ~7.5 s per run
local WAVE_INTERVAL = { 4.5, 6.5 }
local TELEGRAPH_SECONDS = 1.6
local HIT_HALF_LENGTH = 5
local HIT_HALF_WIDTH = 3.2
local CROSSING_GAPS = { -200, -100, 0, 100, 200 } -- x positions with no barrier (+ every door near the track)
local GAP_WIDTH = 26

local HorseRace = {
	id = "HorseRace",
	buildUpSeconds = 3,
}

local HORSE_COLORS = { "#6B4423", "#2B2B2B", "#C8A27A", "#8B5A2B", "#EDE6DA" }
local SILK_COLORS = { "#D6452F", "#2F7BD6", "#F2C14E", "#3FA34D", "#9B59B6" }

local function makePart(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: string,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A simple blocky horse with a jockey, built around a pivot at hoof level.
local function makeHorse(parent: Instance, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Horse"
	local coat = HORSE_COLORS[rng:NextInteger(1, #HORSE_COLORS)]
	local silk = SILK_COLORS[rng:NextInteger(1, #SILK_COLORS)]
	local base = CFrame.new()
	local body = makePart(model, Vector3.new(7, 3, 2.6), base * CFrame.new(0, 5, 0), coat)
	makePart(
		model,
		Vector3.new(1.6, 3.2, 1.8),
		base * CFrame.new(3.6, 6.6, 0) * CFrame.Angles(0, 0, math.rad(-25)),
		coat
	)
	makePart(model, Vector3.new(2.4, 1.4, 1.5), base * CFrame.new(4.9, 7.8, 0), coat)
	for _, lx in { -2.6, 2.6 } do
		for _, lz in { -0.8, 0.8 } do
			makePart(model, Vector3.new(0.7, 3.6, 0.7), base * CFrame.new(lx, 1.8, lz), coat)
		end
	end
	makePart(model, Vector3.new(1.6, 2.2, 1.6), base * CFrame.new(-0.3, 7.6, 0), silk) -- jockey
	makePart(model, Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(0, 9.2, 0), "#F1C27D") -- head
	makePart(
		model,
		Vector3.new(0.4, 2.4, 0.4),
		base * CFrame.new(-3.8, 5.8, 0) * CFrame.Angles(0, 0, math.rad(35)),
		"#222222"
	) -- tail
	model.PrimaryPart = body
	-- Pivot at hoof level so PivotTo(y = street) keeps the legs on the street.
	body.PivotOffset = CFrame.new(0, -5, 0)
	model:PivotTo(CFrame.new(0, -500, 0)) -- out of sight until the first step
	model.Parent = parent
	return model
end

local function buildBarriers(ctx: any)
	local folder = Instance.new("Folder")
	folder.Name = "Barriers"
	folder.Parent = ctx.folder
	-- Rails sit just inside the track edge, clear of the door points.
	local edges = { TRACK.z - TRACK.sz / 2 + 1, TRACK.z + TRACK.sz / 2 - 1 }
	local x0 = TRACK.x - TRACK.sx / 2
	local x1 = TRACK.x + TRACK.sx / 2
	-- Segments between crossing gaps
	-- Gaps: fixed crossings + every delivery door that faces the track.
	local gaps = table.clone(CROSSING_GAPS)
	for _, address in MapService.getAddresses() do
		local d = address.doorPosition
		if math.abs(d.Z - TRACK.z) < TRACK.sz / 2 + 12 then
			table.insert(gaps, d.X)
		end
	end
	-- Union of gap intervals → alternating rail cut points.
	table.sort(gaps)
	local intervals: { { number } } = {}
	for _, gx in gaps do
		local a, b = gx - GAP_WIDTH / 2, gx + GAP_WIDTH / 2
		local last = intervals[#intervals]
		if last and a <= last[2] then
			last[2] = math.max(last[2], b)
		else
			table.insert(intervals, { a, b })
		end
	end
	local cuts = { x0 }
	for _, interval in intervals do
		table.insert(cuts, interval[1])
		table.insert(cuts, interval[2])
	end
	table.insert(cuts, x1)
	for _, z in edges do
		for i = 1, #cuts - 1, 2 do
			local a, b = cuts[i], cuts[i + 1]
			if b - a > 2 then
				local rail = makePart(
					folder,
					Vector3.new(b - a, 2.4, 0.6),
					CFrame.new((a + b) / 2, 1.6, z),
					"#FFFFFF",
					Enum.Material.Wood
				)
				rail.CanCollide = true
				-- flags on posts
				local count = math.floor((b - a) / 30)
				for k = 0, count do
					local fx = a + (b - a) * (k / math.max(count, 1))
					makePart(folder, Vector3.new(0.3, 6, 0.3), CFrame.new(fx, 3.4, z), "#DDDDDD")
					makePart(
						folder,
						Vector3.new(2.2, 1.4, 0.1),
						CFrame.new(fx + 1.2, 5.6, z),
						SILK_COLORS[(k % #SILK_COLORS) + 1],
						Enum.Material.Fabric
					)
				end
			end
		end
	end
	return folder
end

local function laneStrip(parent: Instance, laneZ: number): Part
	local strip = makePart(
		parent,
		Vector3.new(TRACK.sx, 0.15, 9),
		CFrame.new(TRACK.x, 0.5, laneZ),
		"#FF3B30",
		Enum.Material.Neon
	)
	strip.Transparency = 1
	return strip
end

function HorseRace.warning(ctx: any)
	ctx.announce("🏇 SURPRISE HORSE RACE on Crust Road! Use the bridge or cross between waves!")
end

function HorseRace.buildUp(ctx: any)
	buildBarriers(ctx)
end

function HorseRace.active(ctx: any)
	local rng: Random = ctx.rng
	local strips = {}
	for i, z in LANES do
		strips[i] = laneStrip(ctx.folder, z)
	end

	type Runner = { model: Model, lane: number, x: number, dir: number }
	local runners: { Runner } = {}

	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		for i = #runners, 1, -1 do
			local r = runners[i]
			r.x += r.dir * HORSE_SPEED * dt
			local z = LANES[r.lane]
			local facing = if r.dir > 0 then 0 else math.pi
			r.model:PivotTo(CFrame.new(r.x, 0.4, z) * CFrame.Angles(0, facing, 0))
			if (r.dir > 0 and r.x > END_X) or (r.dir < 0 and r.x < START_X) then
				r.model:Destroy()
				table.remove(runners, i)
				continue
			end
			-- Server-side hit test against every courier on the track
			for _, player in Players:GetPlayers() do
				local root = CharacterService.getRootPart(player)
				if root then
					local p = root.Position
					-- Crossing a lane while a horse is close = "Hoofbeat" style.
					if
						math.abs(p.Z - z) < HIT_HALF_WIDTH
						and math.abs(p.X - r.x) < Tuning.Style.horseNearStuds
						and p.Y < 12
					then
						StyleService.markHazard(player, "horse")
					end
					if
						math.abs(p.X - r.x) < HIT_HALF_LENGTH
						and math.abs(p.Z - z) < HIT_HALF_WIDTH
						and p.Y < 12
					then
						local side = if p.Z >= z then 1 else -1
						local impulse = Vector3.new(r.dir * 55, 45, side * 35)
						KnockbackService.hit(player, impulse, "HorseRace", 1.4)
					end
				end
			end
		end
	end)
	ctx.track(heartbeat)

	while ctx.phase() == "active" and ctx.isRunning() do
		-- Choose 1–2 lanes for this wave; never all three, so there is always a gap.
		local laneCount = rng:NextInteger(1, 2)
		local chosen: { number } = {}
		local pool = { 1, 2, 3 }
		for _ = 1, laneCount do
			table.insert(chosen, table.remove(pool, rng:NextInteger(1, #pool)) :: number)
		end
		local dir = if rng:NextNumber() < 0.5 then 1 else -1

		-- Telegraph: the chosen lanes flash before the horses arrive.
		for _, lane in chosen do
			strips[lane].Transparency = 0.7
		end
		task.wait(TELEGRAPH_SECONDS)
		for _, lane in chosen do
			strips[lane].Transparency = 0.85
		end
		for _, lane in chosen do
			local horses = rng:NextInteger(1, 2)
			for h = 1, horses do
				local model = makeHorse(ctx.folder, rng)
				local startX = if dir > 0 then START_X - (h - 1) * 12 else END_X + (h - 1) * 12
				table.insert(runners, { model = model, lane = lane, x = startX, dir = dir })
			end
		end
		task.delay(3, function()
			for _, lane in chosen do
				if strips[lane].Parent then
					strips[lane].Transparency = 1
				end
			end
		end)
		local waitFor = WAVE_INTERVAL[1] + rng:NextNumber() * (WAVE_INTERVAL[2] - WAVE_INTERVAL[1])
		local untilAt = os.clock() + waitFor
		while os.clock() < untilAt and ctx.phase() == "active" and ctx.isRunning() do
			task.wait(0.1)
		end
	end
end

function HorseRace.windDown(ctx: any)
	ctx.announce("🏁 The race is over. Carry on, couriers!")
end

function HorseRace.cleanup(_ctx: any)
	-- Everything lives in ctx.folder, which EventService destroys.
end

return HorseRace
