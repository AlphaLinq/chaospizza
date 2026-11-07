--!strict
-- Micro-chaos visuals (#187). Reads CityState "MicroChaos" and draws it
-- locally: a rattling shopping cart, a line of geese, a bubbling puddle that
-- turns into a geyser, or a tumbled stack of pizza boxes (taken ones vanish).
-- Visual only: the server (MicroChaosService) decides bumps and pickups.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local MicroChaos = require(ReplicatedStorage.Shared.Util.MicroChaos)

local MicroChaosController = {}

local GROUND_Y = MapLayout.streetY + 0.2

type Data = { [string]: any }

local folder: Folder
local current: Data? = nil
local movers: { Model } = {}
local puddle: BasePart? = nil
local geyser: BasePart? = nil
local boxes: { [number]: BasePart } = {}

local function part(
	name: string,
	size: Vector3,
	color: string,
	parent: Instance,
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
	p.Parent = parent
	return p
end

local function cart(): Model
	local m = Instance.new("Model")
	m.Name = "RunawayCart"
	local basket = part("Basket", Vector3.new(2.6, 1.8, 3.6), "#B8C4CC", m)
	basket.Material = Enum.Material.DiamondPlate
	basket.CFrame = CFrame.new(0, 2, 0)
	local handle = part("Handle", Vector3.new(2.6, 0.3, 0.3), "#D6452F", m)
	handle.CFrame = CFrame.new(0, 3.3, 1.9)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local w =
				part("Wheel", Vector3.new(0.4, 0.8, 0.8), "#2B2633", m, Enum.PartType.Cylinder)
			w.CFrame = CFrame.new(x * 1.1, 0.6, z * 1.5)
		end
	end
	m.WorldPivot = CFrame.new() -- pivot on the ground under the cart
	return m
end

local function goose(): Model
	local m = Instance.new("Model")
	m.Name = "Goose"
	local body = part("Body", Vector3.new(1.4, 1.2, 2), "#F4F4F0", m, Enum.PartType.Ball)
	body.CFrame = CFrame.new(0, 1, 0)
	local neck = part("Neck", Vector3.new(0.4, 1.4, 0.4), "#F4F4F0", m)
	neck.CFrame = CFrame.new(0, 2, -0.8)
	local beak = part("Beak", Vector3.new(0.3, 0.25, 0.6), "#FF9B2F", m)
	beak.CFrame = CFrame.new(0, 2.6, -1.2)
	m.WorldPivot = CFrame.new()
	return m
end

local function clear()
	folder:ClearAllChildren()
	table.clear(movers)
	table.clear(boxes)
	puddle = nil
	geyser = nil
end

local function build(d: Data)
	clear()
	local kind = d.kind
	if kind == "Cart" then
		table.insert(movers, cart())
	elseif kind == "Geese" then
		for _ = 1, d.count or 1 do
			table.insert(movers, goose())
		end
	elseif kind == "Sprinkler" then
		local s = d.spot
		local r = (d.radius or 4) * 2
		local p = part("Puddle", Vector3.new(0.2, r, r), "#3FA9F5", folder, Enum.PartType.Cylinder)
		p.Transparency = 0.4
		p.CFrame = CFrame.new(s.x, GROUND_Y + 0.1, s.z) * CFrame.Angles(0, 0, math.rad(90))
		puddle = p
		local g =
			part("Geyser", Vector3.new(14, 2.4, 2.4), "#9BE7FF", folder, Enum.PartType.Cylinder)
		g.Material = Enum.Material.Neon
		g.Transparency = 1
		g.CFrame = CFrame.new(s.x, GROUND_Y + 7, s.z) * CFrame.Angles(0, 0, math.rad(90))
		geyser = g
	elseif kind == "Boxes" then
		for i, b in d.boxes or {} do
			local box = part(`Box{i}`, Vector3.new(1.8, 0.5, 1.8), "#E8B04A", folder)
			box.Material = Enum.Material.Cardboard
			box.CFrame = CFrame.new(b.x, GROUND_Y + 0.6, b.z) * CFrame.Angles(0, i, 0)
			boxes[i] = box
		end
	end
	for _, m in movers do
		m.Parent = folder
	end
end

local function sync()
	local raw = ReplicatedStorage:WaitForChild("CityState"):GetAttribute("MicroChaos")
	if typeof(raw) ~= "string" then
		current = nil
		clear()
		return
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" then
		return
	end
	local data = d :: Data
	if not current or current.id ~= data.id then
		build(data)
	end
	current = data
	for _, i in data.taken or {} do
		local box = boxes[i]
		if box then
			box:Destroy()
			boxes[i] = nil
		end
	end
end

local function step()
	local d = current
	if not d then
		return
	end
	local t = Workspace:GetServerTimeNow()
	if d.kind == "Cart" or d.kind == "Geese" then
		local dir = Vector3.new(d.to.x - d.from.x, 0, d.to.z - d.from.z).Unit
		for i, m in movers do
			local at =
				MicroChaos.moverAt(d.from, d.to, d.t0, d.speed, t, (i - 1) * (d.spacing or 0))
			if at then
				local wobble = if d.kind == "Geese"
					then math.sin(t * 14 + i) * 0.25
					else math.sin(t * 30) * 0.08
				local pos = Vector3.new(at.x, GROUND_Y + wobble, at.z)
				m:PivotTo(CFrame.lookAt(pos, pos + dir))
			else
				m:PivotTo(CFrame.new(0, -500, 0))
			end
		end
	elseif d.kind == "Sprinkler" then
		local spraying = t >= d.t0 + (d.warn or 0)
		local p, g = puddle, geyser
		if p then
			p.Transparency = if spraying then 0.2 else 0.45 + math.sin(t * 12) * 0.15
		end
		if g then
			g.Transparency = if spraying then 0.35 + math.sin(t * 20) * 0.1 else 1
		end
	elseif d.kind == "Boxes" then
		for i, box in boxes do
			local b = d.boxes[i]
			box.CFrame = CFrame.new(b.x, GROUND_Y + 0.6 + math.sin(t * 3 + i) * 0.15, b.z)
				* CFrame.Angles(0, t + i, 0)
		end
	end
end

function MicroChaosController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalMicroChaos"
	folder.Parent = Workspace
	local cityState = ReplicatedStorage:WaitForChild("CityState")
	cityState:GetAttributeChangedSignal("MicroChaos"):Connect(sync)
	sync()
	RunService.Heartbeat:Connect(step)
end

return MicroChaosController
