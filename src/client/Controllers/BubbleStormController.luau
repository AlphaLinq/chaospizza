--!strict
-- Bubble Storm visuals and riding (#161). Draws the bubbles from CityState
-- "Bubbles" with the shared Util/Bubbles motion (fewer on Low quality), and
-- while the server says we ride one (player attribute "BubbleRide") it moves
-- our own character with the bubble. Jump pops it: we stop following, play a
-- pop, and fall; the server sees us leave and releases the ride.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Bubbles = require(ReplicatedStorage.Shared.Util.Bubbles)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local BubbleStormController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local cfg = Tuning.BubbleStorm
local TINTS = { "#BFEFFF", "#FFD6F5", "#E6FFD1", "#FFF2C2", "#D9D2FF" }
local FOLLOW = 10 -- how hard the character is pulled to the bubble centre

type Live = { data: Bubbles.Bubble, part: BasePart }

local folder: Folder
local live: { [number]: Live } = {}
local popped: { [number]: boolean } = {}

local function parse(raw: unknown): { Bubbles.Bubble }
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(decoded) ~= "table" then
		return {}
	end
	local list: { Bubbles.Bubble } = {}
	for _, b in decoded :: { any } do
		if typeof(b) == "table" and typeof(b.id) == "number" and typeof(b.t0) == "number" then
			table.insert(list, b :: Bubbles.Bubble)
		end
	end
	return list
end

local function popEffect(part: BasePart)
	local tween = TweenService:Create(part, TweenInfo.new(0.25), {
		Size = part.Size * 1.4,
		Transparency = 1,
	})
	tween:Play()
	-- Destroy on a timer, not on Completed: tweens can stall (e.g. a
	-- backgrounded window) and the part must never be left behind.
	task.delay(0.3, function()
		part:Destroy()
	end)
end

local function makeBubble(b: Bubbles.Bubble): BasePart
	local p = Instance.new("Part")
	p.Name = "Bubble"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Glass
	p.Transparency = 0.65
	p.Reflectance = 0.25
	p.Color = Color3.fromHex(TINTS[(b.id % #TINTS) + 1])
	p.Size = Vector3.one * b.r * 2
	p.Parent = folder
	return p
end

local function sync(raw: unknown)
	local list = parse(raw)
	if #list == 0 then
		table.clear(popped)
	end
	local cap = if settings.particleScale(player:GetAttribute("EffectQuality")) < 0.5
		then cfg.lowQualityBubbles
		else cfg.maxBubbles
	local seen: { [number]: boolean } = {}
	for i, b in list do
		if i > cap then
			break
		end
		seen[b.id] = true
		if not live[b.id] and not popped[b.id] then
			live[b.id] = { data = b, part = makeBubble(b) }
		end
	end
	for id, entry in live do
		if not seen[id] then
			popEffect(entry.part)
			live[id] = nil
		end
	end
end

local function popRide()
	local id = player:GetAttribute("BubbleRide")
	if typeof(id) ~= "number" or popped[id] then
		return
	end
	popped[id] = true
	local entry = live[id]
	if entry then
		popEffect(entry.part)
		live[id] = nil
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for id, entry in live do
		local b = entry.data
		if not Bubbles.alive(b, now, cfg.lifeSeconds) then
			popEffect(entry.part)
			live[id] = nil
			continue
		end
		local x, y, z = Bubbles.position(b, now, cfg.riseSpeed, cfg.maxHeight)
		local wobble = math.sin(now * 3 + id) * 0.3
		entry.part.CFrame = CFrame.new(x + wobble, y, z - wobble)
	end
	-- Riding: our client owns the character, so it follows the bubble.
	local rideId = player:GetAttribute("BubbleRide")
	if typeof(rideId) ~= "number" or popped[rideId] then
		return
	end
	local entry = live[rideId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not entry or not root or not root:IsA("BasePart") then
		return
	end
	local b = entry.data
	local x, y, z = Bubbles.position(b, now, cfg.riseSpeed, cfg.maxHeight)
	local target = Vector3.new(x, y - 0.5, z)
	local rising = if y < b.y0 + cfg.maxHeight then cfg.riseSpeed else 0
	root.AssemblyLinearVelocity = (target - root.Position) * FOLLOW
		+ Vector3.new(b.vx, rising, b.vz)
end

function BubbleStormController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalBubbles"
	folder.Parent = Workspace
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	state:GetAttributeChangedSignal("Bubbles"):Connect(function()
		sync(state:GetAttribute("Bubbles"))
	end)
	sync(state:GetAttribute("Bubbles"))
	UserInputService.JumpRequest:Connect(popRide)
	RunService.Heartbeat:Connect(step)
end

return BubbleStormController
