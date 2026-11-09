--!strict
-- Event: The Floor Is Lava (#244). The streets are cut into tiles
-- (Util/LavaFloor, same list on every machine); in waves about a third of
-- them glow orange, then turn to lava for a few seconds. Step on live lava
-- and you get "Hot feet!": a bounce up and off the tile (a launch, not an
-- accident, so the streak survives). Doors, the counter, the spawn and the
-- safe spots never burn. Hop over live lava through the air for the
-- "Lava hopper" style tag and the event challenge.
--
-- Replication: CityState "Lava" = JSON { tiles, startsAt, lavaAt, endsAt }
-- (server time, tile indices), "FloorIsLava" = true while it runs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local LavaFloor = require(ReplicatedStorage.Shared.Util.LavaFloor)
local MapGeometry = require(ReplicatedStorage.Shared.Util.MapGeometry)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local KnockbackService = require(Services.KnockbackService)
local StyleService = require(Services.StyleService)

local FloorIsLava = {
	id = "FloorIsLava",
	buildUpSeconds = 3,
}

local POLL_SECONDS = 0.15
local cfg = Tuning.FloorIsLava :: any
local tiles: { LavaFloor.Tile }? = nil

local function allTiles(): { LavaFloor.Tile }
	if not tiles then
		local keep = LavaFloor.keepClear(MapLayout, function(b)
			local p = MapGeometry.doorPoint(b, MapLayout.streetY)
			return { x = p.x, z = p.z }
		end)
		tiles = LavaFloor.tiles(MapLayout.streets :: any, keep, cfg)
	end
	return tiles :: { LavaFloor.Tile }
end

local function feetHeight(root: BasePart): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
	if not hit then
		return math.huge
	end
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local legs = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	-- Only the street counts: standing on a car, box or ledge is safe.
	local onStreet = math.abs(hit.Position.Y - (MapLayout.streetY + 0.2)) < 0.6
	local feet = root.Position.Y - hit.Position.Y - legs
	return if onStreet then feet else math.huge
end

type Burns = { [Player]: number }

local function burn(player: Player, root: BasePart, tile: LavaFloor.Tile, burns: Burns)
	local now = os.clock()
	if now - (burns[player] or -math.huge) < cfg.hopCooldownSeconds then
		return
	end
	burns[player] = now
	local out = LavaFloor.pushOut(tile, root.Position.X, root.Position.Z)
	local velocity = Vector3.new(out.x * cfg.hopOut, cfg.hopUp, out.z * cfg.hopOut)
	KnockbackService.launch(player, velocity, "Lava", cfg.hopFlightSeconds)
end

local function poll(wave: LavaFloor.Wave, hopped: { [Player]: boolean }, burns: Burns)
	local all = allTiles()
	for _, player in Players:GetPlayers() do
		local root = CharacterService.getRootPart(player)
		if not root or player:GetAttribute("Knocked") == true then
			continue
		end
		local index = LavaFloor.tileAt(all, wave.tiles, root.Position.X, root.Position.Z)
		if not index then
			continue
		end
		local feet = feetHeight(root)
		if feet <= cfg.groundFeet then
			burn(player, root, all[index], burns)
		elseif
			not hopped[player]
			and feet >= cfg.hopFeetMin
			and feet <= cfg.hopFeetMax
			and os.clock() - (burns[player] or -math.huge) > cfg.hopFlightSeconds + 0.5
		then
			hopped[player] = true -- once per wave; a bounce off the lava doesn't count
			StyleService.markHazard(player, "lava")
		end
	end
end

function FloorIsLava.warning(ctx: any)
	ctx.announce("🌋 The pavement is getting HOT… the floor is about to be LAVA!")
end

function FloorIsLava.buildUp(ctx: any)
	allTiles()
	ctx.setState("FloorIsLava", true)
end

function FloorIsLava.active(ctx: any)
	local all = allTiles()
	local burns: Burns = {}
	local function going(): boolean
		return ctx.phase() == "active" and ctx.isRunning()
	end
	while going() do
		local picked = LavaFloor.pickWave(#all, cfg, function(a, b)
			return ctx.rng:NextInteger(a, b)
		end)
		local wave = LavaFloor.schedule(picked, Workspace:GetServerTimeNow(), cfg)
		ctx.setState("Lava", HttpService:JSONEncode(wave))
		local hopped: { [Player]: boolean } = {}
		while going() do
			local phase = LavaFloor.phase(wave, Workspace:GetServerTimeNow())
			if phase == "cool" then
				break
			elseif phase == "lava" then
				poll(wave, hopped, burns)
			end
			task.wait(POLL_SECONDS)
		end
		ctx.setState("Lava", nil)
		local untilAt = os.clock() + cfg.coolSeconds
		while going() and os.clock() < untilAt do
			task.wait(POLL_SECONDS)
		end
	end
end

function FloorIsLava.windDown(ctx: any)
	ctx.setState("Lava", nil)
	ctx.announce("🌋 The streets are cooling down. Phew!")
end

function FloorIsLava.cleanup(ctx: any)
	ctx.setState("Lava", nil)
	ctx.setState("FloorIsLava", nil)
end

return FloorIsLava
