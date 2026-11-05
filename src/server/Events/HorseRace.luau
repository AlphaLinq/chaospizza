--!strict
-- Event: Surprise Horse Race (brief 1.0 ch. 13).
-- The main street turns into a race track. Horses run in waves along lanes;
-- before each wave the lanes it will use flash red (readable warning), and
-- the gaps between waves are where couriers cross. The overpass is always safe.
-- Barriers leave crossing gaps so no address is ever cut off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

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

local HORSE_COLORS = 5 -- coat variants (client: HorseRaceController)
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

	-- Horses are pure data: the server only replicates where/when each runner
	-- started (CityState "HorseRunners", JSON); every client animates its own
	-- models (HorseRaceController). The hit test uses the same formula here.
	type Runner = {
		id: number,
		lane: number,
		z: number,
		x0: number,
		dir: number,
		t0: number,
		speed: number,
		coat: number,
		silk: number,
		x: number,
	}
	local runners: { Runner } = {}
	local nextId = 0

	local function publish()
		local list = {}
		for _, r in runners do
			table.insert(list, {
				id = r.id,
				z = r.z,
				x0 = r.x0,
				dir = r.dir,
				t0 = r.t0,
				speed = r.speed,
				coat = r.coat,
				silk = r.silk,
				startX = START_X - 30,
				endX = END_X + 30,
			})
		end
		ctx.setState("HorseRunners", HttpService:JSONEncode(list))
	end
	publish()

	local heartbeat = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local removed = false
		for i = #runners, 1, -1 do
			local r = runners[i]
			r.x = r.x0 + r.dir * r.speed * (now - r.t0)
			local z = r.z
			if (r.dir > 0 and r.x > END_X) or (r.dir < 0 and r.x < START_X) then
				table.remove(runners, i)
				removed = true
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
		if removed then
			publish()
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
		local t0 = Workspace:GetServerTimeNow()
		for _, lane in chosen do
			local horses = rng:NextInteger(1, 2)
			for h = 1, horses do
				local startX = if dir > 0 then START_X - (h - 1) * 12 else END_X + (h - 1) * 12
				nextId += 1
				table.insert(runners, {
					id = nextId,
					lane = lane,
					z = LANES[lane],
					x0 = startX,
					dir = dir,
					t0 = t0,
					speed = HORSE_SPEED,
					coat = rng:NextInteger(1, HORSE_COLORS),
					silk = rng:NextInteger(1, #SILK_COLORS),
					x = startX,
				})
			end
		end
		publish()
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
