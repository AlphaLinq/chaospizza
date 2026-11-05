--!strict
local Players = game:GetService("Players")
local View = require(script.Parent.ShopView)
local CommunityPanel = {}
function CommunityPanel.new(name: string, title: string)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = name
	screen.DisplayOrder = 26
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = pg
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
	overlay.Parent = screen
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.BackgroundColor3 = Color3.new()
	backdrop.BackgroundTransparency = 0.3
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = overlay
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Active = true
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.84)
	panel.BackgroundColor3 = View.colors.panel
	panel.Parent = overlay
	View.round(panel)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(620, 660)
	limit.Parent = panel
	local heading = View.label(panel, "Title", title, 26)
	heading.Font = Enum.Font.FredokaOne
	heading.Position = UDim2.fromOffset(18, 12)
	heading.Size = UDim2.new(1, -86, 0, 44)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "×"
	close.TextSize = 24
	close.TextColor3 = View.colors.cream
	close.BackgroundColor3 = View.colors.row
	close.Position = UDim2.new(1, -56, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	close.Parent = panel
	View.round(close)
	local status = View.label(panel, "Status", "", 15)
	status.Position = UDim2.fromOffset(18, 60)
	status.Size = UDim2.new(1, -36, 0, 52)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Content"
	scroll.Position = UDim2.fromOffset(18, 122)
	scroll.Size = UDim2.new(1, -36, 1, -134)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local function hide()
		if pg:GetAttribute("PizzaOverlay") == name then
			pg:SetAttribute("PizzaOverlay", nil)
		end
	end
	local connections = {
		close.Activated:Connect(hide),
		backdrop.Activated:Connect(hide),
		pg:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			overlay.Visible = pg:GetAttribute("PizzaOverlay") == name
		end),
	}
	screen.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	return { screen = screen, overlay = overlay, panel = panel, scroll = scroll, status = status }
end
function CommunityPanel.clear(scroll: Instance)
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end
function CommunityPanel.row(parent: Instance, name: string, text: string, order: number): TextButton
	local row = Instance.new("TextButton")
	row.Name = name
	row.Text = text
	row.TextWrapped = true
	row.Font = Enum.Font.GothamBold
	row.TextSize = 17
	row.TextColor3 = View.colors.cream
	row.BackgroundColor3 = View.colors.row
	row.Size = UDim2.new(1, -8, 0, 72)
	row.LayoutOrder = order
	row.Parent = parent
	View.round(row)
	return row
end
return CommunityPanel
