--!strict
local Players = game:GetService("Players")
local Panel = require(script.Parent.CommunityPanel)
local CommunityLinks = {}
function CommunityLinks.mount(parent: Instance)
	local help = Panel.row(parent, "HelpLink", "How to play", 0)
	help.Activated:Connect(function()
		Players.LocalPlayer.PlayerGui:SetAttribute("PizzaOverlay", "Help")
	end)
	local emote = Panel.row(parent, "EmotesLink", "Emote wheel", 32)
	emote.Activated:Connect(function()
		Players.LocalPlayer.PlayerGui:SetAttribute("PizzaOverlay", "Emotes")
	end)
	local button = Panel.row(parent, "CourierProfileLink", "Courier profiles", 30)
	button.Activated:Connect(function()
		Players.LocalPlayer.PlayerGui:SetAttribute("PizzaOverlay", "CourierProfile")
	end)
	local visit = Panel.row(parent, "VisitsLink", "Visit pizzerias", 31)
	visit.Activated:Connect(function()
		Players.LocalPlayer.PlayerGui:SetAttribute("PizzaOverlay", "Visits")
	end)
end
return CommunityLinks
