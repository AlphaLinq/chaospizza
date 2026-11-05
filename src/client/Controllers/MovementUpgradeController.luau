--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.MovementUpgrades)
local RideAnimation = require(script.Parent.Parent.Util.RideAnimation)
local MovementUpgradeController = {}
local player = Players.LocalPlayer
local gui: ScreenGui?
local alive = false
local connections: { RBXScriptConnection } = {}
local stopAnimation: (() -> ())?
local C = {
	panel = Color3.fromHex("#1F1B24"),
	row = Color3.fromHex("#302936"),
	cream = Color3.fromHex("#FFF3D6"),
	cheese = Color3.fromHex("#FFD24A"),
}
local function round(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = parent
end
local function label(parent: Instance, name: string, value: string, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Text = value
	text.TextSize = size
	text.TextColor3 = C.cream
	text.Font = Enum.Font.GothamMedium
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.BackgroundTransparency = 1
	text.Parent = parent
	return text
end
local function button(parent: Instance, name: string, value: string): TextButton
	local result = Instance.new("TextButton")
	result.Name = name
	result.Text = value
	result.TextSize = 16
	result.Font = Enum.Font.GothamBold
	result.TextColor3 = C.panel
	result.BackgroundColor3 = C.cheese
	result.Parent = parent
	round(result)
	return result
end
function MovementUpgradeController.start()
	if alive then
		return
	end
	alive = true
	stopAnimation = RideAnimation.start()
	local pg = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "Rides"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 24
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = pg
	gui = screen
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
	overlay.Parent = screen
	local backdrop = button(overlay, "Backdrop", "")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.3
	backdrop.AutoButtonColor = false
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.84)
	panel.BackgroundColor3 = C.panel
	panel.Active = true
	panel.Parent = overlay
	round(panel)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(620, 620)
	limit.Parent = panel
	local title = label(panel, "Title", "Upgrade your ride", 26)
	title.Font = Enum.Font.FredokaOne
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -86, 0, 44)
	local close = button(panel, "Close", "×")
	close.Position = UDim2.new(1, -56, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	local balance = label(panel, "Balance", "Your rides are loading…", 15)
	balance.Position = UDim2.fromOffset(18, 62)
	balance.Size = UDim2.new(1, -36, 0, 40)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Tiers"
	scroll.Position = UDim2.fromOffset(18, 112)
	scroll.Size = UDim2.new(1, -36, 1, -174)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = C.cheese
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local status = label(panel, "Status", "Faster deliveries. Same pizza insurance.", 14)
	status.Position = UDim2.new(0, 18, 1, -54)
	status.Size = UDim2.new(1, -36, 0, 44)
	local state: { any } = {}
	local pending: string? = nil
	local token = 0
	local render: () -> ()
	local function request(tier: number)
		if pending then
			return
		end
		local key = `ride:upgrade.{tier}`
		pending = key
		token += 1
		local current = token
		status.Text = "Saving your new ride…"
		render()
		Net.event("RequestPurchase"):FireServer(key)
		task.delay(Config.requestTimeoutSeconds, function()
			if alive and token == current and pending == key then
				pending = nil
				render()
				status.Text = "No reply yet. Please try again."
			end
		end)
	end
	render = function()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local tips = player:GetAttribute("Tips")
		local level = player:GetAttribute("CourierLevel")
		balance.Text = `{if type(tips) == "number" then tips else 0} tips · Courier level {if type(
				level
			) == "number"
			then level
			else 1}`
		for index, entry in state do
			local row = Instance.new("Frame")
			row.Name = `Tier{entry.tier}`
			row.Size = UDim2.new(1, -8, 0, 154)
			row.LayoutOrder = index
			row.BackgroundColor3 = C.row
			row.Parent = scroll
			round(row)
			local name = label(row, "Name", entry.name, 19)
			name.Font = Enum.Font.GothamBold
			name.Position = UDim2.fromOffset(12, 6)
			name.Size = UDim2.new(1, -24, 0, 32)
			local detail = label(
				row,
				"Detail",
				`+{math.round(entry.speedBonus * 100)}% speed · Level {entry.level} · {entry.cost} tips`,
				14
			)
			detail.Position = UDim2.fromOffset(12, 40)
			detail.Size = UDim2.new(1, -24, 0, 24)
			local hint = label(
				row,
				"Hint",
				if entry.active
					then "Your current ride"
					elseif entry.owned then "Already unlocked"
					else entry.reason,
				14
			)
			hint.Position = UDim2.fromOffset(12, 66)
			hint.Size = UDim2.new(1, -24, 0, 32)
			local buy = button(
				row,
				"Upgrade",
				if entry.active then "Current ride" elseif entry.owned then "Unlocked" else "Upgrade"
			)
			buy.Position = UDim2.fromOffset(12, 102)
			buy.Size = UDim2.new(1, -24, 0, 44)
			local enabled = entry.available == true and pending == nil
			buy.Active = enabled
			buy.AutoButtonColor = enabled
			buy.BackgroundColor3 = if enabled then C.cheese else C.panel
			buy.TextColor3 = if enabled then C.panel else C.cream
			buy.Activated:Connect(function()
				if enabled then
					request(entry.tier)
				end
			end)
		end
		if #state == 0 then
			status.Text = "Your rides are loading. Try reopening in a moment."
		end
	end
	local function refresh()
		local raw = player:GetAttribute("RideState")
		if type(raw) == "string" then
			local ok, value = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(value) == "table" then
				state = value
			end
		end
		render()
	end
	local function hide()
		overlay.Visible = false
		if pg:GetAttribute("PizzaOverlay") == "Rides" then
			pg:SetAttribute("PizzaOverlay", nil)
		end
	end
	table.insert(connections, close.Activated:Connect(hide))
	table.insert(connections, backdrop.Activated:Connect(hide))
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			overlay.Visible = pg:GetAttribute("PizzaOverlay") == "Rides"
			if overlay.Visible then
				refresh()
			end
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("RideState"):Connect(refresh))
	table.insert(connections, player:GetAttributeChangedSignal("Tips"):Connect(render))
	table.insert(connections, player:GetAttributeChangedSignal("CourierLevel"):Connect(render))
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(ok: any, reason: any, key: any)
			if pending and key == pending then
				pending = nil
				token += 1
				refresh()
				status.Text = if type(reason) == "string"
					then reason
					else if ok then "Ride upgraded!" else "Please try again."
			end
		end)
	)
	refresh()
end
function MovementUpgradeController.destroy()
	alive = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if stopAnimation then
		stopAnimation()
		stopAnimation = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end
return MovementUpgradeController
