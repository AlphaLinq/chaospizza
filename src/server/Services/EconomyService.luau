--!strict
-- Tips (soft currency), XP and delivery count. Server-owned.
-- In memory for now; DataService (M5) will load/save the same fields.
-- Replicated to the owning client (and others, for leaderstats) via
-- player attributes: Tips, XP, Deliveries.

local Players = game:GetService("Players")

local DebugService = require(script.Parent.DebugService)

type State = {
	tips: number,
	xp: number,
	deliveries: number,
}

local MAX_TIPS = 1e12

local EconomyService = {}

local states: { [Player]: State } = {}

local function publish(player: Player, state: State)
	player:SetAttribute("Tips", state.tips)
	player:SetAttribute("XP", state.xp)
	player:SetAttribute("Deliveries", state.deliveries)
	local leaderstats = player:FindFirstChild("leaderstats")
	local tipsValue = leaderstats and leaderstats:FindFirstChild("Tips")
	if tipsValue and tipsValue:IsA("IntValue") then
		tipsValue.Value = state.tips
	end
end

local function getState(player: Player): State?
	return states[player]
end

local function onPlayerAdded(player: Player)
	local state: State = { tips = 0, xp = 0, deliveries = 0 }
	states[player] = state
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local tips = Instance.new("IntValue")
	tips.Name = "Tips"
	tips.Parent = leaderstats
	leaderstats.Parent = player
	publish(player, state)
end

-- Amount must be a finite, non-negative integer; reason is for analytics later.
function EconomyService.addTips(player: Player, amount: number, _reason: string): boolean
	local state = getState(player)
	if not state or amount ~= amount or amount < 0 or amount ~= math.floor(amount) then
		return false
	end
	state.tips = math.min(MAX_TIPS, state.tips + amount)
	publish(player, state)
	return true
end

function EconomyService.spendTips(player: Player, amount: number, _reason: string): boolean
	local state = getState(player)
	if not state or amount ~= amount or amount < 0 or state.tips < amount then
		return false
	end
	state.tips -= amount
	publish(player, state)
	return true
end

function EconomyService.addXp(player: Player, amount: number)
	local state = getState(player)
	if not state or amount ~= amount or amount < 0 then
		return
	end
	state.xp += math.floor(amount)
	publish(player, state)
end

function EconomyService.recordDelivery(player: Player): number
	local state = getState(player)
	if not state then
		return 0
	end
	state.deliveries += 1
	publish(player, state)
	return state.deliveries
end

function EconomyService.getTips(player: Player): number
	local state = getState(player)
	return if state then state.tips else 0
end

function EconomyService.getDeliveries(player: Player): number
	local state = getState(player)
	return if state then state.deliveries else 0
end

function EconomyService.init()
	DebugService.register("tips", "Give yourself tips", "tips <amount>", function(player, args)
		local amount = tonumber(args[1])
		if not amount or amount ~= math.floor(amount) or amount < 1 or amount > 1_000_000 then
			return false, "usage: tips <1..1000000>"
		end
		EconomyService.addTips(player, amount, "debug")
		return true, `+{amount} tips (total {EconomyService.getTips(player)})`
	end)
	DebugService.register("stats", "Show your tips, XP and deliveries", "stats", function(player)
		local state = getState(player)
		if not state then
			return false, "no state"
		end
		return true, `tips={state.tips} xp={state.xp} deliveries={state.deliveries}`
	end)
end

function EconomyService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if not states[player] then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return EconomyService
