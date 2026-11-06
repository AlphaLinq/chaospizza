--!strict
-- Event: Bubble Storm (#161). The soap factory blew up: giant bubbles rise
-- from the streets. Walk into one and it carries you up and along; jump to
-- pop it and fall (no knockback — the tumble is your own fault). Deliveries
-- made while riding (or right after) earn the "Bubble rider" style tag.
--
-- Bubbles are data only: CityState "Bubbles" (JSON list of
-- { id, x, z, y0, t0, vx, vz, r }), republished when the set changes. Clients
-- animate them and move their own character while riding
-- (BubbleStormController); the server decides catches and releases with the
-- same Util/Bubbles formula. Player attribute "BubbleRide" = bubble id.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Bubbles = require(ReplicatedStorage.Shared.Util.Bubbles)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local StyleService = require(Services.StyleService)

local GROUND_Y = MapLayout.streetY + 0.2

local BubbleStorm = {
	id = "BubbleStorm",
	buildUpSeconds = 3,
}

function BubbleStorm.warning(ctx: any)
	ctx.announce("🫧 The soap factory exploded! BUBBLE STORM incoming — ride them or pop them!")
end

function BubbleStorm.active(ctx: any)
	local rng: Random = ctx.rng
	local cfg = Tuning.BubbleStorm
	local live: { Bubbles.Bubble } = {}
	local riding: { [Player]: number } = {}
	local cooldownUntil: { [Player]: number } = {}
	local nextId = 0
	local lastSpawn = 0

	local function publish()
		local list = {}
		for _, b in live do
			table.insert(list, {
				id = b.id,
				x = math.floor(b.x * 10) / 10,
				z = math.floor(b.z * 10) / 10,
				y0 = b.y0,
				t0 = b.t0,
				vx = math.floor(b.vx * 100) / 100,
				vz = math.floor(b.vz * 100) / 100,
				r = b.r,
			})
		end
		ctx.setState("Bubbles", if #list > 0 then HttpService:JSONEncode(list) else nil)
	end

	local function release(player: Player)
		if riding[player] then
			riding[player] = nil
			cooldownUntil[player] = os.clock() + cfg.catchCooldownSeconds
			player:SetAttribute("BubbleRide", nil)
		end
	end

	local function spawnBubble(now: number)
		local streets = MapLayout.streets
		local s = streets[rng:NextInteger(1, #streets)]
		local r = cfg.minRadius + rng:NextNumber() * (cfg.maxRadius - cfg.minRadius)
		local angle = rng:NextNumber() * math.pi * 2
		nextId += 1
		table.insert(live, {
			id = nextId,
			x = s.x + (rng:NextNumber() - 0.5) * math.max(0, s.sx - 2 * r),
			z = s.z + (rng:NextNumber() - 0.5) * math.max(0, s.sz - 2 * r),
			y0 = GROUND_Y + r, -- sits on the street when it appears
			t0 = now,
			vx = math.cos(angle) * cfg.driftSpeed,
			vz = math.sin(angle) * cfg.driftSpeed,
			r = r,
		})
	end

	local heartbeat = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local changed = false
		for i = #live, 1, -1 do
			if not Bubbles.alive(live[i], now, cfg.lifeSeconds) then
				table.remove(live, i)
				changed = true
			end
		end
		if
			ctx.phase() == "active"
			and #live < cfg.maxBubbles
			and now - lastSpawn >= cfg.spawnEverySeconds
		then
			lastSpawn = now
			spawnBubble(now)
			changed = true
		end
		if changed then
			publish()
		end
		local byId: { [number]: Bubbles.Bubble } = {}
		for _, b in live do
			byId[b.id] = b
		end
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if not root then
				release(player)
				continue
			end
			local p = root.Position
			local rideId = riding[player]
			if rideId then
				local b = byId[rideId]
				if not b then
					release(player)
				else
					local bx, by, bz = Bubbles.position(b, now, cfg.riseSpeed, cfg.maxHeight)
					if (p - Vector3.new(bx, by, bz)).Magnitude > b.r + cfg.releaseMargin then
						-- The rider jumped out: that bubble popped for everyone.
						release(player)
						local index = table.find(live, b)
						if index then
							table.remove(live, index)
							publish()
						end
					else
						StyleService.markHazard(player, "bubble")
					end
				end
				continue
			end
			if os.clock() < (cooldownUntil[player] or 0) or player:GetAttribute("Knocked") then
				continue
			end
			for _, b in live do
				local bx, by, bz = Bubbles.position(b, now, cfg.riseSpeed, cfg.maxHeight)
				if (p - Vector3.new(bx, by, bz)).Magnitude < b.r - cfg.catchMargin + 2 then
					riding[player] = b.id
					player:SetAttribute("BubbleRide", b.id)
					StyleService.markHazard(player, "bubble")
					break
				end
			end
		end
	end)
	ctx.track(heartbeat)
	ctx.track(function()
		for player in riding do
			if player.Parent then
				player:SetAttribute("BubbleRide", nil)
			end
		end
		table.clear(riding)
		table.clear(live)
	end)

	while ctx.phase() == "active" and ctx.isRunning() do
		task.wait(0.2)
	end
	-- wind-down: no new bubbles; the rest float away and pop on their own
end

function BubbleStorm.windDown(ctx: any)
	ctx.announce("🫧 The last bubbles drift off. The city smells VERY clean.")
end

function BubbleStorm.cleanup(ctx: any)
	ctx.setState("Bubbles", nil)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("BubbleRide", nil)
	end
end

return BubbleStorm
