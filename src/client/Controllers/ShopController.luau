--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.Shared.Net)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Progression).shop
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ActiveBoostView = require(script.Parent.Parent.Util.ActiveBoostView)
local ShopController = {}
local player = Players.LocalPlayer
local View = require(script.Parent.Parent.Util.ShopView)
local C, round, label = View.colors, View.round, View.label
local connections: { RBXScriptConnection } = {}
local function listen(signal: RBXScriptSignal, callback: any)
	table.insert(connections, signal:Connect(callback))
end
local gui: ScreenGui?
local alive = false
function ShopController.start()
	if alive then
		return
	end
	alive = true
	local playerGui = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "Shop"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 20
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	gui = screen
	local open = Instance.new("TextButton")
	open.Name = "OpenShop"
	open.Position = UDim2.fromOffset(12, 116)
	open.Size = UDim2.fromOffset(110, 44)
	open.BackgroundColor3 = C.row
	open.TextColor3 = C.cream
	open.Text = "Shop"
	open.Font = Enum.Font.GothamBold
	open.TextSize = 18
	open.Parent = screen
	round(open)
	local lockHint = label(screen, "ShopLock", "", 13)
	lockHint.Position = UDim2.fromOffset(12, 272)
	lockHint.Size = UDim2.fromOffset(200, 48)
	lockHint.TextYAlignment = Enum.TextYAlignment.Top
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.Parent = screen
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Text = ""
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.3
	backdrop.AutoButtonColor = false
	backdrop.Parent = overlay
	local panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.84)
	panel.BackgroundColor3 = C.panel
	panel.Active = true
	panel.Parent = overlay
	round(panel)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(760, 620)
	constraint.Parent = panel
	local title = label(panel, "Title", "The Pizza Shop", 26)
	title.Font = Enum.Font.FredokaOne
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -86, 0, 38)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "×"
	close.TextSize = 30
	close.Font = Enum.Font.GothamBold
	close.TextColor3 = C.cream
	close.BackgroundColor3 = C.row
	close.Position = UDim2.new(1, -56, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	close.Parent = panel
	round(close)
	local status = label(panel, "Status", "Browse passes, boosts and tips.", 14)
	status.Position = UDim2.fromOffset(18, 108)
	status.Size = UDim2.new(1, -36, 0, 40)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.Position = UDim2.fromOffset(18, 156)
	scroll.Size = UDim2.new(1, -36, 1, -174)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = C.cheese
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local selected = "Passes"
	local updateBoosts = ActiveBoostView.new(player, scroll, function()
		return selected == "Boosts"
	end)
	local snapshot: any = nil
	local fetching = false
	local pending = false
	local pendingKey: string? = nil
	local pendingSince = 0
	local serverBlock: string? = nil
	local unlockAt = 0
	local buttons: { TextButton } = {}
	local cityConnection: RBXScriptConnection? = nil
	local function localBlock(): string?
		return View.blockReason(player, unlockAt, serverBlock)
	end
	local function gate()
		local reason = localBlock()
		open.BackgroundColor3 = if reason then C.row else C.cheese
		open.TextColor3 = if reason then C.muted else C.panel
		lockHint.Text = reason or ""
		if reason then
			status.Text = reason
		end
		for _, button in buttons do
			local enabled = button:GetAttribute("Available") == true and not reason and not pending
			button.Active = enabled
			button.AutoButtonColor = enabled
			button.BackgroundColor3 = if enabled then C.cheese else C.row
			button.TextColor3 = if enabled then C.panel else C.muted
		end
	end
	local function hide()
		overlay.Visible = false
		if playerGui:GetAttribute("PizzaOverlay") == "Shop" then
			playerGui:SetAttribute("PizzaOverlay", nil)
		end
	end
	local function render()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") and child.Name ~= "ActiveBoosts" then
				child:Destroy()
			end
		end
		table.clear(buttons)
		updateBoosts()
		if not snapshot then
			return
		end
		local source = if selected == "Passes" then snapshot.gamepasses else snapshot.products
		local count = 0
		for _, item in source do
			local tips = string.match(item.key, "^Tips") ~= nil
			if
				selected == "Passes"
				or (selected == "Tips" and tips)
				or (selected == "Boosts" and not tips)
			then
				count += 1
				local odds = {}
				if type(item.odds) == "table" then
					for _, rarity in Rarities do
						table.insert(
							odds,
							`{rarity.displayName} {string.format("%.2f", item.odds[rarity.id] or 0)}%`
						)
					end
				end
				local row = Instance.new("Frame")
				row.Name = item.key
				row.LayoutOrder = count
				row.Size = UDim2.new(1, -8, 0, if #odds > 0 then 204 else 108)
				row.BackgroundColor3 = C.row
				row.Parent = scroll
				round(row)
				local name = label(row, "ItemName", item.name, 18)
				name.Font = Enum.Font.GothamBold
				name.Position = UDim2.fromOffset(12, 10)
				name.Size = UDim2.new(1, -24, 0, 44)
				local buy = Instance.new("TextButton")
				buy.Name = "Buy"
				buy.Position = UDim2.fromOffset(12, 56)
				buy.Size = UDim2.fromOffset(150, 44)
				buy.Font = Enum.Font.GothamBold
				buy.TextSize = 16
				buy.Text = if item.owned
					then "Owned"
					elseif not item.available then "Coming soon"
					else `{item.price} Robux`
				buy:SetAttribute("Available", item.available == true and item.owned ~= true)
				buy.Parent = row
				round(buy)
				table.insert(buttons, buy)
				buy.Activated:Connect(function()
					if localBlock() or pending or buy:GetAttribute("Available") ~= true then
						return
					end
					pending = true
					pendingKey = item.key
					pendingSince = os.clock()
					status.Text = "Opening Roblox purchase window…"
					gate()
					Net.event("RequestPurchase"):FireServer(item.key)
				end)
				if #odds > 0 then
					local prefix = if item.key == "MegaChaosNow"
						then "MEGA base customer odds"
						else "Customer odds with this boost"
					local oddsText =
						label(row, "Odds", prefix .. "\n" .. table.concat(odds, " · "), 14)
					oddsText.Position = UDim2.fromOffset(12, 110)
					oddsText.Size = UDim2.new(1, -24, 0, 82)
					oddsText.TextYAlignment = Enum.TextYAlignment.Top
				end
			end
		end
		status.Text = if count == 0
			then "No items in this section yet."
			else "Roblox shows the final price before you confirm."
		gate()
	end
	local function refresh()
		if fetching then
			return
		end
		fetching = true
		status.Text = "Loading the shop…"
		task.spawn(function()
			local ok, result = pcall(function()
				return Net.func("GetShop"):InvokeServer()
			end)
			fetching = false
			if not alive then
				return
			end
			if
				ok
				and type(result) == "table"
				and type(result.gamepasses) == "table"
				and type(result.products) == "table"
			then
				snapshot = result
				serverBlock = result.blockedReason
				-- Persistent server gates are refreshed on attribute changes and opening.
				if
					type(result.secondsUntilAllowed) == "number"
					and player:GetAttribute("SessionCount") == 1
				then
					unlockAt = os.clock() + result.secondsUntilAllowed
				end
				render()
			else
				status.Text = "The shop couldn't load. Close and reopen to retry."
			end
		end)
	end
	local function refreshGate()
		serverBlock = nil
		gate()
		if overlay.Visible then
			refresh()
		end
	end
	for index, tab in { "Passes", "Boosts", "Tips", "Looks", "Ride" } do
		local button = Instance.new("TextButton")
		button.Name = tab
		button.Text = tab
		button.Size = UDim2.new(0.2, -13.6, 0, 44)
		button.Position = UDim2.new((index - 1) / 5, 18 - (index - 1) * 5.6, 0, 58)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 16
		button.BackgroundColor3 = if tab == selected then C.cheese else C.row
		button.TextColor3 = if tab == selected then C.panel else C.cream
		button.Parent = panel
		round(button)
		table.insert(
			connections,
			button.Activated:Connect(function()
				if tab == "Ride" then
					playerGui:SetAttribute("PizzaOverlay", "Rides")
					return
				end
				if tab == "Looks" then
					playerGui:SetAttribute("PizzaOverlay", "Cosmetics")
					return
				end
				selected = tab
				for _, sibling in panel:GetChildren() do
					if sibling:IsA("TextButton") and sibling.Name ~= "Close" then
						sibling.BackgroundColor3 = if sibling == button then C.cheese else C.row
						sibling.TextColor3 = if sibling == button then C.panel else C.cream
					end
				end
				render()
			end)
		)
	end
	listen(open.Activated, function()
		if overlay.Visible then
			hide()
			return
		end
		playerGui:SetAttribute("PizzaOverlay", "Shop")
		overlay.Visible = true
		pending = false
		refresh()
	end)
	listen(close.Activated, hide)
	listen(backdrop.Activated, hide)
	listen(UserInputService.InputBegan, function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			hide()
		end
	end)
	listen(playerGui:GetAttributeChangedSignal("PizzaOverlay"), function()
		if playerGui:GetAttribute("PizzaOverlay") ~= "Shop" then
			overlay.Visible = false
		end
	end)
	listen(player:GetAttributeChangedSignal("OnboardingStep"), refreshGate)
	listen(player:GetAttributeChangedSignal("SessionCount"), refreshGate)
	listen(Net.event("PurchaseResult").OnClientEvent, function(accepted: any, reason: any, key: any)
		if type(key) == "string" and string.find(key, ":", 1, true) then
			return
		end
		if pending and key ~= pendingKey then
			return
		end
		pending = false
		pendingKey = nil
		status.Text = if type(reason) == "string" then reason else "Purchase request finished."
		gate()
		if accepted == false then
			serverBlock = nil
		end
	end)
	local function observeCity(city: Instance)
		if cityConnection then
			cityConnection:Disconnect()
		end
		cityConnection = city:GetAttributeChangedSignal("EventPhase"):Connect(refreshGate)
	end
	local city = ReplicatedStorage:FindFirstChild("CityState")
	if city then
		observeCity(city)
	end
	listen(ReplicatedStorage.ChildAdded, function(child)
		if child.Name == "CityState" then
			observeCity(child)
		end
	end)
	listen(screen.Destroying, function()
		if cityConnection then
			cityConnection:Disconnect()
		end
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if not alive then
				break
			end
			updateBoosts()
			if pending and os.clock() - pendingSince >= ShopConfig.requestTimeoutSeconds then
				pending = false
				pendingKey = nil
				gate()
				status.Text = "No reply yet. Please try again."
			end
			if unlockAt > 0 and unlockAt <= os.clock() then
				unlockAt = 0
				serverBlock = nil
				gate()
				if overlay.Visible then
					refresh()
				end
			end
		end
	end)
	gate()
end
function ShopController.destroy()
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
return ShopController
