--!strict
-- Decorative geometry follows the existing character; it never changes physics.
local RideVisuals = {}
function RideVisuals.apply(character: Model, tier: number, look: any)
	local old = character:FindFirstChild("CourierRide")
	if old then
		old:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or tier == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CourierRide"
	folder:SetAttribute("Tier", tier)
	local ground = if humanoid.RigType == Enum.HumanoidRigType.R6
		then -3
		else -humanoid.HipHeight - root.Size.Y / 2
	local function part(name: string, size: Vector3, offset: CFrame, target: BasePart?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = Color3.fromHex(if name == "Wheel" then look.accent else look.color)
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		local body = target or root
		p.CFrame = body.CFrame * offset
		p.Parent = folder
		if name == "Wheel" then
			p.Shape = Enum.PartType.Cylinder
			local motor = Instance.new("Motor6D")
			motor.Name = "RideWheel"
			motor.Part0 = body
			motor.Part1 = p
			motor.C0 = offset
			motor:SetAttribute("Radius", size.Y / 2)
			motor.Parent = p
			-- A visible spoke makes the client-side wheel rotation readable.
			local spoke = Instance.new("Part")
			spoke.Name = "Spoke"
			spoke.Size = Vector3.new(size.X + 0.02, size.Y * 0.65, 0.07)
			spoke.Color = Color3.fromHex(look.color)
			spoke.CFrame = p.CFrame
			spoke.CanCollide = false
			spoke.CanTouch = false
			spoke.CanQuery = false
			spoke.Massless = true
			spoke.Parent = folder
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = p
			weld.Part1 = spoke
			weld.Parent = spoke
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = p
			weld.Parent = p
		end
		return p
	end
	if tier == 1 or tier == 3 then
		for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
			local foot = character:FindFirstChild(name)
			if foot and foot:IsA("BasePart") then
				local y = -foot.Size.Y / 2
				local sole = part("Sole", Vector3.new(0.9, 0.16, 1.25), CFrame.new(0, y, 0), foot)
				if tier == 3 then
					for _, x in { -0.44, 0.44 } do
						for _, z in { -0.38, 0.38 } do
							part(
								"Wheel",
								Vector3.new(0.15, 0.3, 0.3),
								CFrame.new(x, -0.12, z),
								sole
							)
						end
					end
				end
			end
		end
	else
		local deck = part("Deck", Vector3.new(1.15, 0.16, 3), CFrame.new(0, ground + 0.1, 0), nil)
		for _, z in { -1.1, 1.1 } do
			if tier == 2 then
				for _, x in { -0.65, 0.65 } do
					part("Wheel", Vector3.new(0.22, 0.45, 0.45), CFrame.new(x, -0.15, z), deck)
				end
			else
				part("Wheel", Vector3.new(0.25, 0.65, 0.65), CFrame.new(0, -0.1, z), deck)
			end
		end
		if tier == 4 then
			part("Stem", Vector3.new(0.14, 2.7, 0.14), CFrame.new(0, 1.35, -1.1), deck)
			part("Handlebar", Vector3.new(1.8, 0.16, 0.16), CFrame.new(0, 2.7, -1.1), deck)
			part("Battery", Vector3.new(0.7, 0.18, 1.3), CFrame.new(0, 0.12, 0.1), deck)
		end
	end
	folder.Parent = character
end
return RideVisuals
