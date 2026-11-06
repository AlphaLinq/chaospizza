--!strict
-- Local animation for the Runaway Cheese Wheel (#140). The server replicates
-- only the run (CityState "CheeseWheel": route, start time, speed, size); this
-- controller builds the wheel on this device, rolls it along the route with
-- the same RoutePath formula as the server hit test, and tips it over at the
-- end. Cheese chunks (server parts tagged "CheeseChunk") get a gentle spin.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RoutePath = require(ReplicatedStorage.Shared.Util.RoutePath)

local CheeseWheelController = {}

local GROUND_Y = 0.4
local CHEESE = Color3.fromHex("#F7C948")
local RIND = Color3.fromHex("#E0A526")
local HOLE = Color3.fromHex("#D9952B")

type RunData = {
	id: number,
	route: { RoutePath.Point },
	t0: number,
	speed: number,
	diameter: number,
	thickness: number,
}
type Live = { data: RunData, model: Model, body: BasePart, spin: number, fallen: boolean }

local folder: Folder
local live: Live? = nil
local chunks: { BasePart } = {}

local function parse(raw: unknown): RunData?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(decoded) ~= "table" then
		return nil
	end
	local d = decoded :: any
	if
		typeof(d.id) ~= "number"
		or typeof(d.t0) ~= "number"
		or typeof(d.speed) ~= "number"
		or typeof(d.route) ~= "table"
	then
		return nil
	end
	local route: { RoutePath.Point } = {}
	for _, p in d.route do
		if typeof(p) == "table" and typeof(p[1]) == "number" and typeof(p[2]) == "number" then
			table.insert(route, { x = p[1], z = p[2] })
		end
	end
	if #route < 2 then
		return nil
	end
	return {
		id = d.id,
		route = route,
		t0 = d.t0,
		speed = d.speed,
		diameter = if typeof(d.diameter) == "number" then d.diameter else 6,
		thickness = if typeof(d.thickness) == "number" then d.thickness else 3,
	}
end

local function part(model: Model, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- Wheel: a cylinder (axis = local X = across the street) with holes on both
-- faces and a missing wedge, so the rolling is easy to see.
local function makeWheel(data: RunData): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "CheeseWheel"
	local d, t = data.diameter, data.thickness
	local body = part(model, Vector3.new(t, d, d), CHEESE, Enum.PartType.Cylinder)
	local rind = part(model, Vector3.new(t * 0.9, d + 0.15, d + 0.15), RIND, Enum.PartType.Cylinder)
	local parts: { { p: BasePart, offset: CFrame } } = { { p = rind, offset = CFrame.new() } }
	local rng = Random.new(data.id)
	for side = -1, 1, 2 do
		for _ = 1, 4 do
			local r = rng:NextNumber() * d * 0.32
			local a = rng:NextNumber() * math.pi * 2
			local size = 0.5 + rng:NextNumber() * 0.5
			local hole = part(model, Vector3.new(0.12, size, size), HOLE, Enum.PartType.Cylinder)
			table.insert(parts, {
				p = hole,
				offset = CFrame.new(side * (t / 2 + 0.02), math.cos(a) * r, math.sin(a) * r),
			})
		end
	end
	-- the cut-out slice, a darker wedge on the rim
	local slice = part(model, Vector3.new(t + 0.05, 0.3, d * 0.42), HOLE)
	table.insert(parts, { p = slice, offset = CFrame.new(0, d / 2 - 0.1, 0) })
	model.PrimaryPart = body
	-- Anchored parts: PivotTo moves the whole model, keeping these offsets.
	for _, entry in parts do
		entry.p.CFrame = body.CFrame * entry.offset
	end
	model.Parent = folder
	return model, body
end

local function place(entry: Live, x: number, z: number, hx: number, hz: number)
	local r = entry.data.diameter / 2
	-- look along the heading; the cylinder axis (local X) then lies across it
	local base =
		CFrame.lookAt(Vector3.new(x, GROUND_Y + r, z), Vector3.new(x + hx, GROUND_Y + r, z + hz))
	entry.model:PivotTo(base * CFrame.Angles(-entry.spin, 0, 0))
end

local function tipOver(entry: Live)
	entry.fallen = true
	local start = entry.model:GetPivot()
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(function(k: number)
		if entry.model.Parent then
			entry.model:PivotTo(
				start
					* CFrame.new(0, -entry.data.diameter / 2 * k + entry.data.thickness / 2 * k, 0)
					* CFrame.Angles(0, 0, math.rad(90) * k)
			)
		end
	end)
	TweenService:Create(value, TweenInfo.new(0.6, Enum.EasingStyle.Bounce), { Value = 1 }):Play()
	task.delay(2.5, function()
		value:Destroy()
		entry.model:Destroy()
	end)
end

local function sync(raw: unknown)
	local data = parse(raw)
	local current = live
	if current and (not data or data.id ~= current.data.id) then
		if not current.fallen then
			tipOver(current)
		end
		live = nil
	end
	if data and not live then
		local model, body = makeWheel(data)
		local entry: Live = { data = data, model = model, body = body, spin = 0, fallen = false }
		live = entry
		local x, z, hx, hz = RoutePath.sample(data.route, 0)
		place(entry, x, z, hx, hz)
	end
end

local function step(dt: number)
	local now = Workspace:GetServerTimeNow()
	local entry = live
	if entry and not entry.fallen then
		local d = entry.data
		local travelled = math.max(0, d.speed * (now - d.t0))
		local x, z, hx, hz, done = RoutePath.sample(d.route, travelled)
		entry.spin = travelled / (d.diameter / 2)
		place(entry, x, z, hx, hz)
		if done then
			tipOver(entry)
		end
	end
	if #chunks > 0 then
		local turn = CFrame.Angles(0, dt * 1.5, 0)
		for _, chunk in chunks do
			chunk.CFrame *= turn
		end
	end
end

function CheeseWheelController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalCheese"
	folder.Parent = Workspace

	CollectionService:GetInstanceAddedSignal("CheeseChunk"):Connect(function(inst)
		if inst:IsA("BasePart") then
			table.insert(chunks, inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal("CheeseChunk"):Connect(function(inst)
		local i = table.find(chunks, inst :: any)
		if i then
			table.remove(chunks, i)
		end
	end)

	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	state:GetAttributeChangedSignal("CheeseWheel"):Connect(function()
		sync(state:GetAttribute("CheeseWheel"))
	end)
	sync(state:GetAttribute("CheeseWheel"))
	RunService.Heartbeat:Connect(step)
end

return CheeseWheelController
