--!strict
-- "What's new" panel (#268): the server says when (Net "WhatsNew"); the
-- lines come from Config/WhatsNew. Big "Let's go!" button for thumbs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local WhatsNew = require(ReplicatedStorage.Shared.Config.WhatsNew)

local WhatsNewController = {}

local player = Players.LocalPlayer
local BG = Color3.fromHex("#2B2633")
local TEXT = Color3.fromHex("#FFF3D6")
local ACCENT = Color3.fromHex("#FFD23F")
local LINE_HEIGHT = 30

local panel: Frame

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WhatsNew"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 26
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(380, 120 + #WhatsNew.lines * LINE_HEIGHT)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.04
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Thickness = 2
	stroke.Parent = panel
	-- never wider than a phone screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, 600)
	limit.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 34)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 24
	title.TextColor3 = ACCENT
	title.Text = `✨ {WhatsNew.title}`
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	for i, line in WhatsNew.lines do
		local l = Instance.new("TextLabel")
		l.Name = `Line{i}`
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(16, 48 + (i - 1) * LINE_HEIGHT)
		l.Size = UDim2.new(1, -32, 0, LINE_HEIGHT - 2)
		l.Font = Enum.Font.FredokaOne
		l.TextSize = 16
		l.TextColor3 = TEXT
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.Text = `{line.icon}  {line.text}`
		l.Parent = panel
	end

	local ok = Instance.new("TextButton")
	ok.Name = "OK"
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -12)
	ok.Size = UDim2.fromOffset(170, 46)
	ok.BackgroundColor3 = ACCENT
	ok.Font = Enum.Font.FredokaOne
	ok.TextSize = 20
	ok.TextColor3 = BG
	ok.Text = "Let's go!"
	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 12)
	okCorner.Parent = ok
	ok.Activated:Connect(function()
		panel.Visible = false
	end)
	ok.Parent = panel

	panel.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

function WhatsNewController.start()
	build()
	Net.event("WhatsNew").OnClientEvent:Connect(function(version)
		if version == WhatsNew.version then
			panel.Visible = true
		end
	end)
end

return WhatsNewController
