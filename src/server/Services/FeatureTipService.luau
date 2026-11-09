--!strict
-- First-time tips (#211): FeatureTipService.show(player, id) sends a short
-- explainer card (Config/FeatureTips) once per courier, remembered in the
-- profile (claims["tip.<id>"]). Before the profile has loaded nothing is
-- shown, so a returning courier never sees a tip twice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FeatureTips = require(ReplicatedStorage.Shared.Config.FeatureTips)
local Net = require(ReplicatedStorage.Shared.Net)

local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)

local FeatureTipService = {}

local shownThisSession: { [Player]: { [string]: boolean } } = {}

local function key(id: string): string
	return `tip.{id}`
end

function FeatureTipService.show(player: Player, id: string, force: boolean?): boolean
	if not FeatureTips[id] then
		return false
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return false
	end
	local session = shownThisSession[player] or {}
	shownThisSession[player] = session
	if not force and (session[id] or profile.claims[key(id)]) then
		return false
	end
	session[id] = true
	DataService.update(player, function(p)
		p.claims[key(id)] = true
	end)
	Net.event("FeatureTip"):FireClient(player, id)
	return true
end

-- Every courier online (the vote, the finale notice).
function FeatureTipService.showAll(id: string)
	for _, player in Players:GetPlayers() do
		FeatureTipService.show(player, id)
	end
end

function FeatureTipService.init()
	DebugService.register(
		"tips",
		"First-time tips: show one again, or forget them all",
		"tips [reset | show <OfferBoard|Vote|Challenge|Finale|MicroChaos>]",
		function(player, args)
			if args[1] == "show" then
				local ok = FeatureTipService.show(player, args[2] or "", true)
				return ok, if ok then `shown {args[2]}` else "unknown tip"
			elseif args[1] == "reset" then
				shownThisSession[player] = nil
				DataService.update(player, function(p)
					for id in FeatureTips do
						p.claims[key(id)] = nil
					end
				end)
				return true, "tips forgotten"
			end
			return false, "usage: tips [reset | show <id>]"
		end
	)
end

function FeatureTipService.start()
	Players.PlayerRemoving:Connect(function(player)
		shownThisSession[player] = nil
	end)
end

return FeatureTipService
