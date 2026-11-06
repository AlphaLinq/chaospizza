--!strict
-- Small geometric diagrams, drawn locally; no external image or model assets.
local HelpIllustration = {}
function HelpIllustration.mount(parent: Instance, kind: string)
	local view = Instance.new("ViewportFrame")
	view.Name = "Diagram"
	view.Position, view.Size = UDim2.fromOffset(12, 12), UDim2.fromOffset(64, 64)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.new(1, 1, 1)
	view.LightColor = Color3.new(1, 1, 1)
	view.Parent = parent
	local model = Instance.new("Model")
	model.Parent = view
	local function block(size: Vector3, at: Vector3, color: string): Part
		local part = Instance.new("Part")
		part.Size, part.Position, part.Color = size, at, Color3.fromHex(color)
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		return part
	end
	if kind == "book" then
		block(Vector3.new(2.4, 0.3, 2.8), Vector3.zero, "#D6452F")
		block(Vector3.new(2.1, 0.12, 2.5), Vector3.new(0, 0.2, 0), "#FFF3D6")
		block(Vector3.new(0.1, 0.08, 2.5), Vector3.new(0, 0.3, 0), "#D6452F")
	elseif kind == "chaos" then
		for i = 1, 4 do
			local ring = block(
				Vector3.new(0.4, 0.8 + i * 0.3, 0.8 + i * 0.3),
				Vector3.new(0, i * 0.5 - 1, 0),
				"#FFD24A"
			)
			ring.Shape = Enum.PartType.Cylinder
			ring.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
		end
	elseif kind == "pizzeria" or kind == "pickup" then
		block(Vector3.new(2.5, 2, 2), Vector3.zero, "#D6452F")
		block(Vector3.new(3, 0.3, 2.6), Vector3.new(0, 1.2, 0), "#FFD24A")
		block(Vector3.new(2.5, 0.5, 0.8), Vector3.new(0, -0.4, -1.4), "#FFF3D6")
	else
		block(Vector3.new(if kind == "giant" then 3.4 else 2.3, 0.45, 2.3), Vector3.zero, "#D9A66B")
		block(Vector3.new(1.2, 0.08, 1.2), Vector3.new(0, 0.28, 0), "#D6452F")
		if kind == "deliver" then
			block(Vector3.new(0.25, 1.2, 0.25), Vector3.new(1.6, 0.4, 0), "#FFD24A")
		end
	end
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(4, 4, 5), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
end
return HelpIllustration
