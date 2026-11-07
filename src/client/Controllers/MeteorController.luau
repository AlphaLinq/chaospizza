--!strict
-- Meteor Shower visuals (#181): for every scheduled impact in CityState
-- "Meteors" a red circle pulses and fills on the ground, a glowing rock falls
-- from the sky to land exactly at the server's impact time, then a flash and
-- a dark crater that fades. Stardust (server parts tagged "Stardust") bobs.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local MeteorController = {}

local GROUND_Y = MapLayout.streetY + 0.2
local FALL_SECONDS = 1.2
local cfg = Tuning.MeteorShower

type Live = {
	id: number,
	x: number,
	z: number,
	t: number,
	r: number,
	circle: BasePart,
	fill: BasePart,
	rock: BasePart?,
}

local folder: Folder
local live: { [number]: Live } = {}
local dust: { BasePart } = {}

local function part(shape: Enum.PartType, color: string, neon: boolean): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = Color3.fromHex(color)
	p.Parent = folder
	return p
end

local function flat(p: BasePart, x: number, z: number, y: number, diameter: number)
	p.Size = Vector3.new(0.15, diameter, diameter)
	p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
end

local function crater(x: number, z: number, r: number)
	local c = part(Enum.PartType.Cylinder, "#2A1E1A", false)
	flat(c, x, z, GROUND_Y + 0.06, r * 1.6)
	local flash = part(Enum.PartType.Ball, "#FFD27A", true)
	flash.Size = Vector3.one * r * 1.5
	flash.Position = Vector3.new(x, GROUND_Y + 1, z)
	flash.Transparency = 0.2
	task.spawn(function()
		for i = 1, 10 do
			flash.Transparency = 0.2 + i * 0.08
			flash.Size = Vector3.one * r * (1.5 + i * 0.12)
			task.wait(0.03)
		end
		flash:Destroy()
		task.wait(4)
		for i = 1, 10 do
			c.Transparency = i / 10
			task.wait(0.1)
		end
		c:Destroy()
	end)
end

local function parse(raw: unknown): { any }
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and typeof(d) == "table" then d else {}
end

local function sync(raw: unknown)
	local seen: { [number]: boolean } = {}
	for _, m in parse(raw) do
		if typeof(m) == "table" and typeof(m.id) == "number" then
			seen[m.id] = true
			if not live[m.id] then
				local circle = part(Enum.PartType.Cylinder, "#FF3B30", true)
				circle.Transparency = 0.55
				flat(circle, m.x, m.z, GROUND_Y + 0.08, m.r * 2)
				local fill = part(Enum.PartType.Cylinder, "#FF7A1A", true)
				fill.Transparency = 0.35
				flat(fill, m.x, m.z, GROUND_Y + 0.1, 0.5)
				live[m.id] =
					{ id = m.id, x = m.x, z = m.z, t = m.t, r = m.r, circle = circle, fill = fill }
			end
		end
	end
	for id, m in live do
		if not seen[id] then
			m.circle:Destroy()
			m.fill:Destroy()
			if m.rock then
				m.rock:Destroy()
			end
			crater(m.x, m.z, m.r)
			live[id] = nil
		end
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for _, m in live do
		local left = m.t - now
		local k = math.clamp(1 - left / cfg.telegraphSeconds, 0, 1)
		flat(m.fill, m.x, m.z, GROUND_Y + 0.1, math.max(0.5, m.r * 2 * k))
		m.circle.Transparency = 0.45 + math.sin(now * 12) * 0.15
		if left <= FALL_SECONDS then
			local rock = m.rock
			if not rock then
				local r = part(Enum.PartType.Ball, "#FF9A3D", true)
				r.Size = Vector3.new(3, 3, 3)
				local fire = Instance.new("Fire")
				fire.Size = 6
				fire.Heat = 12
				fire.Parent = r
				m.rock = r
				rock = r
			end
			local f = math.clamp(left / FALL_SECONDS, 0, 1)
			local from = Vector3.new(m.x + 40, GROUND_Y + 120, m.z + 25)
			local to = Vector3.new(m.x, GROUND_Y + 1.5, m.z);
			(rock :: BasePart).Position = to:Lerp(from, f)
		end
	end
	local bob = math.sin(now * 3) * 0.3
	for _, d in dust do
		d.Position = Vector3.new(d.Position.X, GROUND_Y + 1.2 + bob, d.Position.Z)
	end
end

function MeteorController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalMeteors"
	folder.Parent = Workspace
	CollectionService:GetInstanceAddedSignal("Stardust"):Connect(function(inst)
		if inst:IsA("BasePart") then
			table.insert(dust, inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal("Stardust"):Connect(function(inst)
		local i = table.find(dust, inst :: any)
		if i then
			table.remove(dust, i)
		end
	end)
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	state:GetAttributeChangedSignal("Meteors"):Connect(function()
		sync(state:GetAttribute("Meteors"))
	end)
	sync(state:GetAttribute("Meteors"))
	RunService.Heartbeat:Connect(step)
end

return MeteorController
