--!strict
-- Client side of the debug panel. Only shown when the SERVER says this player
-- is authorized; the server re-checks every command anyway (see DebugService).
-- Built in code, mobile friendly: a small DEV button toggles the panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared is guaranteed to exist: the client entry point waits for it first.
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)

local DebugController = {}

local BUTTON_HEIGHT = 36
local PANEL_WIDTH = 320

local resultLabel: TextLabel? = nil

local function makeButton(text: string, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 16
	button.Text = text
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	button.Parent = parent
	return button
end

local function splitArgs(text: string): { string }
	local args = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(args, word)
		if #args >= 4 then
			break
		end
	end
	return args
end

local function buildPanel(info: Types.DebugInfo)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local runRemote = Net.event("DebugRun")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = false

	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.Size = UDim2.fromOffset(64, 32)
	toggle.Position = UDim2.new(0, 8, 0.35, 0)
	toggle.BackgroundColor3 = Color3.fromRGB(200, 60, 40)
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 14
	toggle.Text = "DEV"
	toggle.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Visible = false
	panel.Size = UDim2.new(0, PANEL_WIDTH, 0.6, 0)
	panel.Position = UDim2.new(0, 80, 0.2, 0)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	panel.BackgroundTransparency = 0.1
	panel.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = panel

	local argsBox = Instance.new("TextBox")
	argsBox.Name = "Args"
	argsBox.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	argsBox.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	argsBox.TextColor3 = Color3.new(1, 1, 1)
	argsBox.PlaceholderText = "arguments (space separated)"
	argsBox.Text = ""
	argsBox.ClearTextOnFocus = false
	argsBox.Font = Enum.Font.Gotham
	argsBox.TextSize = 14
	argsBox.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "Result"
	label.Size = UDim2.new(1, 0, 0, 48)
	label.Position = UDim2.fromOffset(0, BUTTON_HEIGHT + 6)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Code
	label.TextSize = 13
	label.Text = "ready"
	label.Parent = panel
	resultLabel = label

	local list = Instance.new("ScrollingFrame")
	list.Name = "Commands"
	list.Size = UDim2.new(1, 0, 1, -(BUTTON_HEIGHT + 60))
	list.Position = UDim2.fromOffset(0, BUTTON_HEIGHT + 60)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	for _, command in info.commands do
		local button = makeButton(command.usage, list)
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Activated:Connect(function()
			runRemote:FireServer(command.name, table.unpack(splitArgs(argsBox.Text)))
		end)
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	gui.Parent = playerGui
end

function DebugController.start()
	Net.event("DebugResult").OnClientEvent:Connect(function(success: unknown, message: unknown)
		local text = `{success == true and "OK" or "FAIL"}: {tostring(message)}`
		print(`[Debug] {text}`)
		if resultLabel then
			resultLabel.Text = text
		end
	end)

	local ok, info = pcall(function()
		return Net.func("DebugGetInfo"):InvokeServer()
	end)
	if not ok or typeof(info) ~= "table" or info.authorized ~= true then
		return -- not authorized (or server busy): no panel
	end
	buildPanel(info :: Types.DebugInfo)
end

return DebugController
