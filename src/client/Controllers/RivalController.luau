--!strict
-- Speedy Sal visuals (#148), only for the racing player: Sal on his rocket
-- scooter revs above the plaza, flies an arc over the rooftops to your door
-- (timed by the server's arrival time), and a countdown strip tells you how
-- long you have. On "won" he spins off in a huff; on "lost" he does a little
-- victory bounce at the door. Visual only; the server decides the result.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RivalController = {}

local player = Players.LocalPlayer

type RaceData = {
	id: number,
	from: Vector3,
	to: Vector3,
	t0: number,
	arrive: number,
	cruise: number,
	outcome: string?,
}

local folder: Folder
local sal: Model? = nil
local salId: number? = nil
local race: RaceData? = nil
local outcomeAt: number? = nil
local strip: TextLabel

local function vec(v: any): Vector3?
	if
		typeof(v) == "table"
		and typeof(v[1]) == "number"
		and typeof(v[2]) == "number"
		and typeof(v[3]) == "number"
	then
		return Vector3.new(v[1], v[2], v[3])
	end
	return nil
end

local function parse(raw: unknown): RaceData?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" then
		return nil
	end
	local data = d :: any
	local from, to = vec(data.from), vec(data.to)
	if not from or not to or typeof(data.t0) ~= "number" or typeof(data.arrive) ~= "number" then
		return nil
	end
	return {
		id = tonumber(data.id) or 0,
		from = from,
		to = to,
		t0 = data.t0,
		arrive = data.arrive,
		cruise = tonumber(data.cruise) or 45,
		outcome = if typeof(data.outcome) == "string" then data.outcome else nil,
	}
end

local function block(
	model: Model,
	size: Vector3,
	offset: CFrame,
	color: string,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = Color3.fromHex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	p.CFrame = offset
	p.Parent = model
	return p
end

-- Built around a pivot at the scooter's deck, facing -Z.
local function makeSal(): Model
	local model = Instance.new("Model")
	model.Name = "SpeedySal"
	local deck = block(model, Vector3.new(1.6, 0.4, 4.4), CFrame.new(), "#2E8B57")
	block(model, Vector3.new(0.3, 2.6, 0.3), CFrame.new(0, 1.3, -1.9), "#333333") -- stem
	block(model, Vector3.new(2, 0.3, 0.3), CFrame.new(0, 2.6, -1.9), "#333333") -- bars
	for _, z in { -1.8, 1.8 } do
		local wheel = block(model, Vector3.new(0.5, 1.2, 1.2), CFrame.new(0, -0.5, z), "#1E1E1E")
		wheel.Shape = Enum.PartType.Cylinder
	end
	local rocket = block(
		model,
		Vector3.new(1.6, 0.9, 0.9),
		CFrame.new(0, 0.4, 2.4) * CFrame.Angles(0, math.rad(90), 0),
		"#B0B0B0"
	)
	rocket.Shape = Enum.PartType.Cylinder
	local flame = block(
		model,
		Vector3.new(1.2, 0.7, 0.7),
		CFrame.new(0, 0.4, 3.4) * CFrame.Angles(0, math.rad(90), 0),
		"#FF7A1A",
		Enum.Material.Neon
	)
	flame.Shape = Enum.PartType.Cylinder
	flame.Name = "Flame"
	-- Sal himself: green jacket, cap, big moustache
	block(model, Vector3.new(1.6, 1.8, 1), CFrame.new(0, 1.5, 0), "#2E8B57") -- body
	block(model, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 3, 0), "#E8B58A") -- head
	block(model, Vector3.new(1.3, 0.4, 1.5), CFrame.new(0, 3.7, -0.15), "#1F5E3B") -- cap
	block(model, Vector3.new(1, 0.25, 0.2), CFrame.new(0, 2.8, -0.65), "#3B2416") -- moustache
	local box = block(model, Vector3.new(1.6, 0.4, 1.6), CFrame.new(0, 2.6, 0.9), "#E9D7B4")
	box.Name = "Box"
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 34)
	tag.StudsOffset = Vector3.new(0, 5.2, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 400
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromHex("#7CFFB2")
	text.TextStrokeTransparency = 0.2
	text.Text = "🛵 Speedy Sal"
	text.Parent = tag
	tag.Adornee = deck
	tag.Parent = model
	model.PrimaryPart = deck
	model.Parent = folder
	return model
end

local function clearSal()
	if sal then
		sal:Destroy()
		sal = nil
		salId = nil
	end
end

local function buildStrip()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RivalHUD"
	gui.ResetOnSpawn = false
	strip = Instance.new("TextLabel")
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.new(0.5, 0, 0, 96)
	strip.Size = UDim2.fromOffset(300, 34)
	strip.BackgroundColor3 = Color3.fromHex("#1F5E3B")
	strip.BackgroundTransparency = 0.1
	strip.TextColor3 = Color3.fromHex("#FFFFFF")
	strip.Font = Enum.Font.FredokaOne
	strip.TextSize = 20
	strip.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = strip
	strip.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function sync()
	local data = parse(player:GetAttribute("RivalRace"))
	race = data
	if not data then
		clearSal()
		outcomeAt = nil
		strip.Visible = false
		return
	end
	if salId ~= data.id then
		clearSal()
		sal = makeSal()
		salId = data.id
		outcomeAt = nil
	end
	if data.outcome and not outcomeAt then
		outcomeAt = os.clock()
	end
end

-- Position along the flight: rev hover, then a rooftop arc to the door.
local function flightCFrame(d: RaceData, now: number): CFrame
	local door = d.to + Vector3.new(4, 0.5, 0)
	if now < d.t0 then
		local wobble = math.sin(now * 20) * 0.15
		return CFrame.lookAt(d.from, door) * CFrame.new(wobble, 0, 0)
	end
	local t = math.clamp((now - d.t0) / math.max(0.1, d.arrive - d.t0), 0, 1)
	local eased = t * t * (3 - 2 * t)
	local flat = d.from:Lerp(door, eased)
	local lift = math.sin(math.pi * t) * math.max(0, d.cruise - math.max(d.from.Y, door.Y))
	local pos = flat + Vector3.new(0, lift, 0)
	local ahead = d.from:Lerp(door, math.min(1, eased + 0.02))
		+ Vector3.new(0, math.sin(math.pi * math.min(1, t + 0.02)) * lift, 0)
	if (ahead - pos).Magnitude < 0.01 then
		return CFrame.new(pos) * CFrame.lookAt(d.from, door).Rotation
	end
	return CFrame.lookAt(pos, ahead)
end

local function step()
	local d = race
	local model = sal
	if not d or not model then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if d.outcome and outcomeAt then
		local k = os.clock() - outcomeAt
		local base = flightCFrame(d, math.min(now, d.arrive))
		if d.outcome == "lost" then
			-- victory bounce at the door
			model:PivotTo(base * CFrame.new(0, math.abs(math.sin(k * 6)) * 1.5, 0))
			strip.Text = "🛵 Sal got there first!"
		else
			-- huffy spin and off he goes
			model:PivotTo(base * CFrame.new(0, k * 12, 0) * CFrame.Angles(0, k * 8, 0))
			strip.Text = if d.outcome == "won" then "🏁 You beat Sal! Tips ×2" else ""
		end
		strip.Visible = d.outcome ~= "cancelled"
		return
	end
	model:PivotTo(flightCFrame(d, now))
	local left = math.max(0, d.arrive - now)
	strip.Text = if now < d.t0
		then `🛵 Sal is revving up… GO! {math.ceil(left)}s`
		else `🛵 Beat Speedy Sal! {math.ceil(left)}s`
	strip.BackgroundColor3 = if left < 5
		then Color3.fromHex("#B23A2B")
		else Color3.fromHex("#1F5E3B")
	strip.Visible = true
end

function RivalController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalRival"
	folder.Parent = Workspace
	buildStrip()
	player:GetAttributeChangedSignal("RivalRace"):Connect(sync)
	sync()
	RunService.Heartbeat:Connect(step)
end

return RivalController
