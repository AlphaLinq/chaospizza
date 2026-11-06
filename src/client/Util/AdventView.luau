--!strict
local Paint = require(script.Parent.ShopView)
local View = {}
function View.new(parent: Instance)
	local root = Instance.new("Frame")
	root.Name = "AdventCalendar"
	root.LayoutOrder = -1
	root.Size = UDim2.new(1, -8, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundTransparency = 1
	root.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root
	local top = Instance.new("Frame")
	top.Name = "Heading"
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, 64)
	top.Parent = root
	-- One static snowflake, drawn with the same cream strokes as our UI.
	for angle = 0, 120, 60 do
		local spoke = Instance.new("Frame")
		spoke.AnchorPoint = Vector2.new(0.5, 0.5)
		spoke.Position = UDim2.fromOffset(18, 28)
		spoke.Size = UDim2.fromOffset(28, 2)
		spoke.Rotation = angle
		spoke.BorderSizePixel = 0
		spoke.BackgroundColor3 = Paint.colors.cream
		spoke.Parent = top
	end
	local title = Paint.label(top, "Title", "", 24)
	title.Font = Enum.Font.FredokaOne
	title.Position = UDim2.fromOffset(44, 0)
	title.Size = UDim2.new(1, -44, 1, 0)
	local info = Paint.label(root, "Rules", "", 15)
	info.LayoutOrder = 1
	info.Size = UDim2.new(1, -4, 0, 0)
	info.AutomaticSize = Enum.AutomaticSize.Y
	local notice = Paint.label(root, "Notice", "", 15)
	notice.LayoutOrder = 2
	notice.Size = UDim2.new(1, -4, 0, 0)
	notice.AutomaticSize = Enum.AutomaticSize.Y
	local grid = Instance.new("Frame")
	grid.Name = "Windows"
	grid.LayoutOrder = 3
	grid.Size = UDim2.fromScale(1, 0)
	grid.BackgroundTransparency = 1
	grid.Parent = root
	local tiles = Instance.new("UIGridLayout")
	tiles.SortOrder = Enum.SortOrder.LayoutOrder
	tiles.CellPadding = UDim2.fromOffset(10, 10)
	tiles.Parent = grid
	local cells = {}
	for day = 1, 24 do
		local button = Instance.new("TextButton")
		button.Name = `Day{day}`
		button.LayoutOrder = day
		button.Text = ""
		button.Parent = grid
		Paint.round(button)
		local date = Paint.label(button, "Date", "", 21)
		date.Font = Enum.Font.FredokaOne
		date.Position = UDim2.fromOffset(10, 8)
		date.Size = UDim2.new(1, -20, 0, 46)
		local reward = Paint.label(button, "Reward", "", 16)
		reward.Position = UDim2.fromOffset(10, 58)
		reward.Size = UDim2.new(1, -20, 0, 64)
		local status = Paint.label(button, "State", "", 15)
		status.Font = Enum.Font.GothamBold
		status.Position = UDim2.fromOffset(10, 128)
		status.Size = UDim2.new(1, -20, 0, 48)
		cells[day] = { button = button, date = date, reward = reward, status = status }
	end
	local function resize()
		local scale = 1
		local ancestor: Instance? = grid
		while ancestor do
			local s = ancestor:FindFirstChildOfClass("UIScale")
			if s then
				scale *= s.Scale
			end
			ancestor = ancestor.Parent
		end
		local columns = math.clamp(math.floor((grid.AbsoluteSize.X / scale + 10) / 122), 1, 4)
		tiles.CellSize = UDim2.new(1 / columns, -10 * (columns - 1) / columns, 0, 184)
		grid.Size = UDim2.new(1, 0, 0, math.ceil(#cells / columns) * 194 - 10)
	end
	local changed = grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	root.Destroying:Connect(function()
		changed:Disconnect()
	end)
	resize()
	return { root = root, title = title, info = info, notice = notice, cells = cells }
end
return View
