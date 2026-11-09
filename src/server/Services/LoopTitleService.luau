--!strict
-- Loop titles (#227): long-term goals for the new loop. Counters live in
-- profile.claims (Tuning.LoopTitles); crossing a goal adds the title
-- cosmetic to the owned list, tells the courier, and refreshes the
-- cosmetics state so it can be equipped (CourierTitle shows it overhead).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local CosmeticConfig = require(ReplicatedStorage.Shared.Config.Cosmetics)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local DayCycleService = require(script.Parent.DayCycleService)
local DebugService = require(script.Parent.DebugService)
local OrderService = require(script.Parent.OrderService)

local LoopTitleService = {}

local names: { [string]: string } = {}
for _, item in CosmeticConfig.items do
	names[item.id] = item.name
end

-- Grants every title whose goal is met and not yet owned.
function LoopTitleService.check(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local newOnes = {}
	for _, def in Tuning.LoopTitles do
		local count = profile.claims[def.counter]
		if
			typeof(count) == "number"
			and count >= def.goal
			and not profile.cosmetics.owned[def.cosmetic]
		then
			table.insert(newOnes, def.cosmetic)
		end
	end
	if #newOnes == 0 then
		return
	end
	DataService.update(player, function(p)
		for _, id in newOnes do
			p.cosmetics.owned[id] = true
		end
	end)
	CosmeticService.refresh(player, true)
	for _, id in newOnes do
		AnalyticsService.custom(player, `title_{id}`)
		Net.event("Hint")
			:FireClient(
				player,
				`🏷️ New title unlocked: {names[id] or id}! Equip it in Cosmetics.`
			)
	end
end

-- Adds to a counter, then checks the titles.
function LoopTitleService.bump(player: Player, counter: string, amount: number?)
	DataService.update(player, function(p)
		p.claims[counter] = (tonumber(p.claims[counter]) or 0) + (amount or 1)
	end)
	LoopTitleService.check(player)
end

function LoopTitleService.init()
	DebugService.register(
		"titles",
		"Loop titles: show counters, or bump one",
		"titles [show | bump <counter> <n>]",
		function(player, args)
			if args[1] == "bump" and args[2] then
				LoopTitleService.bump(player, args[2], tonumber(args[3]) or 1)
			end
			local profile = DataService.getProfile(player)
			if not profile then
				return false, "no profile"
			end
			local parts = {}
			for _, def in Tuning.LoopTitles do
				local owned = profile.cosmetics.owned[def.cosmetic] == true
				table.insert(
					parts,
					`{def.cosmetic} {profile.claims[def.counter] or 0}/{def.goal}{if owned
						then " ✓"
						else ""}`
				)
			end
			return true, table.concat(parts, " · ")
		end
	)
end

function LoopTitleService.start()
	DataService.onLoaded(function(player)
		LoopTitleService.check(player) -- e.g. challenges done before titles existed
	end)
	OrderService.onDelivered(function(player, _, _, _, info)
		if info.daredevil then
			LoopTitleService.bump(player, "loop.daredevil")
		end
		if DayCycleService.isNight() then
			LoopTitleService.bump(player, "loop.night")
		end
	end)
	for _, player in Players:GetPlayers() do
		LoopTitleService.check(player)
	end
end

return LoopTitleService
