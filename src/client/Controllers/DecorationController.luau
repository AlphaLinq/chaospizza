--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Decorations)
local Logic = require(ReplicatedStorage.Shared.Util.Decorations).new(Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Localize = require(ReplicatedStorage.Shared.Util.Localize)
local Paint = require(script.Parent.Parent.Util.ShopView)
local View = require(script.Parent.Parent.Util.DecorationView)
local Controller = {}
local alive = false
local generation = 0
local connections: { RBXScriptConnection } = {}
local link: TextButton? = nil
local ui: any = nil
function Controller.start()
	if alive then
		return
	end
	alive = true
	generation += 1
	local version = generation
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local screen = pg:WaitForChild("Cosmetics", Config.startupTimeoutSeconds)
	if not screen or not alive or generation ~= version then
		return
	end
	local overlay = screen:WaitForChild("Overlay") :: Frame
	local panel = overlay:WaitForChild("Panel") :: Frame
	local items = panel:WaitForChild("Items")
	if not alive or generation ~= version then
		return
	end
	local state: any = nil
	local slot, id = "flag", Config.items[1].id
	local pending: string? = nil
	local requestToken = 0
	local message: string? = nil
	local function language(): string
		return Localize.locale(
			pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
		)
	end
	local function render()
		if not alive then
			return
		end
		if link then
			link.Text = Config.labels[language()].link
		end
		if ui then
			ui.render(language(), slot, id, state, pending ~= nil, message)
		end
	end
	local function selectItem(selected: string)
		local item = Logic.get(selected)
		if not item then
			return
		end
		id, slot, message = item.id, item.slot, nil
		render()
	end
	local function selectSlot(selected: string)
		for _, item in Config.items do
			if item.slot == selected then
				selectItem(
					if state and state.slots[selected] then state.slots[selected] else item.id
				)
				return
			end
		end
	end
	local function request(action: string)
		if pending or not state or not state.ready then
			return
		end
		pending = "decor:" .. action
		message = nil
		requestToken += 1
		local token = requestToken
		render()
		Net.event("RequestPurchase"):FireServer(pending)
		task.delay(Config.requestTimeoutSeconds, function()
			if alive and generation == version and pending and requestToken == token then
				pending = nil
				message = "timeout"
				render()
			end
		end)
	end
	local function back()
		pg:SetAttribute("PizzaDecorationEditor", nil)
	end
	ui = View.new(panel, selectItem, selectSlot, function()
		if state and state.slots[slot] ~= id then
			request(if state.owned[id] then "place." .. slot .. "." .. id else "buy." .. id)
		end
	end, function()
		if state and state.slots[slot] then
			request("clear." .. slot)
		end
	end, back)
	local entry = Instance.new("TextButton")
	entry.Name, entry.LayoutOrder = "DecorationsLink", -10
	entry.Font, entry.TextSize, entry.TextWrapped = Enum.Font.GothamBold, 17, true
	entry.Size = UDim2.new(1, -8, 0, 64)
	entry.BackgroundColor3, entry.TextColor3 = Paint.colors.cheese, Paint.colors.panel
	entry.Parent = items
	Paint.round(entry)
	link = entry
	table.insert(
		connections,
		entry.Activated:Connect(function()
			pg:SetAttribute("PizzaDecorationEditor", true)
		end)
	)
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("PizzaDecorationEditor"):Connect(function()
			local open = pg:GetAttribute("PizzaDecorationEditor") == true and overlay.Visible
			ui.show(open)
			render()
			if open and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
				GuiService.SelectedObject = ui.back
			end
		end)
	)
	table.insert(
		connections,
		overlay:GetPropertyChangedSignal("Visible"):Connect(function()
			if not overlay.Visible then
				back()
			end
		end)
	)
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("DecorationPreview"):Connect(function()
			local value = pg:GetAttribute("DecorationPreview")
			if type(value) == "string" then
				selectItem(value)
			end
		end)
	)
	local function refresh()
		local raw = player:GetAttribute("DecorationsState")
		local ok, result = pcall(function()
			return HttpService:JSONDecode(if type(raw) == "string" then raw else "")
		end)
		state = if ok
				and type(result) == "table"
				and type(result.slots) == "table"
				and type(result.owned) == "table"
			then result
			else nil
		render()
	end
	table.insert(connections, player:GetAttributeChangedSignal("DecorationsState"):Connect(refresh))
	table.insert(connections, pg:GetAttributeChangedSignal("UILocaleOverride"):Connect(render))
	table.insert(
		connections,
		LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(render)
	)
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(_, reason, key)
			if pending and key == pending then
				pending = nil
				requestToken += 1
				message = if type(reason) == "string" then reason else "failed"
				refresh()
			end
		end)
	)
	ContextActionService:BindActionAtPriority("PizzaDecorationBack", function(_, inputState)
		if
			ui
			and ui.detail.Visible
			and overlay.Visible
			and not GuiService.MenuIsOpen
			and inputState == Enum.UserInputState.Begin
		then
			back()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 3, Enum.KeyCode.ButtonB)
	refresh()
end
function Controller.destroy()
	alive = false
	generation += 1
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	ContextActionService:UnbindAction("PizzaDecorationBack")
	if ui then
		ui.destroy()
		ui = nil
	end
	if link then
		link:Destroy()
		link = nil
	end
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		pg:SetAttribute("PizzaDecorationEditor", nil)
	end
end
return Controller
