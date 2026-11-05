--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.Sounds)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Policy = require(ReplicatedStorage.Shared.Util.SoundPolicy)
local Panel = require(script.Parent.CommunityPanel)
local View = require(script.Parent.ShopView)
local AudioSettingsWidget = {}
function AudioSettingsWidget.mount(parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = "Audio"
	frame.LayoutOrder = 5
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 308)
	frame.Parent = parent
	local player = Players.LocalPlayer
	local pending: string? = nil
	local token = 0
	local rows: { [string]: any } = {}
	local status = View.label(frame, "Status", "", 15)
	status.Position = UDim2.fromOffset(0, 256)
	status.Size = UDim2.new(1, 0, 0, 72)
	local function refresh()
		for channel, row in rows do
			local value = math.floor(Policy.volume(player:GetAttribute(row.attribute)) * 100 + 0.5)
			row.value.Text = if value == 0 then "Muted · Restore" else `{value}% · Mute`
			for _, b in { row.less, row.value, row.more } do
				b.Active = pending == nil
				b.AutoButtonColor = pending == nil
			end
			row.less.Selectable = pending == nil and value > 0
			row.more.Selectable = pending == nil and value < 100
			local _ = channel
		end
	end
	local function send(channel: string, value: number)
		if pending then
			return
		end
		local key = `audio:{channel}.{value}`
		pending = key
		token += 1
		local current = token
		status.Text = "Saving…"
		refresh()
		Net.event("RequestPurchase"):FireServer(key)
		task.delay(Settings.requestTimeoutSeconds, function()
			if frame.Parent and pending == key and token == current then
				pending = nil
				status.Text = "No reply yet. Please try again."
				refresh()
			end
		end)
	end
	for index, channel in { "music", "sfx" } do
		local y = (index - 1) * 128
		local title = View.label(
			frame,
			channel .. "Label",
			if channel == "music" then "Music" else "Sound effects",
			18
		)
		title.Position = UDim2.fromOffset(0, y)
		title.Size = UDim2.new(1, 0, 0, 36)
		local less = Panel.row(frame, channel .. "Less", "−", 0)
		less.Position, less.Size = UDim2.fromOffset(0, y + 40), UDim2.fromOffset(52, 72)
		local value = Panel.row(frame, channel .. "Mute", "", 0)
		value.Position, value.Size = UDim2.fromOffset(64, y + 40), UDim2.new(1, -128, 0, 72)
		local more = Panel.row(frame, channel .. "More", "+", 0)
		more.Position, more.Size = UDim2.new(1, -52, 0, y + 40), UDim2.fromOffset(52, 72)
		local attribute = if channel == "music" then "MusicVolume" else "SfxVolume"
		rows[channel] = { attribute = attribute, less = less, value = value, more = more }
		local function percent(): number
			return math.floor(Policy.volume(player:GetAttribute(attribute)) * 100 + 0.5)
		end
		less.Activated:Connect(function()
			send(channel, Policy.step(percent(), -1, Config.volumeSteps))
		end)
		more.Activated:Connect(function()
			send(channel, Policy.step(percent(), 1, Config.volumeSteps))
		end)
		value.Activated:Connect(function()
			send(channel, if percent() == 0 then 50 else 0)
		end)
	end
	local observed = {
		player:GetAttributeChangedSignal("MusicVolume"):Connect(refresh),
		player:GetAttributeChangedSignal("SfxVolume"):Connect(refresh),
		Net.event("PurchaseResult").OnClientEvent:Connect(function(ok: any, reason: any, key: any)
			if not pending or pending ~= key then
				return
			end
			pending = nil
			token += 1
			status.Text = if ok then "Volume saved." else tostring(reason)
			refresh()
		end),
	}
	frame.Destroying:Connect(function()
		token += 1
		for _, c in observed do
			c:Disconnect()
		end
	end)
	refresh()
end
return AudioSettingsWidget
