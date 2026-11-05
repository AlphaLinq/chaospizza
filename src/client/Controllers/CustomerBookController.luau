--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RarityLabel = require(ReplicatedStorage.Shared.Util.RarityLabel)
local CustomerBookController = {}
local player = Players.LocalPlayer
local COLORS = {
	panel = Color3.fromHex("#1F1B24"),
	card = Color3.fromHex("#302936"),
	cream = Color3.fromHex("#FFF3D6"),
	cheese = Color3.fromHex("#FFD24A"),
}
local colors: { [string]: Color3 } = {}
for _, rarity in Rarities do
	colors[rarity.id] = Color3.fromHex(rarity.colorHex)
end
local connections: { RBXScriptConnection } = {}
local gui: ScreenGui?
local flash: Tween?
local alive = false
local revision = 0
local fetching = false
local dirty = true

local function rounded(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end
local function text(parent: Instance, name: string, value: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = COLORS.cream
	label.TextSize = size
	label.Text = value
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end
function CustomerBookController.start()
	if alive then
		return
	end
	alive = true
	local playerGui = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "CustomerBook"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 20
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	gui = screen
	local open = Instance.new("TextButton")
	open.Name = "OpenBook"
	open.Position = UDim2.fromOffset(12, 64)
	open.Size = UDim2.fromOffset(110, 44)
	open.BackgroundColor3 = COLORS.cheese
	open.TextColor3 = COLORS.panel
	open.Font = Enum.Font.GothamBold
	open.TextSize = 18
	open.Text = "📖 Book"
	open.Parent = screen
	rounded(open, 12)
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
	overlay.Parent = screen
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.3
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Parent = overlay
	local panel = Instance.new("Frame")
	panel.Name = "BookPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.84)
	panel.BackgroundColor3 = COLORS.panel
	panel.Active = true
	panel.Parent = overlay
	rounded(panel, 16)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(880, 620)
	constraint.Parent = panel
	local title = text(panel, "Title", "Customer Book", 26)
	title.Font = Enum.Font.FredokaOne
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -86, 0, 38)
	local progress = text(panel, "Progress", "Meet the city's weirdest regulars.", 15)
	progress.Position = UDim2.fromOffset(18, 54)
	progress.Size = UDim2.new(1, -36, 0, 26)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "×"
	close.Font = Enum.Font.GothamBold
	close.TextSize = 30
	close.BackgroundColor3 = COLORS.card
	close.TextColor3 = COLORS.cream
	close.Size = UDim2.fromOffset(44, 44)
	close.Position = UDim2.new(1, -56, 0, 12)
	close.Parent = panel
	rounded(close, 12)
	local status = text(panel, "Status", "", 16)
	status.Position = UDim2.fromOffset(18, 86)
	status.Size = UDim2.new(1, -36, 0, 42)
	local retry = Instance.new("TextButton")
	retry.Name = "Retry"
	retry.Text = "Retry"
	retry.Size = UDim2.fromOffset(110, 44)
	retry.Position = UDim2.fromOffset(18, 132)
	retry.BackgroundColor3 = COLORS.cheese
	retry.TextColor3 = COLORS.panel
	retry.Font = Enum.Font.GothamBold
	retry.TextSize = 17
	retry.Visible = false
	retry.Parent = panel
	rounded(retry, 10)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Customers"
	scroll.Position = UDim2.fromOffset(18, 88)
	scroll.Size = UDim2.new(1, -36, 1, -106)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = COLORS.cheese
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local function resize()
		local width = scroll.AbsoluteSize.X - 8
		local columns = math.max(1, math.floor((width + 10) / 180))
		grid.CellSize =
			UDim2.fromOffset(math.max(1, math.floor((width - (columns - 1) * 10) / columns)), 184)
	end
	local function hide()
		overlay.Visible = false
		if playerGui:GetAttribute("PizzaOverlay") == "Book" then
			playerGui:SetAttribute("PizzaOverlay", nil)
		end
	end
	local function render(snapshot: any)
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		progress.Text = `{snapshot.discovered} / {snapshot.total} discovered`
		for index, customer in snapshot.customers do
			local card = Instance.new("Frame")
			card.Name = customer.id
			card.LayoutOrder = index
			card.BackgroundColor3 = COLORS.card
			card.Parent = scroll
			rounded(card, 12)
			local rarityColor = colors[customer.rarity] or COLORS.cream
			local rarity = text(card, "Rarity", string.upper(RarityLabel.text(customer.rarity)), 12)
			rarity.TextColor3 = rarityColor
			rarity.Font = Enum.Font.GothamBold
			rarity.Position = UDim2.fromOffset(12, 10)
			rarity.Size = UDim2.new(1, -24, 0, 20)
			local name =
				text(card, "CustomerName", if customer.known then customer.name else "???", 18)
			name.Font = Enum.Font.GothamBold
			name.Position = UDim2.fromOffset(12, 34)
			name.Size = UDim2.new(1, -24, 0, 44)
			if not customer.known then
				-- A geometric head-and-shoulders silhouette needs no unpublished assets.
				local head = Instance.new("Frame")
				head.Name = "SilhouetteHead"
				head.BackgroundColor3 = Color3.fromHex("#8B7C90")
				head.Size = UDim2.fromOffset(20, 20)
				head.Position = UDim2.new(1, -38, 0, 34)
				head.Parent = card
				rounded(head, 10)
				local body = Instance.new("Frame")
				body.Name = "SilhouetteBody"
				body.BackgroundColor3 = head.BackgroundColor3
				body.Size = UDim2.fromOffset(32, 15)
				body.Position = UDim2.new(1, -44, 0, 56)
				body.Parent = card
				rounded(body, 8)
			end
			local stars = math.clamp(math.floor(tonumber(customer.stars) or 0), 0, 5)
			local rating =
				text(card, "Stars", string.rep("★", stars) .. string.rep("☆", 5 - stars), 18)
			rating.TextColor3 = COLORS.cheese
			rating.Position = UDim2.fromOffset(12, 82)
			rating.Size = UDim2.new(1, -24, 0, 24)
			local detail = if customer.known
				then `Served {customer.served} times`
				else customer.hint
			local hint = text(card, "Detail", detail, 14)
			hint.Position = UDim2.fromOffset(12, 114)
			hint.Size = UDim2.new(1, -24, 0, 58)
			hint.TextYAlignment = Enum.TextYAlignment.Top
		end
		status.Text = if #snapshot.customers == 0
			then "No customers yet. Your first delivery awaits!"
			else ""
		scroll.Visible = #snapshot.customers > 0
	end
	local refresh: () -> ()
	refresh = function()
		if fetching or not alive or not overlay.Visible then
			return
		end
		fetching = true
		dirty = false
		local requestRevision = revision
		status.Text = "Opening the guest list…"
		retry.Visible = false
		task.spawn(function()
			local ok, snapshot = pcall(function()
				return Net.func("GetCustomerBook"):InvokeServer()
			end)
			fetching = false
			if not alive then
				return
			end
			if ok and type(snapshot) == "table" and type(snapshot.customers) == "table" then
				render(snapshot)
			else
				status.Text = "The guest list couldn't load. Try again."
				scroll.Visible = false
				retry.Visible = true
				dirty = true
			end
			if revision ~= requestRevision then
				dirty = true
				task.delay(1, function()
					if alive and overlay.Visible then
						refresh()
					end
				end)
			end
		end)
	end
	table.insert(
		connections,
		open.Activated:Connect(function()
			if overlay.Visible then
				hide()
				return
			end
			playerGui:SetAttribute("PizzaOverlay", "Book")
			overlay.Visible = true
			if dirty then
				refresh()
			end
		end)
	)
	table.insert(connections, close.Activated:Connect(hide))
	table.insert(connections, backdrop.Activated:Connect(hide))
	table.insert(connections, retry.Activated:Connect(refresh))
	table.insert(connections, scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	table.insert(
		connections,
		playerGui:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			if playerGui:GetAttribute("PizzaOverlay") ~= "Book" then
				overlay.Visible = false
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.Escape then
				hide()
			end
		end)
	)
	table.insert(
		connections,
		Net.event("CustomerBookUpdated").OnClientEvent:Connect(function(payload: any)
			revision += 1
			dirty = true
			if type(payload) == "table" and payload.isNew == true then
				if flash then
					flash:Cancel()
				end
				open.BackgroundColor3 = COLORS.cheese
				local animation = TweenService:Create(
					open,
					TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 3, true),
					{ BackgroundColor3 = COLORS.cream }
				)
				flash = animation
				animation:Play()
			end
			if overlay.Visible then
				refresh()
			end
		end)
	)
	resize()
end
function CustomerBookController.destroy()
	alive = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if flash then
		flash:Cancel()
		flash = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end
return CustomerBookController
