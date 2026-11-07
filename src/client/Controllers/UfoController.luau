--!strict
-- UFO Abduction visuals (#183): saucers from CityState "Ufos" fly their loops
-- with spinning rim lights; the beam flickers during its warning and shines
-- green when live (shared Util/Ufo timing). While this courier is being
-- abducted ("Abducted" attribute) its client floats the character up the beam.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ComfortFlags = require(ReplicatedStorage.Shared.Util.ComfortFlags)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local RoutePath = require(ReplicatedStorage.Shared.Util.RoutePath)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ufo = require(ReplicatedStorage.Shared.Util.Ufo)

local UfoController = {}

local player = Players.LocalPlayer
local cfg = Tuning.Ufo
local GROUND_Y = MapLayout.streetY + 0.2

type Live = { saucer: Ufo.Saucer, model: Model, beam: BasePart, lights: { BasePart } }

local folder: Folder
local live: { [number]: Live } = {}

local function part(
	model: Instance,
	shape: Enum.PartType,
	size: Vector3,
	color: string,
	neon: boolean?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape
	p.Size = size
	p.Color = Color3.fromHex(color)
	p.Material = if neon then Enum.Material.Neon else Enum.Material.Metal
	p.Parent = model
	return p
end

local function makeSaucer(s: Ufo.Saucer): Live
	local model = Instance.new("Model")
	model.Name = "Ufo"
	local disc = part(model, Enum.PartType.Cylinder, Vector3.new(2, 18, 18), "#9AA3B5")
	disc.CFrame = CFrame.Angles(0, 0, math.rad(90))
	local dome = part(model, Enum.PartType.Ball, Vector3.new(8, 6, 8), "#8CF5FF", true)
	dome.Transparency = 0.35
	dome.CFrame = CFrame.new(0, 2, 0)
	local lights = {}
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local l = part(model, Enum.PartType.Ball, Vector3.new(1, 1, 1), "#FFD23F", true)
		l.CFrame = CFrame.new(math.cos(a) * 8.6, -0.2, math.sin(a) * 8.6)
		table.insert(lights, l)
	end
	model.PrimaryPart = disc
	model.Parent = folder
	local beam = part(
		folder,
		Enum.PartType.Cylinder,
		Vector3.new(cfg.height, cfg.beamRadius * 2, cfg.beamRadius * 2),
		"#7CFF8A",
		true
	)
	beam.Transparency = 1
	return { saucer = s, model = model, beam = beam, lights = lights }
end

local function sync(raw: unknown)
	for _, l in live do
		l.model:Destroy()
		l.beam:Destroy()
	end
	table.clear(live)
	if typeof(raw) ~= "string" then
		return
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(list) ~= "table" then
		return
	end
	for _, s in list :: { any } do
		if typeof(s) == "table" and typeof(s.id) == "number" and MapLayout.ufoRoutes[s.route] then
			live[s.id] = makeSaucer({ id = s.id, route = s.route, t0 = s.t0, offset = s.offset })
		end
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local abductedBy = player:GetAttribute("Abducted")
	for id, l in live do
		local route = MapLayout.ufoRoutes[l.saucer.route] :: any
		local x, z = Ufo.position(RoutePath :: any, route, l.saucer, now, cfg :: any)
		local y = GROUND_Y + cfg.height + math.sin(now * 1.5 + id) * 1.2
		local base = CFrame.new(x, y, z)
		l.model:PivotTo(base * CFrame.Angles(0, now * 1.2, 0))
		local state = Ufo.beam(l.saucer, now, cfg :: any)
		-- Comfort (#177): with reduced flashes the warning beam and rim lights
		-- hold steady instead of strobing.
		local steady = ComfortFlags.reduced(player:GetAttribute("ReduceFlashes"))
		l.beam.CFrame = CFrame.new(x, GROUND_Y + cfg.height / 2, z)
			* CFrame.Angles(0, 0, math.rad(90))
		l.beam.Transparency = if state == "on"
			then 0.55
			elseif state == "warn" then (if steady or math.sin(now * 25) > 0 then 0.8 else 1)
			else 1
		for i, light in l.lights do
			light.Color = if (i + (if steady then 0 else math.floor(now * 8))) % 2 == 0
				then Color3.fromHex("#FFD23F")
				else Color3.fromHex("#7CFF8A")
		end
		-- being abducted by this saucer: float up the beam
		if abductedBy == id then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local target = Vector3.new(x, y - 4, z)
				root.AssemblyLinearVelocity = (target - root.Position) * 2
			end
		end
	end
end

function UfoController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalUfos"
	folder.Parent = Workspace
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	state:GetAttributeChangedSignal("Ufos"):Connect(function()
		sync(state:GetAttribute("Ufos"))
	end)
	sync(state:GetAttribute("Ufos"))
	RunService.Heartbeat:Connect(step)
end

return UfoController
