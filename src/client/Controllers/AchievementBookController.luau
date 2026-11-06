--!strict
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.AchievementBook)
local View = require(script.Parent.Parent.Util.AchievementBookView)
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local Paint = require(script.Parent.Parent.Util.ShopView)
local Controller = {}
local alive = false
local link: TextButton? = nil
local screen: ScreenGui? = nil
local connections: { RBXScriptConnection } = {}
function Controller.start()
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local ui = View.new()
	screen = ui.screen
	local function locale(): string
		return if string.sub(
				string.lower(
					tostring(
						pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
					)
				),
				1,
				2
			) == "hu"
			then "hu"
			else "en"
	end
	local function render()
		if not alive then
			return
		end
		local language = locale()
		local copy = Config.labels[language]
		local heading = ui.panel:FindFirstChild("Title") :: TextLabel
		heading.Text = copy.title
		if link and link.Parent then
			link.Text = copy.link
		end
		Panel.clear(ui.scroll)
		local raw = player:GetAttribute("AchievementBook")
		local ok, rows = pcall(function()
			return HttpService:JSONDecode(if type(raw) == "string" then raw else "")
		end)
		if not ok or type(rows) ~= "table" then
			ui.status.Text = copy.loading
			return
		end
		local earned = 0
		for index, row in rows do
			local info = Config.entries[row.key]
			local text = if info then info[language] else { row.key, row.key }
			local card = Instance.new("Frame")
			card.Name, card.LayoutOrder = row.key, index
			card.Size = UDim2.new(1, -8, 0, 188)
			card.BackgroundColor3 = Paint.colors.row
			card.Parent = ui.scroll
			Paint.round(card)
			local title = Paint.label(card, "Heading", text[1], 20)
			title.Font = Enum.Font.FredokaOne
			title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 48)
			local state = if row.awarded
				then copy.awarded
				elseif row.earned then copy.earned
				elseif row.current >= row.target then copy.ready
				else copy.waiting
			local progress =
				Paint.label(card, "Progress", `{row.current} / {row.target} · {state}`, 15)
			progress.Position, progress.Size = UDim2.fromOffset(12, 60), UDim2.new(1, -24, 0, 40)
			local hint = Paint.label(card, "Hint", text[2], 16)
			hint.Position, hint.Size = UDim2.fromOffset(12, 108), UDim2.new(1, -24, 0, 72)
			if row.earned then
				earned += 1
			end
		end
		ui.status.Text = `{copy.summary}: {earned} / {#rows}`
	end
	local ensure: () -> ()
	ensure = function()
		if not alive or link and link.Parent then
			return
		end
		local profile = pg:FindFirstChild("CourierProfile")
		local panel = profile and profile:FindFirstChild("Panel", true)
		local content = panel and panel:FindFirstChild("Content")
		if not content then
			return
		end
		local current = Panel.row(content, "AchievementsLink", Config.labels[locale()].link, -1)
		link = current
		current.Activated:Connect(function()
			pg:SetAttribute("PizzaOverlay", "AchievementBook")
		end)
		current.Destroying:Connect(function()
			task.defer(ensure)
		end)
	end
	table.insert(
		connections,
		pg.DescendantAdded:Connect(function(instance)
			if instance.Name == "Content" or instance.Name == "Stats" then
				task.defer(ensure)
			end
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("AchievementBook"):Connect(render))
	table.insert(connections, pg:GetAttributeChangedSignal("UILocaleOverride"):Connect(render))
	table.insert(
		connections,
		LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(render)
	)
	render()
	ensure()
end
function Controller.destroy()
	alive = false
	if link then
		link:Destroy()
		link = nil
	end
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg and pg:GetAttribute("PizzaOverlay") == "AchievementBook" then
		pg:SetAttribute("PizzaOverlay", "CourierProfile")
	end
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if screen then
		screen:Destroy()
		screen = nil
	end
end
return Controller
