--!strict
-- Event vote + chaos finale HUD (#186). Reads CityState only:
-- "EventVote" (ballot: three big buttons with live counts and the time left,
-- tap or press 7/8/9 to vote — the vote can be changed), "FinaleAt" (a strip
-- "🎆 Finale in 2:41" in the last minutes, then a big 30-second countdown)
-- and "Finale" (a "GRAND FINALE" strip while it runs). The server decides.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local EventVote = require(ReplicatedStorage.Shared.Util.EventVote)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local VoteController = {}

local player = Players.LocalPlayer
local BG = Color3.fromHex("#2B2633")
local TEXT = Color3.fromHex("#FFF3D6")
local PICKED = Color3.fromHex("#FFD23F")
local FINALE = Color3.fromHex("#FF4FD8")
local KEYS = { Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }

local names: { [string]: string } = {}
for _, e in Events do
	names[e.id] = e.displayName
end

type Ballot = { options: { string }, counts: { number }, endsAt: number }

local cityState: Instance
local panel: Frame
local header: TextLabel
local buttons: { TextButton } = {}
local finaleStrip: TextLabel
local countdown: TextLabel
local ballot: Ballot? = nil
local myVote: number? = nil
local ballotKey = ""

local function parse(raw: unknown): Ballot?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" or typeof((d :: any).options) ~= "table" then
		return nil
	end
	return d :: any
end

local function vote(index: number)
	local b = ballot
	if b and b.options[index] then
		myVote = index
		Net.event("CastVote"):FireServer(index)
	end
end

local function render()
	local b = ballot
	panel.Visible = b ~= nil
	if not b then
		return
	end
	local key = table.concat(b.options, ",")
	if key ~= ballotKey then
		ballotKey = key
		myVote = nil -- a new ballot
	end
	for i, button in buttons do
		local id = b.options[i]
		button.Visible = id ~= nil
		if id then
			local mine = myVote == i
			button.Text =
				`{i + 6}  {names[id] or id}  · {b.counts[i] or 0}{if mine then "  ✔" else ""}`
			button.BackgroundColor3 = if mine then PICKED else BG
			button.TextColor3 = if mine then BG else TEXT
		end
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EventVote"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	panel = Instance.new("Frame")
	panel.Name = "Ballot"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 262)
	panel.Size = UDim2.fromOffset(236, 32 + 3 * 46)
	panel.BackgroundTransparency = 1
	panel.Visible = false
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 26)
	header.Font = Enum.Font.FredokaOne
	header.TextSize = 18
	header.TextColor3 = TEXT
	header.TextStrokeTransparency = 0.3
	header.TextXAlignment = Enum.TextXAlignment.Right
	header.LayoutOrder = 0
	header.Parent = panel
	for i = 1, 3 do
		local b = Instance.new("TextButton")
		b.Name = `Vote{i}`
		b.Size = UDim2.new(1, 0, 0, 42) -- big enough for a thumb
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 16
		b.TextColor3 = TEXT
		b.BackgroundColor3 = BG
		b.LayoutOrder = i
		b.TextTruncate = Enum.TextTruncate.AtEnd
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = b
		b.Activated:Connect(function()
			vote(i)
		end)
		b.Parent = panel
		buttons[i] = b
	end
	panel.Parent = gui

	finaleStrip = Instance.new("TextLabel")
	finaleStrip.Name = "FinaleStrip"
	finaleStrip.AnchorPoint = Vector2.new(0.5, 0)
	finaleStrip.Position = UDim2.new(0.5, 0, 0, 250)
	finaleStrip.Size = UDim2.fromOffset(320, 34)
	finaleStrip.BackgroundColor3 = BG
	finaleStrip.BackgroundTransparency = 0.1
	finaleStrip.Font = Enum.Font.FredokaOne
	finaleStrip.TextSize = 20
	finaleStrip.TextColor3 = FINALE
	finaleStrip.Visible = false
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 10)
	sc.Parent = finaleStrip
	finaleStrip.Parent = gui

	countdown = Instance.new("TextLabel")
	countdown.Name = "FinaleCountdown"
	countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	countdown.Position = UDim2.fromScale(0.5, 0.33)
	countdown.Size = UDim2.fromOffset(260, 120)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.FredokaOne
	countdown.TextScaled = true
	countdown.TextColor3 = FINALE
	countdown.TextStrokeTransparency = 0.2
	countdown.Visible = false
	countdown.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local b = ballot
	if b then
		header.Text = `🗳️ Next event? {EventVote.clock(b.endsAt - now)}`
	end
	local running = cityState:GetAttribute("Finale") == true
	local at = cityState:GetAttribute("FinaleAt")
	local left = if typeof(at) == "number" then at - now else math.huge
	local stage = EventVote.finaleStage(left, Tuning.Finale :: any)
	if running then
		finaleStrip.Visible = true
		finaleStrip.Text = "🎆 GRAND FINALE! Deliver for a bonus!"
		countdown.Visible = false
	elseif stage == "notice" then
		finaleStrip.Visible = true
		finaleStrip.Text = `🎆 Chaos finale in {EventVote.clock(left)}!`
		countdown.Visible = false
	elseif stage == "countdown" then
		finaleStrip.Visible = true
		finaleStrip.Text = "🎆 CHAOS FINALE"
		countdown.Visible = true
		countdown.Text = tostring(math.max(1, math.ceil(left)))
	else
		finaleStrip.Visible = false
		countdown.Visible = false
	end
end

function VoteController.start()
	cityState = ReplicatedStorage:WaitForChild("CityState")
	build()
	local function sync()
		ballot = parse(cityState:GetAttribute("EventVote"))
		render()
	end
	cityState:GetAttributeChangedSignal("EventVote"):Connect(sync)
	sync()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not ballot then
			return
		end
		local index = table.find(KEYS, input.KeyCode)
		if index then
			vote(index)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			step()
		end
	end)
end

return VoteController
