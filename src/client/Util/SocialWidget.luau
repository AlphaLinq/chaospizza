--!strict
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local View = require(script.Parent.ShopView)
local SocialWidget = {}
function SocialWidget.mount(parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = "Friends"
	frame.LayoutOrder = 20
	frame.Size = UDim2.new(1, 0, 0, 108)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local button = Instance.new("TextButton")
	button.Name = "Invite"
	button.Text = "Invite a friend"
	button.Size = UDim2.new(1, -8, 0, 48)
	button.TextSize = 18
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = View.colors.panel
	button.BackgroundColor3 = View.colors.cheese
	button.Parent = frame
	View.round(button)
	local status = View.label(
		frame,
		"Status",
		"Play together for 2 minutes to earn a daily friend reward.",
		14
	)
	status.Position = UDim2.fromOffset(0, 54)
	status.Size = UDim2.new(1, -8, 0, 48)
	local pending = false
	button.Activated:Connect(function()
		if pending then
			return
		end
		pending = true
		button.Active = false
		local ok, allowed = pcall(function()
			return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
		end)
		if frame.Parent then
			if ok and allowed then
				local opened = pcall(function()
					SocialService:PromptGameInvite(Players.LocalPlayer)
				end)
				status.Text = if opened
					then "Invite sent? Rewards arrive when you play together."
					else "Invites are unavailable right now. Try again later."
			else
				status.Text = "Invites are unavailable on this device right now."
			end
			pending = false
			button.Active = true
		end
	end)
end
return SocialWidget
