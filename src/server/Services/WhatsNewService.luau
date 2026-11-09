--!strict
-- "What's new" (#268): after a big update, returning couriers (not brand
-- new ones) get one panel listing the new things (Config/WhatsNew), once
-- per version (claims["whatsnew"]). The client draws it from the config;
-- the remote only says "show it".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local WhatsNew = require(ReplicatedStorage.Shared.Config.WhatsNew)

local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)

local WhatsNewService = {}

function WhatsNewService.show(player: Player, force: boolean?): boolean
	local profile = DataService.getProfile(player)
	if not profile then
		return false
	end
	if not force then
		if profile.claims["whatsnew"] == WhatsNew.version then
			return false
		end
		if EconomyService.getDeliveries(player) < WhatsNew.minDeliveries then
			return false -- new couriers: onboarding first; they get the next one
		end
	end
	DataService.update(player, function(p)
		p.claims["whatsnew"] = WhatsNew.version
	end)
	Net.event("WhatsNew"):FireClient(player, WhatsNew.version)
	return true
end

function WhatsNewService.init()
	DebugService.register(
		"whatsnew",
		"Show the What's new panel again",
		"whatsnew",
		function(player)
			WhatsNewService.show(player, true)
			return true, `shown {WhatsNew.version}`
		end
	)
end

function WhatsNewService.start()
	DataService.onLoaded(function(player)
		task.delay(WhatsNew.delaySeconds, function()
			if player.Parent then
				WhatsNewService.show(player)
			end
		end)
	end)
	-- Profiles that loaded before this service started.
	for _, player in Players:GetPlayers() do
		task.delay(WhatsNew.delaySeconds, function()
			if player.Parent then
				WhatsNewService.show(player)
			end
		end)
	end
end

return WhatsNewService
