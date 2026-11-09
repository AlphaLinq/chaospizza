--!strict
-- Order choice board (#185): three big cards when "OrderOffers" is set on the
-- local player (OfferService). Each card shows the customer (rarity frame and
-- code, so colour is never the only cue), the address, the order type, the
-- quirk and a rough tip. Tap a card or press 1/2/3; a bar shows the time
-- left before the first card is taken. The server decides everything.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RarityLabel = require(ReplicatedStorage.Shared.Util.RarityLabel)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local OfferController = {}

local player = Players.LocalPlayer
local CARD_BG = Color3.fromHex("#2B2633")
local TEXT = Color3.fromHex("#FFF3D6")
local DARE = Color3.fromHex("#FF3B3B")
local SLOT_ICON =
	{ near = "🏃", far = "🗺️", special = "⭐", daredevil = "😈", story = "📖" }
local KIND_TEXT = {
	double = "📦📦 Double stop",
	rush = "⏱️ Rush",
	fragile = "🎂 Fragile cake",
	party = "🎉 Party tower",
}

local rarityColor: { [string]: Color3 } = {}
for _, r in Rarities do
	rarityColor[r.id] = Color3.fromHex(r.colorHex)
end

type Data = { expires: number, offers: { { [string]: any } } }

local gui: ScreenGui
local row: Frame
local bar: Frame
local data: Data? = nil
local chooseRemote: RemoteEvent

local function parse(raw: unknown): Data?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" or typeof((d :: any).offers) ~= "table" then
		return nil
	end
	return d :: any
end

local function label(parent: Instance, text: string, size: number, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 4)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = size
	l.TextColor3 = TEXT
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.LayoutOrder = order
	l.Parent = parent
	return l
end

local function choose(index: number)
	local d = data
	if d and d.offers[index] then
		chooseRemote:FireServer(index)
	end
end

local function render()
	for _, child in row:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local d = data
	gui.Enabled = d ~= nil
	if not d then
		return
	end
	local count = #d.offers
	for i, offer in d.offers do
		local dare = offer.slot == "daredevil"
		local button = Instance.new("TextButton")
		button.Name = `Offer{i}`
		button.AutoButtonColor = true
		button.Text = ""
		button.BackgroundColor3 = if dare then Color3.fromHex("#4A1820") else CARD_BG
		button.Size = UDim2.new(1 / count, -8, 1, 0)
		button.LayoutOrder = i
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = if dare then DARE else rarityColor[offer.rarity] or TEXT
		stroke.Parent = button
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = button
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 1)
		list.Parent = button
		local title =
			label(button, `{i}  {SLOT_ICON[offer.slot] or "🍕"} {offer.title or ""}`, 18, 1)
		title.TextColor3 = if dare then DARE else TEXT
		local who = label(button, tostring(offer.customer or "?"), 16, 2)
		who.TextColor3 = rarityColor[offer.rarity] or TEXT
		label(button, RarityLabel.text(tostring(offer.rarity or "Common")), 12, 3)
		label(button, `📍 {offer.address or "?"}`, 14, 4)
		local kind = KIND_TEXT[offer.kind]
		if kind then
			label(button, kind, 14, 5)
		end
		if offer.quirk then
			label(button, `💬 "{offer.quirk}"`, 12, 6)
		end
		if offer.extra then
			local extra = label(button, tostring(offer.extra), 12, 7)
			extra.TextColor3 = if dare then DARE else Color3.fromHex("#7CFFB2")
		end
		label(
			button,
			if offer.tipMax
				then `~{offer.tip}–{offer.tipMax} tips`
				else `~{offer.tip or "?"} tips`,
			18,
			8
		)
		button.Activated:Connect(function()
			choose(i)
		end)
		button.Parent = row
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "OrderOffers"
	gui.ResetOnSpawn = false
	-- Above the menus (20-26): the board answers an explicit counter press.
	gui.DisplayOrder = 30
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.55)
	frame.Size = UDim2.new(0.96, 0, 0, 252)
	-- A backdrop so the board reads cleanly over the city or an open menu.
	frame.BackgroundColor3 = Color3.fromHex("#14111A")
	frame.BackgroundTransparency = 0.15
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(740, 252)
	limit.Parent = frame
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 18)
	frameCorner.Parent = frame
	local framePad = Instance.new("UIPadding")
	framePad.PaddingTop = UDim.new(0, 6)
	framePad.PaddingBottom = UDim.new(0, 8)
	framePad.PaddingLeft = UDim.new(0, 8)
	framePad.PaddingRight = UDim.new(0, 8)
	framePad.Parent = frame
	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 26)
	header.Font = Enum.Font.FredokaOne
	header.TextSize = 22
	header.TextColor3 = TEXT
	header.TextStrokeTransparency = 0.3
	header.Text = "🍕 Pick an order!"
	header.Parent = frame
	row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 30)
	row.Size = UDim2.new(1, 0, 1, -42)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	row.Parent = frame
	local track = Instance.new("Frame")
	track.BackgroundColor3 = CARD_BG
	track.Position = UDim2.new(0, 0, 1, -8)
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Parent = frame
	bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromHex("#FFD23F")
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(1, 1)
	bar.Parent = track
	frame.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

function OfferController.start()
	chooseRemote = Net.event("ChooseOffer")
	build()
	local function sync()
		data = parse(player:GetAttribute("OrderOffers"))
		render()
	end
	player:GetAttributeChangedSignal("OrderOffers"):Connect(sync)
	sync()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not data then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.One then
			choose(1)
		elseif key == Enum.KeyCode.Two then
			choose(2)
		elseif key == Enum.KeyCode.Three then
			choose(3)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local d = data
		if d then
			local left = d.expires - Workspace:GetServerTimeNow()
			bar.Size = UDim2.fromScale(math.clamp(left / Tuning.Offers.choiceSeconds, 0, 1), 1)
		end
	end)
end

return OfferController
