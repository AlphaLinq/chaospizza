--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.Emotes)
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local Animation = require(script.Parent.Parent.Util.EmoteAnimation)
local EmoteController = {}
local gui: ScreenGui?
local connections: { RBXScriptConnection } = {}
local stop: (() -> ())?
function EmoteController.start()
	local ui = Panel.new("Emotes", "Strike a pose")
	gui = ui.screen
	stop = Animation.start()
	ui.status.Text = "Move to cancel. Poses never change your stats."
	local wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.Size = UDim2.new(1, -8, 0, 300)
	wheel.BackgroundTransparency = 1
	wheel.Parent = ui.scroll
	local function refresh()
		local owned: { [string]: boolean } = {}
		local raw = Players.LocalPlayer:GetAttribute("CosmeticsState")
		local ok, data = pcall(function()
			return HttpService:JSONDecode(if type(raw) == "string" then raw else "")
		end)
		if ok and type(data) == "table" then
			for _, item in data do
				owned[item.id] = item.owned == true
			end
		end
		for _, child in wheel:GetChildren() do
			child:Destroy()
		end
		for index, item in Config.items do
			local angle = (index - 1) * 2 * math.pi / #Config.items - math.pi / 2
			local button = Panel.row(
				wheel,
				item.id,
				item.name .. (if owned[item.id] then "" else "\nUnlock in Looks"),
				index
			)
			button.AnchorPoint = Vector2.new(0.5, 0.5)
			button.Position =
				UDim2.fromScale(0.5 + math.cos(angle) * 0.3, 0.5 + math.sin(angle) * 0.3)
			button.Size = UDim2.fromOffset(110, 80)
			button.Active = owned[item.id] == true
			button.Activated:Connect(function()
				if owned[item.id] then
					Net.event("RequestPurchase"):FireServer(`emote:{item.id}`)
				end
			end)
		end
	end
	table.insert(
		connections,
		Players.LocalPlayer:GetAttributeChangedSignal("CosmeticsState"):Connect(refresh)
	)
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(_, reason: any, key: any)
			if type(key) == "string" and string.match(key, "^emote:") then
				ui.status.Text = tostring(reason)
			end
		end)
	)
	refresh()
end
function EmoteController.destroy()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if stop then
		stop()
		stop = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end
return EmoteController
