--!strict
-- Tips (soft currency), XP, courier level and delivery count. Server-owned and
-- persisted through DataService (session-locked profile). Nothing pays out
-- before the profile is loaded (isReady).
--
-- Replicated to the owner via player attributes: Tips, XP, Deliveries,
-- CourierLevel; Tips also as leaderstats for the player list.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pizzeria = require(ReplicatedStorage.Shared.Config.Pizzeria)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Util.Progression)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)

local MAX_TIPS = 1e12

local EconomyService = {}

local progression = Progression.new(ProgressionConfig :: any, Rarities :: any, Pizzeria :: any)
local levelUpCallbacks: { (player: Player, level: number) -> () } = {}

local function ensureLeaderstats(player: Player): IntValue
	local leaderstats: Instance? = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		leaderstats = folder
	end
	local existing = (leaderstats :: Instance):FindFirstChild("Tips")
	if existing and existing:IsA("IntValue") then
		return existing
	end
	local tips = Instance.new("IntValue")
	tips.Name = "Tips"
	tips.Parent = leaderstats
	return tips
end

local function publish(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	player:SetAttribute("Tips", profile.tips)
	player:SetAttribute("XP", profile.xp)
	player:SetAttribute("Deliveries", profile.deliveries)
	player:SetAttribute("CourierLevel", progression.levelFromXp(profile.xp))
	ensureLeaderstats(player).Value = math.min(profile.tips, 2 ^ 31 - 1)
end

function EconomyService.isReady(player: Player): boolean
	return DataService.isLoaded(player)
end

function EconomyService.getProgression()
	return progression
end

function EconomyService.onLevelUp(callback: (player: Player, level: number) -> ())
	table.insert(levelUpCallbacks, callback)
end

-- DataService.update returns false while a persisted transaction (e.g. a
-- purchase) holds the session. Rewards retry briefly instead of being lost.
local function updateWithRetry(player: Player, fn: (any) -> ()): boolean
	for attempt = 1, 10 do
		if DataService.update(player, fn) then
			return true
		end
		if not DataService.isLoaded(player) then
			return false
		end
		if attempt < 10 then
			task.wait(0.2)
		end
	end
	warn(`[EconomyService] profile update failed after retries for {player.UserId}`)
	return false
end

local function validAmount(amount: number): boolean
	return amount == amount and amount >= 0 and amount < math.huge and amount == math.floor(amount)
end

-- reason: stable analytics category (e.g. "delivery", "passive", "debug").
function EconomyService.addTips(player: Player, amount: number, reason: string): boolean
	if not validAmount(amount) or amount == 0 then
		return false
	end
	local ok = updateWithRetry(player, function(profile)
		profile.tips = math.min(MAX_TIPS, profile.tips + amount)
	end)
	if ok then
		publish(player)
		AnalyticsService.economy(player, "Source", amount, reason, reason)
	end
	return ok
end

-- Atomic check-and-spend. Returns false (and spends nothing) if not enough.
function EconomyService.spendTips(player: Player, amount: number, item: string): boolean
	if not validAmount(amount) or amount == 0 then
		return false
	end
	local ok = DataService.transaction(player, function(profile)
		if profile.tips < amount then
			return false
		end
		profile.tips -= amount
		return true
	end)
	if ok then
		publish(player)
		AnalyticsService.economy(player, "Sink", amount, item, "purchase")
	end
	return ok
end

function EconomyService.addXp(player: Player, amount: number)
	if not validAmount(amount) or amount == 0 then
		return
	end
	local before = DataService.getProfile(player)
	if not before then
		return
	end
	local oldLevel = progression.levelFromXp(before.xp)
	local ok = updateWithRetry(player, function(profile)
		profile.xp += amount
	end)
	if not ok then
		return
	end
	publish(player)
	local after = DataService.getProfile(player)
	local newLevel = if after then progression.levelFromXp(after.xp) else oldLevel
	if newLevel > oldLevel then
		Net.event("Hint"):FireClient(player, `⭐ Courier level {newLevel}!`)
		for _, callback in levelUpCallbacks do
			task.spawn(callback, player, newLevel)
		end
	end
end

function EconomyService.recordDelivery(player: Player): number
	local count = 0
	local ok = updateWithRetry(player, function(profile)
		profile.deliveries += 1
		count = profile.deliveries
	end)
	if ok then
		publish(player)
	end
	return count
end

function EconomyService.getTips(player: Player): number
	local profile = DataService.getProfile(player)
	return if profile then profile.tips else 0
end

function EconomyService.getDeliveries(player: Player): number
	local profile = DataService.getProfile(player)
	return if profile then profile.deliveries else 0
end

function EconomyService.getCourierLevel(player: Player): number
	local profile = DataService.getProfile(player)
	return if profile then progression.levelFromXp(profile.xp) else 1
end

-- Re-publish attributes (e.g. after a debug wipe).
function EconomyService.refresh(player: Player)
	publish(player)
end

function EconomyService.init()
	DebugService.register("tips", "Give yourself tips", "tips <amount>", function(player, args)
		local amount = tonumber(args[1])
		if not amount or amount ~= math.floor(amount) or amount < 1 or amount > 1_000_000 then
			return false, "usage: tips <1..1000000>"
		end
		if not EconomyService.addTips(player, amount, "debug") then
			return false, "profile not loaded"
		end
		return true, `+{amount} tips (total {EconomyService.getTips(player)})`
	end)
	DebugService.register("xp", "Give yourself XP", "xp <amount>", function(player, args)
		local amount = tonumber(args[1])
		if not amount or amount ~= math.floor(amount) or amount < 1 or amount > 1_000_000 then
			return false, "usage: xp <1..1000000>"
		end
		EconomyService.addXp(player, amount)
		return true, `level {EconomyService.getCourierLevel(player)}`
	end)
	DebugService.register("stats", "Show your tips, XP and deliveries", "stats", function(player)
		local profile = DataService.getProfile(player)
		if not profile then
			return false, "profile not loaded"
		end
		publish(player)
		return true,
			`tips={profile.tips} xp={profile.xp} level={progression.levelFromXp(profile.xp)} deliveries={profile.deliveries}`
	end)
end

function EconomyService.start()
	DataService.onLoaded(function(player)
		publish(player)
	end)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			publish(player)
		end
	end
end

return EconomyService
