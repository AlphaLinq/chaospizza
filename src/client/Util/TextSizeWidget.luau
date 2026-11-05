--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.Settings)
local Panel = require(script.Parent.CommunityPanel)
local TextSizeWidget = {}
function TextSizeWidget.mount(parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = "TextSize"
	frame.LayoutOrder = 4
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 160)
	frame.Parent = parent
	local pending: string? = nil
	local buttons: { [string]: TextButton } = {}
	local function refresh()
		for key, button in buttons do
			button.Active = pending == nil
			button.Text = (if key == "large" then "Large text" else "Normal text")
				.. (
					if Players.LocalPlayer:GetAttribute("TextSize") == key
						then " · selected"
						else ""
				)
		end
	end
	for index, key in { "normal", "large" } do
		local b = Panel.row(frame, key, "", index)
		b.Size = UDim2.new(1, 0, 0, 72)
		b.Position = UDim2.fromOffset(0, (index - 1) * 84)
		buttons[key] = b
		b.Activated:Connect(function()
			if pending then
				return
			end
			local intent = `settings:textsize.{key}`
			pending = intent
			refresh()
			Net.event("RequestPurchase"):FireServer(intent)
			task.delay(Config.requestTimeoutSeconds, function()
				if frame.Parent and pending == intent then
					pending = nil
					refresh()
				end
			end)
		end)
	end
	local observed = Players.LocalPlayer:GetAttributeChangedSignal("TextSize"):Connect(refresh)
	local reply = Net.event("PurchaseResult").OnClientEvent:Connect(function(_, _, key: any)
		if pending == key then
			pending = nil
			refresh()
		end
	end)
	frame.Destroying:Connect(function()
		observed:Disconnect()
		reply:Disconnect()
	end)
	refresh()
end
return TextSizeWidget
