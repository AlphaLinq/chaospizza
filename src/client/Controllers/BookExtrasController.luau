--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.BookExtras)
local Settings = require(ReplicatedStorage.Shared.Util.Settings).new(
	require(ReplicatedStorage.Shared.Config.Settings)
)
local View = require(script.Parent.Parent.Util.BookExtrasView)
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local Controller = {}
local alive = false
local connections: { RBXScriptConnection } = {}
local owned: { [TextButton]: boolean } = {}
local ui: any = nil
local link: TextButton? = nil
local grid: UIGridLayout? = nil
local original: UDim2? = nil
local mode: string? = nil
function Controller.start()
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local current: string? = nil
	local data: any = nil
	local customers: ScrollingFrame? = nil
	local function language(): string
		local value = pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
		return if string.sub(string.lower(tostring(value)), 1, 2) == "hu" then "hu" else "en"
	end
	local function request(id: string, row: any): (string, string)
		local translated = if language() == "hu" then Config.quirksHu[id] else nil
		return if translated then translated[1] else row.title,
			if translated then translated[2] else row.request
	end
	local function render()
		if not ui then
			return
		end
		local copy = Config.labels[language()]
		ui.root.Visible = mode ~= nil
		if customers and mode then
			customers.Visible = false
		end
		ui.back.Text = copy.back
		if link then
			link.Text = if data
				then `{copy.golden}\n{data.found} / {#data.rows}\n{data.remaining} {copy.remaining}\n{copy.open}`
				else copy.loading
		end
		if not mode then
			return
		end
		Panel.clear(ui.scroll)
		if not data then
			ui.status.Text = copy.loading
			return
		end
		if mode == "golden" then
			ui.title.Text = copy.golden
			ui.status.Text = `{data.found} / {#data.rows} · {data.remaining} {copy.remaining}`
			for index, spot in data.rows do
				local state = (if spot.found then copy.found else "")
					.. (if spot.found then " · " else "")
					.. (if spot.active then copy.active else copy.waiting)
				View.card(
					ui.scroll,
					spot.id,
					`{spot.id} · {state}`,
					if language() == "hu" then Config.hintsHu[index] else spot.hint,
					index,
					spot.active
				)
			end
		else
			local row = current and data.customers[current]
			ui.title.Text = copy.request
			if row and row.request then
				local title, hint = request(current :: string, row)
				ui.status.Text = if row.done then copy.done else copy.pending
				View.card(ui.scroll, "Request", title, hint, 1, row.done)
			end
		end
	end
	local function resize()
		if not alive then
			return
		end
		local g, scroll = grid, customers
		if not g or not scroll then
			return
		end
		local width = scroll.AbsoluteSize.X / Settings.textScale(player)
		local columns = math.max(1, math.floor((width + 10) / 180))
		local size = UDim2.new(1 / columns, -(8 + (columns - 1) * 10) / columns, 0, 244)
		if g.CellSize ~= size then
			g.CellSize = size
		end
	end
	local function augment()
		if not alive or not customers or not data then
			return
		end
		local copy = Config.labels[language()]
		for _, card in customers:GetChildren() do
			if not card:IsA("Frame") or not card:FindFirstChild("Detail") then
				continue
			end
			local row = data.customers[card.Name]
			if not row then
				continue
			end
			local found = card:FindFirstChild("QuirkInfo")
			if not found then
				local button = Panel.row(card, "QuirkInfo", "", 0)
				button.Position, button.Size = UDim2.fromOffset(12, 176), UDim2.new(1, -24, 0, 56)
				button.TextSize = 13
				owned[button] = true
				button.Destroying:Connect(function()
					owned[button] = nil
				end)
				button.Activated:Connect(function()
					local latest = data and data.customers[card.Name]
					if latest and latest.request then
						mode, current = "quirk", card.Name
						render()
					end
				end)
				found = button
			end
			local b = found :: TextButton
			b.Active, b.AutoButtonColor = row.request ~= nil, row.request ~= nil
			if row.request then
				local title = request(card.Name, row)
				b.Text = title .. (if row.done then "\n" .. copy.done else "")
				local mark = b:FindFirstChild("Completed")
				if row.done and not mark then
					local icon = Instance.new("Frame")
					icon.Name = "Completed"
					icon.BackgroundTransparency = 1
					icon.Size = UDim2.fromOffset(16, 16)
					icon.Position = UDim2.new(1, -18, 0, 2)
					icon.Parent = b
					for index, angle in { 45, -45 } do
						local line = Instance.new("Frame")
						line.Size = UDim2.fromOffset(if index == 1 then 6 else 12, 2)
						line.Position = UDim2.fromOffset(
							if index == 1 then 0 else 4,
							if index == 1 then 8 else 5
						)
						line.Rotation = angle
						line.BorderSizePixel = 0
						line.BackgroundColor3 = Color3.fromHex("#FFD24A")
						line.Parent = icon
					end
				elseif not row.done and mark then
					mark:Destroy()
				end
			else
				b.Text = if row.known then copy.none else copy.unknown
			end
		end
		resize()
		render()
	end
	local function ensure()
		if not alive or ui and ui.root.Parent then
			return
		end
		local book = pg:FindFirstChild("CustomerBook")
		local panel = book and book:FindFirstChild("BookPanel", true)
		local scroll = panel and panel:FindFirstChild("Customers")
		if not panel or not scroll or not scroll:IsA("ScrollingFrame") then
			return
		end
		customers = scroll
		grid = scroll:FindFirstChildOfClass("UIGridLayout")
		if not grid then
			return
		end
		original = grid.CellSize
		ui = View.new(panel)
		local entry = Panel.row(scroll, "GoldenPepperoniLink", "", -1)
		link = entry
		entry.Activated:Connect(function()
			mode = "golden"
			ui.scroll.CanvasPosition = Vector2.zero
			render()
		end)
		ui.back.Activated:Connect(function()
			mode = nil
			scroll.Visible = true
			render()
		end)
		table.insert(connections, grid:GetPropertyChangedSignal("CellSize"):Connect(resize))
		table.insert(connections, scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
		augment()
	end
	local function read()
		local raw = player:GetAttribute("BookExtras")
		local ok, value = pcall(function()
			return HttpService:JSONDecode(if type(raw) == "string" then raw else "")
		end)
		data = if ok and type(value) == "table" then value else nil
		augment()
	end
	table.insert(connections, player:GetAttributeChangedSignal("BookExtras"):Connect(read))
	table.insert(
		connections,
		player:GetAttributeChangedSignal("TextSize"):Connect(function()
			task.defer(resize)
		end)
	)
	table.insert(connections, pg:GetAttributeChangedSignal("UILocaleOverride"):Connect(augment))
	table.insert(
		connections,
		LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(augment)
	)
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			if pg:GetAttribute("PizzaOverlay") ~= "Book" then
				mode = nil
				if customers then
					customers.Visible = true
				end
				render()
			end
		end)
	)
	table.insert(
		connections,
		pg.DescendantAdded:Connect(function(instance)
			if instance.Name == "Customers" then
				task.defer(ensure)
			elseif instance.Name == "Detail" then
				task.defer(augment)
			end
		end)
	)
	read()
	ensure()
end
function Controller.destroy()
	alive, mode = false, nil
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for button in owned do
		button:Destroy()
	end
	table.clear(owned)
	if grid and original and grid.Parent then
		grid.CellSize = original
	end
	if link then
		link:Destroy()
		link = nil
	end
	if ui then
		ui.root:Destroy()
		ui = nil
	end
	grid, original = nil, nil
end
return Controller
