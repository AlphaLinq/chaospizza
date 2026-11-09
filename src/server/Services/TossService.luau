--!strict
-- Pizza toss (#236). Within Tuning.Toss.maxStuds of the doorstep, with a
-- clear line of sight, a courier can throw the pizza instead of walking the
-- last steps: it delivers like a normal drop-off plus the "Yeet" style tag.
-- The client only asks (Net "TossOrder"); the server checks the order, its
-- kind (cakes and party towers don't fly), distance, height and a raycast,
-- then completes the order with the wider radius and tells every client to
-- draw the flying box (Net "PizzaToss").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Toss = require(ReplicatedStorage.Shared.Util.Toss)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local DailyService = require(script.Parent.DailyService)
local DebugService = require(script.Parent.DebugService)
local FeatureTipService = require(script.Parent.FeatureTipService)
local LoopTitleService = require(script.Parent.LoopTitleService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)
local StyleService = require(script.Parent.StyleService)

local TossService = {}

local cfg = Tuning.Toss
local TOLERANCE = 4 -- latency slack, same as the door check
local lastToss: { [Player]: number } = {}
-- Door side -> the direction out into the street (x = east, z = south).
local OUTWARD: { [string]: Vector3 } = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}

local function clearShot(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(from, to - from, params)
	-- Hitting the door itself (or anything right at it) still counts.
	return hit == nil or (hit.Position - to).Magnitude <= 4
end

-- Tosses the active order. Returns ok + message (debug uses it too).
function TossService.toss(player: Player): (boolean, string)
	local order = OrderService.getOrder(player)
	local root = CharacterService.getRootPart(player)
	if not order or not root then
		return false, "no order"
	end
	local address = MapService.getAddress(order.addressId)
	if not address then
		return false, "unknown address"
	end
	local now = os.clock()
	if now - (lastToss[player] or -math.huge) < cfg.cooldownSeconds then
		return false, "easy, one pizza at a time"
	end
	local target = OrderService.deliveryPoint(address)
	local from = root.Position + Vector3.new(0, 1.5, 0)
	local flat = ((target - root.Position) * Vector3.new(1, 0, 1)).Magnitude
	local ok, reason = Toss.check(
		order.kind,
		flat,
		root.Position.Y - target.Y,
		Tuning.Orders.deliveryRadiusStuds,
		cfg :: any,
		TOLERANCE
	)
	if not ok then
		return false, reason
	end
	if not clearShot(from, target) then
		return false, "Something's in the way: find a clear throw!"
	end
	lastToss[player] = now
	StyleService.markHazard(player, "toss") -- the Yeet tag (5 s window)
	local delivered, why = OrderService.completeOrder(player, false, cfg.maxStuds)
	if not delivered then
		return false, why
	end
	AnalyticsService.custom(player, "toss_delivery", math.floor(flat))
	DailyService.recordProgress(player, "toss", 1) -- weekly Yeeter (#240)
	LoopTitleService.bump(player, "loop.toss") -- Yeet Master (#251)
	Net.event("PizzaToss"):FireAllClients(from, target)
	return true, `tossed from {math.floor(flat)} studs`
end

function TossService.init()
	DebugService.register(
		"toss",
		"Pizza toss: stand 20 studs from your door, or toss now",
		"toss [here|now]",
		function(player, args)
			if args[1] == "now" then
				return TossService.toss(player)
			end
			local order = OrderService.getOrder(player)
			local address = order and MapService.getAddress(order.addressId)
			if not address then
				return false, "no order"
			end
			local dir = Vector3.new(0, 0, 1)
			for _, b in MapLayout.buildings do
				local a = (b :: any).address
				if a and a.id == address.id then
					dir = OUTWARD[b.door] or dir
				end
			end
			CharacterService.teleport(
				player,
				address.doorPosition + dir * 20 + Vector3.new(0, 1, 0)
			)
			return true, "20 studs from the door: press F or tap Toss"
		end
	)
end

function TossService.start()
	Net.onServerEvent("TossOrder", { ratePerSecond = 2, burst = 3 }, function(player, rawOrderId)
		if typeof(rawOrderId) ~= "string" or #rawOrderId > 64 then
			return
		end
		local order = OrderService.getOrder(player)
		if not order or order.id ~= rawOrderId then
			return -- stale or forged
		end
		local ok, reason = TossService.toss(player)
		if not ok then
			Net.event("Hint"):FireClient(player, reason)
		end
	end)
	OrderService.onDelivered(function(player, _, _, deliveries)
		if deliveries >= 2 then
			FeatureTipService.show(player, "Toss") -- once per courier (#238)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastToss[player] = nil
	end)
end

return TossService
