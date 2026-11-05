--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local Localize = require(ReplicatedStorage.Shared.Util.Localize)
local Translate = Localize.new(require(ReplicatedStorage.Shared.Config.Strings))
local Settings = require(ReplicatedStorage.Shared.Util.Settings).new(
	require(ReplicatedStorage.Shared.Config.Settings)
)
local AudioCaption = {}
function AudioCaption.new(seconds: number)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "AudioCaptions"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 18
	local label = Instance.new("TextLabel")
	label.Name = "Caption"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 0.78)
	label.Size = UDim2.new(0.9, 0, 0, 88)
	label.BackgroundColor3 = Color3.fromHex("#1F1B24")
	label.TextColor3 = Color3.fromHex("#FFF3D6")
	label.Font = Enum.Font.GothamBold
	label.TextWrapped = true
	label.Visible = false
	label.Parent = screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(360, 88)
	limit.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	padding.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	screen.Parent = pg
	local token = 0
	return {
		show = function(text: string)
			token += 1
			local current = token
			local locale = pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
			label.Text = Translate(text, Localize.locale(tostring(locale)))
			label.TextSize = 17 * Settings.textScale(Players.LocalPlayer)
			label.Visible = true
			task.delay(seconds, function()
				if screen.Parent and current == token then
					label.Visible = false
				end
			end)
		end,
		destroy = function()
			token += 1
			screen:Destroy()
		end,
	}
end
return AudioCaption
