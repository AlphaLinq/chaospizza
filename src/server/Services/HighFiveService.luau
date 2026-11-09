--!strict
-- High five (#246). A tiny social gesture: when another courier is close a
-- 🙌 button shows (HighFiveController); if both raise a hand within
-- Tuning.HighFive.windowSeconds, both get a token tip, a hint and everyone
-- sees a 🙌 burst between them (Net "HighFiveDone"). The server checks the
-- distance itself; the same pair pays once per pair cooldown. Count kept in
-- claims["social.highFives"] for the profile / a future title.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HighFive = require(ReplicatedStorage.Shared.Util.HighFive)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)

local HighFiveService = {}

local cfg = Tuning.HighFive
local requests: { [number]: HighFive.Request } = {}
local paid: { [string]: number } = {}
local lastRequest: { [Player]: number } = {}
local DEBUG_USER_ID = -2

local function reward(player: Player, partnerName: string, pays: boolean)
	if pays then
		EconomyService.addTips(player, cfg.tips, "high_five")
		DataService.update(player, function(profile)
			profile.claims["social.highFives"] = (profile.claims["social.highFives"] or 0) + 1
		end)
	end
	AnalyticsService.custom(player, "high_five")
	Net.event("Hint"):FireClient(
		player,
		if pays
			then `🙌 High five with {partnerName}! +{cfg.tips} tips`
			else `🙌 High five with {partnerName}!`
	)
end

-- Raises `player`'s hand. Returns ok + message (debug uses it too).
function HighFiveService.request(player: Player): (boolean, string)
	local root = CharacterService.getRootPart(player)
	if not root then
		return false, "no character"
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < cfg.requestCooldownSeconds then
		return false, "easy there"
	end
	lastRequest[player] = now
	HighFive.prune(requests, now, cfg :: any)
	local p = root.Position
	local partnerId = HighFive.match(requests, player.UserId, p.X, p.Z, now, cfg :: any)
	if not partnerId then
		requests[player.UserId] = { t = now, x = p.X, z = p.Z }
		-- Tell whoever is close that a hand is up.
		for _, other in Players:GetPlayers() do
			local r = other ~= player and CharacterService.getRootPart(other)
			if r and (r.Position - p).Magnitude <= cfg.radius then
				Net.event("Hint")
					:FireClient(other, `🙌 {player.DisplayName} wants a high five! Tap 🙌`)
			end
		end
		return true, "hand up: waiting for a partner"
	end
	requests[partnerId] = nil
	local partner = Players:GetPlayerByUserId(partnerId)
	local pays = HighFive.claimPair(paid, player.UserId, partnerId, now, cfg :: any)
	local partnerName = if partner then partner.DisplayName else "Test Courier"
	reward(player, partnerName, pays)
	local partnerRoot = partner and CharacterService.getRootPart(partner)
	if partner then
		reward(partner, player.DisplayName, pays)
	end
	Net.event("HighFiveDone"):FireAllClients(p, if partnerRoot then partnerRoot.Position else p)
	return true, `high five with {partnerName}{if pays then "" else " (no tips: pair cooldown)"}`
end

function HighFiveService.init()
	DebugService.register(
		"highfive",
		"High five: a pretend courier raises a hand next to you",
		"highfive",
		function(player)
			local root = CharacterService.getRootPart(player)
			if not root then
				return false, "no character"
			end
			requests[DEBUG_USER_ID] =
				{ t = os.clock(), x = root.Position.X + 3, z = root.Position.Z }
			return true, `hand up next to you: tap 🙌 within {cfg.windowSeconds}s`
		end
	)
end

function HighFiveService.start()
	Net.onServerEvent("HighFive", { ratePerSecond = 2, burst = 3 }, function(player)
		local ok, message = HighFiveService.request(player)
		if not ok and message ~= "easy there" then
			Net.event("Hint"):FireClient(player, message)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		requests[player.UserId] = nil
		lastRequest[player] = nil
	end)
end

return HighFiveService
