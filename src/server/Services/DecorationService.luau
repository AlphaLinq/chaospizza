--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Decorations)
local Logic = require(ReplicatedStorage.Shared.Util.Decorations).new(Config)
local Visuals = require(ReplicatedStorage.Shared.Runtime.DecorVisuals)
local Mounts = require(script.Parent.Parent.Util.DecorMounts)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local Data = require(script.Parent.DataService)
local Moni = require(script.Parent.MonetizationService)
local Debug = require(script.Parent.DebugService)
local Analytics = require(script.Parent.AnalyticsService)
local limiter = require(ReplicatedStorage.Shared.Util.RateLimiter).new(Config.rate, Config.burst)
local Service = {}
local signatures: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any
local function plotFor(player: Player): Model?
	local map = Workspace:FindFirstChild("PizzaMap")
	if map then
		for _, model in map:GetChildren() do
			if
				model:IsA("Model")
				and model:GetAttribute("OwnerUserId") == player.UserId
				and model:FindFirstChild("PizzeriaCounter")
			then
				return model
			end
		end
	end
	return nil
end
function Service.refresh(player: Player)
	local profile = Data.getProfile(player)
	if not profile then
		return
	end
	local plot = plotFor(player)
	local mounts = if plot then Mounts.get(plot) else {}
	local ready = plot ~= nil
	for _, slot in Config.slots do
		if not mounts[slot.id] then
			ready = false
		end
	end
	local encoded = HttpService:JSONEncode(Logic.snapshot(profile, ready))
	if player:GetAttribute("DecorationsState") ~= encoded then
		player:SetAttribute("DecorationsState", encoded)
	end
	if not plot or not ready then
		return
	end
	local ids = {}
	for _, slot in Config.slots do
		table.insert(
			ids,
			(Logic.selected(profile, slot.id) or "") .. tostring(mounts[slot.id].WorldCFrame)
		)
	end
	local signature = table.concat(ids, ":")
	if signatures[plot] == signature and plot:FindFirstChild(Config.folderName) then
		return
	end
	signatures[plot] = signature
	local old = plot:FindFirstChild(Config.folderName)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.folderName
	folder.Parent = plot
	for _, slot in Config.slots do
		local id = Logic.selected(profile, slot.id)
		if id then
			Visuals.draw(folder, mounts[slot.id].WorldCFrame, Logic.get(id))
		end
	end
end
function Service.apply(player: Player, action: string): (boolean, string)
	if not limiter:allow(player) then
		return false, "wait"
	end
	local mode = Logic.action(action)
	if not mode then
		return false, "missing"
	end
	local plot = plotFor(player)
	if not plot then
		return false, "loading"
	end
	local mounts = Mounts.get(plot)
	for _, slot in Config.slots do
		if not mounts[slot.id] then
			return false, "loading"
		end
	end
	local spent = 0
	local ok, reason = Transaction.run(player, function(profile)
		local before = profile.tips
		local accepted, message = Logic.apply(profile, action)
		spent = before - profile.tips
		return accepted, message
	end, "decoration")
	if ok and spent > 0 then
		Analytics.economy(player, "Sink", spent, action, "decoration")
	end
	Service.refresh(player)
	return ok, reason
end
function Service.init()
	Debug.register(
		"decor",
		"Inspect, buy or place pizzeria decorations",
		"decor [buy <id>|place <slot> <id>|clear <slot>]",
		function(player, args)
			if not args[1] or args[1] == "state" then
				Service.refresh(player)
				return true, tostring(player:GetAttribute("DecorationsState"))
			end
			return Service.apply(player, table.concat(args, "."))
		end
	)
end
function Service.start()
	Moni.registerAction("decor", Service.apply)
	Data.onLoaded(Service.refresh)
	Data.onUpdated(Service.refresh)
	Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			local owner = instance:GetAttribute("OwnerUserId")
			local player = if type(owner) == "number" then Players:GetPlayerByUserId(owner) else nil
			if player then
				task.defer(Service.refresh, player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:remove(player)
	end)
	for _, player in Players:GetPlayers() do
		Service.refresh(player)
	end
end
return Service
