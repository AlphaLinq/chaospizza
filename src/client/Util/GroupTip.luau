--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Community)
local View = require(script.Parent.ShopView)
local GroupTip = {}
function GroupTip.mount(parent: Instance)
	if Config.groupId == 0 then
		return
	end
	local row = Instance.new("Frame")
	row.Name = "GroupTip"
	row.LayoutOrder = -2
	row.Size = UDim2.new(1, -8, 0, 112)
	row.BackgroundColor3 = View.colors.row
	row.Parent = parent
	View.round(row)
	local text = View.label(
		row,
		"CommunityHint",
		`Join our Roblox community for a free courier bag!\nGroup {Config.groupId} · membership is checked when you join.`,
		16
	)
	text.Position = UDim2.fromOffset(12, 8)
	text.Size = UDim2.new(1, -24, 1, -16)
end
return GroupTip
