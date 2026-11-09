--!strict
-- Golden pizza (#223). About 2% of orders (never two in a row for the same
-- courier, not party or giant orders) are golden: the box turns gold, the
-- server hears "✨ X is carrying a GOLDEN PIZZA!", and the delivery pays ×3
-- ("Golden"). An accident on the way scuffs it to ×2 — tension, not a loss.
--
-- Replication: player attribute "GoldenOrder" = "shiny" | "scuffed" (the
-- client adds sparkles, GoldenController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local KnockbackService = require(script.Parent.KnockbackService)
local LoopTitleService = require(script.Parent.LoopTitleService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)

local GoldenService = {}

type State = { orderId: string, scuffed: boolean }

local cfg = Tuning.Golden
local golden: { [Player]: State } = {}
local lastWasGolden: { [Player]: boolean } = {}

local GOLD = Color3.fromHex("#FFC83D")

local function paintBox(player: Player)
	local character = player.Character
	local box = character and character:FindFirstChild("PizzaBox")
	if box and box:IsA("BasePart") then
		box.Color = GOLD
		box.Material = Enum.Material.Foil
	end
end

local function clear(player: Player)
	if golden[player] then
		golden[player] = nil
		player:SetAttribute("GoldenOrder", nil)
	end
end

function GoldenService.make(player: Player, order: OrderService.Order)
	golden[player] = { orderId = order.id, scuffed = false }
	lastWasGolden[player] = true
	player:SetAttribute("GoldenOrder", "shiny")
	-- the box is attached right before onAssigned; paint it on the next frame too
	paintBox(player)
	task.defer(paintBox, player)
	local address = MapService.getAddress(order.addressId)
	AnalyticsService.custom(player, "golden_order")
	Net.event("Hint"):FireAllClients(
		`✨ {player.DisplayName} is carrying a GOLDEN PIZZA{if address
			then ` to {address.label}`
			else ""}!`
	)
end

function GoldenService.init()
	DebugService.register(
		"golden",
		"Make your current order (or a new one) golden",
		"golden",
		function(player)
			local order = OrderService.getOrder(player) or OrderService.assignOrder(player)
			if not order then
				return false, "no order"
			end
			GoldenService.make(player, order)
			return true, `golden order to {order.addressId}`
		end
	)
end

function GoldenService.start()
	OrderService.onAssigned(function(player, order)
		clear(player)
		local kind = order.kind or "normal"
		local eligible = kind ~= "party"
			and not player:GetAttribute("GiantOrderId")
			and EconomyService.getDeliveries(player) >= cfg.minDeliveries
		if eligible and not lastWasGolden[player] and math.random() < cfg.chance then
			GoldenService.make(player, order)
		else
			lastWasGolden[player] = false
		end
	end)
	KnockbackService.onHit(function(player)
		local g = golden[player]
		if g and not g.scuffed then
			g.scuffed = true
			player:SetAttribute("GoldenOrder", "scuffed")
			Net.event("Hint"):FireClient(
				player,
				`😬 The golden pizza got scuffed! Still ×{cfg.scuffedMultiplier}.`
			)
		end
	end)
	OrderService.addTipModifier(function(player, order)
		local g = golden[player]
		if not g or g.orderId ~= order.id then
			return 1, nil
		end
		AnalyticsService.custom(player, "golden_done")
		task.spawn(LoopTitleService.bump, player, "loop.golden") -- Gold Rush (#227)
		if g.scuffed then
			return cfg.scuffedMultiplier, "Golden (scuffed)"
		end
		return cfg.tipMultiplier, "Golden"
	end)
	OrderService.onDelivered(function(player)
		clear(player)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, g in golden do
				local order = OrderService.getOrder(player)
				if not order or order.id ~= g.orderId then
					clear(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		golden[player] = nil
		lastWasGolden[player] = nil
	end)
end

return GoldenService
