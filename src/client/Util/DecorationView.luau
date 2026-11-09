--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Decorations)
local Paint = require(script.Parent.ShopView)
local Visuals = require(ReplicatedStorage.Shared.Runtime.DecorVisuals)
local View = {}
local function button(parent: Instance, name: string, height: number): TextButton
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.TextSize = name, "", 16
	b.Font, b.TextWrapped = Enum.Font.GothamBold, true
	b.BackgroundColor3, b.TextColor3 = Paint.colors.row, Paint.colors.cream
	b.Size = UDim2.new(1, 0, 0, height)
	b.Parent = parent
	Paint.round(b)
	return b
end
local function grid(
	parent: Instance,
	name: string,
	height: number,
	cell: number,
	order: number
): Frame
	local frame = Instance.new("Frame")
	frame.Name, frame.BackgroundTransparency = name, 1
	frame.Size, frame.LayoutOrder = UDim2.new(1, 0, 0, height), order
	frame.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize, layout.CellPadding = UDim2.new(0.5, -4, 0, cell), UDim2.fromOffset(8, 8)
	layout.SortOrder, layout.Parent = Enum.SortOrder.LayoutOrder, frame
	return frame
end
function View.new(
	panel: GuiObject,
	selectItem: (string) -> (),
	selectSlot: (string) -> (),
	act: () -> (),
	clear: () -> (),
	back: () -> ()
)
	local detail = Instance.new("Frame")
	detail.Name = "DecorationDetail"
	detail.BackgroundColor3 = Paint.colors.panel
	detail.Position, detail.Size = UDim2.fromOffset(18, 62), UDim2.new(1, -36, 1, -80)
	detail.Visible, detail.ZIndex = false, 4
	detail.Parent = panel
	local close = button(detail, "Back", 44)
	close.Activated:Connect(back)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "DecorContent", 1, 0
	scroll.Position, scroll.Size = UDim2.fromOffset(0, 56), UDim2.new(1, 0, 1, -56)
	scroll.AutomaticCanvasSize, scroll.CanvasSize, scroll.ScrollBarThickness =
		Enum.AutomaticSize.Y, UDim2.new(), 6
	scroll.Parent = detail
	local list = Instance.new("UIListLayout")
	list.Padding, list.SortOrder, list.Parent = UDim.new(0, 10), Enum.SortOrder.LayoutOrder, scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingRight, padding.PaddingBottom, padding.Parent =
		UDim.new(0, 8), UDim.new(0, 12), scroll
	local slots = grid(scroll, "Slots", 120, 56, 1)
	local slotButtons: { [string]: TextButton } = {}
	for i, slot in Config.slots do
		local b = button(slots, slot.id, 56)
		b.LayoutOrder = i
		b.Activated:Connect(function()
			selectSlot(slot.id)
		end)
		slotButtons[slot.id] = b
	end
	local choices = grid(scroll, "Choices", 88, 88, 2)
	local itemButtons: { [string]: TextButton } = {}
	for i, item in Config.items do
		local b = button(choices, item.id, 88)
		b.LayoutOrder = i
		b.Activated:Connect(function()
			selectItem(item.id)
		end)
		itemButtons[item.id] = b
	end
	local preview = Instance.new("ViewportFrame")
	preview.Name, preview.BackgroundColor3 = "DecorPreview", Paint.colors.row
	preview.Size, preview.LayoutOrder = UDim2.new(1, 0, 0, 150), 3
	preview.Ambient, preview.LightColor = Color3.new(1, 1, 1), Color3.new(1, 1, 1)
	preview.Parent = scroll
	Paint.round(preview)
	local world = Instance.new("WorldModel")
	world.Parent = preview
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(
		Vector3.new(table.unpack(Config.preview.camera)),
		Vector3.new(table.unpack(Config.preview.lookAt))
	)
	camera.FieldOfView = Config.preview.fieldOfView
	camera.Parent = preview
	preview.CurrentCamera = camera
	local name = Paint.label(scroll, "SelectedName", "", 18)
	name.Size, name.AutomaticSize, name.LayoutOrder =
		UDim2.new(1, 0, 0, 48), Enum.AutomaticSize.Y, 4
	local choose = button(scroll, "Action", 52)
	choose.LayoutOrder = 5
	choose.Activated:Connect(act)
	local remove = button(scroll, "ClearSlot", 48)
	remove.LayoutOrder = 6
	remove.Activated:Connect(clear)
	local status = Paint.label(scroll, "DecorStatus", "", 15)
	status.Size, status.AutomaticSize, status.LayoutOrder =
		UDim2.new(1, 0, 0, 60), Enum.AutomaticSize.Y, 7
	local hidden: { [GuiObject]: boolean } = {}
	local shownId: string? = nil
	local api = { detail = detail, back = close, scroll = scroll }
	function api.show(open: boolean)
		if open == detail.Visible then
			return
		end
		if open then
			for _, child in panel:GetChildren() do
				if
					child:IsA("GuiObject")
					and child ~= detail
					and child.Name ~= "Title"
					and child.Name ~= "Close"
				then
					hidden[child] = child.Visible
					child.Visible = false
				end
			end
		else
			for child, visible in hidden do
				if child.Parent then
					child.Visible = visible
				end
			end
			table.clear(hidden)
			world:ClearAllChildren()
			shownId = nil
		end
		detail.Visible = open
	end
	function api.render(
		language: string,
		slotId: string,
		id: string,
		state: any,
		pending: boolean,
		message: string?
	)
		if not detail.Visible then
			return
		end
		local copy = Config.labels[language]
		close.Text = copy.back
		local item: any = nil
		for _, v in Config.items do
			if v.id == id then
				item = v
			end
		end
		if not item then
			return
		end
		for _, s in Config.slots do
			local b = slotButtons[s.id]
			b.Text = s[language]
				.. "\n"
				.. (if state and state.slots[s.id] then copy.placed else copy.empty)
			b.BackgroundColor3, b.TextColor3 =
				if s.id == slotId then Paint.colors.cheese else Paint.colors.row,
				if s.id == slotId then Paint.colors.panel else Paint.colors.cream
		end
		for _, v in Config.items do
			local b = itemButtons[v.id]
			b.Visible = v.slot == slotId
			b.Text = v[language]
				.. "\n"
				.. (
					if v.price == 0
						then copy.free
						elseif state and state.owned[v.id] then copy.owned
						else string.format(copy.price, v.price)
				)
			b.BackgroundColor3, b.TextColor3 =
				if v.id == id then Paint.colors.cheese else Paint.colors.row,
				if v.id == id then Paint.colors.panel else Paint.colors.cream
		end
		if shownId ~= id then
			world:ClearAllChildren()
			Visuals.draw(world, CFrame.new(), item)
			shownId = id
		end
		local owned = state and state.owned[id] == true
		local placed = state and state.slots[slotId] == id
		name.Text = item[language] .. "\n" .. (if placed then copy.placed else copy.preview)
		choose.Text = if pending
			then copy.saving
			elseif placed then copy.placed
			elseif owned then copy.place
			else string.format(copy.buy, item.price)
		choose.Active = state ~= nil
			and state.ready == true
			and not pending
			and not placed
			and (owned or state.tips >= item.price)
		choose.AutoButtonColor = choose.Active
		choose.Selectable = choose.Active
		choose.BackgroundColor3, choose.TextColor3 =
			if choose.Active then Paint.colors.cheese else Paint.colors.row,
			if choose.Active then Paint.colors.panel else Paint.colors.cream
		remove.Text, remove.Active =
			copy.clear,
			state ~= nil and state.ready == true and state.slots[slotId] ~= nil and not pending
		remove.AutoButtonColor = remove.Active
		remove.Selectable = remove.Active
		remove.TextColor3 = if remove.Active then Paint.colors.cream else Paint.colors.muted
		status.Text = if not state or not state.ready
			then copy.loading
			elseif message then (copy[message] or copy.failed)
			else string.format(copy.balance, state.tips)
	end
	function api.destroy()
		api.show(false)
		detail:Destroy()
	end
	return api
end
return View
