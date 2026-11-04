--!strict
-- Minimal in-run HUD (brief ch. 20): order card, tips counter, delivery popup,
-- onboarding hints. Reads player attributes; never decides anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local RARITY_COLOR: { [string]: Color3 } = {}
for _, r in Rarities do
	RARITY_COLOR[r.id] = Color3.fromHex(r.colorHex)
end

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
local popupStyle: TextLabel
local chaosFill: Frame
local chaosText: TextLabel

local shownTips = 0
local hintToken = 0
local popupToken = 0

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
	popup.Size = UDim2.fromOffset(340, 150)
	popup.BackgroundColor3 = COLORS.panel
	popup.BackgroundTransparency = 0.1
	popup.Visible = false
	popup.Parent = gui
	corner(popup, 16)
	popupTips = label(popup, "Tips", 34, Enum.Font.FredokaOne)
	popupTips.Size = UDim2.new(1, 0, 0, 50)
	popupTips.Position = UDim2.fromOffset(0, 8)
	popupTips.TextColor3 = COLORS.cheese
	popupStyle = label(popup, "Style", 16, Enum.Font.FredokaOne)
	popupStyle.Size = UDim2.new(1, -20, 0, 24)
	popupStyle.Position = UDim2.fromOffset(10, 54)
	popupStyle.TextColor3 = Color3.fromHex("#7FE7FF")
	popupLine = label(popup, "Line", 16, Enum.Font.GothamMedium)
	popupLine.Size = UDim2.new(1, -20, 0, 64)
	popupLine.Position = UDim2.fromOffset(10, 78)

	-- City chaos meter (mirrors the giant gauge on the plaza)
	local chaos = Instance.new("Frame")
	chaos.Name = "Chaos"
	chaos.AnchorPoint = Vector2.new(1, 0)
	chaos.Position = UDim2.new(1, -12, 0, 62)
	chaos.Size = UDim2.fromOffset(150, 22)
	chaos.BackgroundColor3 = COLORS.panel
	chaos.BackgroundTransparency = 0.15
	chaos.ClipsDescendants = true
	chaos.Parent = gui
	corner(chaos, 8)
	chaosFill = Instance.new("Frame")
	chaosFill.Name = "Fill"
	chaosFill.Size = UDim2.fromScale(0, 1)
	chaosFill.BackgroundColor3 = COLORS.cheese
	chaosFill.BorderSizePixel = 0
	chaosFill.Parent = chaos
	corner(chaosFill, 8)
	chaosText = label(chaos, "Text", 13, Enum.Font.GothamBold)
	chaosText.Size = UDim2.fromScale(1, 1)
	chaosText.TextStrokeTransparency = 0.4
	chaosText.Text = "CHAOS 0%"

	-- Free "unstuck" button (bottom left, small; server applies a cooldown)
	local unstuck = Instance.new("TextButton")
	unstuck.Name = "Unstuck"
	-- Top right next to the tips counter: away from the mobile thumbstick, >= 44 px tall.
	unstuck.AnchorPoint = Vector2.new(1, 0)
	unstuck.Position = UDim2.new(1, -170, 0, 12)
	unstuck.Size = UDim2.fromOffset(110, 44)
	unstuck.BackgroundColor3 = COLORS.panel
	unstuck.BackgroundTransparency = 0.25
	unstuck.Font = Enum.Font.GothamBold
	unstuck.TextSize = 14
	unstuck.TextColor3 = COLORS.cream
	unstuck.Text = "🆘 Unstuck"
	unstuck.Parent = gui
	corner(unstuck, 10)
	unstuck.Activated:Connect(function()
		Net.event("RequestUnstuck"):FireServer()
	end)

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
	local giant = player:GetAttribute("GiantCustomer")
	if typeof(giant) == "string" then
		local target = player:GetAttribute("GiantTarget")
		orderText.Text = if typeof(target) == "Vector3"
			then `🍕🍕 GIANT · {giant} · {player:GetAttribute("GiantLabel") or ""}`
			else `🍕🍕 GIANT for {giant} · waiting for more couriers…`
		orderCard.Visible = true
		return
	end
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
	local tipsText = `+{result.tips or 0} 💰`
	if result.giant then
		tipsText ..= "  TEAM BONUS!"
	end
	if result.mega then
		tipsText ..= "  MEGA ×3!"
	elseif result.eventBonus then
		tipsText ..= "  CHAOS BONUS!"
	end
	popupTips.Text = tipsText
	local styleNames = {}
	if typeof(result.style) == "table" then
		for _, name in result.style do
			if typeof(name) == "string" then
				table.insert(styleNames, string.upper(name) .. "!")
			end
		end
	end
	popupStyle.Text = table.concat(styleNames, " ")
	local rarity = tostring(result.rarity or "Common")
	local line = `{result.customer or ""}: “{result.line or ""}”`
	if result.isNew then
		line = `✨ NEW {string.upper(rarity)} CUSTOMER! ✨\n{line}`
		popup.BackgroundColor3 = RARITY_COLOR[rarity] or COLORS.panel
	else
		popup.BackgroundColor3 = COLORS.panel
	end
	popupLine.Text = line
	popup.Visible = true
	popup.Size = UDim2.fromOffset(240, 80)
	TweenService
		:Create(popup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(340, 150),
		})
		:Play()
	popupToken += 1
	local token = popupToken
	task.delay(2, function()
		if popupToken == token then
			popup.Visible = false
		end
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

	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild("CityState", 30)
		if not state then
			return
		end
		local function refreshChaos()
			local value = state:GetAttribute("Chaos")
			local fraction = if typeof(value) == "number" then math.clamp(value, 0, 1) else 0
			local mega = state:GetAttribute("Mega") == true
			chaosText.Text = if mega
				then "💥 MEGA CHAOS!"
				else `CHAOS {math.floor(fraction * 100)}%`
			chaosFill.BackgroundColor3 = if mega or fraction >= 1
				then Color3.fromHex("#FF3FA4")
				else COLORS.cheese
			TweenService:Create(chaosFill, TweenInfo.new(0.4), {
				Size = UDim2.fromScale(if mega then 1 else fraction, 1),
			}):Play()
		end
		state:GetAttributeChangedSignal("Chaos"):Connect(refreshChaos)
		state:GetAttributeChangedSignal("Mega"):Connect(refreshChaos)
		refreshChaos()
	end)

	player:GetAttributeChangedSignal("OrderId"):Connect(refreshOrder)
	player:GetAttributeChangedSignal("GiantOrderId"):Connect(refreshOrder)
	player:GetAttributeChangedSignal("GiantTarget"):Connect(refreshOrder)
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
