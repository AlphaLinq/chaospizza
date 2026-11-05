--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.Cosmetics)
local Logic = require(ReplicatedStorage.Shared.Util.Cosmetics).new(Config)
local Visuals = require(script.Parent.Parent.Util.CosmeticVisuals)
local Persistence = require(ReplicatedStorage.Shared.Config.Progression).persistence
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local MonetizationService = require(script.Parent.MonetizationService)
local DebugService = require(script.Parent.DebugService)
local CosmeticService = {}
local signatures: { [Player]: string } = {}
local playerConnections: { [Player]: RBXScriptConnection } = {}
local characterConnections: { [Player]: { RBXScriptConnection } } = {}
local function plotFor(player: Player): Model?
	local map = Workspace:FindFirstChild("PizzaMap")
	if map then
		for _, model in map:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
				return model
			end
		end
	end
	return nil
end
function CosmeticService.refresh(player: Player, force: boolean?)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	player:SetAttribute("CosmeticsState", HttpService:JSONEncode(Logic.catalog(profile)))
	local looks: any = {}
	local ids: { string } = {}
	for _, slot in Config.slots do
		looks[slot] = Logic.effective(profile, slot)
		table.insert(ids, if looks[slot] then looks[slot].id else "")
	end
	local signature = table.concat(ids, ":")
	if signatures[player] == signature and not force then
		return
	end
	signatures[player] = signature
	if player.Character then
		Visuals.character(player.Character, looks)
	end
	local plot = plotFor(player)
	if plot then
		Visuals.plot(plot, looks)
	end
end
local function mutate(player: Player, id: string, buy: boolean): boolean
	for _ = 1, Persistence.retries do
		local evaluated = false
		local price = 0
		local ok = DataService.transaction(player, function(profile)
			evaluated = true
			local item = Logic.get(id)
			if not item then
				return false
			end
			price = item.price or 0
			return if buy then Logic.buy(profile, id) else Logic.equip(profile, id)
		end, true)
		if ok then
			CosmeticService.refresh(player)
			EconomyService.refresh(player)
			if buy and price > 0 then
				AnalyticsService.economy(player, "Sink", price, id, "cosmetic")
			end
			return true
		end
		if evaluated or not DataService.isLoaded(player) then
			return false
		end
		task.wait(Persistence.retryBaseSeconds)
	end
	return false
end
function CosmeticService.buy(player: Player, id: string): boolean
	return mutate(player, id, true)
end
function CosmeticService.equip(player: Player, id: string): boolean
	return mutate(player, id, false)
end
local function onCharacter(player: Player, character: Model)
	local old = characterConnections[player]
	if old then
		for _, connection in old do
			connection:Disconnect()
		end
	end
	characterConnections[player] = {
		character.ChildAdded:Connect(function(child)
			if child.Name == "PizzaBox" then
				local profile = DataService.getProfile(player)
				if profile then
					Visuals.box(character, Logic.effective(profile, "box"))
				end
			end
		end),
	}
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("UpperTorso", 3)
	if player.Character == character then
		CosmeticService.refresh(player, true)
	end
end
local function onPlayer(player: Player)
	playerConnections[player] = player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end
function CosmeticService.init()
	DebugService.register(
		"cosmetic",
		"Inspect or equip owned courier looks",
		"cosmetic [equip <id>]",
		function(player, args)
			if args[1] == "equip" then
				local ok = CosmeticService.equip(player, args[2] or "")
				return ok, if ok then "look equipped" else "look is not owned"
			end
			CosmeticService.refresh(player, true)
			return true, tostring(player:GetAttribute("CosmeticsState"))
		end
	)
end
function CosmeticService.start()
	MonetizationService.registerAction("cosmetic", function(player, action)
		local mode, id = string.match(action, "^(%a+)%.([%w_]+)$")
		local ok = if mode == "buy" and id
			then CosmeticService.buy(player, id)
			elseif mode == "equip" and id then CosmeticService.equip(player, id)
			else false
		return ok,
			if ok then "Courier look updated." else "This look isn't owned or you need more tips."
	end)
	DataService.onLoaded(function(player)
		CosmeticService.refresh(player, true)
	end)
	DataService.onUpdated(function(player)
		CosmeticService.refresh(player)
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
		CosmeticService.refresh(player, true)
	end
	Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			local owner = instance:GetAttribute("OwnerUserId")
			if type(owner) == "number" then
				local player = Players:GetPlayerByUserId(owner)
				if player then
					task.defer(CosmeticService.refresh, player, true)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		signatures[player] = nil
		local old: { RBXScriptConnection } = characterConnections[player] or {}
		for _, connection in old do
			connection:Disconnect()
		end
		characterConnections[player] = nil
		local connection = playerConnections[player]
		if connection then
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end)
end
return CosmeticService
