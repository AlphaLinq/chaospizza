--!strict
-- Convoy bonus (#232). The city is shared but deliveries are solo; this
-- rewards arriving together: two couriers who deliver within
-- Tuning.Convoy.windowSeconds and radius of each other both get a small flat
-- tip bonus ("🚚 Convoy with Anna!"). Flat, not a multiplier, so it doesn't
-- feed the tip inflation the style and event multipliers already push.
-- Matching is pure (Util/Convoy); the server uses the courier's own position
-- at the moment the delivery is accepted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Convoy = require(ReplicatedStorage.Shared.Util.Convoy)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local DailyService = require(script.Parent.DailyService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local FeatureTipService = require(script.Parent.FeatureTipService)
local LoopTitleService = require(script.Parent.LoopTitleService)
local OrderService = require(script.Parent.OrderService)

local ConvoyService = {}

local cfg = Tuning.Convoy
local log: { Convoy.Entry } = {}
local DEBUG_USER_ID = -1 -- a pretend partner for QA

local function pay(player: Player, partnerName: string)
	EconomyService.addTips(player, cfg.tips, "convoy")
	AnalyticsService.custom(player, "convoy")
	DailyService.recordProgress(player, "convoy", 1) -- weekly Convoy Crew (#240)
	LoopTitleService.bump(player, "loop.convoy") -- Convoy Captain (#251)
	FeatureTipService.show(player, "Convoy") -- first convoy explains itself (#238)
	Net.event("Hint"):FireClient(player, `🚚 Convoy with {partnerName}! +{cfg.tips} tips`)
end

local function delivered(player: Player)
	local root = CharacterService.getRootPart(player)
	if not root then
		return
	end
	local now = os.clock()
	local p = root.Position
	Convoy.prune(log, now, cfg :: any)
	local partners = Convoy.match(log, player.UserId, p.X, p.Z, now, cfg :: any)
	Convoy.record(log, player.UserId, player.DisplayName, p.X, p.Z, now)
	if #partners == 0 then
		return
	end
	local names = {}
	for _, e in partners do
		table.insert(names, e.name)
		local partner = Players:GetPlayerByUserId(e.userId)
		if partner then
			pay(partner, player.DisplayName)
		end
	end
	pay(player, table.concat(names, " & "))
end

function ConvoyService.init()
	DebugService.register(
		"convoy",
		"Convoy: pretend a courier just delivered next to you",
		"convoy",
		function(player)
			local root = CharacterService.getRootPart(player)
			if not root then
				return false, "no character"
			end
			Convoy.prune(log, os.clock(), cfg :: any)
			Convoy.record(
				log,
				DEBUG_USER_ID,
				"Test Courier",
				root.Position.X,
				root.Position.Z,
				os.clock()
			)
			return true, `deliver within {cfg.windowSeconds}s and {cfg.radius} studs for a convoy`
		end
	)
end

function ConvoyService.start()
	OrderService.onDelivered(function(player, _, _, _, info)
		-- A giant order is already a team delivery with its own reward.
		if not info.giant then
			delivered(player)
		end
	end)
end

return ConvoyService
