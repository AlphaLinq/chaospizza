--!strict
-- Event: Pizza Rain (#182) — a reward event. Pizzas fall from the sky; the
-- shadow on the ground shows where. Be under one when it lands (you may jump
-- for it) and you catch it: a few tips each. Together the server chases a
-- shared goal; reaching it pays everyone who caught at least one pizza.
--
-- CityState: "PizzaRain" (JSON list { id, x, z, t } with t = landing server
-- time), "PizzaRainCount", "PizzaRainGoal". Catches are decided here.

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
local ChallengeService = require(Services.ChallengeService)
local CharacterService = require(Services.CharacterService)
local EconomyService = require(Services.EconomyService)

local GROUND_Y = MapLayout.streetY + 0.2

local PizzaRain = {
	id = "PizzaRain",
	buildUpSeconds = 3,
}

type Drop = { id: number, x: number, z: number, t: number }

function PizzaRain.warning(ctx: any)
	ctx.announce("🍕☁️ The clouds smell like pepperoni… PIZZA RAIN incoming! Catch them!")
end

function PizzaRain.active(ctx: any)
	local rng: Random = ctx.rng
	local cfg = Tuning.PizzaRain
	local live: { Drop } = {}
	local caught: { [Player]: number } = {}
	local count = 0
	local goal = math.max(cfg.goalMin, #Players:GetPlayers() * cfg.goalPerPlayer)
	local goalPaid = false
	local nextId = 0
	local lastSpawn = 0
	ctx.setState("PizzaRainCount", 0)
	ctx.setState("PizzaRainGoal", goal)

	local function publish()
		local list = {}
		for _, d in live do
			table.insert(
				list,
				{ id = d.id, x = math.floor(d.x * 10) / 10, z = math.floor(d.z * 10) / 10, t = d.t }
			)
		end
		ctx.setState("PizzaRain", if #list > 0 then HttpService:JSONEncode(list) else nil)
	end

	local function payGoal()
		goalPaid = true
		for player, n in caught do
			if n > 0 and player.Parent then
				EconomyService.addTips(player, cfg.goalTips, "pizza_rain_goal")
				Net.event("Hint")
					:FireClient(
						player,
						`🍕🎉 The city caught {goal} pizzas! +{cfg.goalTips} tips`
					)
			end
		end
	end

	local function land(d: Drop)
		local centre = Vector3.new(d.x, GROUND_Y, d.z)
		local best: Player? = nil
		local bestDist = cfg.catchRadius
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if root and root.Position.Y - GROUND_Y < cfg.catchMaxFeet + 3 then
				local dist = ((root.Position - centre) * Vector3.new(1, 0, 1)).Magnitude
				if dist <= bestDist then
					best, bestDist = player, dist
				end
			end
		end
		if best then
			caught[best] = (caught[best] or 0) + 1
			count += 1
			ctx.setState("PizzaRainCount", count)
			EconomyService.addTips(best, cfg.catchTips, "pizza_rain")
			Net.event("Hint"):FireClient(best, `🍕 Caught! +{cfg.catchTips} · {count}/{goal}`)
			ChallengeService.progress(best, "pizza")
			if count >= goal and not goalPaid then
				payGoal()
			end
		end
	end

	local function target(): (number, number)
		local players = Players:GetPlayers()
		if #players > 0 and rng:NextNumber() < cfg.targetPlayerChance then
			local root = CharacterService.getRootPart(players[rng:NextInteger(1, #players)])
			if root then
				local a = rng:NextNumber() * math.pi * 2
				local r = 4 + rng:NextNumber() * 14 -- close enough to run for
				return root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r
			end
		end
		local s = MapLayout.streets[rng:NextInteger(1, #MapLayout.streets)]
		return s.x + (rng:NextNumber() - 0.5) * s.sx, s.z + (rng:NextNumber() - 0.5) * s.sz
	end

	local heartbeat = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local changed = false
		for i = #live, 1, -1 do
			if now >= live[i].t then
				land(live[i])
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
			local x, z = target()
			nextId += 1
			table.insert(live, { id = nextId, x = x, z = z, t = now + cfg.fallSeconds })
			changed = true
		end
		if changed then
			publish()
		end
	end)
	ctx.track(heartbeat)
	ctx.track(function()
		table.clear(live)
		table.clear(caught)
	end)
	while ctx.phase() == "active" and ctx.isRunning() do
		task.wait(0.2)
	end
end

function PizzaRain.windDown(ctx: any)
	ctx.announce("🍕☁️ The pizza clouds are empty. What a delicious day.")
end

function PizzaRain.cleanup(ctx: any)
	ctx.setState("PizzaRain", nil)
	ctx.setState("PizzaRainCount", nil)
	ctx.setState("PizzaRainGoal", nil)
end

return PizzaRain
