--!strict
-- First-time tip cards (#211). The server sends a tip id ("FeatureTip");
-- this shows its card (Config/FeatureTips) near the bottom centre, clear of
-- the jump button, with a big "Got it" button. One card at a time, queued;
-- each hides by itself after Tuning.FeatureTips.showSeconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FeatureTips = require(ReplicatedStorage.Shared.Config.FeatureTips)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local FeatureTipController = {}

local player = Players.LocalPlayer
local queue: { string } = {}
local showing = false
local card: Frame
local title: TextLabel
local body: TextLabel
local token = 0

local function showNext()
	local id = table.remove(queue, 1)
	if not id then
		showing = false
		card.Visible = false
		return
	end
	local tip = FeatureTips[id]
	if not tip then
		showNext()
		return
	end
	showing = true
	token += 1
	local mine = token
	title.Text = `{tip.icon} {tip.title}`
	body.Text = tip.text
	card.Visible = true
	task.delay(Tuning.FeatureTips.showSeconds, function()
		if token == mine then
			showNext()
		end
	end)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FeatureTips"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -150)
	card.Size = UDim2.new(0.9, 0, 0, 120)
	card.BackgroundColor3 = Color3.fromHex("#2B2633")
	card.BackgroundTransparency = 0.05
	card.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(440, 120)
	limit.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#FFD23F")
	stroke.Thickness = 2
	stroke.Parent = card
	title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 26)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 20
	title.TextColor3 = Color3.fromHex("#FFD23F")
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card
	body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(12, 32)
	body.Size = UDim2.new(1, -120, 1, -38)
	body.Font = Enum.Font.Gotham
	body.TextSize = 15
	body.TextWrapped = true
	body.TextColor3 = Color3.fromHex("#FFF3D6")
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = card
	local ok = Instance.new("TextButton")
	ok.Name = "GotIt"
	ok.AnchorPoint = Vector2.new(1, 1)
	ok.Position = UDim2.new(1, -10, 1, -10)
	ok.Size = UDim2.fromOffset(96, 44) -- thumb-sized
	ok.BackgroundColor3 = Color3.fromHex("#FFD23F")
	ok.Font = Enum.Font.FredokaOne
	ok.TextSize = 18
	ok.TextColor3 = Color3.fromHex("#2B2633")
	ok.Text = "Got it"
	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 10)
	okCorner.Parent = ok
	ok.Activated:Connect(function()
		token += 1
		showNext()
	end)
	ok.Parent = card
	card.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

function FeatureTipController.start()
	build()
	Net.event("FeatureTip").OnClientEvent:Connect(function(id: unknown)
		if typeof(id) ~= "string" or table.find(queue, id) then
			return
		end
		table.insert(queue, id)
		if not showing then
			showNext()
		end
	end)
end

return FeatureTipController
