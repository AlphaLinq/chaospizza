--!strict
-- Event: Giant Cat (#184), a boss. A huge cat plops down on Fountain Square
-- and swipes at couriers who come close: each swipe is telegraphed by a paw
-- shadow (CityState "CatPaws": JSON { id, x, z, t, r }), then slams. The
-- whole server can calm it: deliveries during the event "feed" it
-- ("CatFed" / "CatFeedGoal"); once fed it curls up and purrs (no more
-- swipes) and everyone online gets a bonus. "GiantCat" = "angry" | "fed".

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
local OrderService = require(Services.OrderService)

local GROUND_Y = MapLayout.streetY + 0.2

local GiantCat = {
	id = "GiantCat",
	buildUpSeconds = 4,
}

type Paw = { id: number, x: number, z: number, t: number, r: number }

-- Deliveries are routed here while the cat is on the square.
local feedHandler: ((Player) -> ())? = nil
local hooked = false

function GiantCat.warning(ctx: any)
	ctx.announce(
		"🐈 Something HUGE is padding towards Fountain Square… a GIANT CAT! Feed it pizza!"
	)
	if not hooked then
		hooked = true
		OrderService.onDelivered(function(player)
			local handler = feedHandler
			if handler then
				handler(player)
			end
		end)
	end
end

function GiantCat.buildUp(ctx: any)
	ctx.setState("GiantCat", "angry")
end

function GiantCat.active(ctx: any)
	local rng: Random = ctx.rng
	local cfg = Tuning.GiantCat
	local centre = Vector3.new(cfg.x, GROUND_Y, cfg.z)
	local paws: { Paw } = {}
	local nextId = 0
	local lastSwipe = 0
	local fed = 0
	local goal = math.max(cfg.feedMin, #Players:GetPlayers() * cfg.feedPerPlayer)
	local happy = false
	ctx.setState("GiantCat", "angry")
	ctx.setState("CatFed", 0)
	ctx.setState("CatFeedGoal", goal)

	local function publish()
		local list = {}
		for _, p in paws do
			table.insert(list, { id = p.id, x = p.x, z = p.z, t = p.t, r = p.r })
		end
		ctx.setState("CatPaws", if #list > 0 then HttpService:JSONEncode(list) else nil)
	end

	feedHandler = function(player: Player)
		if happy then
			return
		end
		fed += 1
		ctx.setState("CatFed", fed)
		Net.event("Hint")
			:FireClient(player, `🐈 The giant cat sniffs your delivery… {fed}/{goal}`)
		if fed >= goal then
			happy = true
			table.clear(paws)
			publish()
			ctx.setState("GiantCat", "fed")
			for _, p in Players:GetPlayers() do
				EconomyService.addTips(p, cfg.fedTips, "giant_cat_fed")
				Net.event("Hint"):FireClient(
					p,
					`🐈💤 The giant cat is full and purring! +{cfg.fedTips} tips for everyone`
				)
			end
		end
	end

	local function swipeTarget(): Vector3?
		local near = {}
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if root and ((root.Position - centre) * Vector3.new(1, 0, 1)).Magnitude < cfg.reach then
				table.insert(near, root.Position)
			end
		end
		if #near == 0 then
			return nil
		end
		local p = near[rng:NextInteger(1, #near)]
		return Vector3.new(p.X + rng:NextNumber(-3, 3), GROUND_Y, p.Z + rng:NextNumber(-3, 3))
	end

	local heartbeat = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local changed = false
		for i = #paws, 1, -1 do
			local paw = paws[i]
			if now >= paw.t then
				table.remove(paws, i)
				changed = true
				local at = Vector3.new(paw.x, GROUND_Y, paw.z)
				for _, player in Players:GetPlayers() do
					local root = CharacterService.getRootPart(player)
					if root then
						local flat = (root.Position - at) * Vector3.new(1, 0, 1)
						if flat.Magnitude <= paw.r and root.Position.Y - GROUND_Y < 10 then
							local away = (root.Position - centre) * Vector3.new(1, 0, 1)
							local dir = if away.Magnitude > 0.1
								then away.Unit
								else Vector3.new(1, 0, 0)
							KnockbackService.hit(
								player,
								dir * cfg.knockPower + Vector3.new(0, cfg.knockPower * 0.7, 0),
								"GiantCat",
								cfg.knockSeconds
							)
						end
					end
				end
			end
		end
		if not happy and ctx.phase() == "active" and now - lastSwipe >= cfg.swipeEverySeconds then
			local target = swipeTarget()
			if target then
				lastSwipe = now
				nextId += 1
				table.insert(
					paws,
					{
						id = nextId,
						x = target.X,
						z = target.Z,
						t = now + cfg.swipeWarnSeconds,
						r = cfg.swipeRadius,
					}
				)
				changed = true
			end
		end
		if changed then
			publish()
		end
	end)
	ctx.track(heartbeat)
	ctx.track(function()
		feedHandler = nil
		table.clear(paws)
	end)
	while ctx.phase() == "active" and ctx.isRunning() do
		task.wait(0.2)
	end
	feedHandler = nil
end

function GiantCat.windDown(ctx: any)
	ctx.announce("🐈 The giant cat stretches, yawns… and wanders off to nap somewhere else.")
	ctx.setState("CatPaws", nil)
end

function GiantCat.cleanup(ctx: any)
	feedHandler = nil
	ctx.setState("GiantCat", nil)
	ctx.setState("CatPaws", nil)
	ctx.setState("CatFed", nil)
	ctx.setState("CatFeedGoal", nil)
end

return GiantCat
