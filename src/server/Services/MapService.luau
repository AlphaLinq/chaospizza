--!strict
-- Builds the greybox district from Config/MapLayout at server start and exposes
-- the gameplay points (addresses, counter, spawn, safe spots, zones).
-- The map lives in Workspace.PizzaMap and is rebuilt every server start, so it
-- is versioned in Git (AGENTS.md: map from code until a ticket says otherwise).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local MapGeometry = require(ReplicatedStorage.Shared.Util.MapGeometry)

export type Address = {
	id: string,
	label: string,
	starter: boolean,
	doorPosition: Vector3,
	highPosition: Vector3,
}

local MapService = {}

local mapFolder: Folder? = nil
local addresses: { Address } = {}
local addressById: { [string]: Address } = {}
local counterPart: BasePart? = nil
local spawnPosition = Vector3.zero
local safeSpots: { Vector3 } = {}

local function color(hex: string): Color3
	return Color3.fromHex(hex)
end

local function part(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance,
	transparency: number?,
	canCollide: boolean?,
	className: string?,
}): BasePart
	local p = Instance.new((props.className or "Part") :: any) :: BasePart
	p.Name = props.name
	p.Anchored = true
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.CanCollide = if props.canCollide == nil then true else props.canCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A tilted slab from (x, y0, z0) to (x, y1, z1) along z.
local function ramp(
	name: string,
	x: number,
	z0: number,
	z1: number,
	y0: number,
	y1: number,
	width: number,
	parent: Instance
)
	local run = z1 - z0
	local rise = y1 - y0
	local length = math.sqrt(run * run + rise * rise)
	local mid = Vector3.new(x, (y0 + y1) / 2, (z0 + z1) / 2)
	local cf = CFrame.lookAt(mid, mid + Vector3.new(0, rise, run))
	part({
		name = name,
		size = Vector3.new(width, 1, length),
		cframe = cf,
		color = color("#9A9A9A"),
		material = Enum.Material.Concrete,
		parent = parent,
	})
end

local function buildStreets(root: Folder)
	local streets = folder("Streets", root)
	for _, s in MapLayout.streets do
		part({
			name = s.name,
			size = Vector3.new(s.sx, 0.4, s.sz),
			cframe = CFrame.new(s.x, MapLayout.streetY, s.z),
			color = color(s.color),
			material = Enum.Material.Concrete,
			parent = streets,
		})
	end
end

local function buildBuildings(root: Folder)
	local buildings = folder("Buildings", root)
	local addressFolder = folder("Addresses", root)
	local groundY = MapLayout.streetY + 0.2

	for index, b in MapLayout.buildings do
		local model = Instance.new("Model")
		model.Name = if b.address then `Building_{b.address.id}` else `Building_{index}`
		model.Parent = buildings

		part({
			name = "Body",
			size = Vector3.new(b.sx, b.h, b.sz),
			cframe = CFrame.new(b.x, groundY + b.h / 2, b.z),
			color = color(b.color),
			material = Enum.Material.Brick,
			parent = model,
		})

		local f = MapGeometry.facing(b.door)
		local halfDepth = if f.x ~= 0 then b.sx / 2 else b.sz / 2
		local facadeCenter = Vector3.new(b.x + f.x * halfDepth, groundY, b.z + f.z * halfDepth)
		local lookCF = CFrame.lookAt(facadeCenter, facadeCenter + Vector3.new(f.x, 0, f.z))

		-- Door (visual), awning above it (jumpable ledge)
		part({
			name = "Door",
			size = Vector3.new(6, MapGeometry.DOOR_HEIGHT, 0.6),
			cframe = lookCF * CFrame.new(0, MapGeometry.DOOR_HEIGHT / 2, -0.3),
			color = color("#5A3A22"),
			material = Enum.Material.Wood,
			parent = model,
		})
		part({
			name = "Awning",
			size = Vector3.new(10, 0.6, 4),
			cframe = lookCF * CFrame.new(0, MapGeometry.DOOR_HEIGHT + 1, -2),
			color = color("#F4F1EA"),
			material = Enum.Material.Fabric,
			parent = model,
		})

		if b.address then
			-- Balcony + ladder: the flood-time delivery point (brief 1.0 ch. 7.3)
			part({
				name = "Balcony",
				size = Vector3.new(12, 1, MapGeometry.BALCONY_DEPTH),
				cframe = lookCF
					* CFrame.new(0, MapGeometry.BALCONY_HEIGHT, -MapGeometry.BALCONY_DEPTH / 2),
				color = color("#E0E0E0"),
				material = Enum.Material.Concrete,
				parent = model,
			})
			part({
				name = "Ladder",
				className = "TrussPart",
				size = Vector3.new(2, MapGeometry.BALCONY_HEIGHT, 2),
				cframe = lookCF
					* CFrame.new(7, MapGeometry.BALCONY_HEIGHT / 2, -MapGeometry.BALCONY_DEPTH + 1),
				color = color("#8A8A8A"),
				material = Enum.Material.Metal,
				parent = model,
			})

			local door = MapGeometry.doorPoint(b, groundY)
			local high = MapGeometry.highPoint(b, groundY)
			local doorPosition = Vector3.new(door.x, door.y, door.z)
			local highPosition = Vector3.new(high.x, high.y, high.z)

			-- Invisible marker part: the delivery point other systems look up.
			local marker = part({
				name = b.address.id,
				size = Vector3.new(4, 1, 4),
				cframe = CFrame.new(doorPosition - Vector3.new(0, 2.5, 0)),
				color = color("#FFD24A"),
				parent = addressFolder,
				transparency = 1,
				canCollide = false,
			})
			marker:SetAttribute("AddressId", b.address.id)
			marker:SetAttribute("Label", b.address.label)

			-- House number sign
			local sign = Instance.new("BillboardGui")
			sign.Size = UDim2.fromOffset(160, 36)
			sign.StudsOffsetWorldSpace = Vector3.new(0, MapGeometry.DOOR_HEIGHT + 4, 0)
			sign.MaxDistance = 80
			sign.Adornee = marker
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamBold
			text.TextScaled = true
			text.TextColor3 = Color3.new(1, 1, 1)
			text.TextStrokeTransparency = 0.4
			text.Text = b.address.label
			text.Parent = sign
			sign.Parent = marker

			local address: Address = {
				id = b.address.id,
				label = b.address.label,
				starter = b.address.starter == true,
				doorPosition = doorPosition,
				highPosition = highPosition,
			}
			table.insert(addresses, address)
			addressById[address.id] = address
		end
	end
end

local function buildPlaza(root: Folder)
	local plaza = folder("Plaza", root)
	local groundY = MapLayout.streetY + 0.2

	-- Pizza HQ counter: where orders are picked up
	local c = MapLayout.counter
	local hq = part({
		name = "PizzaHQ",
		size = Vector3.new(18, 10, 8),
		cframe = CFrame.new(c.x, groundY + 5, c.z - 6),
		color = color("#D6452F"),
		material = Enum.Material.SmoothPlastic,
		parent = plaza,
	})
	counterPart = part({
		name = "Counter",
		size = Vector3.new(14, 3.5, 3),
		cframe = CFrame.new(c.x, groundY + 1.75, c.z),
		color = color("#F4E3C1"),
		material = Enum.Material.Wood,
		parent = plaza,
	})
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 50)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	sign.Adornee = hq
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex("#FFF3D6")
	label.TextStrokeTransparency = 0.2
	label.Text = "🍕 PIZZA HQ"
	label.Parent = sign
	sign.Parent = hq

	-- Pizzeria plots (empty markers until M5)
	local plots = folder("Plots", root)
	for i, p in MapLayout.plots do
		local plot = part({
			name = `Plot{i}`,
			size = Vector3.new(14, 0.2, 14),
			cframe = CFrame.new(p.x, groundY + 0.1, p.z),
			color = color("#C8B88F"),
			material = Enum.Material.Sand,
			parent = plots,
			canCollide = false,
		})
		plot:SetAttribute("PlotIndex", i)
	end

	-- Spawn
	local s = MapLayout.spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PizzaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.new(s.x, groundY + 0.2, s.z)
	spawn.Color = color("#FFD24A")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = plaza
	spawnPosition = spawn.Position + Vector3.new(0, 3, 0)

	-- Simple fountain on the fountain square (tornado landmark)
	local fz = MapLayout.zones.Fountain
	part({
		name = "FountainBasin",
		className = "Part",
		size = Vector3.new(16, 2, 16),
		cframe = CFrame.new(fz.x, groundY + 1, fz.z),
		color = color("#BFC7CF"),
		material = Enum.Material.Marble,
		parent = plaza,
	})
end

local function buildOverpass(root: Folder)
	local o = MapLayout.overpass
	local f = folder("Overpass", root)
	local groundY = MapLayout.streetY + 0.2
	part({
		name = "Deck",
		size = Vector3.new(o.width, 1, o.zSouth - o.zNorth),
		cframe = CFrame.new(o.x, o.deckY, (o.zNorth + o.zSouth) / 2),
		color = color("#9A9A9A"),
		material = Enum.Material.Concrete,
		parent = f,
	})
	ramp("RampNorth", o.x, o.zNorth - o.rampLength, o.zNorth, groundY, o.deckY, o.width, f)
	ramp("RampSouth", o.x, o.zSouth + o.rampLength, o.zSouth, groundY, o.deckY, o.width, f)
	-- Pillars
	for _, z in { o.zNorth + 2, o.zSouth - 2 } do
		for _, dx in { -o.width / 2 + 1, o.width / 2 - 1 } do
			part({
				name = "Pillar",
				size = Vector3.new(1.5, o.deckY, 1.5),
				cframe = CFrame.new(o.x + dx, o.deckY / 2, z),
				color = color("#7A7A7A"),
				material = Enum.Material.Concrete,
				parent = f,
			})
		end
	end
end

local function buildBounds(root: Folder)
	local b = MapLayout.bounds
	local f = folder("Bounds", root)
	local h = b.wallHeight
	local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
	local w, d = b.maxX - b.minX, b.maxZ - b.minZ
	local walls = {
		{ Vector3.new(w, h, 2), Vector3.new(cx, h / 2, b.minZ) },
		{ Vector3.new(w, h, 2), Vector3.new(cx, h / 2, b.maxZ) },
		{ Vector3.new(2, h, d), Vector3.new(b.minX, h / 2, cz) },
		{ Vector3.new(2, h, d), Vector3.new(b.maxX, h / 2, cz) },
	}
	for i, wall in walls do
		part({
			name = `Wall{i}`,
			size = wall[1],
			cframe = CFrame.new(wall[2]),
			color = Color3.new(1, 1, 1),
			parent = f,
			transparency = 1,
		})
	end
end

local function build()
	local existing = Workspace:FindFirstChild("PizzaMap")
	if existing then
		existing:Destroy()
	end
	-- Only our spawn should be used.
	for _, d in Workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end

	local root = Instance.new("Folder")
	root.Name = "PizzaMap"
	buildStreets(root)
	buildBuildings(root)
	buildPlaza(root)
	buildOverpass(root)
	buildBounds(root)
	root.Parent = Workspace
	mapFolder = root

	for _, s in MapLayout.safeSpots do
		table.insert(safeSpots, Vector3.new(s.x, MapLayout.streetY + 3.5, s.z))
	end
end

function MapService.init()
	build()
end

function MapService.getAddresses(): { Address }
	return addresses
end

function MapService.getAddress(id: string): Address?
	return addressById[id]
end

function MapService.getCounterPart(): BasePart
	assert(counterPart, "map not built")
	return counterPart
end

function MapService.getSpawnPosition(): Vector3
	return spawnPosition
end

function MapService.getSafeSpots(): { Vector3 }
	return safeSpots
end

function MapService.nearestSafeSpot(position: Vector3): Vector3
	local best, bestDistance = spawnPosition, math.huge
	for _, spot in safeSpots do
		local d = (spot - position).Magnitude
		if d < bestDistance then
			best, bestDistance = spot, d
		end
	end
	return best
end

function MapService.getMapFolder(): Folder
	assert(mapFolder, "map not built")
	return mapFolder
end

return MapService
