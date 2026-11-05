--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.Settings)
local Settings = require(ReplicatedStorage.Shared.Util.Settings).new(Config)
local Net = require(ReplicatedStorage.Shared.Net)
local SettingsController = {}
local player = Players.LocalPlayer
local connections: { RBXScriptConnection } = {}
local gui: ScreenGui?
local alive = false
local C = {
	panel = Color3.fromHex("#1F1B24"),
	row = Color3.fromHex("#302936"),
	cream = Color3.fromHex("#FFF3D6"),
	cheese = Color3.fromHex("#FFD24A"),
}
local function round(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = parent
end
local function button(parent: Instance, name: string, value: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = value
	b.Font = Enum.Font.GothamBold
	b.TextSize = 17
	b.TextColor3 = C.cream
	b.BackgroundColor3 = C.row
	b.Parent = parent
	round(b)
	return b
end
function SettingsController.start()
	alive = true
	local pg = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "Settings"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 22
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = pg
	gui = screen
	local open = button(screen, "OpenSettings", "Settings")
	open.Position = UDim2.fromOffset(12, 220)
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
	panel.Size = UDim2.new(0.94, 0, 0, 340)
	panel.BackgroundColor3 = C.panel
	panel.Active = true
	panel.Parent = overlay
	round(panel)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 340)
	limit.Parent = panel
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "Graphics"
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = C.cream
	title.TextSize = 26
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -86, 0, 44)
	title.Parent = panel
	local close = button(panel, "Close", "×")
	close.Position = UDim2.new(1, -56, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	local status = title:Clone()
	status.Name = "Status"
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 15
	status.TextWrapped = true
	status.Text = "Choose how much chaos to show."
	status.Position = UDim2.fromOffset(18, 62)
	status.Size = UDim2.new(1, -36, 0, 44)
	status.Parent = panel
	local choices: { [string]: TextButton } = {}
	local pending: string? = nil
	local requestToken = 0
	local function refresh()
		local quality = player:GetAttribute("EffectQuality")
		for key, b in choices do
			b.Active = pending == nil
			b.AutoButtonColor = pending == nil
			b.BackgroundColor3 = if key == quality then C.cheese else C.row
			b.TextColor3 = if key == quality then C.panel else C.cream
		end
		if pending then
			status.Text = "Saving…"
		elseif type(quality) == "string" and Config.presets[quality] then
			status.Text = Config.presets[quality].description
		end
	end
	for index, quality in { "low", "medium", "high" } do
		local preset = Config.presets[quality]
		local b = button(panel, quality, preset.label)
		b.Position = UDim2.fromOffset(18, 112 + (index - 1) * 64)
		b.Size = UDim2.new(1, -36, 0, 52)
		choices[quality] = b
		table.insert(
			connections,
			b.Activated:Connect(function()
				if pending then
					return
				end
				local key = `settings:quality.{quality}`
				pending = key
				requestToken += 1
				local token = requestToken
				refresh()
				Net.event("RequestPurchase"):FireServer(key)
				task.delay(Config.requestTimeoutSeconds, function()
					if
						gui == screen
						and screen.Parent
						and pending == key
						and token == requestToken
					then
						pending = nil
						refresh()
						status.Text = "No reply yet. Please try again."
					end
				end)
			end)
		)
	end
	local function hide()
		overlay.Visible = false
		if pg:GetAttribute("PizzaOverlay") == "Settings" then
			pg:SetAttribute("PizzaOverlay", nil)
		end
	end
	table.insert(
		connections,
		open.Activated:Connect(function()
			if overlay.Visible then
				hide()
			else
				pg:SetAttribute("PizzaOverlay", "Settings")
				overlay.Visible = true
				refresh()
			end
		end)
	)
	table.insert(connections, close.Activated:Connect(hide))
	table.insert(connections, backdrop.Activated:Connect(hide))
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			if pg:GetAttribute("PizzaOverlay") ~= "Settings" then
				overlay.Visible = false
			end
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("EffectQuality"):Connect(refresh))
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(ok: any, reason: any, key: any)
			if type(key) == "string" and not string.match(key, "^settings:") then
				return
			end
			if pending and key ~= pending then
				return
			end
			pending = nil
			requestToken += 1
			refresh()
			if overlay.Visible then
				if ok then
					refresh()
				else
					status.Text = tostring(reason)
				end
			end
		end)
	)
	local requestedDefault = false
	local initial: () -> ()
	initial = function()
		if
			not alive
			or player:GetAttribute("QualityLoaded") ~= true
			or requestedDefault
			or Settings.isQuality(player:GetAttribute("EffectQuality"))
		then
			return
		end
		requestedDefault = true
		local camera = Workspace.CurrentCamera
		local width = if camera
			then math.min(camera.ViewportSize.X, camera.ViewportSize.Y)
			else Config.mobileMaxWidth
		local quality = Settings.default(UserInputService.TouchEnabled, width)
		Net.event("RequestPurchase"):FireServer(`settings:quality.{quality}`)
		task.delay(2, function()
			if alive and not Settings.isQuality(player:GetAttribute("EffectQuality")) then
				requestedDefault = false
				initial()
			end
		end)
	end
	table.insert(connections, player:GetAttributeChangedSignal("QualityLoaded"):Connect(initial))
	refresh()
	initial()
end
function SettingsController.destroy()
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
return SettingsController
