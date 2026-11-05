--!strict
-- These parts never participate in collisions, queries, touches or character mass.
local Visuals = {}
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: string,
	target: BasePart?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = frame
	result.Color = Color3.fromHex(color)
	result.CanCollide = false
	result.CanQuery = false
	result.CanTouch = false
	result.Massless = true
	result.Anchored = target == nil
	result.Parent = parent
	if target then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = target
		weld.Part1 = result
		weld.Parent = result
	end
	return result
end
local function replace(parent: Instance, name: string): Folder
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end
function Visuals.box(character: Model, item: any)
	local box = character:FindFirstChild("PizzaBox")
	if box and box:IsA("BasePart") then
		box.Color = Color3.fromHex(item.color)
		local lid = box:FindFirstChild("Lid")
		if lid and lid:IsA("BasePart") then
			lid.Color = Color3.fromHex(item.accent)
		end
	end
end
function Visuals.character(character: Model, looks: any)
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not root or not root:IsA("BasePart") or not torso or not torso:IsA("BasePart") then
		return
	end
	local folder = replace(character, "CourierCosmetics")
	part(
		folder,
		"CourierBag",
		Vector3.new(1.7, 1.8, 0.65),
		torso.CFrame * CFrame.new(0, 0, 0.8),
		looks.bag.color,
		torso
	)
	part(
		folder,
		"BagStripe",
		Vector3.new(1.75, 0.18, 0.1),
		torso.CFrame * CFrame.new(0, 0.2, 1.16),
		looks.bag.accent,
		torso
	)
	part(
		folder,
		"CourierApron",
		Vector3.new(1.9, 1.55, 0.12),
		torso.CFrame * CFrame.new(0, -0.1, -0.64),
		looks.uniform.color,
		torso
	)
	part(
		folder,
		"ApronStripe",
		Vector3.new(1.9, 0.18, 0.08),
		torso.CFrame * CFrame.new(0, 0.25, -0.74),
		looks.uniform.accent,
		torso
	)
	for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			part(
				folder,
				"ShoeAccent",
				Vector3.new(0.8, 0.12, 1.05),
				foot.CFrame * CFrame.new(0, -0.15, -0.03),
				looks.movement.color,
				foot
			)
		end
	end
	Visuals.box(character, looks.box)
end
function Visuals.plot(model: Model, looks: any)
	local counter = model:FindFirstChild("PizzeriaCounter")
	if not counter or not counter:IsA("BasePart") then
		return
	end
	local folder = replace(model, "CourierCosmetics")
	local sign = part(
		folder,
		"CosmeticSign",
		Vector3.new(2.2, 1.4, 0.12),
		counter.CFrame * CFrame.new(-4, 2.2, 0),
		looks.decor.color,
		nil
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PIZZA"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex(looks.decor.accent)
	label.Parent = gui
	local jar = part(
		folder,
		"CosmeticTipJar",
		Vector3.new(1.1, 1.3, 1.1),
		counter.CFrame * CFrame.new(2, 1.9, 0),
		looks.jar.color,
		nil
	)
	jar.Material = Enum.Material.Glass
	jar.Transparency = 0.25
	part(
		folder,
		"JarLid",
		Vector3.new(1.2, 0.15, 1.2),
		jar.CFrame * CFrame.new(0, 0.7, 0),
		looks.jar.accent,
		nil
	)
end
return Visuals
