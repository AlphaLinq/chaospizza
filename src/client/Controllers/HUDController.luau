--!strict
-- Minimal in-run HUD (brief ch. 20): order card, tips counter, delivery popup,
-- onboarding hints. Reads player attributes; never decides anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local HUDController = {}

local player = Players.LocalPlayer

local ONBOARDING_HINTS: { [string]: string } = {
	pickup = "Pick up your first order at the 🍕 Pizza HQ counter!",
	deliver = "Follow the yellow arrow and deliver the pizza!",
	again = "Nice! Grab another order at Pizza HQ.",
}

local COLORS = {
	panel = Color3.fromHex("#1F1B24"),
	cheese = Color3.fromHex("#FFD24A"),
	tomato = Color3.fromHex("#D6452F"),
	cream = Color3.fromHex("#FFF3D6"),
}

local gui: ScreenGui
local orderCard: Frame
local orderText: TextLabel
local tipsLabel: TextLabel
local hintLabel: TextLabel
local popup: Frame
local popupTips: TextLabel
local popupLine: TextLabel

local shownTips = 0
local hintToken = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, name: string, textSize: number, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = COLORS.cream
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	-- Tips counter (top right, away from the default mobile jump button)
	local tipsFrame = Instance.new("Frame")
	tipsFrame.Name = "Tips"
	tipsFrame.AnchorPoint = Vector2.new(1, 0)
	tipsFrame.Position = UDim2.new(1, -12, 0, 12)
	tipsFrame.Size = UDim2.fromOffset(150, 44)
	tipsFrame.BackgroundColor3 = COLORS.panel
	tipsFrame.BackgroundTransparency = 0.15
	tipsFrame.Parent = gui
	corner(tipsFrame, 12)
	tipsLabel = label(tipsFrame, "Amount", 22, Enum.Font.FredokaOne)
	tipsLabel.Size = UDim2.fromScale(1, 1)
	tipsLabel.TextColor3 = COLORS.cheese
	tipsLabel.Text = "💰 0"

	-- Order card (top centre)
	orderCard = Instance.new("Frame")
	orderCard.Name = "Order"
	orderCard.AnchorPoint = Vector2.new(0.5, 0)
	orderCard.Position = UDim2.new(0.5, 0, 0, 12)
	orderCard.Size = UDim2.fromOffset(320, 52)
	orderCard.BackgroundColor3 = COLORS.tomato
	orderCard.BackgroundTransparency = 0.05
	orderCard.Visible = false
	orderCard.Parent = gui
	corner(orderCard, 12)
	orderText = label(orderCard, "Text", 17)
	orderText.Size = UDim2.new(1, -16, 1, 0)
	orderText.Position = UDim2.fromOffset(8, 0)

	-- Hint (bottom centre, above the mobile thumbstick area)
	hintLabel = label(gui, "Hint", 20, Enum.Font.GothamBold)
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -150)
	hintLabel.Size = UDim2.new(0.8, 0, 0, 50)
	hintLabel.TextStrokeTransparency = 0.35
	hintLabel.Text = ""

	-- Delivery popup (centre)
	popup = Instance.new("Frame")
	popup.Name = "Delivered"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.36)
	popup.Size = UDim2.fromOffset(340, 110)
	popup.BackgroundColor3 = COLORS.panel
	popup.BackgroundTransparency = 0.1
	popup.Visible = false
	popup.Parent = gui
	corner(popup, 16)
	popupTips = label(popup, "Tips", 34, Enum.Font.FredokaOne)
	popupTips.Size = UDim2.new(1, 0, 0, 50)
	popupTips.Position = UDim2.fromOffset(0, 8)
	popupTips.TextColor3 = COLORS.cheese
	popupLine = label(popup, "Line", 16, Enum.Font.GothamMedium)
	popupLine.Size = UDim2.new(1, -20, 0, 44)
	popupLine.Position = UDim2.fromOffset(10, 58)

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function setTips(target: number)
	-- Count up quickly for a "juicy" feel.
	local from = shownTips
	shownTips = target
	if target <= from then
		tipsLabel.Text = `💰 {target}`
		return
	end
	task.spawn(function()
		local steps = 12
		for i = 1, steps do
			if shownTips ~= target then
				return
			end
			tipsLabel.Text = `💰 {math.floor(from + (target - from) * i / steps)}`
			task.wait(0.03)
		end
	end)
end

local function showHint(text: string, seconds: number?)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	if seconds then
		task.delay(seconds, function()
			if hintToken == token then
				hintLabel.Text = ""
				HUDController.refreshOnboarding()
			end
		end)
	end
end

function HUDController.refreshOnboarding()
	local step = player:GetAttribute("OnboardingStep")
	local text = typeof(step) == "string" and ONBOARDING_HINTS[step] or nil
	if text then
		hintLabel.Text = text
	elseif hintLabel.Text ~= "" and ONBOARDING_HINTS.again == hintLabel.Text then
		hintLabel.Text = ""
	end
end

local function refreshOrder()
	local customer = player:GetAttribute("OrderCustomer")
	local labelText = player:GetAttribute("OrderLabel")
	if typeof(customer) == "string" then
		orderText.Text = `🍕 {customer} · {labelText or ""}`
		orderCard.Visible = true
	else
		orderCard.Visible = false
	end
end

local function showDelivery(result: { [string]: any })
	popupTips.Text = `+{result.tips or 0} 💰`
	popupLine.Text = `{result.customer or ""}: “{result.line or ""}”`
	popup.Visible = true
	popup.Size = UDim2.fromOffset(240, 80)
	TweenService
		:Create(popup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(340, 110),
		})
		:Play()
	task.delay(2, function()
		popup.Visible = false
	end)
end

function HUDController.start()
	build()

	local tips = player:GetAttribute("Tips")
	shownTips = if typeof(tips) == "number" then tips else 0
	tipsLabel.Text = `💰 {shownTips}`
	player:GetAttributeChangedSignal("Tips"):Connect(function()
		local value = player:GetAttribute("Tips")
		if typeof(value) == "number" then
			setTips(value)
		end
	end)

	player:GetAttributeChangedSignal("OrderId"):Connect(refreshOrder)
	player:GetAttributeChangedSignal("OnboardingStep"):Connect(HUDController.refreshOnboarding)
	refreshOrder()
	HUDController.refreshOnboarding()

	Net.event("Hint").OnClientEvent:Connect(function(text: unknown)
		if typeof(text) == "string" then
			showHint(text, 3)
		end
	end)
	Net.event("DeliveryResult").OnClientEvent:Connect(function(result: unknown)
		if typeof(result) == "table" then
			showDelivery(result :: any)
		end
	end)
end

return HUDController
