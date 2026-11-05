--!strict
local Emotes = {}
function Emotes.allowed(profile: any, id: string, cosmetics: any): boolean
	local item = cosmetics.get(id)
	return item ~= nil and item.slot == "emote" and cosmetics.owns(profile, id)
end
return Emotes
