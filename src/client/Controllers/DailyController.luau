--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.DailyRewards)
local DailyController = {}
local player = Players.LocalPlayer
local C = {
	panel = Color3.fromHex("#1F1B24"),
	row = Color3.fromHex("#302936"),
	cream = Color3.fromHex("#FFF3D6"),
	cheese = Color3.fromHex("#FFD24A"),
}
local connections: { RBXScriptConnection } = {}
local gui: ScreenGui?
local function round(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = parent
end
local function text(parent: Instance, value: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = C.cream
	label.TextWrapped = true
	label.TextSize = size
	label.Text = value
	label.Parent = parent
	return label
end
local function button(parent: Instance, name: string, value: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = value
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.BackgroundColor3 = C.cheese
	b.TextColor3 = C.panel
	b.Parent = parent
	round(b)
	return b
end
local function decode(attribute: string): any
	local value = player:GetAttribute(attribute)
	if type(value) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(value)
	end)
	return if ok and type(decoded) == "table" then decoded else nil
end
function DailyController.start()
	local pg = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "Daily"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 21
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = pg
	gui = screen
	local open = button(screen, "OpenDaily", "Daily")
	open.Position = UDim2.fromOffset(12, 168)
	open.Size = UDim2.fromOffset(110, 44)
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
	limit.MaxSize = Vector2.new(720, 620)
	limit.Parent = panel
	local title = text(panel, "Daily specials", 26)
	title.Name = "Title"
	title.Font = Enum.Font.FredokaOne
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -86, 0, 40)
	local close = button(panel, "Close", "×")
	close.Position = UDim2.new(1, -56, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	local status = text(panel, "Rewards for your next route.", 15)
	status.Name = "Status"
	status.Position = UDim2.fromOffset(18, 58)
	status.Size = UDim2.new(1, -36, 0, 42)
	status.TextXAlignment = Enum.TextXAlignment.Left
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Calendar"
	scroll.Position = UDim2.fromOffset(18, 106)
	scroll.Size = UDim2.new(1, -36, 1, -124)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = C.cheese
	scroll.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pending: string? = nil
	local requestToken = 0
	local function hide()
		overlay.Visible = false
		if pg:GetAttribute("PizzaOverlay") == "Daily" then
			pg:SetAttribute("PizzaOverlay", nil)
		end
	end
	local function render()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local state = decode("DailyState")
		if not state then
			status.Text = "Your calendar is loading. It will appear here shortly."
			return
		end
		local reward = decode("DailyReward")
		status.Text = if pending
			then "Saving your challenge…"
			elseif
				reward
			then `Day {reward.day} claimed: +{reward.tips} tips · +{reward.xp} XP{if reward.cosmetic
				then " · New look!"
				else ""}`
			else "Today's reward is already claimed. Skipped days never reset your calendar."
		for day, gift in Config.daily do
			local row = Instance.new("Frame")
			row.Name = `Day{day}`
			row.LayoutOrder = day
			row.Size = UDim2.new(1, -8, 0, 54)
			row.BackgroundColor3 = if day == state.daily.day then C.cheese else C.row
			row.Parent = scroll
			round(row)
			local copy = text(
				row,
				`Day {day}  ·  {gift.tips} tips{if gift.xp > 0
					then " + " .. gift.xp .. " XP"
					else ""}{if gift.cosmetic then " + new look" else ""}{if day
						== state.daily.day
					then "  ·  Claimed"
					else ""}`,
				16
			)
			copy.Size = UDim2.new(1, -20, 1, 0)
			copy.Position = UDim2.fromOffset(10, 0)
			copy.TextXAlignment = Enum.TextXAlignment.Left
			copy.TextColor3 = if day == state.daily.day then C.panel else C.cream
		end
		local heading = Instance.new("Frame")
		heading.Name = "WeeklyHeading"
		heading.LayoutOrder = 8
		heading.Size = UDim2.new(1, -8, 0, 50)
		heading.BackgroundTransparency = 1
		heading.Parent = scroll
		local caption = text(heading, "This week's challenges · choose up to 3", 18)
		caption.Size = UDim2.fromScale(1, 1)
		caption.TextXAlignment = Enum.TextXAlignment.Left
		local selected = 0
		for _ in state.weekly.selected do
			selected += 1
		end
		for index, challenge in state.choices do
			local entry = state.weekly.selected[challenge.id]
			local row = Instance.new("Frame")
			row.Name = challenge.id
			row.LayoutOrder = 8 + index
			row.Size = UDim2.new(1, -8, 0, 144)
			row.BackgroundColor3 = C.row
			row.Parent = scroll
			round(row)
			local description = text(
				row,
				`{challenge.name}\n{if entry then entry.progress else 0} / {challenge.target} · {challenge.tips} tips + {challenge.xp} XP`,
				16
			)
			description.Position = UDim2.fromOffset(12, 8)
			description.Size = UDim2.new(1, -24, 0, 70)
			description.TextXAlignment = Enum.TextXAlignment.Left
			local eligible = if entry
				then not entry.claimed and entry.progress >= challenge.target
				else selected < Config.weekly.selectionLimit
			local action = button(
				row,
				"Action",
				if entry
					then (if entry.claimed
						then "Claimed"
						elseif eligible then "Claim reward"
						else "In progress")
					elseif eligible then "Choose challenge"
					else "3 selected"
			)
			action.Position = UDim2.fromOffset(12, 88)
			action.Size = UDim2.fromOffset(170, 44)
			local enabled = eligible and pending == nil
			action.Active = enabled
			action.AutoButtonColor = enabled
			action.BackgroundColor3 = if enabled then C.cheese else C.row
			action.TextColor3 = if enabled then C.panel else C.cream
			action.Activated:Connect(function()
				if not eligible or pending then
					return
				end
				local key = `daily:{if entry then "claim" else "select"}.{challenge.id}`
				pending = key
				requestToken += 1
				local token = requestToken
				render()
				Net.event("RequestPurchase"):FireServer(key)
				task.delay(Config.requestTimeoutSeconds, function()
					if
						gui == screen
						and screen.Parent
						and pending == key
						and token == requestToken
					then
						pending = nil
						render()
						status.Text = "No reply yet. Please try again."
					end
				end)
			end)
		end
	end
	local function show()
		pg:SetAttribute("PizzaOverlay", "Daily")
		overlay.Visible = true
		render()
	end
	table.insert(
		connections,
		open.Activated:Connect(function()
			if overlay.Visible then
				hide()
			else
				show()
			end
		end)
	)
	table.insert(connections, close.Activated:Connect(hide))
	table.insert(connections, backdrop.Activated:Connect(hide))
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			if pg:GetAttribute("PizzaOverlay") ~= "Daily" then
				overlay.Visible = false
			end
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("DailyState"):Connect(render))
	local seenReward: string? = nil
	local function rewardChanged()
		local value = player:GetAttribute("DailyReward")
		if type(value) == "string" and value ~= seenReward then
			seenReward = value
			show()
		end
	end
	table.insert(
		connections,
		player:GetAttributeChangedSignal("DailyReward"):Connect(rewardChanged)
	)
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(ok: any, reason: any, key: any)
			if type(key) == "string" and not string.match(key, "^daily:") then
				return
			end
			if pending and key == pending then
				pending = nil
				requestToken += 1
				render()
				if ok == false then
					status.Text = tostring(reason)
				end
			end
		end)
	)
	render()
	rewardChanged()
end
function DailyController.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if gui then
		gui:Destroy()
		gui = nil
	end
end
return DailyController
