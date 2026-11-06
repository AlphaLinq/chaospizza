--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.Ticker)
local Feed = require(ReplicatedStorage.Shared.Util.Ticker).new(Config)
local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Data = require(script.Parent.DataService)
local Orders = require(script.Parent.OrderService)
local Events = require(script.Parent.EventService)
local Debug = require(script.Parent.DebugService)
local Moni = require(script.Parent.MonetizationService)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local limiter = require(ReplicatedStorage.Shared.Util.RateLimiter).new(Config.rate, Config.burst)
local Service = {}
local giant: { [string]: any } = {}
local rareAt: { [Player]: number } = {}
local function publish()
	local encoded = HttpService:JSONEncode(Feed.rows(Workspace:GetServerTimeNow()))
	if ReplicatedStorage:GetAttribute("MomentTicker") ~= encoded then
		ReplicatedStorage:SetAttribute("MomentTicker", encoded)
	end
end
function Service.push(
	kind: string,
	key: string,
	names: { string },
	customer: string?,
	rarity: string?
): boolean
	local ok = Feed.push(kind, key, names, customer, rarity, Workspace:GetServerTimeNow())
	if ok then
		publish()
	end
	return ok
end
local function preference(player: Player)
	local p = Data.getProfile(player)
	if p then
		player:SetAttribute("TickerEnabled", p.claims[Config.settingKey] == nil)
	end
end
function Service.setEnabled(player: Player, enabled: boolean): (boolean, string)
	if not limiter:allow(player) then
		return false, "Please wait before changing city highlights."
	end
	local ok, reason = Transaction.run(player, function(profile)
		profile.claims[Config.settingKey] = if enabled then nil else os.time()
		return true, "City highlights saved."
	end, "ticker_setting")
	preference(player)
	return ok, reason
end
local function delivered(player: Player, order: any, info: any)
	if info and info.giant then
		local id = order.id
		if not giant[id] then
			giant[id] = {}
			task.delay(Config.giantGatherSeconds, function()
				local names = giant[id]
				giant[id] = nil
				if names then
					table.sort(names)
					Service.push("giant", "giant." .. id, names)
				end
			end)
		end
		table.insert(giant[id], player.DisplayName)
		return
	end
	local now = Workspace:GetServerTimeNow()
	if rareAt[player] and now - rareAt[player] < Config.playerSeconds then
		return
	end
	for _, c in Customers do
		if c.id == order.customerId and Config.rare[c.rarity] then
			if
				Service.push(
					"rare",
					"delivery." .. order.id,
					{ player.DisplayName },
					c.displayName,
					c.rarity
				)
			then
				rareAt[player] = now
			end
			break
		end
	end
end
function Service.init()
	Debug.register(
		"ticker",
		"Preview real city highlight publishing or save its visibility",
		"ticker <rare|giant|mega|on|off>",
		function(player, args)
			local mode = args[1]
			if mode == "on" or mode == "off" then
				return Service.setEnabled(player, mode == "on")
			end
			if mode ~= "rare" and mode ~= "giant" and mode ~= "mega" then
				return false, "Choose rare, giant, mega, on or off."
			end
			local ok =
				Service.push(mode, "preview." .. mode, { player.DisplayName }, "Santa", "Legendary")
			return ok,
				if ok then "City highlight published." else "Highlight rate limit; wait a moment."
		end
	)
end
function Service.start()
	Moni.registerAction("ticker", function(player, action)
		if action ~= "on" and action ~= "off" then
			return false, "Choose on or off."
		end
		return Service.setEnabled(player, action == "on")
	end)
	Data.onLoaded(preference)
	Data.onUpdated(preference)
	for _, player in Players:GetPlayers() do
		preference(player)
	end
	Orders.onDelivered(function(player, order, _tips, _count, info)
		delivered(player, order, info)
	end)
	Events.onStarted(function()
		if Events.isMega() then
			Service.push("mega", "mega", {})
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		rareAt[player] = nil
		limiter:remove(player)
	end)
	publish()
	task.spawn(function()
		while true do
			task.wait(Config.refreshSeconds)
			publish()
		end
	end)
end
return Service
