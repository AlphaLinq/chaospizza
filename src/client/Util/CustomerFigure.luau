--!strict
-- A simple blocky customer that waits at the delivery door (local only, no
-- network cost). Waves when the courier gets close; hops away when the order
-- ends. Rarity shows as hat/scarf colour; Epic+ gets a soft glow.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CustomerFigure = {}

export type Figure = {
	model: Model,
	step: (dt: number, courier: Vector3?) -> (),
	leave: () -> (),
}

local SKIN = { "#F1C27D", "#E0AC69", "#C68642", "#8D5524", "#FFDBAC" }
local SHIRT = { "#3A6EA5", "#7A4FA3", "#3FA34D", "#D6452F", "#2B2B2B", "#E8E2D6" }
local WAVE_DISTANCE = 45

local function part(
	model: Model,
	name: string,
	size: Vector3,
	color: string,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- `feet`: ground position; `seed`: stable per customer id so they look the same.
-- `bubble`: optional speech bubble text (customer quirk, #139).
function CustomerFigure.new(
	feet: Vector3,
	rarityColor: Color3,
	glow: boolean,
	seed: number,
	bubble: string?
): Figure
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "LocalCustomer"
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local shirt = SHIRT[rng:NextInteger(1, #SHIRT)]

	local legs = part(model, "Legs", Vector3.new(1.8, 2, 1), "#3B3B46")
	local torso = part(model, "Torso", Vector3.new(2, 2, 1), shirt)
	local head = part(model, "Head", Vector3.new(1.3, 1.3, 1.3), skin, Enum.PartType.Ball)
	local hat = part(model, "Hat", Vector3.new(1.4, 0.5, 1.4), "#FFFFFF")
	hat.Color = rarityColor
	local scarf = part(model, "Scarf", Vector3.new(2.1, 0.35, 1.1), "#FFFFFF")
	scarf.Color = rarityColor
	local armL = part(model, "ArmL", Vector3.new(0.6, 1.9, 0.6), skin)
	local armR = part(model, "ArmR", Vector3.new(0.6, 1.9, 0.6), skin)
	if glow then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Range = 10
		light.Brightness = 2
		light.Parent = torso
	end
	if bubble then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Bubble"
		gui.Size = UDim2.fromOffset(190, 46)
		gui.StudsOffset = Vector3.new(0, 2.2, 0)
		gui.MaxDistance = 90
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local frame = Instance.new("TextLabel")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHex("#FFF8EC")
		frame.TextColor3 = Color3.fromHex("#3B2A20")
		frame.Font = Enum.Font.FredokaOne
		frame.TextScaled = true
		frame.TextWrapped = true
		frame.Text = `💬 {bubble}`
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = frame
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = frame
		frame.Parent = gui
		gui.Adornee = head
		gui.Parent = model
	end
	model.PrimaryPart = torso
	model.Parent = Workspace

	local base = CFrame.new(feet)
	local t = rng:NextNumber() * 10
	local waving = 0
	local gone = false

	local function pose(offset: CFrame, wave: number)
		local root = base * offset
		legs.CFrame = root * CFrame.new(0, 1, 0)
		torso.CFrame = root * CFrame.new(0, 3, 0)
		scarf.CFrame = root * CFrame.new(0, 3.85, 0)
		head.CFrame = root * CFrame.new(0, 4.7, 0)
		hat.CFrame = root * CFrame.new(0, 5.45, 0)
		armL.CFrame = root * CFrame.new(-1.3, 3, 0)
		-- right arm swings up while waving
		armR.CFrame = root
			* CFrame.new(1.3, 3.8, 0)
			* CFrame.Angles(0, 0, math.rad(20 + 140 * wave) + math.sin(t * 8) * 0.4 * wave)
			* CFrame.new(0, -0.8, 0)
	end
	pose(CFrame.new(), 0)

	local function step(dt: number, courier: Vector3?)
		if gone then
			return
		end
		t += dt
		local near = courier ~= nil and (courier - feet).Magnitude < WAVE_DISTANCE
		waving += ((if near then 1 else 0) - waving) * math.clamp(dt * 6, 0, 1)
		-- idle sway; face the courier when close
		local facing = CFrame.new()
		if courier and near then
			local flat = Vector3.new(courier.X - feet.X, 0, courier.Z - feet.Z)
			if flat.Magnitude > 0.1 then
				facing = CFrame.lookAt(Vector3.zero, flat.Unit)
			end
		end
		local bob = CFrame.new(0, math.abs(math.sin(t * 2)) * 0.08, 0)
		pose(bob * facing, waving)
	end

	local function leave()
		if gone then
			return
		end
		gone = true
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService
					:Create(d, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
						CFrame = d.CFrame + Vector3.new(0, 4, 0),
						Transparency = 1,
					})
					:Play()
			end
		end
		task.delay(0.7, function()
			model:Destroy()
		end)
	end

	return { model = model, step = step, leave = leave }
end

return CustomerFigure
