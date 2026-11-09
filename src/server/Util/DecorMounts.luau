--!strict
-- Adapter to the published pizzeria instance contract; no builder edits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Decorations)
local Mounts = {}
function Mounts.get(model: Model): { [string]: Attachment }
	local result: { [string]: Attachment } = {}
	for _, child in model:GetDescendants() do
		local slot = child:GetAttribute("DecorSlot")
		if child:IsA("Attachment") and type(slot) == "string" and not result[slot] then
			result[slot] = child
		end
	end
	local counter = model:FindFirstChild("PizzeriaCounter")
	if not counter or not counter:IsA("BasePart") then
		return result
	end
	for _, slot in Config.slots do
		if not result[slot.id] then
			local attachment = Instance.new("Attachment")
			attachment.Name = Config.attachmentPrefix .. slot.id
			attachment.CFrame = CFrame.new(table.unpack(slot.offset))
			attachment:SetAttribute("DecorSlot", slot.id)
			attachment.Parent = counter
			result[slot.id] = attachment
		end
	end
	return result
end
return Mounts
