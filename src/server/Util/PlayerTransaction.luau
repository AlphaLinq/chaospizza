--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.Parent.Services.DataService)
local EconomyService = require(script.Parent.Parent.Services.EconomyService)
local AnalyticsService = require(script.Parent.Parent.Services.AnalyticsService)
local Persistence = require(ReplicatedStorage.Shared.Config.Progression).persistence
local PlayerTransaction = {}
function PlayerTransaction.run(
	player: Player,
	mutate: (any) -> (boolean, string),
	reason: string
): (boolean, string)
	for _ = 1, Persistence.retries do
		local evaluated, accepted, earned = false, false, 0
		local message = "Your profile is still loading."
		local ok = DataService.transaction(player, function(profile)
			evaluated = true
			local before = profile.tips
			accepted, message = mutate(profile)
			earned = profile.tips - before
			return accepted
		end, true)
		if ok then
			EconomyService.refresh(player)
			if earned > 0 then
				AnalyticsService.economy(player, "Source", earned, reason, reason)
			end
			return true, message
		end
		if evaluated then
			return false, if accepted then "Couldn't save. Please try again." else message
		end
		if not DataService.isLoaded(player) then
			return false, message
		end
		task.wait(Persistence.retryBaseSeconds)
	end
	return false, "Your profile is busy. Please try again."
end
return PlayerTransaction
