--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.MovementUpgrades)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Progression = require(ReplicatedStorage.Shared.Util.Progression).new(
	ProgressionConfig,
	require(ReplicatedStorage.Shared.Config.Rarities) :: any,
	require(ReplicatedStorage.Shared.Config.Pizzeria) :: any
)
local Logic = require(ReplicatedStorage.Shared.Util.MovementUpgrades).new(
	require(ReplicatedStorage.Shared.Config.Movement),
	require(ReplicatedStorage.Shared.Config.Tuning).Movement.maxSpeedBonus,
	Progression.levelFromXp
)
local Looks = require(ReplicatedStorage.Shared.Util.Cosmetics).new(
	require(ReplicatedStorage.Shared.Config.Cosmetics)
)
local Visuals = require(script.Parent.Parent.Util.RideVisuals)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local CharacterService = require(script.Parent.CharacterService)
local MonetizationService = require(script.Parent.MonetizationService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DebugService = require(script.Parent.DebugService)
local MovementUpgradeService = {}
local passes: { [Player]: boolean } = {}
local signatures: { [Player]: string } = {}
local connections: { [Player]: RBXScriptConnection } = {}
function MovementUpgradeService.refresh(player: Player, force: boolean?)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local early = passes[player] == true
	local tier = Logic.effective(profile, early)
	player:SetAttribute("RideState", HttpService:JSONEncode(Logic.catalog(profile, early)))
	player:SetAttribute("MovementTier", tier.tier)
	local look = Looks.effective(profile, "movement")
	local signature = `{tier.tier}:{look.id}`
	if signatures[player] == signature and not force then
		return
	end
	signatures[player] = signature
	CharacterService.setSpeedBonus(player, tier.speedBonus)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if humanoid:GetAttribute("RideBaseJumpPower") == nil then
			humanoid:SetAttribute("RideBaseJumpPower", humanoid.JumpPower)
			humanoid:SetAttribute("RideBaseJumpHeight", humanoid.JumpHeight)
		end
		local multiplier = if tier.tier == 2 then 1 + Config.skateboardJumpBonus else 1
		humanoid.JumpPower = (humanoid:GetAttribute("RideBaseJumpPower") :: number) * multiplier
		humanoid.JumpHeight = (humanoid:GetAttribute("RideBaseJumpHeight") :: number) * multiplier
	end
	if character then
		Visuals.apply(character, tier.tier, look)
	end
end
function MovementUpgradeService.buy(player: Player, target: number): (boolean, string)
	if passes[player] == nil then
		return false, "Your rides are still loading. Try again."
	end
	for _ = 1, ProgressionConfig.persistence.retries do
		local evaluated = false
		local accepted = false
		local reason = "Your profile is still loading. Try again."
		local ok = DataService.transaction(player, function(profile)
			evaluated = true
			accepted, reason = Logic.buy(profile, target, passes[player] == true)
			return accepted
		end, true)
		if ok then
			MovementUpgradeService.refresh(player, true)
			EconomyService.refresh(player)
			local entry = Logic.get(target)
			if entry then
				AnalyticsService.economy(player, "Sink", entry.cost, entry.displayName, "movement")
			end
			return true, reason
		end
		if evaluated then
			return false, if accepted then "Couldn't save your ride. Please try again." else reason
		end
		if not DataService.isLoaded(player) then
			break
		end
		task.wait(ProgressionConfig.persistence.retryBaseSeconds)
	end
	return false, "Couldn't save your ride. Please try again."
end
local function onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", Config.characterWaitSeconds)
	character:WaitForChild("Humanoid", Config.characterWaitSeconds)
	if player.Character == character then
		MovementUpgradeService.refresh(player, true)
	end
end
local function onPlayer(player: Player)
	connections[player] = player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end
local function loaded(player: Player)
	task.spawn(function()
		local owns = MonetizationService.hasPass(player, "EarlyEScooter")
		if player.Parent ~= Players then
			return
		end
		passes[player] = owns
		MovementUpgradeService.refresh(player, true)
	end)
end
function MovementUpgradeService.init()
	DebugService.register(
		"ride",
		"Inspect or buy the next ride tier",
		"ride [buy <1-4>|respawn]",
		function(player, args)
			if args[1] == "respawn" then
				player:LoadCharacterAsync()
				return true, "respawned with saved ride"
			end
			if args[1] == "buy" then
				local target = tonumber(args[2] or "")
				if not target then
					return false, "usage: ride buy <1-4>"
				end
				return MovementUpgradeService.buy(player, target)
			end
			MovementUpgradeService.refresh(player, true)
			return true, tostring(player:GetAttribute("RideState"))
		end
	)
end
function MovementUpgradeService.start()
	MonetizationService.registerAction("ride", function(player, action)
		local target = string.match(action, "^upgrade%.([1-4])$")
		if not target then
			return false, "Choose your next ride upgrade."
		end
		return MovementUpgradeService.buy(player, tonumber(target) :: number)
	end)
	DataService.onLoaded(loaded)
	DataService.onUpdated(function(player)
		MovementUpgradeService.refresh(player)
	end)
	MonetizationService.onPassChanged(function(player, key, owned)
		if key == "EarlyEScooter" then
			passes[player] = owned
			MovementUpgradeService.refresh(player, true)
		end
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
		if DataService.isLoaded(player) then
			loaded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local connection = connections[player]
		if connection then
			connection:Disconnect()
		end
		connections[player], signatures[player], passes[player] = nil, nil, nil
	end)
end
return MovementUpgradeService
