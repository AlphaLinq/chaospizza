--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.PizzeriaLikes)
local Logic = require(ReplicatedStorage.Shared.Util.PizzeriaLikes).new(Config)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Persistence = require(ReplicatedStorage.Shared.Config.Progression).persistence
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local PizzeriaLikeService = {}
local joined: { [Player]: number } = {}
local limiter = RateLimiter.new(Config.requestRate, Config.requestBurst)
local attachments: { [Player]: Attachment } = {}
local function counterFor(player: Player): BasePart?
	local map = Workspace:FindFirstChild("PizzaMap")
	if map then
		for _, model in map:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
				local counter = model:FindFirstChild("PizzeriaCounter")
				if counter and counter:IsA("BasePart") then
					return counter
				end
			end
		end
	end
	return nil
end
function PizzeriaLikeService.refresh()
	local counts: { [number]: number } = {}
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local profile = DataService.getProfile(player)
		local count = if profile then Logic.count(profile.likes, now) else 0
		counts[player.UserId] = count
		player:SetAttribute("PizzeriaLikes", count)
	end
	local leaders = Logic.leaders(counts)
	for _, player in Players:GetPlayers() do
		local favourite = leaders[player.UserId] == true
		player:SetAttribute("PizzeriaFavourite", favourite)
		local attachment = attachments[player]
		local label = attachment and attachment:FindFirstChild("LikesSign")
		local text = label and label:FindFirstChild("Label")
		if text and text:IsA("TextLabel") then
			text.Text = `{counts[player.UserId] or 0} likes today{if favourite
				then "\nCity favourite"
				else "\nVisit & leave a like"}`
			text.TextColor3 = Color3.fromHex(if favourite then "#FFD24A" else "#FFF3D6")
		end
	end
end
function PizzeriaLikeService.like(from: Player, owner: Player): (boolean, string)
	if not limiter:allow(from) then
		return false, "Give the next like a moment."
	end
	if from.Parent ~= Players or owner.Parent ~= Players or not DataService.isLoaded(from) then
		return false, "This pizzeria is still loading."
	end
	local counter = counterFor(owner)
	local root = from.Character and from.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = from.Character and from.Character:FindFirstChildOfClass("Humanoid")
	if
		not counter
		or not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
		or (root.Position - counter.Position).Magnitude > Config.distance
	then
		return false, "Get closer to the pizzeria counter to leave a like."
	end
	for _ = 1, Persistence.retries do
		local evaluated, accepted = false, false
		local reason = "This pizzeria is still loading."
		local ok = DataService.transaction(owner, function(profile)
			evaluated = true
			accepted, reason = Logic.apply(
				profile,
				from.UserId,
				owner.UserId,
				os.time(),
				os.clock() - (joined[from] or os.clock())
			)
			return accepted
		end, true)
		if ok then
			PizzeriaLikeService.refresh()
			AnalyticsService.custom(from, "pizzeria_like", 1)
			return true, reason
		end
		if evaluated then
			return false, if accepted then "Couldn't save your like. Please try again." else reason
		end
		if not DataService.isLoaded(owner) then
			break
		end
		task.wait(Persistence.retryBaseSeconds)
		-- A busy profile can yield: never accept a remote visit after either player moves or leaves.
		if
			from.Parent ~= Players
			or owner.Parent ~= Players
			or from.Character ~= root.Parent
			or not root.Parent
			or humanoid.Health <= 0
			or not counter.Parent
			or counterFor(owner) ~= counter
			or (root.Position - counter.Position).Magnitude > Config.distance
		then
			return false, "Get closer to the pizzeria counter to leave a like."
		end
	end
	return false, "Couldn't save your like. Please try again."
end
local function decorate(player: Player)
	local counter = counterFor(player)
	if not counter then
		return
	end
	local old = attachments[player]
	if old and old.Parent == counter then
		return
	end
	if old then
		old:Destroy()
	end
	local anchor = Instance.new("Attachment")
	anchor.Name = "PizzeriaLikes"
	anchor.Position = Vector3.new(-2, 2.4, 0)
	local sign = Instance.new("BillboardGui")
	sign.Name = "LikesSign"
	sign.Size = UDim2.fromOffset(220, 54)
	sign.StudsOffset = Vector3.new(0, 1.3, 0)
	sign.MaxDistance = Config.signDistance
	sign.Adornee = anchor
	sign.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundColor3 = Color3.fromHex("#1F1B24")
	label.BackgroundTransparency = 0.15
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextWrapped = true
	label.TextColor3 = Color3.fromHex("#FFF3D6")
	label.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LikePizzeria"
	prompt.ActionText = "Like · once a day"
	prompt.ObjectText = `{player.DisplayName}'s pizzeria`
	prompt.HoldDuration = Config.promptHoldSeconds
	prompt.MaxActivationDistance = Config.distance
	prompt.KeyboardKeyCode = Enum.KeyCode.L
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(visitor)
		local _, message = PizzeriaLikeService.like(visitor, player)
		Net.event("Hint"):FireClient(visitor, message)
	end)
	anchor.Parent = counter
	attachments[player] = anchor
	PizzeriaLikeService.refresh()
end
function PizzeriaLikeService.init()
	DebugService.register(
		"likes",
		"Inspect or leave nearby pizzeria likes",
		"likes [ready|give <userId>]",
		function(player, args)
			if args[1] == "ready" then
				joined[player] = os.clock() - Config.minimumSessionSeconds
				return true, "QA minimum visit time reached"
			elseif args[1] == "give" then
				local id = tonumber(args[2] or "")
				if not id or id <= 0 or id % 1 ~= 0 or id >= math.huge then
					return false, "choose a player userId"
				end
				local owner = Players:GetPlayerByUserId(id)
				if not owner then
					return false, "pizzeria owner is not here"
				end
				return PizzeriaLikeService.like(player, owner)
			end
			PizzeriaLikeService.refresh()
			return true,
				`likes={player:GetAttribute("PizzeriaLikes")} favourite={player:GetAttribute(
					"PizzeriaFavourite"
				)}`
		end
	)
end
function PizzeriaLikeService.start()
	Players.PlayerAdded:Connect(function(player)
		joined[player] = os.clock()
	end)
	for _, player in Players:GetPlayers() do
		joined[player] = os.clock()
		decorate(player)
	end
	DataService.onLoaded(decorate)
	DataService.onUpdated(PizzeriaLikeService.refresh)
	Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			local id = instance:GetAttribute("OwnerUserId")
			if type(id) == "number" then
				local player = Players:GetPlayerByUserId(id)
				if player then
					task.defer(decorate, player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
		limiter:remove(player)
		local attachment = attachments[player]
		if attachment then
			attachment:Destroy()
		end
		attachments[player] = nil
		task.defer(PizzeriaLikeService.refresh)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.refreshSeconds)
			PizzeriaLikeService.refresh()
		end
	end)
end
return PizzeriaLikeService
