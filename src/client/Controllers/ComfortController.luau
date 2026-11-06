--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local Config = require(ReplicatedStorage.Shared.Config.Comfort)
local Net = require(ReplicatedStorage.Shared.Net)
local Paint = require(script.Parent.Parent.Util.ShopView)
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local Controller = {}
local alive = false
local connections: { RBXScriptConnection } = {}
local ui: any = nil
local pending: string? = nil
local failed = false
local sequence = 0
function Controller.start()
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local function render()
		if not alive or not ui or not ui.root.Parent then
			return
		end
		local locale = pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
		local copy = Config.labels[if string.sub(string.lower(tostring(locale)), 1, 2) == "hu"
			then "hu"
			else "en"]
		ui.heading.Text = copy.title
		local ready = player:GetAttribute("ComfortReady") == true
		ui.status.Text = if not ready
			then copy.loading
			elseif pending then copy.busy
			elseif failed then copy.failed
			else ""
		for _, item in Config.items do
			local b = ui.buttons[item.key]
			b.Text = copy[item.key]
				.. " · "
				.. (if player:GetAttribute(item.attribute) == true then copy.on else copy.off)
			b.Active, b.AutoButtonColor = ready and pending == nil, ready and pending == nil
		end
	end
	local function ensure()
		if not alive or ui and ui.root.Parent then
			return
		end
		local screen = pg:FindFirstChild("Settings")
		local parent = screen and screen:FindFirstChild("Options", true)
		if not parent then
			return
		end
		local root = Instance.new("Frame")
		root.Name = "Comfort"
		root.BackgroundTransparency = 1
		root.LayoutOrder = 5
		root.Size = UDim2.new(1, -8, 0, 280)
		root.Parent = parent
		local heading = Paint.label(root, "Title", "", 20)
		heading.Font = Enum.Font.FredokaOne
		heading.Size = UDim2.new(1, 0, 0, 42)
		local status = Paint.label(root, "Status", "", 15)
		status.Position, status.Size = UDim2.fromOffset(0, 212), UDim2.new(1, 0, 0, 64)
		ui = { root = root, heading = heading, status = status, buttons = {} }
		for index, item in Config.items do
			local b = Panel.row(root, item.key, "", index)
			b.Position = UDim2.fromOffset(0, 44 + (index - 1) * 84)
			b.Size = UDim2.new(1, 0, 0, 72)
			ui.buttons[item.key] = b
			b.Activated:Connect(function()
				if pending or player:GetAttribute("ComfortReady") ~= true then
					return
				end
				local key = `comfort:{item.key}.{if player:GetAttribute(item.attribute)
					then "off"
					else "on"}`
				pending, failed = key, false
				sequence += 1
				local token = sequence
				render()
				Net.event("RequestPurchase"):FireServer(key)
				task.delay(Config.requestTimeoutSeconds, function()
					if alive and pending == key and sequence == token then
						pending, failed = nil, true
						render()
					end
				end)
			end)
		end
		root.Destroying:Connect(function()
			task.defer(ensure)
		end)
		render()
	end
	for _, attr in { "ComfortReady", "ReduceMotion", "ReduceFlashes" } do
		table.insert(connections, player:GetAttributeChangedSignal(attr):Connect(render))
	end
	table.insert(connections, pg:GetAttributeChangedSignal("UILocaleOverride"):Connect(render))
	table.insert(
		connections,
		LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(render)
	)
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
		Net.event("PurchaseResult").OnClientEvent:Connect(function(ok: any, _, key: any)
			if pending and pending == key then
				pending, failed = nil, ok ~= true
				sequence += 1
				render()
			end
		end)
	)
	ensure()
end
function Controller.destroy()
	alive = false
	sequence += 1
	pending, failed = nil, false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if ui then
		ui.root:Destroy()
		ui = nil
	end
end
return Controller
