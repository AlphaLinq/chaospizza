--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.ProgressRewards)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Progression = require(ReplicatedStorage.Shared.Util.Progression).new(
	ProgressionConfig,
	require(ReplicatedStorage.Shared.Config.Rarities) :: any,
	require(ReplicatedStorage.Shared.Config.Pizzeria) :: any
)
local Logic = require(ReplicatedStorage.Shared.Util.ProgressRewards).new(
	Config,
	require(ReplicatedStorage.Shared.Config.Customers),
	Progression.levelFromXp
)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DebugService = require(script.Parent.DebugService)
local ProgressRewardService = {}
local dirty: { [Player]: boolean } = {}
local running: { [Player]: boolean } = {}
local playerConnections: { [Player]: RBXScriptConnection } = {}
local function publish(player: Player)
	local profile = DataService.getProfile(player)
	if profile then
		player:SetAttribute("ProgressRewards", HttpService:JSONEncode(profile.progressRewards))
		player:SetAttribute("CourierTitle", Logic.title(profile))
	end
end
function ProgressRewardService.claim(player: Player): boolean
	local profile = DataService.getProfile(player)
	if not profile then
		return false
	end
	if not Logic.plan(profile).changed then
		publish(player)
		return true
	end
	local granted: any = nil
	local ok = DataService.transaction(player, function(draft)
		granted = Logic.claim(draft)
		return true
	end, true)
	if not ok then
		return false
	end
	publish(player)
	EconomyService.refresh(player)
	if granted and granted.changed then
		local message = if #granted.milestones > 0
			then `Customer Book milestone! +{granted.tips} tips`
			else `Courier level {granted.levelTo} reward! +{granted.tips} tips`
		if #granted.cosmetics > 0 then
			message ..= " · New cosmetic unlocked!"
		end
		Net.event("Hint"):FireClient(player, message)
		if granted.tips > 0 then
			AnalyticsService.economy(player, "Source", granted.tips, "progress", "progress_reward")
		end
	end
	return true
end
local function queue(player: Player)
	dirty[player] = true
	if running[player] then
		return
	end
	running[player] = true
	task.spawn(function()
		while dirty[player] and player.Parent == Players and DataService.isLoaded(player) do
			dirty[player] = nil
			if not ProgressRewardService.claim(player) and DataService.isLoaded(player) then
				dirty[player] = true
				task.wait(ProgressionConfig.persistence.retryBaseSeconds)
			end
		end
		running[player] = nil
	end)
end
local function onCharacter(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") or player.Character ~= character then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CourierTitle"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(220, 28)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.MaxDistance = 70
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Color3.fromHex("#FFD24A")
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.Parent = billboard
	local function update()
		local title = player:GetAttribute("CourierTitle")
		label.Text = if type(title) == "string" then title else ""
	end
	local connection = player:GetAttributeChangedSignal("CourierTitle"):Connect(update)
	billboard.Destroying:Connect(function()
		connection:Disconnect()
	end)
	update()
end
local function onPlayer(player: Player)
	playerConnections[player] = player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end
function ProgressRewardService.init()
	DebugService.register(
		"progressrewards",
		"Claim or inspect earned book and level rewards",
		"progressrewards",
		function(player)
			local ok = ProgressRewardService.claim(player)
			local profile = DataService.getProfile(player)
			return ok,
				if profile
					then HttpService:JSONEncode(profile.progressRewards)
					else "profile unavailable"
		end
	)
end
function ProgressRewardService.start()
	DataService.onLoaded(queue)
	DataService.onUpdated(queue)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
		if DataService.isLoaded(player) then
			queue(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		running[player] = nil
		local connection = playerConnections[player]
		if connection then
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end)
end
return ProgressRewardService
