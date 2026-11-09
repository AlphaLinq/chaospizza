--!strict
-- High five (#246), client side: a round 🙌 button (PC: H) shows while
-- another courier stands close; it only asks the server (Net "HighFive").
-- Every client draws the 🙌 burst between the two (Net "HighFiveDone").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local HighFiveController = {}

local player = Players.LocalPlayer
local cfg = Tuning.HighFive
local ACCENT = Color3.fromHex("#7FE7FF")
local DARK = Color3.fromHex("#2B2633")

local button: TextButton

local function request()
	Net.event("HighFive"):FireServer()
end

local function someoneClose(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	for _, other in Players:GetPlayers() do
		local c = other ~= player and other.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if
			r
			and r:IsA("BasePart")
			and (r.Position - root.Position).Magnitude <= cfg.buttonRadius
		then
			return true
		end
	end
	return false
end

local function burst(a: Vector3, b: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "HighFiveBurst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new((a + b) / 2 + Vector3.new(0, 4, 0))
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(40, 40)
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "🙌"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = billboard
	billboard.Parent = anchor
	anchor.Parent = Workspace
	TweenService:Create(
		billboard,
		TweenInfo.new(0.35, Enum.EasingStyle.Back),
		{ Size = UDim2.fromOffset(90, 90) }
	):Play()
	task.delay(0.9, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end)
	task.delay(1.3, function()
		anchor:Destroy()
	end)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HighFive"
	gui.ResetOnSpawn = false
	button = Instance.new("TextButton")
	button.Name = "HighFive"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -18, 0.5, 108) -- under the toss button
	button.Size = UDim2.fromOffset(72, 72)
	button.BackgroundColor3 = ACCENT
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 28
	button.TextColor3 = DARK
	button.Text = if UserInputService.KeyboardEnabled then "🙌\nH" else "🙌"
	button.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.Activated:Connect(request)
	button.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

function HighFiveController.start()
	build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then
			request()
		end
	end)
	Net.event("HighFiveDone").OnClientEvent:Connect(function(a, b)
		if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			burst(a, b)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then
			elapsed = 0
			button.Visible = someoneClose()
		end
	end)
end

return HighFiveController
