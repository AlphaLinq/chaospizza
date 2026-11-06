--!strict
-- Moon Walk visuals (#180): while CityState "LowGravity" is on, slow glowing
-- "moon dust" motes drift around the camera (count scaled by EffectQuality).
-- The floaty fall comes from the replicated Workspace.Gravity. Humanoids in
-- JumpHeight mode jump to the same height whatever the gravity, so while the
-- event runs this client raises its own JumpHeight to match (and puts the
-- value back afterwards, unless the game changed it meanwhile).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)

local LowGravityController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local COLORS = { "#E9DDFF", "#FFF6C9", "#CFE8FF" }
local RADIUS = 40

type Mote = { part: BasePart, offset: Vector3, drift: Vector3 }

local folder: Folder? = nil
local motes: { Mote } = {}
local connection: RBXScriptConnection? = nil
type Boost = { humanoid: Humanoid, original: number, boosted: number }
local boost: Boost? = nil

local function boostJump()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.UseJumpPower or (boost and boost.humanoid == humanoid) then
		return
	end
	local original = humanoid.JumpHeight
	local boosted = original / Tuning.LowGravity.gravityFactor
	humanoid.JumpHeight = boosted
	boost = { humanoid = humanoid, original = original, boosted = boosted }
end

local function restoreJump()
	local b = boost
	boost = nil
	-- (float32 property: compare loosely)
	if b and b.humanoid.Parent and math.abs(b.humanoid.JumpHeight - b.boosted) < 0.05 then
		b.humanoid.JumpHeight = b.original
	end
end

local function stop()
	restoreJump()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(motes)
end

local function start()
	if folder then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "LocalMoon"
	root.Parent = Workspace
	folder = root
	local count = math.clamp(
		math.floor(10 + 40 * settings.particleScale(player:GetAttribute("EffectQuality"))),
		8,
		50
	)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromHex(COLORS[math.random(1, #COLORS)])
		local size = 0.2 + math.random() * 0.35
		p.Size = Vector3.new(size, size, size)
		p.Parent = root
		table.insert(motes, {
			part = p,
			offset = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
				* RADIUS
				* 2,
			drift = Vector3.new(
				math.random() - 0.5,
				0.3 + math.random() * 0.4,
				math.random() - 0.5
			) * 1.5,
		})
	end
	boostJump()
	connection = RunService.Heartbeat:Connect(function(dt)
		boostJump() -- respawned characters get the boost too
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local centre = camera.CFrame.Position
		for _, m in motes do
			m.offset += m.drift * dt
			-- wrap around the camera so the dust is always nearby
			local o = m.offset
			if o.Magnitude > RADIUS then
				m.offset = -o.Unit * (RADIUS - 1)
			end
			m.part.Position = centre + m.offset
		end
	end)
end

function LowGravityController.start()
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	local function refresh()
		if state:GetAttribute("LowGravity") == true then
			start()
		else
			stop()
		end
	end
	state:GetAttributeChangedSignal("LowGravity"):Connect(refresh)
	refresh()
end

return LowGravityController
