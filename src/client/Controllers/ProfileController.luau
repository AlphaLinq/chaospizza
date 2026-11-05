--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local ProfileController = {}
local connections: { RBXScriptConnection } = {}
local observed: { [Player]: RBXScriptConnection } = {}
local screen: ScreenGui?
function ProfileController.start()
	local ui = Panel.new("CourierProfile", "Courier profile")
	screen = ui.screen
	local selected = Players.LocalPlayer
	local function render()
		Panel.clear(ui.scroll)
		local raw = selected:GetAttribute("CourierProfile")
		local ok, data = pcall(function()
			return HttpService:JSONDecode(if type(raw) == "string" then raw else "")
		end)
		ui.status.Text = `Viewing {selected.DisplayName} · choose a courier below`
		if ok and type(data) == "table" then
			local details = Panel.row(
				ui.scroll,
				"Stats",
				`{data.title}\nCourier level {data.level} · {data.deliveries} deliveries\nBook {data.discovered}/{data.total}\nRarest: {data.rarest} ({data.rarity})\nPizzeria level {data.pizzeriaLevel} · {data.likes} likes today`,
				0
			)
			details.Active = false
			details.Selectable = false
			details.TextSize = 18
			details.Size = UDim2.new(1, -8, 0, 240)
		else
			ui.status.Text = "This courier's profile is loading. Try again shortly."
		end
		for index, player in Players:GetPlayers() do
			local row =
				Panel.row(ui.scroll, tostring(player.UserId), `View {player.DisplayName}`, index)
			row.Activated:Connect(function()
				selected = player
				render()
			end)
		end
	end
	local function observe(player: Player)
		observed[player] = player:GetAttributeChangedSignal("CourierProfile"):Connect(render)
		render()
	end
	table.insert(connections, Players.PlayerAdded:Connect(observe))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			local c = observed[player]
			if c then
				c:Disconnect()
			end
			observed[player] = nil
			if selected == player then
				selected = Players.LocalPlayer
			end
			task.defer(render)
		end)
	)
	for _, player in Players:GetPlayers() do
		observe(player)
	end
end
function ProfileController.destroy()
	for _, c in connections do
		c:Disconnect()
	end
	for _, c in observed do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(observed)
	if screen then
		screen:Destroy()
		screen = nil
	end
end
return ProfileController
