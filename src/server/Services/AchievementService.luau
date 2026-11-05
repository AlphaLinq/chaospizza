--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxBadges = game:GetService("BadgeService")
local Config = require(ReplicatedStorage.Shared.Config.Badges)
local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Logic = require(ReplicatedStorage.Shared.Util.Achievements)
local DataService = require(script.Parent.DataService)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local DebugService = require(script.Parent.DebugService)
local OrderService = require(script.Parent.OrderService)
local EventService = require(script.Parent.EventService)
local StyleService = require(script.Parent.StyleService)
local MapService = require(script.Parent.MapService)
local AchievementService = {}
local busy: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local logged: { [Player]: { [string]: boolean } } = {}
local mega: { [Player]: boolean } = {}
local giantIds: { [Player]: string } = {}
local giantConnections: { [Player]: RBXScriptConnection } = {}
function AchievementService.mark(player: Player, key: string): boolean
	local known = false
	for _, item in Config.items do
		if item.key == key then
			known = true
			break
		end
	end
	if not known then
		return false
	end
	return (
		Transaction.run(player, function(profile)
			profile.claims[`achievement.{key}`] = profile.claims[`achievement.{key}`] or os.time()
			return true, "Achievement recorded."
		end, "achievement")
	)
end
local function award(player: Player, definition: any)
	local profile = DataService.getProfile(player)
	if not profile or not Logic.met(profile, definition, Customers) then
		return
	end
	if profile.claims[`achievement.{definition.key}`] == nil then
		if not AchievementService.mark(player, definition.key) then
			return
		end
	end
	if definition.badgeId == 0 then
		local seen = logged[player] or {}
		logged[player] = seen
		if not seen[definition.key] then
			seen[definition.key] = true
			print(
				`[AchievementService] {definition.key} earned by {player.UserId}; badgeId=0 (no API call)`
			)
		end
		return
	end
	local ledgerKey = `badge.{definition.badgeId}`
	if profile.claims[ledgerKey] ~= nil then
		return
	end
	for attempt = 1, Config.retries do
		if player.Parent ~= Players or not DataService.isLoaded(player) then
			return
		end
		local ok, granted = pcall(function()
			return RobloxBadges:UserHasBadgeAsync(player.UserId, definition.badgeId)
				or RobloxBadges:AwardBadgeAsync(player.UserId, definition.badgeId)
		end)
		if ok and granted then
			Transaction.run(player, function(draft)
				draft.claims[ledgerKey] = os.time()
				return true, "Badge awarded."
			end, "badge")
			return
		end
		if attempt < Config.retries then
			task.wait(Config.retrySeconds * attempt)
		end
	end
	warn(`[AchievementService] {definition.key} award pending for {player.UserId}`)
end
function AchievementService.refresh(player: Player)
	dirty[player] = true
	if busy[player] then
		return
	end
	busy[player] = true
	task.spawn(function()
		while dirty[player] and player.Parent == Players and DataService.isLoaded(player) do
			dirty[player] = nil
			for _, item in Config.items do
				award(player, item)
			end
		end
		busy[player] = nil
	end)
end
function AchievementService.init()
	DebugService.register(
		"achievement",
		"Record an achievement using its real grant path",
		"achievement <key>",
		function(player, args)
			local ok = AchievementService.mark(player, args[1] or "")
			AchievementService.refresh(player)
			return ok, if ok then "Achievement queued (ID=0 only logs)." else "Unknown achievement."
		end
	)
end
function AchievementService.start()
	DataService.onLoaded(function(player)
		if EventService.isMega() then
			mega[player] = true
		end
		AchievementService.refresh(player)
	end)
	DataService.onUpdated(AchievementService.refresh)
	OrderService.onDelivered(function(player, order, _tips, _count, info: any?)
		if info and info.giant or giantIds[player] == order.id then
			AchievementService.mark(player, "GiantDelivery")
			giantIds[player] = nil
		end
		if table.find(EventService.getActiveEvents(), "Tornado") then
			local address = MapService.getAddress(order.addressId)
			if address then
				local distance = (address.doorPosition - MapService.getCounterPart().Position).Magnitude
				if
					table.find(
						StyleService.evaluate(player, order.createdAt, distance).tags,
						"AirDelivery"
					)
				then
					AchievementService.mark(player, "TornadoAir")
				end
			end
		end
		AchievementService.refresh(player)
	end)
	EventService.onStarted(function()
		if EventService.isMega() then
			for _, player in Players:GetPlayers() do
				mega[player] = true
			end
		end
	end)
	EventService.onEnded(function()
		local participants = mega
		mega = {}
		for player in participants do
			if player.Parent == Players then
				AchievementService.mark(player, "FirstMega")
			end
		end
	end)
	local function watchGiant(player: Player)
		local function changed()
			local id = player:GetAttribute("GiantOrderId")
			if type(id) == "string" then
				giantIds[player] = id
			end
		end
		giantConnections[player] = player:GetAttributeChangedSignal("GiantOrderId"):Connect(changed)
		changed()
	end
	Players.PlayerAdded:Connect(watchGiant)
	for _, player in Players:GetPlayers() do
		watchGiant(player)
		AchievementService.refresh(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local connection = giantConnections[player]
		if connection then
			connection:Disconnect()
		end
		giantConnections[player], giantIds[player] = nil, nil
		busy[player], dirty[player], logged[player], mega[player] = nil, nil, nil, nil
	end)
end
return AchievementService
