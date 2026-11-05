--!strict
-- Hourly city goal (#133), client side: a small HUD bar (top right, under the
-- chaos bar and streak) and fireworks over the plaza when the goal is done.
-- Reads CityState CityGoalTarget / CityGoalProgress / CityGoalEndsAt /
-- CityGoalDone and the player's CityGoalMine. Visual only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CityGoalController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)

local FIREWORK_COLORS = { "#FF4FD8", "#3FE0FF", "#FFD23F", "#7FE07A", "#FF7A45" }
local BAR_Y = 116

local text: TextLabel
local fill: Frame

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CityGoalHUD"
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.Name = "CityGoal"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -12, 0, BAR_Y)
	frame.Size = UDim2.fromOffset(150, 20)
	frame.BackgroundColor3 = Color3.fromHex("#2B2633")
	frame.BackgroundTransparency = 0.15
	frame.ClipsDescendants = true
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = frame
	fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromHex("#7FE07A")
	fill.BorderSizePixel = 0
	fill.Parent = frame
	text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 12
	text.TextColor3 = Color3.fromHex("#FFF3D6")
	text.TextStrokeTransparency = 0.4
	text.Text = ""
	text.Parent = frame
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function burst(origin: Vector3, color: Color3, sparks: number)
	local folder = Instance.new("Folder")
	folder.Name = "Firework"
	folder.Parent = Workspace
	for i = 1, sparks do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.8, 0.8, 0.8)
		p.CFrame = CFrame.new(origin)
		p.Parent = folder
		local a = i / sparks * math.pi * 2
		local up = (math.random() - 0.3) * 1.4
		local dir = Vector3.new(math.cos(a), up, math.sin(a)).Unit
		TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Quad), {
			CFrame = CFrame.new(origin + dir * (14 + math.random() * 6) - Vector3.new(0, 4, 0)),
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
		}):Play()
	end
	task.delay(1.6, function()
		folder:Destroy()
	end)
end

local function fireworks()
	local scale = settings.particleScale(player:GetAttribute("EffectQuality"))
	local rockets = math.clamp(math.floor(4 + 8 * scale), 3, 12)
	local sparks = math.clamp(math.floor(10 + 14 * scale), 8, 24)
	local board = MapLayout.cityGoalBoard
	task.spawn(function()
		for _ = 1, rockets do
			local origin = Vector3.new(
				board.x + 22 + (math.random() - 0.5) * 60,
				45 + math.random() * 20,
				board.z + (math.random() - 0.5) * 60
			)
			burst(origin, Color3.fromHex(FIREWORK_COLORS[math.random(1, #FIREWORK_COLORS)]), sparks)
			task.wait(0.35 + math.random() * 0.3)
		end
	end)
end

function CityGoalController.start()
	build()
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	local wasDone = state:GetAttribute("CityGoalDone") == true
	local function refresh()
		local target = state:GetAttribute("CityGoalTarget")
		local progress = state:GetAttribute("CityGoalProgress")
		local endsAt = state:GetAttribute("CityGoalEndsAt")
		if typeof(target) ~= "number" or typeof(progress) ~= "number" or target <= 0 then
			text.Text = ""
			return
		end
		local done = state:GetAttribute("CityGoalDone") == true
		local mine = player:GetAttribute("CityGoalMine")
		local minutes = if typeof(endsAt) == "number"
			then math.max(0, math.ceil((endsAt - Workspace:GetServerTimeNow()) / 60))
			else 0
		local need = Tuning.CityGoal.minContribution
		local mark = if typeof(mine) == "number" and mine >= need
			then "✅"
			else `{mine or 0}/{need}`
		text.Text = if done
			then `🎆 City goal done! · {minutes}m`
			else `🏙️ {progress}/{target} · you {mark} · {minutes}m`
		TweenService:Create(fill, TweenInfo.new(0.4), {
			Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1),
		}):Play()
		if done and not wasDone then
			fireworks()
		end
		wasDone = done
	end
	for _, name in { "CityGoalTarget", "CityGoalProgress", "CityGoalEndsAt", "CityGoalDone" } do
		state:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("CityGoalMine"):Connect(refresh)
	refresh()
	-- the minutes left tick down
	task.spawn(function()
		while true do
			task.wait(20)
			refresh()
		end
	end)
end

return CityGoalController
