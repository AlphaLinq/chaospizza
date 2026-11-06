--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RarityLabel = require(ReplicatedStorage.Shared.Util.RarityLabel)
local View = require(script.Parent.ShopView)
local ProductRow = {}
function ProductRow.new(parent: Instance, item: any, index: number): TextButton
	local odds = {}
	if type(item.odds) == "table" then
		for _, rarity in Rarities do
			table.insert(
				odds,
				`{RarityLabel.text(rarity.id)} {string.format("%.2f", item.odds[rarity.id] or 0)}%`
			)
		end
	end
	local baseHeight = if #odds > 0 then 204 else 108
	local row = Instance.new("Frame")
	row.Name, row.LayoutOrder = item.key, index
	row.Size = UDim2.new(1, -8, 0, baseHeight + (if item.disabledReason then 72 else 0))
	row.BackgroundColor3 = View.colors.row
	row.Parent = parent
	View.round(row)
	local name = View.label(row, "ItemName", item.name, 18)
	name.Font = Enum.Font.GothamBold
	name.Position, name.Size = UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 44)
	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Position, buy.Size = UDim2.fromOffset(12, 56), UDim2.fromOffset(150, 44)
	buy.Font, buy.TextSize = Enum.Font.GothamBold, 16
	buy.Text = if item.owned
		then "Owned"
		elseif item.disabledReason then "Unavailable"
		elseif not item.available then "Coming soon"
		else `{item.price} Robux`
	buy:SetAttribute("Available", item.available == true and item.owned ~= true)
	buy.Parent = row
	View.round(buy)
	if #odds > 0 then
		local prefix = if item.key == "MegaChaosNow"
			then "MEGA base customer odds"
			else "Customer odds with this boost"
		local label = View.label(row, "Odds", prefix .. "\n" .. table.concat(odds, " · "), 14)
		label.Position, label.Size = UDim2.fromOffset(12, 110), UDim2.new(1, -24, 0, 82)
		label.TextYAlignment = Enum.TextYAlignment.Top
	end
	if item.disabledReason then
		local reason = View.label(row, "DisabledReason", item.disabledReason, 14)
		reason.Position, reason.Size = UDim2.fromOffset(12, baseHeight), UDim2.new(1, -24, 0, 64)
	end
	return buy
end
return ProductRow
