--!strict
local RarityLabel = {}
function RarityLabel.text(id: string): string
	local codes =
		{ Common = "C", Uncommon = "U", Rare = "R", Epic = "E", Legendary = "L", Mythic = "M" }
	return `[{codes[id] or "?"}] {id}`
end
return RarityLabel
