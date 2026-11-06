--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local LocalizationService = game:GetService("LocalizationService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Ticker)
local Logic = require(ReplicatedStorage.Shared.Util.Ticker)
local Settings = require(ReplicatedStorage.Shared.Util.Settings).new(
	require(ReplicatedStorage.Shared.Config.Settings)
)
local Net = require(ReplicatedStorage.Shared.Net)
local Paint = require(script.Parent.Parent.Util.ShopView)
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local Controller = {}
local alive = false
local screen: ScreenGui? = nil
local button: TextButton? = nil
local connections: { RBXScriptConnection } = {}
function Controller.start()
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "MomentTicker"
	gui.DisplayOrder = 8
	gui.ResetOnSpawn = false
	gui.Parent = pg
	screen = gui
	local root = Instance.new("Frame")
	root.Name = "News"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -12, 0, Config.top)
	root.Parent = gui
	local labels = {}
	for i = 1, Config.maxRows do
		local label = Paint.label(root, `News{i}`, "", Config.textSize)
		label.BackgroundTransparency = 0.15
		label.BackgroundColor3 = Paint.colors.panel
		label.TextTruncate = Enum.TextTruncate.AtEnd
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
		padding.Parent = label
		Paint.round(label)
		labels[i] = label
	end
	local pending: string? = nil
	local failed = false
	local token = 0
	local rows: { any } = {}
	local function copy(): any
		local locale = pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
		return Config.labels[if string.sub(string.lower(tostring(locale)), 1, 2) == "hu"
			then "hu"
			else "en"]
	end
	local function setting()
		if not button or not button.Parent then
			return
		end
		local text = copy()
		local enabled = player:GetAttribute("TickerEnabled")
		button.Active = pending == nil and type(enabled) == "boolean"
		button.Text = if pending
			then text.busy
			elseif failed then text.failed
			elseif enabled == nil then text.loading
			elseif enabled then text.on
			else text.off
	end
	local function render()
		local camera = Workspace.CurrentCamera
		if not camera then
			root.Visible = false
			return
		end
		local viewport = camera.ViewportSize
		local compact = viewport.X < Config.mobileWidth
		root.Visible = player:GetAttribute("TickerEnabled") == true
			and not pg:GetAttribute("PizzaOverlay")
			and not GuiService.MenuIsOpen
			and viewport.Y >= Config.minHeight
		local count = if compact then Config.mobileRows else Config.maxRows
		local scale = Settings.textScale(player)
		local height = (if compact then 66 else 54) * scale
		root.Size = UDim2.fromOffset(
			math.min(Config.maxWidth, math.max(0, viewport.X - Config.leftClearance - 12)),
			count * (height + 6)
		)
		local now = Workspace:GetServerTimeNow()
		local live = {}
		for _, row in rows do
			if row.expiresAt > now then
				table.insert(live, row)
			end
		end
		for i, label in labels do
			local row = live[#live - i + 1]
			label.Visible = i <= count and row ~= nil
			label.Position = UDim2.fromOffset(0, (i - 1) * (height + 6))
			label.Size = UDim2.new(1, 0, 0, height)
			label.TextSize = Config.textSize * scale
			if row then
				label.Text = Logic.format(row, copy(), compact, Config)
			end
		end
	end
	local function read()
		local raw = ReplicatedStorage:GetAttribute("MomentTicker")
		local ok, value = pcall(function()
			return HttpService:JSONDecode(if type(raw) == "string" then raw else "[]")
		end)
		rows = if ok and type(value) == "table" then value else {}
		render()
	end
	local ensure: () -> ()
	ensure = function()
		if not alive or button and button.Parent then
			return
		end
		local settings = pg:FindFirstChild("Settings")
		local options = settings and settings:FindFirstChild("Options", true)
		if not options then
			return
		end
		local b = Panel.row(options, "TickerPreference", "", 6)
		button = b
		b.Activated:Connect(function()
			if pending or type(player:GetAttribute("TickerEnabled")) ~= "boolean" then
				return
			end
			local key = if player:GetAttribute("TickerEnabled") then "ticker:off" else "ticker:on"
			pending, failed = key, false
			token += 1
			local current = token
			setting()
			Net.event("RequestPurchase"):FireServer(key)
			task.delay(Config.requestTimeoutSeconds, function()
				if alive and pending == key and token == current then
					pending, failed = nil, true
					setting()
				end
			end)
		end)
		b.Destroying:Connect(function()
			task.defer(ensure)
		end)
		setting()
	end
	table.insert(
		connections,
		pg.DescendantAdded:Connect(function(instance)
			if instance.Name == "Options" then
				task.defer(ensure)
			end
		end)
	)
	table.insert(
		connections,
		player:GetAttributeChangedSignal("TickerEnabled"):Connect(function()
			setting()
			render()
		end)
	)
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("UILocaleOverride"):Connect(function()
			setting()
			render()
		end)
	)
	table.insert(
		connections,
		LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(function()
			setting()
			render()
		end)
	)
	table.insert(
		connections,
		ReplicatedStorage:GetAttributeChangedSignal("MomentTicker"):Connect(read)
	)
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(ok: any, _, key: any)
			if pending and pending == key then
				pending, failed = nil, ok ~= true
				token += 1
				setting()
			end
		end)
	)
	local elapsed = 0
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= Config.refreshSeconds then
				elapsed = 0
				render()
			end
		end)
	)
	ensure()
	read()
end
function Controller.destroy()
	alive = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if button then
		button:Destroy()
		button = nil
	end
	if screen then
		screen:Destroy()
		screen = nil
	end
end
return Controller
