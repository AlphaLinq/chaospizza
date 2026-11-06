--!strict
-- Party tower (#170): while a courier carries a party order, the server
-- samples their movement (position deltas, so it does not trust any client
-- value) and feeds the pure Util/Tower wobble. Too much tilt drops the top
-- box; a knockback drops two. Player attribute "TowerTilt" (0..1, in 0.05
-- steps to keep traffic low) drives the client wobble (TowerController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Tower = require(ReplicatedStorage.Shared.Util.Tower)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local KnockbackService = require(script.Parent.KnockbackService)
local OrderService = require(script.Parent.OrderService)

local TowerService = {}

local cfg = Tuning.Tower
type Track = { orderId: string, tilt: number, pos: Vector3, vel: Tower.Sample, published: number }
local tracks: { [Player]: Track } = {}

local function publishTilt(player: Player, track: Track)
	local q = math.floor(track.tilt * 20 + 0.5) / 20
	if q ~= track.published then
		track.published = q
		player:SetAttribute("TowerTilt", q)
	end
end

local function drop(player: Player, n: number, why: string)
	local left = OrderService.dropPartyBoxes(player, n)
	if left == nil then
		return
	end
	local total = Tuning.OrderKinds.party.boxes
	Net.event("Hint"):FireClient(
		player,
		if left == 0
			then "🎉💥 The whole party tower fell! Deliver the empty boxes anyway…"
			else `🎉 {why} A box fell off! {left}/{total} left.`
	)
end

local function step(dt: number)
	for _, player in Players:GetPlayers() do
		local order = OrderService.getOrder(player)
		local root = CharacterService.getRootPart(player)
		if not order or order.kind ~= "party" or not root then
			if tracks[player] then
				tracks[player] = nil
				player:SetAttribute("TowerTilt", nil)
			end
			continue
		end
		local track = tracks[player]
		if not track or track.orderId ~= order.id then
			track = {
				orderId = order.id,
				tilt = 0,
				pos = root.Position,
				vel = { vx = 0, vy = 0, vz = 0 },
				published = -1,
			}
			tracks[player] = track
			publishTilt(player, track)
			continue
		end
		local p = root.Position
		local v = (p - track.pos) / dt
		track.pos = p
		local sample = { vx = v.X, vy = v.Y, vz = v.Z }
		local tilt, dropped = Tower.step(track.tilt, track.vel, sample, dt, cfg :: any)
		track.vel = sample
		track.tilt = tilt
		if dropped and (order.boxes or 0) > 0 then
			drop(player, 1, "Whoa, careful!")
		end
		publishTilt(player, track)
	end
end

function TowerService.init()
	DebugService.register(
		"tower",
		"Party tower: set the tilt",
		"tower tilt <0-1>",
		function(player, args)
			local track = tracks[player]
			if not track then
				return false, "no party order (use: order new party)"
			end
			track.tilt = math.clamp(tonumber(args[2] or args[1]) or 0.9, 0, 0.99)
			publishTilt(player, track)
			return true, `tilt {track.tilt}`
		end
	)
end

function TowerService.start()
	KnockbackService.onHit(function(player)
		if tracks[player] then
			drop(player, cfg.boxesLostOnHit, "Ouch!")
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= cfg.sampleSeconds then
			step(elapsed)
			elapsed = 0
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
end

return TowerService
