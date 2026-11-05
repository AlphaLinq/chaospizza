--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)
local CalendarConfig = require(ReplicatedStorage.Shared.Config.DailyRewards)
local Persistence = require(ReplicatedStorage.Shared.Config.Progression).persistence
local Weekly = require(ReplicatedStorage.Shared.Util.WeeklyChallenges).new(CalendarConfig)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local OrderService = require(script.Parent.OrderService)
local LeaderboardService = {}
local labels: { TextLabel } = {}
local mirrors: { TextLabel } = {}
local names: { [number]: string } = {}
local refreshing = false
local stopped = false
local function week(): number
	return Weekly.weekFromTime(os.time())
end
function LeaderboardService.addDelivery(player: Player): boolean
	for _ = 1, Persistence.retries do
		if not DataService.isLoaded(player) then
			return false
		end
		local previous = DataService.getProfile(player)
		if
			previous
			and previous.weeklyDeliveries.week > 0
			and previous.weeklyDeliveries.week ~= week()
		then
			if
				not DataService.save(player)
				or not DataService.updateRanking(
					Config.weeklyStorePrefix .. tostring(previous.weeklyDeliveries.week),
					player.UserId,
					previous.weeklyDeliveries.count
				)
			then
				task.wait(Persistence.retryBaseSeconds)
				continue
			end
		end
		if
			DataService.update(player, function(profile)
				if profile.weeklyDeliveries.week ~= week() then
					profile.weeklyDeliveries = { week = week(), count = 0 }
				end
				profile.weeklyDeliveries.count += 1
			end)
		then
			return true
		end
		task.wait(Persistence.retryBaseSeconds)
	end
	return false
end
local function displayName(key: string): string
	local id = tonumber(key)
	if not id then
		return key
	end
	if names[id] then
		return names[id]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(id)
	end)
	names[id] = if ok then name else `Courier {key}`
	return names[id]
end
function LeaderboardService.refresh(): boolean
	if refreshing then
		return false
	end
	refreshing = true
	local currentWeek = week()
	local weeklyName = Config.weeklyStorePrefix .. tostring(currentWeek)
	for _, player in Players:GetPlayers() do
		local profile = DataService.getProfile(player)
		-- Publish only confirmed profile progress; a rank write is repeatable.
		if profile and DataService.save(player) then
			if
				profile.weeklyDeliveries.week > 0
				and profile.weeklyDeliveries.week ~= currentWeek
			then
				DataService.updateRanking(
					Config.weeklyStorePrefix .. tostring(profile.weeklyDeliveries.week),
					player.UserId,
					profile.weeklyDeliveries.count
				)
			end
			local count = if profile.weeklyDeliveries.week == currentWeek
				then profile.weeklyDeliveries.count
				else 0
			DataService.updateRanking(weeklyName, player.UserId, count)
			DataService.updateRanking(Config.pizzeriaStore, player.UserId, profile.pizzeriaLevel)
		end
	end
	local ok = true
	for index, storeName in { weeklyName, Config.pizzeriaStore } do
		local rows = DataService.readRanking(storeName, Config.limit)
		if rows then
			local lines = { if index == 1 then "THIS WEEK · DELIVERIES" else "PIZZERIA LEVEL" }
			for rank, row in rows do
				table.insert(lines, `{rank}. {displayName(row.key)}  ·  {row.value}`)
			end
			if #rows == 0 then
				table.insert(lines, "Your next delivery could put you here!")
			end
			if labels[index] then
				labels[index].Text = table.concat(lines, "\n")
				if mirrors[index] then
					mirrors[index].Text = labels[index].Text
				end
			end
		else
			ok = false
		end
	end
	refreshing = false
	return ok
end
local function build()
	local board = Instance.new("Part")
	board.Name = "PizzaChaosLeaderboard"
	board.Anchored = true
	board.CanCollide = false
	board.Size = Vector3.new(Config.width, Config.height, 0.4)
	board.Position = Vector3.new(Config.x, Config.y, Config.z)
	board.Color = Color3.fromHex("#1F1B24")
	board.Parent = Workspace
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Rankings"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board
	for index = 1, 2 do
		local label = Instance.new("TextLabel")
		label.Name = if index == 1 then "Weekly" else "Pizzeria"
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromHex("#FFF3D6")
		label.Font = Enum.Font.GothamBold
		label.TextSize = 22
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Position = UDim2.new((index - 1) * 0.5, 16, 0, 16)
		label.Size = UDim2.new(0.5, -32, 1, -32)
		label.Text = "Loading the city's finest…"
		label.Parent = surface
		labels[index] = label
	end
	local reverse = surface:Clone()
	reverse.Name = "RankingsBack"
	reverse.Face = Enum.NormalId.Back
	reverse.Parent = board
	mirrors = {
		reverse:FindFirstChild("Weekly") :: TextLabel,
		reverse:FindFirstChild("Pizzeria") :: TextLabel,
	}
	game:BindToClose(function()
		stopped = true
		board:Destroy()
	end)
end
function LeaderboardService.init()
	DebugService.register("leaderboard", "Refresh the Plaza rankings", "leaderboard", function()
		return LeaderboardService.refresh(),
			"rankings refreshed (memory mock when persistence is unavailable)"
	end)
end
function LeaderboardService.start()
	build()
	OrderService.onDelivered(function(player)
		LeaderboardService.addDelivery(player)
	end)
	DataService.onLoaded(function()
		task.defer(LeaderboardService.refresh)
	end)
	task.spawn(function()
		while not stopped do
			LeaderboardService.refresh()
			task.wait(Config.refreshSeconds)
		end
	end)
end
return LeaderboardService
