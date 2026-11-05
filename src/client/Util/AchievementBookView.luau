--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Settings)
local Settings = require(ReplicatedStorage.Shared.Util.Settings).new(Config)
local Panel = require(script.Parent.CommunityPanel)
local View = {}
function View.new()
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local ui = Panel.new("AchievementBook", "Achievements")
	local close = ui.panel:FindFirstChild("Close") :: TextButton
	local backdrop = ui.overlay:FindFirstChild("Backdrop") :: TextButton
	local size = ui.panel.Size
	local limit = ui.panel:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint
	local max = limit.MaxSize
	local scale = Instance.new("UIScale")
	scale.Parent = ui.panel
	local function apply()
		local n = Settings.textScale(player)
		scale.Scale = n
		ui.panel.Size =
			UDim2.new(size.X.Scale / n, size.X.Offset / n, size.Y.Scale / n, size.Y.Offset / n)
		limit.MaxSize = max / n
	end
	ui.panel.SelectionGroup = true
	ui.scroll.Selectable = true
	close.NextSelectionDown, close.NextSelectionUp = ui.scroll, ui.scroll
	ui.scroll.NextSelectionDown, ui.scroll.NextSelectionUp = close, close
	local function back()
		-- CommunityPanel clears the overlay before this button callback runs.
		local current = pg:GetAttribute("PizzaOverlay")
		if current == nil or current == "AchievementBook" then
			pg:SetAttribute("PizzaOverlay", "CourierProfile")
		end
	end
	local stick = 0
	local connections = {
		player:GetAttributeChangedSignal("TextSize"):Connect(apply),
		close.Activated:Connect(back),
		backdrop.Activated:Connect(back),
		ui.overlay:GetPropertyChangedSignal("Visible"):Connect(function()
			if ui.overlay.Visible then
				-- Let the visibility update reach the engine before selecting a descendant.
				task.defer(function()
					RunService.RenderStepped:Wait()
					if ui.screen.Parent and ui.overlay.Visible then
						GuiService.SelectedObject = close
					end
				end)
			end
		end),
		RunService.RenderStepped:Connect(function(dt)
			if
				ui.overlay.Visible
				and not GuiService.MenuIsOpen
				and math.abs(stick) >= Config.gamepadDeadzone
			then
				ui.scroll.CanvasPosition += Vector2.new(
					0,
					stick * Config.gamepadScrollSpeed * math.min(dt, Config.gamepadMaxDelta)
				)
			end
		end),
	}
	ContextActionService:BindActionAtPriority("PizzaAchievementBack", function(_, state)
		if
			ui.overlay.Visible
			and not GuiService.MenuIsOpen
			and state == Enum.UserInputState.Begin
		then
			back()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("PizzaAchievementScroll", function(_, state, input)
		if not ui.overlay.Visible or GuiService.MenuIsOpen then
			stick = 0
			return Enum.ContextActionResult.Pass
		end
		stick = if state == Enum.UserInputState.End then 0 else -input.Position.Y
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.Thumbstick2)
	ui.screen.Destroying:Connect(function()
		for _, c in connections do
			c:Disconnect()
		end
		ContextActionService:UnbindAction("PizzaAchievementBack")
		ContextActionService:UnbindAction("PizzaAchievementScroll")
	end)
	apply()
	return ui
end
return View
