--!strict
-- Hourly city goal (#133): "120 pizzas for the city this hour". Every delivery
-- on this server counts. When the goal is reached, everyone who delivered at
-- least Tuning.CityGoal.minContribution times in the window gets the reward
-- once (late helpers too), and the plaza fires fireworks (client).
--
-- Replication (CityState): CityGoalTarget, CityGoalProgress, CityGoalEndsAt
-- (server time), CityGoalDone. Player attribute CityGoalMine = own count.
-- State lives in memory per server; rewards are keyed by UserId so leaving and
-- rejoining the same server cannot pay twice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CityGoal = require(ReplicatedStorage.Shared.Util.CityGoal)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)

local CityGoalService = {}

local cfg = Tuning.CityGoal
local state: CityGoal.State
local cityState: Instance? = nil
local boardText: TextLabel? = nil
local boardFill: Frame? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function playerCount(): number
	return #Players:GetPlayers()
end

local function endsAt(): number
	return (state.window + 1) * cfg.windowSeconds
end

local function publish()
	local cs = cityState
	if cs then
		cs:SetAttribute("CityGoalTarget", state.target)
		cs:SetAttribute("CityGoalProgress", math.min(state.progress, state.target))
		cs:SetAttribute("CityGoalEndsAt", endsAt())
		cs:SetAttribute("CityGoalDone", state.completed or nil)
	end
	local text, fill = boardText, boardFill
	if text and fill then
		text.Text = if state.completed
			then `🎆 CITY GOAL DONE! {state.target}/{state.target}`
			else `🏙️ CITY GOAL: {math.min(state.progress, state.target)}/{state.target} pizzas`
		fill.Size = UDim2.fromScale(math.clamp(state.progress / state.target, 0, 1), 1)
	end
end

local function grant(player: Player)
	EconomyService.addTips(player, cfg.rewardTips, "city_goal")
	EconomyService.addXp(player, cfg.rewardXp)
	Net.event("Hint")
		:FireClient(player, `🎆 City goal reached! +{cfg.rewardTips} tips for helping out.`)
end

local function payOut()
	for _, userId in CityGoal.claimable(state, cfg) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			grant(player)
		else
			state.rewarded[userId] = nil -- not here right now: claim on next delivery
		end
	end
end

local function reset()
	state = CityGoal.new(CityGoal.window(now(), cfg), playerCount(), cfg)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("CityGoalMine", 0)
	end
	publish()
end

local function onDelivery(player: Player)
	if CityGoal.window(now(), cfg) ~= state.window then
		reset()
	end
	local completedNow = CityGoal.record(state, player.UserId)
	player:SetAttribute("CityGoalMine", state.contributions[player.UserId])
	if completedNow then
		for _, other in Players:GetPlayers() do
			local mine = state.contributions[other.UserId] or 0
			if mine < cfg.minContribution then
				Net.event("Hint"):FireClient(
					other,
					`🎆 City goal reached! Deliver {cfg.minContribution - mine} more this hour to share the reward.`
				)
			end
		end
	end
	payOut()
	publish()
end

local function buildBoard()
	local map = MapService.getMapFolder()
	local plaza = map:FindFirstChild("Plaza") or map
	local pos = MapLayout.cityGoalBoard
	local model = Instance.new("Model")
	model.Name = "CityGoalBoard"
	local function part(name: string, size: Vector3, cframe: CFrame, color: string): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = Color3.fromHex(color)
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	part("PostL", Vector3.new(0.6, 9, 0.6), CFrame.new(pos.x - 4.5, 4.9, pos.z), "#2B2633")
	part("PostR", Vector3.new(0.6, 9, 0.6), CFrame.new(pos.x + 4.5, 4.9, pos.z), "#2B2633")
	local board = part("Board", Vector3.new(10, 4, 0.5), CFrame.new(pos.x, 8, pos.z), "#2B2633")

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(500, 200)
		gui.LightInfluence = 0
		gui.MaxDistance = 200
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -20, 0.55, 0)
		text.Position = UDim2.fromOffset(10, 8)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromHex("#FFF3D6")
		text.Parent = gui
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, -40, 0.25, 0)
		bar.Position = UDim2.new(0, 20, 0.65, 0)
		bar.BackgroundColor3 = Color3.fromHex("#4A4255")
		bar.BorderSizePixel = 0
		bar.Parent = gui
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromHex("#7FE07A")
		fill.BorderSizePixel = 0
		fill.Parent = bar
		gui.Parent = board
		-- Front face drives both; the back mirrors it via the same updates.
		if face == Enum.NormalId.Front then
			boardText, boardFill = text, fill
		else
			local function mirror()
				if boardText and boardFill then
					text.Text = boardText.Text
					fill.Size = boardFill.Size
				end
			end
			if boardText and boardFill then
				boardText:GetPropertyChangedSignal("Text"):Connect(mirror)
				boardFill:GetPropertyChangedSignal("Size"):Connect(mirror)
			end
		end
	end
	model.Parent = plaza
end

function CityGoalService.getState(): CityGoal.State
	return state
end

function CityGoalService.init()
	state = CityGoal.new(0, 1, cfg)
	DebugService.register(
		"citygoal",
		"Hourly city goal: show, add progress, complete, reset",
		"citygoal [add <n>|complete|reset]",
		function(player, args)
			local sub = args[1]
			if sub == "add" then
				local n = math.clamp(tonumber(args[2]) or 1, 1, 500)
				for _ = 1, n do
					onDelivery(player)
				end
			elseif sub == "complete" then
				while not state.completed do
					onDelivery(player)
				end
			elseif sub == "reset" then
				reset()
			end
			return true,
				`city goal {state.progress}/{state.target} done={state.completed} mine={state.contributions[player.UserId] or 0} ends in {math.floor(
					endsAt() - now()
				)}s`
		end
	)
end

function CityGoalService.start()
	cityState = ReplicatedStorage:WaitForChild("CityState", 30)
	buildBoard()
	reset()
	OrderService.onDelivered(function(player)
		onDelivery(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		CityGoal.observePlayers(state, playerCount(), cfg)
		player:SetAttribute("CityGoalMine", state.contributions[player.UserId] or 0)
		publish()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if CityGoal.window(now(), cfg) ~= state.window then
				reset()
			end
		end
	end)
end

return CityGoalService
