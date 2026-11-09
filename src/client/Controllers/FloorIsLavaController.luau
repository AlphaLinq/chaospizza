--!strict
-- The Floor Is Lava visuals (#244). Reads CityState "Lava" (this wave's
-- tile indices + timings in server time) and draws only those tiles from a
-- small pool: a glowing orange warning first, then bubbling red-orange lava.
-- The tile list comes from Util/LavaFloor with the same MapLayout data the
-- server uses. With Reduce Motion the lava glows steadily instead of
-- pulsing. The server decides who burns.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ComfortFlags = require(ReplicatedStorage.Shared.Util.ComfortFlags)
local LavaFloor = require(ReplicatedStorage.Shared.Util.LavaFloor)
local MapGeometry = require(ReplicatedStorage.Shared.Util.MapGeometry)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local FloorIsLavaController = {}

local player = Players.LocalPlayer
local cfg = Tuning.FloorIsLava :: any
local WARN = Color3.fromRGB(255, 170, 60)
local LAVA_A = Color3.fromRGB(255, 80, 20)
local LAVA_B = Color3.fromRGB(255, 160, 40)
local TOP_Y = MapLayout.streetY + 0.2 -- slab top

local tiles: { LavaFloor.Tile } = {}
local folder: Folder? = nil
local pool: { BasePart } = {}
local wave: LavaFloor.Wave? = nil
local connection: RBXScriptConnection? = nil

local function parse(raw: unknown): LavaFloor.Wave?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" or typeof((d :: any).tiles) ~= "table" then
		return nil
	end
	return d :: any
end

local function part(i: number): BasePart
	local p = pool[i]
	if p then
		return p
	end
	local tile = Instance.new("Part")
	tile.Name = "LavaTile"
	tile.Anchored = true
	tile.CanCollide = false
	tile.CanQuery = false
	tile.CanTouch = false
	tile.CastShadow = false
	tile.Material = Enum.Material.Neon
	tile.Parent = folder
	pool[i] = tile
	return tile
end

local function layout(w: LavaFloor.Wave?)
	local count = 0
	if w then
		for _, index in w.tiles do
			local t = tiles[index]
			if t then
				count += 1
				local p = part(count)
				-- a hair smaller than the cell so neighbours read as tiles
				p.Size = Vector3.new(t.sx - 0.6, 0.12, t.sz - 0.6)
				p.CFrame = CFrame.new(t.x, TOP_Y + 0.06, t.z)
				p.Transparency = 1
			end
		end
	end
	for i = count + 1, #pool do
		pool[i].Transparency = 1
	end
	return count
end

local shown = 0

local function step()
	local w = wave
	local now = Workspace:GetServerTimeNow()
	local phase = LavaFloor.phase(w, now)
	local steady = ComfortFlags.reduced(player:GetAttribute("ReduceMotion"))
	for i = 1, shown do
		local p = pool[i]
		if phase == "telegraph" and w then
			-- brightens as the lava gets close
			local k = 1 - math.clamp((w.lavaAt - now) / cfg.telegraphSeconds, 0, 1)
			p.Color = WARN
			p.Transparency = 0.75 - 0.4 * k
		elseif phase == "lava" then
			local pulse = if steady then 0.5 else 0.5 + 0.5 * math.sin(now * 6 + i)
			p.Color = LAVA_A:Lerp(LAVA_B, pulse)
			p.Transparency = 0.05
		else
			p.Transparency = 1
		end
	end
end

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(pool)
	shown = 0
	wave = nil
end

local function start()
	if folder then
		return
	end
	if #tiles == 0 then
		local keep = LavaFloor.keepClear(MapLayout, function(b)
			local p = MapGeometry.doorPoint(b, MapLayout.streetY)
			return { x = p.x, z = p.z }
		end)
		tiles = LavaFloor.tiles(MapLayout.streets :: any, keep, cfg)
	end
	local f = Instance.new("Folder")
	f.Name = "LocalLava"
	f.Parent = Workspace
	folder = f
	connection = RunService.Heartbeat:Connect(step)
end

function FloorIsLavaController.start()
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	local function syncWave()
		if not folder then
			return
		end
		wave = parse(state:GetAttribute("Lava"))
		shown = layout(wave)
	end
	local function refresh()
		if state:GetAttribute("FloorIsLava") == true then
			start()
			syncWave()
		else
			stop()
		end
	end
	state:GetAttributeChangedSignal("FloorIsLava"):Connect(refresh)
	state:GetAttributeChangedSignal("Lava"):Connect(syncWave)
	refresh()
end

return FloorIsLavaController
