--!strict
-- Event challenge strip (#200): "🎯 Catch 5 pizzas 2/5" right under the event
-- banner while an event with a challenge runs, a tick when it is done. Reads
-- the player attribute "EventChallenge" (ChallengeService); visual only.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local ChallengeController = {}

local player = Players.LocalPlayer
local BG = Color3.fromHex("#2B2633")
local DONE = Color3.fromHex("#7CFFB2")
local TEXT = Color3.fromHex("#FFF3D6")

local label: TextLabel

local function render()
	local raw = player:GetAttribute("EventChallenge")
	if typeof(raw) ~= "string" then
		label.Visible = false
		return
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" then
		label.Visible = false
		return
	end
	local data = d :: any
	label.Visible = true
	if data.done then
		label.Text = `✅ {data.text}!`
		label.TextColor3 = DONE
	else
		label.Text = `🎯 {data.text}  {data.progress or 0}/{data.goal or 1}`
		label.TextColor3 = TEXT
	end
end

function ChallengeController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EventChallenge"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	label = Instance.new("TextLabel")
	label.Name = "Strip"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 142) -- just under the event banner
	label.Size = UDim2.new(0.9, 0, 0, 30)
	label.BackgroundColor3 = BG
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 18
	label.TextColor3 = TEXT
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(360, 30)
	limit.Parent = label
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("EventChallenge"):Connect(render)
	render()
end

return ChallengeController
