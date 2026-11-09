--!strict
-- Shift report card (#234). After each chaos finale the server sends this
-- round's recap (Net "Recap"); show it in the middle of the screen with a
-- big OK button (thumb-sized) and hide it by itself after a few seconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventVote = require(ReplicatedStorage.Shared.Util.EventVote)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local RecapController = {}

local player = Players.LocalPlayer
local BG = Color3.fromHex("#2B2633")
local TEXT = Color3.fromHex("#FFF3D6")
local ACCENT = Color3.fromHex("#FFD23F")

local rarityColor: { [string]: Color3 } = {}
for _, r in Rarities do
	rarityColor[r.id] = Color3.fromHex(r.colorHex)
end

local card: Frame
local headline: TextLabel
local list: Frame
local footer: TextLabel
local shownId = 0

local function line(text: string, order: number, color: Color3?)
	local l = Instance.new("TextLabel")
	l.Name = "Line"
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 24)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 18
	l.TextColor3 = color or TEXT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.LayoutOrder = order
	l.Parent = list
end

local function plural(n: number, one: string, many: string): string
	return `{n} {if n == 1 then one else many}`
end

local function show(report: any)
	if typeof(report) ~= "table" or typeof(report.deliveries) ~= "number" then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	headline.Text = tostring(report.headline or "🍕 Solid Shift!")
	local order = 0
	local function add(text: string, color: Color3?)
		order += 1
		line(text, order, color)
	end
	add(
		`📦 {plural(report.deliveries, "delivery", "deliveries")}  ·  💰 {report.tips or 0} tips`
	)
	if typeof(report.rarestName) == "string" then
		local rarity = tostring(report.rarestRarity or "")
		add(`⭐ Rarest: {report.rarestName} ({rarity})`, rarityColor[rarity])
	end
	if (tonumber(report.bestStreak) or 0) > 1 then
		add(`🔥 Best streak: {report.bestStreak}`)
	end
	if (tonumber(report.daredevils) or 0) > 0 then
		add(`😈 Daredevil runs: {report.daredevils}`)
	end
	if (tonumber(report.challenges) or 0) > 0 then
		add(`🎯 Event challenges: {report.challenges}`)
	end
	if (tonumber(report.events) or 0) > 0 then
		add(`🌪️ Disasters survived: {report.events}`)
	end
	if typeof(report.compare) == "string" then
		add(report.compare, ACCENT) -- vs the previous round (#248)
	end
	footer.Text =
		`Next finale in {EventVote.clock(tonumber(report.nextFinaleIn) or 0)}. One more round?`
	card.Size = UDim2.fromOffset(330, 150 + order * 26)
	card.Visible = true
	shownId += 1
	local myId = shownId
	task.delay(Tuning.Recap.showSeconds, function()
		if shownId == myId then
			card.Visible = false
		end
	end)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShiftReport"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25 -- under the order cards (30)
	card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.52)
	card.Size = UDim2.fromOffset(330, 260)
	card.BackgroundColor3 = BG
	card.BackgroundTransparency = 0.05
	card.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Thickness = 2
	stroke.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 15
	title.TextColor3 = TEXT
	title.TextTransparency = 0.25
	title.Text = "🧾 SHIFT REPORT"
	title.Parent = card

	headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.BackgroundTransparency = 1
	headline.Position = UDim2.fromOffset(0, 20)
	headline.Size = UDim2.new(1, 0, 0, 34)
	headline.Font = Enum.Font.FredokaOne
	headline.TextSize = 26
	headline.TextColor3 = ACCENT
	headline.Parent = card

	list = Instance.new("Frame")
	list.Name = "Lines"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 60)
	list.Size = UDim2.new(1, 0, 1, -150)
	list.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	footer = Instance.new("TextLabel")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 0, 1, -56)
	footer.Size = UDim2.new(1, 0, 0, 22)
	footer.Font = Enum.Font.FredokaOne
	footer.TextSize = 15
	footer.TextColor3 = TEXT
	footer.TextTransparency = 0.2
	footer.Parent = card

	local ok = Instance.new("TextButton")
	ok.Name = "OK"
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.fromScale(0.5, 1)
	ok.Size = UDim2.fromOffset(160, 46)
	ok.BackgroundColor3 = ACCENT
	ok.Font = Enum.Font.FredokaOne
	ok.TextSize = 20
	ok.TextColor3 = BG
	ok.Text = "Let's go!"
	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 12)
	okCorner.Parent = ok
	ok.Activated:Connect(function()
		card.Visible = false
	end)
	ok.Parent = card

	card.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

function RecapController.start()
	build()
	Net.event("Recap").OnClientEvent:Connect(show)
end

return RecapController
