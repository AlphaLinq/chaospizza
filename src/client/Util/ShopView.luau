--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local C = {
	panel = Color3.fromHex("#1F1B24"),
	row = Color3.fromHex("#302936"),
	cream = Color3.fromHex("#FFF3D6"),
	cheese = Color3.fromHex("#FFD24A"),
	muted = Color3.fromHex("#B6A7BB"),
}
local ShopView = { colors = C }
function ShopView.round(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = parent
end
function ShopView.label(parent: Instance, name: string, value: string, size: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Text = value
	item.TextSize = size
	item.Font = Enum.Font.GothamMedium
	item.TextColor3 = C.cream
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.BackgroundTransparency = 1
	item.Parent = parent
	return item
end
function ShopView.blockReason(player: Player, unlockAt: number, serverBlock: string?): string?
	if player:GetAttribute("OnboardingStep") ~= "done" then
		return "Finish your first deliveries to unlock the shop."
	end
	if player:GetAttribute("SessionCount") == nil then
		return "Your profile is still loading."
	end
	local city = ReplicatedStorage:FindFirstChild("CityState")
	if not city then
		return "The city is still loading."
	end
	local phase = city and city:GetAttribute("EventPhase")
	if phase == "warning" or phase == "buildUp" or phase == "active" then
		return "Chaos in progress! Shop when the streets settle."
	end
	if unlockAt > os.clock() then
		return "The shop opens after your first 3 minutes."
	end
	return serverBlock
end
function ShopView.tabs(parent: Instance): ScrollingFrame
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.fromOffset(18, 58)
	tabs.Size = UDim2.new(1, -36, 0, 48)
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.ScrollBarThickness = 3
	tabs.ScrollingDirection = Enum.ScrollingDirection.X
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabs.CanvasSize = UDim2.new()
	tabs.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs
	return tabs
end
function ShopView.tab(parent: Instance, name: string, index: number, selected: boolean): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = name
	button.Size = UDim2.fromOffset(96, 44)
	button.LayoutOrder = index
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.BackgroundColor3 = if selected then C.cheese else C.row
	button.TextColor3 = if selected then C.panel else C.cream
	button.Parent = parent
	ShopView.round(button)
	return button
end
return ShopView
