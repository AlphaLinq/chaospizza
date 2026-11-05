--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.Cosmetics)
local CosmeticController = {}
local player = Players.LocalPlayer
local C = {
	panel = Color3.fromHex("#1F1B24"),
	row = Color3.fromHex("#302936"),
	cream = Color3.fromHex("#FFF3D6"),
	cheese = Color3.fromHex("#FFD24A"),
}
local connections: { RBXScriptConnection } = {}
local gui: ScreenGui?
local alive = false
local function round(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = parent
end
local function button(parent: Instance, name: string, value: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = value
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextWrapped = true
	b.TextColor3 = C.panel
	b.BackgroundColor3 = C.cheese
	b.Parent = parent
	round(b)
	return b
end
local function label(parent: Instance, name: string, value: string, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = value
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = C.cream
	l.BackgroundTransparency = 1
	l.Parent = parent
	return l
end
function CosmeticController.start()
	if alive then
		return
	end
	alive = true
	local pg = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "Cosmetics"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 23
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
	panel.Size = UDim2.fromScale(0.94, 0.88)
	panel.BackgroundColor3 = C.panel
	panel.Active = true
	panel.Parent = overlay
	round(panel)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 690)
	limit.Parent = panel
	local title = label(panel, "Title", "Courier looks", 26)
	title.Font = Enum.Font.FredokaOne
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -86, 0, 44)
	local close = button(panel, "Close", "×")
	close.Position = UDim2.new(1, -56, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	local categories = Instance.new("ScrollingFrame")
	categories.Name = "Categories"
	categories.Position = UDim2.fromOffset(18, 62)
	categories.Size = UDim2.new(1, -36, 0, 48)
	categories.BackgroundTransparency = 1
	categories.BorderSizePixel = 0
	categories.ScrollBarThickness = 3
	categories.ScrollingDirection = Enum.ScrollingDirection.X
	categories.AutomaticCanvasSize = Enum.AutomaticSize.X
	categories.CanvasSize = UDim2.new()
	categories.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = categories
	local caption = label(panel, "PreviewName", "Preview a look before you choose it.", 15)
	caption.Position = UDim2.fromOffset(18, 118)
	caption.Size = UDim2.new(1, -36, 0, 36)
	local preview = Instance.new("ViewportFrame")
	preview.Name = "Preview"
	preview.Position = UDim2.fromOffset(18, 158)
	preview.Size = UDim2.new(1, -36, 0, 126)
	preview.BackgroundColor3 = C.row
	preview.Ambient = Color3.new(1, 1, 1)
	preview.LightColor = Color3.new(1, 1, 1)
	preview.Parent = panel
	round(preview)
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(3, 2.5, 5), Vector3.zero)
	camera.FieldOfView = 40
	camera.Parent = preview
	preview.CurrentCamera = camera
	local titlePreview = label(preview, "TitlePreview", "", 22)
	titlePreview.TextXAlignment = Enum.TextXAlignment.Center
	titlePreview.Size = UDim2.fromScale(1, 1)
	titlePreview.Font = Enum.Font.GothamBold
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.Position = UDim2.fromOffset(18, 294)
	scroll.Size = UDim2.new(1, -36, 1, -354)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = C.cheese
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, 10)
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Parent = scroll
	local status = label(panel, "Status", "", 14)
	status.Position = UDim2.new(0, 18, 1, -52)
	status.Size = UDim2.new(1, -36, 0, 42)
	local slot = "box"
	local state: { any } = {}
	local pending: string? = nil
	local requestToken = 0
	local previewId: string? = nil
	local function showPreview(item: any)
		previewId = item.id
		caption.Text = item.name
		titlePreview.Text = ""
		local old = preview:FindFirstChild("PreviewModel")
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = "PreviewModel"
		model.Parent = preview
		local function part(size: Vector3, position: Vector3, color: string): Part
			local p = Instance.new("Part")
			p.Size = size
			p.Position = position
			p.Color = Color3.fromHex(color)
			p.Anchored = true
			p.Parent = model
			return p
		end
		if item.slot == "box" then
			part(Vector3.new(2.6, 0.5, 2.6), Vector3.zero, item.color)
			part(Vector3.new(1.6, 0.06, 1.6), Vector3.new(0, 0.28, 0), item.accent)
		elseif item.slot == "bag" then
			part(Vector3.new(1.7, 1.8, 0.65), Vector3.zero, item.color)
			part(Vector3.new(1.75, 0.18, 0.1), Vector3.new(0, 0.2, 0.38), item.accent)
		elseif item.slot == "uniform" then
			part(Vector3.new(1.9, 1.55, 0.12), Vector3.zero, item.color)
			part(Vector3.new(1.9, 0.18, 0.08), Vector3.new(0, 0.25, 0.1), item.accent)
			if item.style == "santa" then
				part(Vector3.new(1.4, 0.15, 1.2), Vector3.new(0, 1.2, 0), item.accent)
				part(Vector3.new(1.05, 0.6, 0.9), Vector3.new(0, 1.55, 0), item.color)
				part(Vector3.new(0.3, 0.3, 0.3), Vector3.new(0.2, 1.95, 0), item.accent).Shape =
					Enum.PartType.Ball
			end
		elseif item.slot == "movement" then
			for _, x in { -0.6, 0.6 } do
				part(Vector3.new(0.8, 0.2, 1.1), Vector3.new(x, 0, 0), item.color)
			end
		elseif item.slot == "decor" then
			part(Vector3.new(2.2, 1.4, 0.12), Vector3.zero, item.color)
			part(Vector3.new(1.8, 0.15, 0.14), Vector3.new(0, 0, 0.1), item.accent)
		elseif item.slot == "jar" then
			local jar = part(Vector3.new(1.1, 1.3, 1.1), Vector3.zero, item.color)
			jar.Material = Enum.Material.Glass
			jar.Transparency = 0.25
			part(Vector3.new(1.2, 0.15, 1.2), Vector3.new(0, 0.7, 0), item.accent)
		else
			titlePreview.Text = item.name
			titlePreview.TextColor3 = Color3.fromHex(item.color)
		end
	end
	local render: () -> ()
	local function request(action: string, id: string)
		if pending then
			return
		end
		local key = `cosmetic:{action}.{id}`
		pending = key
		requestToken += 1
		local token = requestToken
		status.Text = "Updating your look…"
		render()
		Net.event("RequestPurchase"):FireServer(key)
		task.delay(Config.requestTimeoutSeconds, function()
			if alive and pending and requestToken == token then
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
		local count = 0
		local tips = player:GetAttribute("Tips")
		local balance = if type(tips) == "number" then tips else 0
		for index, item in state do
			if item.slot == slot then
				count += 1
				if not previewId then
					showPreview(item)
				end
				local row = Instance.new("Frame")
				row.Name = item.id
				row.LayoutOrder = index
				row.Size = UDim2.new(1, -8, 0, if item.seasonal then 188 else 136)
				row.BackgroundColor3 = C.row
				row.Parent = scroll
				round(row)
				local name = label(row, "Name", item.name, 17)
				name.Font = Enum.Font.GothamBold
				name.Position = UDim2.fromOffset(12, 8)
				name.Size = UDim2.new(1, -24, 0, 42)
				local detail = label(
					row,
					"Ownership",
					if item.equipped
						then "Equipped"
						elseif item.owned then "Owned"
						elseif item.price then `{item.price} tips`
						else item.unlockHint or "Earn this look in play",
					14
				)
				detail.Position = UDim2.fromOffset(12, 52)
				detail.Size = UDim2.new(1, -24, 0, 28)
				local see = button(row, "Preview", "Preview")
				see.Size = UDim2.fromOffset(96, 44)
				see.Position = UDim2.fromOffset(12, 82)
				see.BackgroundColor3 = C.panel
				see.TextColor3 = C.cream
				see.Activated:Connect(function()
					showPreview(item)
				end)
				local enabled = not pending
					and not item.equipped
					and (
						item.owned
						or item.price ~= nil
							and item.purchaseAllowed ~= false
							and balance >= item.price
					)
				local choose = button(
					row,
					"Action",
					if item.equipped
						then "Equipped"
						elseif item.owned then "Equip"
						elseif item.seasonal and item.purchaseAllowed == false then "Out of season"
						elseif item.price then "Buy with tips"
						else "Locked"
				)
				choose.Position = UDim2.fromOffset(116, 82)
				choose.Size = UDim2.new(1, -128, 0, 44)
				choose.Active = enabled
				choose.AutoButtonColor = enabled
				choose.BackgroundColor3 = if enabled then C.cheese else C.row
				choose.TextColor3 = if enabled then C.panel else C.cream
				choose.Activated:Connect(function()
					if enabled then
						request(if item.owned then "equip" else "buy", item.id)
					end
				end)
				if item.seasonLabel then
					local season = label(row, "SeasonNotice", item.seasonLabel, 14)
					season.Position, season.Size =
						UDim2.fromOffset(12, 132), UDim2.new(1, -24, 0, 48)
				end
			end
		end
		if count == 0 then
			status.Text = "Your wardrobe is loading…"
		elseif not pending then
			status.Text = `{balance} tips · Preview any look. Equip the ones you own.`
		end
	end
	local function refresh()
		local value = player:GetAttribute("CosmeticsState")
		if type(value) == "string" then
			local ok, data = pcall(function()
				return HttpService:JSONDecode(value)
			end)
			if ok and type(data) == "table" then
				state = data
			end
		end
		render()
	end
	for index, key in Config.slots do
		local names = {
			box = "Box",
			bag = "Bag",
			uniform = "Apron",
			movement = "Shoes",
			decor = "Sign",
			jar = "Jar",
			title = "Title",
			emote = "Emotes",
		}
		local b = button(categories, key, names[key])
		b.Size = UDim2.fromOffset(80, 44)
		b.LayoutOrder = index
		b.BackgroundColor3 = if key == slot then C.cheese else C.row
		b.TextColor3 = if key == slot then C.panel else C.cream
		table.insert(
			connections,
			b.Activated:Connect(function()
				slot = key
				previewId = nil
				scroll.CanvasPosition = Vector2.zero
				for _, other in categories:GetChildren() do
					if other:IsA("TextButton") then
						other.BackgroundColor3 = if other == b then C.cheese else C.row
						other.TextColor3 = if other == b then C.panel else C.cream
					end
				end
				render()
			end)
		)
	end
	local function hide()
		overlay.Visible = false
		if pg:GetAttribute("PizzaOverlay") == "Cosmetics" then
			pg:SetAttribute("PizzaOverlay", nil)
		end
	end
	table.insert(connections, close.Activated:Connect(hide))
	table.insert(connections, backdrop.Activated:Connect(hide))
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			overlay.Visible = pg:GetAttribute("PizzaOverlay") == "Cosmetics"
			if overlay.Visible then
				refresh()
			end
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("CosmeticsState"):Connect(refresh))
	table.insert(connections, player:GetAttributeChangedSignal("Tips"):Connect(render))
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(ok: any, reason: any, key: any)
			if type(key) == "string" and not string.match(key, "^cosmetic:") then
				return
			end
			if pending and key == pending then
				pending = nil
				requestToken += 1
				refresh()
				status.Text = if type(reason) == "string"
					then reason
					else (if ok then "Look updated." else "Please try again.")
			end
		end)
	)
	refresh()
end
function CosmeticController.destroy()
	alive = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if gui then
		gui:Destroy()
		gui = nil
	end
end
return CosmeticController
