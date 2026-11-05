--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config.Settings)
local FocusOrder = require(ReplicatedStorage.Shared.Util.FocusOrder)
local GamepadController = {}
local screens = {
	CustomerBook = true,
	Shop = true,
	Daily = true,
	Settings = true,
	Cosmetics = true,
	Rides = true,
	CourierProfile = true,
	Visits = true,
	Emotes = true,
}
local modes = {
	Book = "CustomerBook",
	Shop = "Shop",
	Daily = "Daily",
	Settings = "Settings",
	Cosmetics = "Cosmetics",
	Rides = "Rides",
	CourierProfile = "CourierProfile",
	Visits = "Visits",
	Emotes = "Emotes",
}
local records: { [GuiObject]: any } = {}
local connections: { RBXScriptConnection } = {}
local alive = false
local previous: GuiObject? = nil
local function visible(object: GuiObject): boolean
	local current: Instance? = object
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return object.Parent ~= nil
end
local function gamepad(): boolean
	return string.match(UserInputService:GetLastInputType().Name, "^Gamepad") ~= nil
end
local function scrollIntoView(object: GuiObject)
	local scale = 1
	local parent: Instance? = object.Parent
	while parent do
		local uiScale = parent:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale *= uiScale.Scale
		end
		parent = parent.Parent
	end
	parent = object.Parent
	while parent do
		if parent:IsA("ScrollingFrame") then
			local delta = object.AbsolutePosition - parent.AbsolutePosition
			local right = delta.X + object.AbsoluteSize.X - parent.AbsoluteSize.X
			local bottom = delta.Y + object.AbsoluteSize.Y - parent.AbsoluteSize.Y
			local dx = if delta.X < 0 then delta.X else math.max(0, right)
			local dy = if delta.Y < 0 then delta.Y else math.max(0, bottom)
			parent.CanvasPosition += Vector2.new(dx, dy) / scale
		end
		parent = parent.Parent
	end
end
function GamepadController.start()
	alive = true
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local queued = false
	local stick = Vector2.zero
	local lastMode: any = nil
	local function refresh(force: boolean?)
		queued = false
		if not alive then
			return
		end
		local mode = pg:GetAttribute("PizzaOverlay")
		local screenName = if type(mode) == "string" then modes[mode] else nil
		local screen = if screenName then pg:FindFirstChild(screenName) else nil
		local items = {}
		for object in records do
			if object.Parent and visible(object) and object.Selectable then
				local owner = object:FindFirstAncestorOfClass("ScreenGui")
				if
					owner
					and (
						not mode
						or owner == screen
							and object.Name ~= "OpenShop"
							and object.Name ~= "OpenDaily"
							and object.Name ~= "OpenSettings"
							and object.Name ~= "OpenBook"
					)
				then
					table.insert(items, {
						object = object,
						x = object.AbsolutePosition.X,
						y = object.AbsolutePosition.Y,
						key = object:GetFullName(),
					})
				end
			end
		end
		items = FocusOrder.sort(items)
		for i, item in items do
			local before = items[(i - 2) % #items + 1].object
			local after = items[i % #items + 1].object
			item.object.NextSelectionUp, item.object.NextSelectionLeft = before, before
			item.object.NextSelectionDown, item.object.NextSelectionRight = after, after
		end
		if mode ~= lastMode then
			if mode then
				previous = GuiService.SelectedObject
			end
			lastMode = mode
			if not mode and previous and visible(previous) then
				GuiService.SelectedObject = previous
				previous = nil
			end
		end
		if force or gamepad() or GuiService.SelectedObject ~= nil then
			local selected = GuiService.SelectedObject
			local valid = false
			for _, item in items do
				if item.object == selected then
					valid = true
					break
				end
			end
			if not valid and #items > 0 then
				GuiService.SelectedObject = items[1].object
			end
		end
	end
	local function queue()
		if not queued then
			queued = true
			task.defer(refresh)
		end
	end
	local function inspect(instance: Instance)
		if
			not (
				instance:IsA("GuiButton")
				or instance:IsA("TextBox")
				or instance:IsA("ScrollingFrame")
			)
			or instance.Name == "Backdrop"
			or records[instance]
		then
			return
		end
		local owner = instance:FindFirstAncestorOfClass("ScreenGui")
		if not owner or not screens[owner.Name] then
			return
		end
		if instance:IsA("ScrollingFrame") then
			instance.Selectable = true
		end
		local stroke = Instance.new("UIStroke")
		stroke.Name = "GamepadFocus"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 3
		stroke.Color = Color3.fromHex("#FFD24A")
		stroke.Enabled = false
		stroke.Parent = instance
		local gained = instance.SelectionGained:Connect(function()
			stroke.Enabled = true
			scrollIntoView(instance)
		end)
		local lost = instance.SelectionLost:Connect(function()
			stroke.Enabled = false
		end)
		records[instance] = { stroke = stroke, gained = gained, lost = lost }
		instance.Destroying:Connect(function()
			gained:Disconnect()
			lost:Disconnect()
			records[instance] = nil
			queue()
		end)
		queue()
	end
	for _, instance in pg:GetDescendants() do
		inspect(instance)
	end
	table.insert(connections, pg.DescendantAdded:Connect(inspect))
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			local mode = pg:GetAttribute("PizzaOverlay")
			local name = if type(mode) == "string" then modes[mode] else nil
			local screen = if name then pg:FindFirstChild(name) else nil
			local panel = screen
				and (
					screen:FindFirstChild("Panel", true)
					or screen:FindFirstChild("ShopPanel", true)
					or screen:FindFirstChild("BookPanel", true)
				)
			if panel and panel:IsA("GuiObject") then
				panel.SelectionGroup = true
			end
			queue()
		end)
	)
	table.insert(connections, UserInputService.LastInputTypeChanged:Connect(queue))
	table.insert(connections, GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(queue))
	ContextActionService:BindActionAtPriority("PizzaCloseOverlay", function(_, state)
		if
			state ~= Enum.UserInputState.Begin
			or not pg:GetAttribute("PizzaOverlay")
			or GuiService.MenuIsOpen
		then
			return Enum.ContextActionResult.Pass
		end
		pg:SetAttribute("PizzaOverlay", nil)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("PizzaFocusMenu", function(_, state)
		if state == Enum.UserInputState.Begin and not GuiService.MenuIsOpen then
			refresh(true)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.ButtonSelect)
	ContextActionService:BindAction("PizzaScrollPanel", function(_, state, input)
		if not pg:GetAttribute("PizzaOverlay") or GuiService.MenuIsOpen then
			stick = Vector2.zero
			return Enum.ContextActionResult.Pass
		end
		stick = if state == Enum.UserInputState.End
			then Vector2.zero
			else Vector2.new(input.Position.X, -input.Position.Y)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Thumbstick2)
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt)
			if stick.Magnitude < Config.gamepadDeadzone or GuiService.MenuIsOpen then
				return
			end
			local mode = pg:GetAttribute("PizzaOverlay")
			local name = if type(mode) == "string" then modes[mode] else nil
			local screen = if name then pg:FindFirstChild(name) else nil
			if not screen then
				return
			end
			local selected = GuiService.SelectedObject
			local scrolling: ScrollingFrame? = nil
			local ancestor: Instance? = selected
			while ancestor and ancestor ~= screen do
				if ancestor:IsA("ScrollingFrame") then
					scrolling = ancestor
					break
				end
				ancestor = ancestor.Parent
			end
			if not scrolling then
				for _, child in screen:GetDescendants() do
					if
						child:IsA("ScrollingFrame")
						and child.ScrollingDirection ~= Enum.ScrollingDirection.X
						and visible(child)
					then
						scrolling = child
						break
					end
				end
			end
			if scrolling then
				scrolling.CanvasPosition += stick * Config.gamepadScrollSpeed * math.min(
					dt,
					Config.gamepadMaxDelta
				)
			end
		end)
	)
	queue()
end
function GamepadController.destroy()
	alive = false
	ContextActionService:UnbindAction("PizzaCloseOverlay")
	ContextActionService:UnbindAction("PizzaFocusMenu")
	ContextActionService:UnbindAction("PizzaScrollPanel")
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for _, record in records do
		record.gained:Disconnect()
		record.lost:Disconnect()
		record.stroke:Destroy()
	end
	table.clear(records)
end
return GamepadController
