--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local Workspace = game:GetService("Workspace")
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local Paint = require(script.Parent.Parent.Util.ShopView)
local Activity = require(script.Parent.Parent.Util.ProfileActivity)
local Config = require(ReplicatedStorage.Shared.Config.ProfileActivity)
local Localize = require(ReplicatedStorage.Shared.Util.Localize)
local Trial = require(ReplicatedStorage.Shared.Util.Trial)
local totalGold = #require(ReplicatedStorage.Shared.Config.Collectibles).spots
local ProfileController = {}
local connections: { RBXScriptConnection } = {}
local observed: { [Player]: { RBXScriptConnection } } = {}
local screen: ScreenGui?
local alive = false
local timer: thread? = nil
function ProfileController.start()
	if alive then
		return
	end
	alive = true
	local ui = Panel.new("CourierProfile", "Courier profile")
	screen = ui.screen
	local selected = Players.LocalPlayer
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local activity: Frame? = nil
	local labels: { [string]: TextLabel } = {}
	local function refreshActivity()
		if not activity or not activity.Parent then
			return
		end
		local language = Localize.locale(
			pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
		)
		local rows = Activity.rows({
			best = selected:GetAttribute("TrialBestMs"),
			gold = selected:GetAttribute("GoldenFound"),
			wins = selected:GetAttribute("RivalWins"),
			buff = selected:GetAttribute("WishBuff"),
			untilAt = selected:GetAttribute("WishBuffUntil"),
			stamps = selected:GetAttribute("RouteStampCount"),
			totalRoutes = selected:GetAttribute("RouteStampTotal"),
		}, Workspace:GetServerTimeNow(), totalGold, Config.labels[language], Trial.format)
		local wanted = {}
		for index, row in rows do
			wanted[row.key] = true
			local label: TextLabel? = labels[row.key]
			if not label then
				local created = Paint.label(activity, row.key, row.text, 17) :: TextLabel
				created.TextXAlignment = Enum.TextXAlignment.Left
				created.AutomaticSize = Enum.AutomaticSize.Y
				created.Size = UDim2.new(1, 0, 0, 56)
				labels[row.key], label = created, created
			end
			if label then
				label.Text, label.LayoutOrder = row.text, index
			end
		end
		for key, label in labels do
			if not wanted[key] then
				label:Destroy()
				labels[key] = nil
			end
		end
	end
	local function render()
		if not alive then
			return
		end
		Panel.clear(ui.scroll)
		activity = nil
		table.clear(labels)
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
			local block = Instance.new("Frame")
			block.Name, block.LayoutOrder = "Activity", 1
			block.Size = UDim2.new(1, -8, 0, 0)
			block.AutomaticSize = Enum.AutomaticSize.Y
			block.BackgroundColor3 = Paint.colors.row
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
			padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
			padding.Parent = block
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 8)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = block
			block.Parent = ui.scroll
			Paint.round(block)
			activity = block
			refreshActivity()
		else
			ui.status.Text = "This courier's profile is loading. Try again shortly."
		end
		for index, player in Players:GetPlayers() do
			local row = Panel.row(
				ui.scroll,
				tostring(player.UserId),
				`View {player.DisplayName}`,
				index + 1
			)
			row.Activated:Connect(function()
				selected = player
				render()
			end)
		end
	end
	local function observe(player: Player)
		local list = {
			player:GetAttributeChangedSignal("CourierProfile"):Connect(function()
				if selected == player then
					render()
				end
			end),
		}
		for _, name in
			{
				"TrialBestMs",
				"GoldenFound",
				"RivalWins",
				"WishBuff",
				"WishBuffUntil",
				"RouteStampCount",
				"RouteStampTotal",
			}
		do
			table.insert(
				list,
				player:GetAttributeChangedSignal(name):Connect(function()
					if selected == player then
						refreshActivity()
					end
				end)
			)
		end
		observed[player] = list
		render()
	end
	table.insert(connections, Players.PlayerAdded:Connect(observe))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			local list = observed[player]
			if list then
				for _, c in list do
					c:Disconnect()
				end
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
	table.insert(
		connections,
		pg:GetAttributeChangedSignal("UILocaleOverride"):Connect(refreshActivity)
	)
	table.insert(
		connections,
		LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(refreshActivity)
	)
	timer = task.spawn(function()
		while alive do
			task.wait(Config.refreshSeconds)
			if alive and ui.overlay.Visible then
				refreshActivity()
			end
		end
	end)
end
function ProfileController.destroy()
	alive = false
	if timer then
		task.cancel(timer)
		timer = nil
	end
	for _, c in connections do
		c:Disconnect()
	end
	for _, list in observed do
		for _, c in list do
			c:Disconnect()
		end
	end
	table.clear(connections)
	table.clear(observed)
	if screen then
		screen:Destroy()
		screen = nil
	end
end
return ProfileController
