--!strict
local Players = game:GetService("Players")
local Panel = require(script.Parent.CommunityPanel)
local CommunityLinks = {}
function CommunityLinks.mount(parent: Instance)
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
