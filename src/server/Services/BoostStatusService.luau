--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Boosts = require(ReplicatedStorage.Shared.Util.Boosts).new(
	require(ReplicatedStorage.Shared.Config.Products)
)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local CustomerService = require(script.Parent.CustomerService)
local MonetizationService = require(script.Parent.MonetizationService)
local BoostStatusService = {}
function BoostStatusService.refresh(player: Player)
	local profile = DataService.getProfile(player)
	if profile then
		player:SetAttribute(
			"ActiveBoosts",
			HttpService:JSONEncode(Boosts.active(profile.boosts, os.time()))
		)
	end
end
function BoostStatusService.init()
	DebugService.register(
		"boosts",
		"Inspect currently active saved boosts",
		"boosts",
		function(player)
			BoostStatusService.refresh(player)
			return DataService.isLoaded(player), tostring(player:GetAttribute("ActiveBoosts"))
		end
	)
end
function BoostStatusService.start()
	-- CustomerService exposes this hook, so paid odds need no edits to its source.
	CustomerService.addModifierProvider(MonetizationService.getOddsModifiers)
	DataService.onLoaded(BoostStatusService.refresh)
	DataService.onUpdated(BoostStatusService.refresh)
	for _, player in Players:GetPlayers() do
		BoostStatusService.refresh(player)
	end
end
return BoostStatusService
