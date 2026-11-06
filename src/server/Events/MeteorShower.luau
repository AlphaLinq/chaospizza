--!strict
-- Event: Meteor Shower (#181). Meteors rain on the city. Every impact is
-- telegraphed by a red circle (CityState "Meteors": JSON list of
-- { id, x, z, t (server time of impact), r }) and each client draws the
-- circle, the falling rock and the crater (MeteorController). At impact the
-- server knocks couriers inside the circle; those just outside get the "Close
-- call" style tag. Impacts leave stardust (server parts tagged "Stardust")
-- that pays a few tips, once.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local EconomyService = require(Services.EconomyService)
local KnockbackService = require(Services.KnockbackService)
local StyleService = require(Services.StyleService)

local GROUND_Y = MapLayout.streetY + 0.2

local MeteorShower = {
	id = "MeteorShower",
	buildUpSeconds = 3,
}

type Meteor = { id: number, x: number, z: number, t: number, r: number }
type Dust = { part: BasePart, expiresAt: number }

local function tooCloseToSafety(x: number, z: number, margin: number): boolean
	for _, spot in MapLayout.safeSpots do
		if (spot.x - x) ^ 2 + (spot.z - z) ^ 2 < margin * margin then
			return true
		end
	end
	return false
end

local function makeDust(parent: Instance, at: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = "Stardust"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromHex("#9FD8FF")
	p.Size = Vector3.new(1.2, 1.2, 1.2)
	p.Position = at + Vector3.new(0, 1, 0)
	CollectionService:AddTag(p, "Stardust")
	p.Parent = parent
	return p
end

function MeteorShower.warning(ctx: any)
	ctx.announce("☄️ METEOR SHOWER incoming! Watch for red circles — and grab the stardust!")
end

function MeteorShower.active(ctx: any)
	local rng: Random = ctx.rng
	local cfg = Tuning.MeteorShower
	local live: { Meteor } = {}
	local dust: { Dust } = {}
	local nextId = 0
	local lastSpawn = 0

	local function publish()
		local list = {}
		for _, m in live do
			table.insert(list, { id = m.id, x = m.x, z = m.z, t = m.t, r = m.r })
		end
		ctx.setState("Meteors", if #list > 0 then HttpService:JSONEncode(list) else nil)
	end

	local function pickTarget(): (number?, number?)
		for _ = 1, 6 do
			local x, z
			local players = Players:GetPlayers()
			if #players > 0 and rng:NextNumber() < cfg.targetPlayerChance then
				local root = CharacterService.getRootPart(players[rng:NextInteger(1, #players)])
				if root then
					-- lead the courier a little so standing still is not safe
					local v = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					local at = root.Position + v * cfg.telegraphSeconds * 0.5
					x, z = at.X + rng:NextNumber(-4, 4), at.Z + rng:NextNumber(-4, 4)
				end
			end
			if not x then
				local s = MapLayout.streets[rng:NextInteger(1, #MapLayout.streets)]
				x = s.x + (rng:NextNumber() - 0.5) * s.sx
				z = s.z + (rng:NextNumber() - 0.5) * s.sz
			end
			local b = MapLayout.bounds
			if
				x > b.minX + 5
				and x < b.maxX - 5
				and z > b.minZ + 5
				and z < b.maxZ - 5
				and not tooCloseToSafety(x, z, cfg.avoidSafeSpotStuds)
			then
				return x, z
			end
		end
		return nil, nil
	end

	local function impact(m: Meteor)
		local centre = Vector3.new(m.x, GROUND_Y, m.z)
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if root then
				local flat = (root.Position - centre) * Vector3.new(1, 0, 1)
				local d = flat.Magnitude
				if d <= m.r and root.Position.Y - GROUND_Y < 12 then
					local away = if d > 0.1 then flat.Unit else Vector3.new(1, 0, 0)
					KnockbackService.hit(
						player,
						away * cfg.knockPower + Vector3.new(0, cfg.knockPower * 0.8, 0),
						"Meteor",
						cfg.knockSeconds
					)
				elseif d <= m.r + cfg.nearMissMargin then
					StyleService.markHazard(player, "meteor")
				end
			end
		end
		for i = 1, cfg.dustPerImpact do
			if #dust >= cfg.dustMax then
				break
			end
			local a = (i / cfg.dustPerImpact) * math.pi * 2 + rng:NextNumber()
			table.insert(dust, {
				part = makeDust(
					ctx.folder,
					centre + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3)
				),
				expiresAt = os.clock() + cfg.dustLifetimeSeconds,
			})
		end
	end

	local heartbeat = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local changed = false
		for i = #live, 1, -1 do
			if now >= live[i].t then
				impact(live[i])
				table.remove(live, i)
				changed = true
			end
		end
		if
			ctx.phase() == "active"
			and #live < cfg.maxLive
			and now - lastSpawn >= cfg.spawnEverySeconds
		then
			lastSpawn = now
			local x, z = pickTarget()
			if x and z then
				nextId += 1
				table.insert(
					live,
					{ id = nextId, x = x, z = z, t = now + cfg.telegraphSeconds, r = cfg.radius }
				)
				changed = true
			end
		end
		if changed then
			publish()
		end
		-- stardust pickups (server-side, once)
		local clock = os.clock()
		for i = #dust, 1, -1 do
			if clock > dust[i].expiresAt then
				dust[i].part:Destroy()
				table.remove(dust, i)
			end
		end
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if root then
				for i = #dust, 1, -1 do
					if (dust[i].part.Position - root.Position).Magnitude < cfg.dustPickupRadius then
						local d = table.remove(dust, i) :: Dust
						d.part:Destroy()
						if EconomyService.addTips(player, cfg.dustTips, "stardust") then
							Net.event("Hint"):FireClient(player, `✨ +{cfg.dustTips} stardust`)
						end
					end
				end
			end
		end
	end)
	ctx.track(heartbeat)
	ctx.track(function()
		for _, d in dust do
			d.part:Destroy()
		end
		table.clear(dust)
		table.clear(live)
	end)
	while ctx.phase() == "active" and ctx.isRunning() do
		task.wait(0.2)
	end
end

function MeteorShower.windDown(ctx: any)
	ctx.announce("☄️ The last meteors fizzle out. Stardust everywhere!")
end

function MeteorShower.cleanup(ctx: any)
	ctx.setState("Meteors", nil)
end

return MeteorShower
