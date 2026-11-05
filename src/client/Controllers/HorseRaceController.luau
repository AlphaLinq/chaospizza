--!strict
-- Local horse animation for the Surprise Horse Race. The server only replicates
-- runner data (CityState "HorseRunners": id, lane z, start x, direction, start
-- time, speed, colours); this controller builds the horse models on this device
-- and moves them every frame. Hits are still decided by the server with the
-- same position formula, so this is visual only.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HorseRaceController = {}

local HORSE_COLORS = { "#6B4423", "#2B2B2B", "#C8A27A", "#8B5A2B", "#EDE6DA" }
local SILK_COLORS = { "#D6452F", "#2F7BD6", "#F2C14E", "#3FA34D", "#9B59B6" }
local GROUND_Y = 0.4
local GALLOP_HEIGHT = 0.5
local GALLOP_SPEED = 14

type RunnerData = {
	id: number,
	z: number,
	x0: number,
	dir: number,
	t0: number,
	speed: number,
	coat: number,
	silk: number,
	startX: number,
	endX: number,
}
type Live = { data: RunnerData, model: Model, phase: number }

local folder: Folder
local live: { [number]: Live } = {}

local function makePart(parent: Instance, size: Vector3, cf: CFrame, color: string): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A simple blocky horse with a jockey, built around a pivot at hoof level.
local function makeHorse(coatIndex: number, silkIndex: number): Model
	local model = Instance.new("Model")
	model.Name = "Horse"
	local coat = HORSE_COLORS[math.clamp(coatIndex, 1, #HORSE_COLORS)]
	local silk = SILK_COLORS[math.clamp(silkIndex, 1, #SILK_COLORS)]
	local body = makePart(model, Vector3.new(7, 3, 2.6), CFrame.new(0, 5, 0), coat)
	makePart(
		model,
		Vector3.new(1.6, 3.2, 1.8),
		CFrame.new(3.6, 6.6, 0) * CFrame.Angles(0, 0, math.rad(-25)),
		coat
	)
	makePart(model, Vector3.new(2.4, 1.4, 1.5), CFrame.new(4.9, 7.8, 0), coat)
	for _, lx in { -2.6, 2.6 } do
		for _, lz in { -0.8, 0.8 } do
			makePart(model, Vector3.new(0.7, 3.6, 0.7), CFrame.new(lx, 1.8, lz), coat)
		end
	end
	makePart(model, Vector3.new(1.6, 2.2, 1.6), CFrame.new(-0.3, 7.6, 0), silk) -- jockey
	makePart(model, Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 9.2, 0), "#F1C27D") -- head
	makePart(
		model,
		Vector3.new(0.4, 2.4, 0.4),
		CFrame.new(-3.8, 5.8, 0) * CFrame.Angles(0, 0, math.rad(35)),
		"#222222"
	) -- tail
	model.PrimaryPart = body
	body.PivotOffset = CFrame.new(0, -5, 0)
	model:PivotTo(CFrame.new(0, -500, 0))
	model.Parent = folder
	return model
end

local function parse(raw: unknown): { RunnerData }
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(decoded) ~= "table" then
		return {}
	end
	local list: { RunnerData } = {}
	for _, r in decoded :: { any } do
		if
			typeof(r) == "table"
			and typeof(r.id) == "number"
			and typeof(r.z) == "number"
			and typeof(r.x0) == "number"
			and typeof(r.t0) == "number"
			and typeof(r.speed) == "number"
		then
			table.insert(list, r :: RunnerData)
		end
	end
	return list
end

local function sync(raw: unknown)
	local seen: { [number]: boolean } = {}
	for _, data in parse(raw) do
		seen[data.id] = true
		if not live[data.id] then
			live[data.id] = {
				data = data,
				model = makeHorse(data.coat or 1, data.silk or 1),
				phase = math.random() * math.pi * 2,
			}
		end
	end
	for id, entry in live do
		if not seen[id] then
			entry.model:Destroy()
			live[id] = nil
		end
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for id, entry in live do
		local d = entry.data
		local x = d.x0 + d.dir * d.speed * (now - d.t0)
		if (d.dir > 0 and x > d.endX) or (d.dir < 0 and x < d.startX) then
			entry.model:Destroy()
			live[id] = nil
			continue
		end
		local bob = math.abs(math.sin(now * GALLOP_SPEED + entry.phase)) * GALLOP_HEIGHT
		local facing = if d.dir > 0 then 0 else math.pi
		entry.model:PivotTo(CFrame.new(x, GROUND_Y + bob, d.z) * CFrame.Angles(0, facing, 0))
	end
end

function HorseRaceController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalHorses"
	folder.Parent = Workspace

	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	state:GetAttributeChangedSignal("HorseRunners"):Connect(function()
		sync(state:GetAttribute("HorseRunners"))
	end)
	sync(state:GetAttribute("HorseRunners"))
	RunService.Heartbeat:Connect(step)
end

return HorseRaceController
