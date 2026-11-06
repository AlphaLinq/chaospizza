--!strict
local Paint = require(script.Parent.ShopView)
local Panel = require(script.Parent.CommunityPanel)
local View = {}
function View.new(parent: Instance)
	local root = Instance.new("Frame")
	root.Name = "BookExtras"
	root.Position, root.Size = UDim2.fromOffset(18, 88), UDim2.new(1, -36, 1, -106)
	root.BackgroundColor3 = Paint.colors.panel
	root.BorderSizePixel = 0
	root.ZIndex = 3
	root.Active = true
	root.Visible = false
	root.Parent = parent
	local title = Paint.label(root, "Title", "", 20)
	title.Font = Enum.Font.FredokaOne
	title.Size = UDim2.new(1, -102, 0, 64)
	local back = Panel.row(root, "Back", "", 0)
	back.Position, back.Size = UDim2.new(1, -92, 0, 0), UDim2.fromOffset(92, 44)
	local status = Paint.label(root, "Summary", "", 15)
	status.Position, status.Size = UDim2.fromOffset(0, 68), UDim2.new(1, 0, 0, 64)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Clues"
	scroll.Position, scroll.Size = UDim2.fromOffset(0, 142), UDim2.new(1, 0, 1, -142)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Selectable = true
	scroll.Parent = root
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	return { root = root, title = title, back = back, status = status, scroll = scroll }
end
function View.card(
	parent: Instance,
	id: string,
	title: string,
	hint: string,
	index: number,
	active: boolean
)
	local frame = Instance.new("Frame")
	frame.Name, frame.LayoutOrder = id, index
	frame.Size = UDim2.new(1, -8, 0, 164)
	frame.BackgroundColor3 = if active then Paint.colors.cheese else Paint.colors.row
	frame.Parent = parent
	Paint.round(frame)
	local heading = Paint.label(frame, "Heading", title, 16)
	heading.Font = Enum.Font.GothamBold
	heading.Position, heading.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 62)
	local body = Paint.label(frame, "Hint", hint, 15)
	body.Position, body.Size = UDim2.fromOffset(12, 78), UDim2.new(1, -24, 0, 76)
	for _, v in { heading, body } do
		v.TextColor3 = if active then Paint.colors.panel else Paint.colors.cream
	end
end
return View
