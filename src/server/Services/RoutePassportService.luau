--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.RoutePassport)
local Layout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Passport = require(ReplicatedStorage.Shared.Util.RoutePassport)
local Data = require(script.Parent.DataService)
local Orders = require(script.Parent.OrderService)
local Debug = require(script.Parent.DebugService)
local Service = {}
local registry = Passport.registry(Layout.buildings, Config)
local pending: { [Player]: { [string]: number } } = {}
function Service.refresh(player: Player)
	local profile = Data.getProfile(player)
	if not profile then
		return
	end
	local count, total = Passport.summary(profile, registry, Config)
	player:SetAttribute("RouteStampTotal", total)
	player:SetAttribute("RouteStampCount", count)
end
local function flush(player: Player)
	local stamps = pending[player]
	if not stamps then
		return
	end
	local changed = false
	local evaluated = false
	local committed = Data.transaction(player, function(profile)
		evaluated = true
		for id, at in stamps do
			changed = Passport.stamp(profile, registry, id, at, Config) or changed
		end
		return changed
	end)
	if committed or (evaluated and not changed) then
		pending[player] = nil
	end
	Service.refresh(player)
end
function Service.record(player: Player, addressId: string)
	if not registry.known[addressId] then
		return
	end
	local stamps = pending[player] or {}
	stamps[addressId] = stamps[addressId] or os.time()
	pending[player] = stamps
	-- A concurrent persisted purchase may hold DataService's session lock.
	-- Keep this bounded set until onUpdated runs after that transaction.
	flush(player)
end
function Service.init()
	Debug.register(
		"passport",
		"City passport: show stamps or assign the next missing address",
		"passport [next]",
		function(player, args)
			local profile = Data.getProfile(player)
			if not profile then
				return false, "profile not ready"
			end
			local count, total, nextId = Passport.summary(profile, registry, Config)
			if args[1] == "next" then
				if Orders.getOrder(player) then
					return false, "finish or cancel your current order first"
				end
				if not nextId then
					return true, "all addresses stamped"
				end
				local order = Orders.assignOrder(player, { addressId = nextId, kind = "normal" })
				return order ~= nil,
					if order then "passport order to " .. nextId else "could not assign order"
			elseif args[1] ~= nil then
				return false, "usage: passport [next]"
			end
			Service.refresh(player)
			return true,
				string.format(
					"%d/%d addresses stamped; next %s",
					count,
					total,
					nextId or "complete"
				)
		end
	)
end
function Service.start()
	Data.onLoaded(Service.refresh)
	Data.onUpdated(function(player)
		flush(player)
	end)
	Orders.onDelivered(function(player, order)
		Service.record(player, order.addressId)
	end)
	for _, player in Players:GetPlayers() do
		Service.refresh(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end
return Service
