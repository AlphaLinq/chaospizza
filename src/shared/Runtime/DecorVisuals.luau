--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Decorations)
local Visuals = {}
local shapes = { Ball = Enum.PartType.Ball, Cylinder = Enum.PartType.Cylinder }
function Visuals.draw(parent: Instance, frame: CFrame, item: any): Model
	local model = Instance.new("Model")
	model.Name = item.slot
	model:SetAttribute("DecorItemId", item.id)
	for _, piece in Config.pieces[item.slot] do
		local p = Instance.new("Part")
		p.Name, p.Size = piece.name, Vector3.new(table.unpack(piece.size))
		p.CFrame = frame
			* CFrame.new(table.unpack(piece.at))
			* CFrame.Angles(0, 0, math.rad(piece.z or 0))
		p.Color = Color3.fromHex(item[piece.color])
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
			true, false, false, false, false
		p.Material = if piece.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if piece.shape then
			p.Shape = shapes[piece.shape] or Enum.PartType.Block
		end
		p.Parent = model
		if piece.text then
			local gui = Instance.new("SurfaceGui")
			gui.Face, gui.CanvasSize, gui.MaxDistance =
				Enum.NormalId.Front, Vector2.new(260, 120), 80
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Size, text.Text = UDim2.fromScale(1, 1), piece.text
			text.Font, text.TextSize = Enum.Font.FredokaOne, 64
			text.TextColor3 = Color3.fromHex(item.accent)
			text.Parent, gui.Parent = gui, p
		end
	end
	model.Parent = parent
	return model
end
return Visuals
