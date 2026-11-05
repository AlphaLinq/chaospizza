--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Codes)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local MonetizationService = require(script.Parent.MonetizationService)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local Level = require(script.Parent.EconomyService).getProgression().levelFromXp
local Logic = require(ReplicatedStorage.Shared.Util.Codes).new(
	Config,
	Level,
	require(ReplicatedStorage.Shared.Util.RewardGrant).apply
)
local limiter = require(ReplicatedStorage.Shared.Util.RateLimiter).new(Config.rate, Config.burst)
local Players = game:GetService("Players")
local CodesService = {}
function CodesService.redeem(player: Player, raw: any): (boolean, string)
	if not limiter:allow(player) then
		return false, "Try the next code in a moment."
	end
	if not DataService.isLoaded(player) then
		return false, "Your profile is still loading."
	end
	return Transaction.run(player, function(profile)
		return Logic.redeem(profile, raw, os.time())
	end, "promo_code")
end
function CodesService.init()
	DebugService.register("code", "Redeem a promotion code", "code <code>", function(player, args)
		return CodesService.redeem(player, args[1])
	end)
end
function CodesService.start()
	MonetizationService.registerAction("code", CodesService.redeem)
	Players.PlayerRemoving:Connect(function(player)
		limiter:remove(player)
	end)
end
return CodesService
