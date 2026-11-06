--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Comfort)
local Policy = require(ReplicatedStorage.Shared.Util.Comfort).new(Config)
local Data = require(script.Parent.DataService)
local Debug = require(script.Parent.DebugService)
local Moni = require(script.Parent.MonetizationService)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local limiter = require(ReplicatedStorage.Shared.Util.RateLimiter).new(Config.rate, Config.burst)
local Service = {}
local function publish(player: Player)
	local profile = Data.getProfile(player)
	for _, item in Config.items do
		-- Consumers should stay quiet until the persisted preferences arrive.
		player:SetAttribute(
			item.attribute,
			if profile then Policy.read(profile)[item.attribute] else true
		)
	end
	player:SetAttribute("ComfortReady", profile ~= nil)
end
function Service.set(player: Player, key: string, enabled: unknown): (boolean, string)
	if not limiter:allow(player) then
		return false, "Please wait before changing comfort settings."
	end
	local ok, reason = Transaction.run(player, function(profile)
		local accepted = Policy.apply(profile, key, enabled, os.time())
		return accepted,
			if accepted then "Comfort preference saved." else "Choose a valid comfort preference."
	end, "comfort")
	publish(player)
	return ok, reason
end
function Service.init()
	Debug.register(
		"comfort",
		"Save reduced motion or flash preferences",
		"comfort <motion|flashes> <on|off>",
		function(player, args)
			local key, enabled = Policy.action((args[1] or "") .. "." .. (args[2] or ""))
			if not key then
				return false, "Choose motion/flashes and on/off."
			end
			return Service.set(player, key, enabled)
		end
	)
end
function Service.start()
	Moni.registerAction("comfort", function(player, action)
		local key, enabled = Policy.action(action)
		if not key then
			return false, "Choose a valid comfort preference."
		end
		return Service.set(player, key, enabled)
	end)
	Data.onLoaded(publish)
	Data.onUpdated(publish)
	Players.PlayerAdded:Connect(publish)
	Players.PlayerRemoving:Connect(function(player)
		limiter:remove(player)
	end)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end
return Service
