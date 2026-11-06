--!strict
-- Time trial visuals (#163): checkpoint rings (the next one glows), a big
-- 3-2-1-GO, a running timer with the checkpoint count, the finish card, and a
-- ghost of your best run this session (recorded on this client). The server
-- (TrialService) owns the clock and the result; this only reads "TrialRun".

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Trial = require(ReplicatedStorage.Shared.Util.Trial)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local TrialController = {}

local player = Players.LocalPlayer
local cfg = Tuning.Trial
local NEXT = Color3.fromHex("#FF4FD8")
local LATER = Color3.fromHex("#6B5C7A")
local GHOST_STEP = 0.1

type RunData = {
	state: string,
	t0: number?,
	next: number?,
	total: number?,
	ms: number?,
	best: number?,
	record: boolean?,
}

local points: { Vector3 } = {}
for _, c in MapLayout.trialCourse do
	table.insert(points, Vector3.new(c.x, c.y, c.z))
end
local gate = MapLayout.trialGate
table.insert(points, Vector3.new(gate.x, gate.y, gate.z))

local folder: Folder
local rings: { BasePart } = {}
local label: TextLabel
local big: TextLabel
local run: RunData? = nil
local recording: { Vector3 } = {}
local ghostPath: { Vector3 }? = nil
local ghost: BasePart? = nil
local recordClock = 0

local function parse(raw: unknown): RunData?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" or typeof((d :: any).state) ~= "string" then
		return nil
	end
	return d :: any
end

local function clearRings()
	for _, r in rings do
		r:Destroy()
	end
	table.clear(rings)
end

local function buildRings()
	clearRings()
	for i, p in points do
		local ring = Instance.new("Part")
		ring.Name = `Checkpoint{i}`
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Size = Vector3.new(0.4, cfg.checkpointRadius * 2, cfg.checkpointRadius * 2)
		ring.CFrame = CFrame.new(p.X, p.Y - 2.4, p.Z) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.7
		ring.Parent = folder
		table.insert(rings, ring)
	end
end

local function paintRings(nextIndex: number)
	for i, ring in rings do
		local done = i < nextIndex
		ring.Color = if i == nextIndex then NEXT else LATER
		ring.Transparency = if done then 1 elseif i == nextIndex then 0.35 else 0.8
	end
end

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrialHUD"
	gui.ResetOnSpawn = false
	label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 56)
	label.Size = UDim2.fromOffset(280, 36)
	label.BackgroundColor3 = Color3.fromHex("#2B2633")
	label.BackgroundTransparency = 0.1
	label.TextColor3 = Color3.fromHex("#FFF3D6")
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 22
	label.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = label
	label.Parent = gui
	big = Instance.new("TextLabel")
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.4)
	big.Size = UDim2.fromOffset(420, 120)
	big.BackgroundTransparency = 1
	big.TextColor3 = NEXT
	big.TextStrokeTransparency = 0.2
	big.Font = Enum.Font.FredokaOne
	big.TextScaled = true
	big.Visible = false
	big.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function sync()
	local data = parse(player:GetAttribute("TrialRun"))
	local was = run
	run = data
	if not data then
		clearRings()
		label.Visible = false
		big.Visible = false
		return
	end
	if #rings == 0 and data.state ~= "finished" then
		buildRings()
		table.clear(recording)
	end
	if data.state == "finished" then
		clearRings()
		big.Visible = true
		big.Text = if data.record then "NEW BEST!" else "FINISH!"
		label.Visible = true
		label.Text =
			`🏁 {Trial.format(data.ms or 0)} · best {Trial.format(data.best or data.ms or 0)}`
		if data.record and #recording > 0 then
			ghostPath = table.clone(recording) -- race your best next time
		end
		task.delay(2, function()
			if run == data then
				big.Visible = false
			end
		end)
		return
	end
	paintRings(data.next or 1)
	if was and was.state == "countdown" and data.state == "running" then
		big.Text = "GO!"
		task.delay(0.8, function()
			if run and run.state == "running" then
				big.Visible = false
			end
		end)
	end
end

local function step(dt: number)
	local data = run
	if not data or data.state == "finished" then
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
		return
	end
	local t = Workspace:GetServerTimeNow() - (data.t0 or 0)
	if data.state == "countdown" then
		big.Visible = true
		big.Text = tostring(math.max(1, math.ceil(-t)))
		label.Visible = true
		label.Text = "⏱️ Get ready…"
		return
	end
	label.Visible = true
	label.Text = `⏱️ {Trial.format(t * 1000)} · {(data.next or 1)}/{data.total or #points}`
	-- record our own path for the ghost
	recordClock += dt
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if recordClock >= GHOST_STEP and root and root:IsA("BasePart") then
		recordClock = 0
		table.insert(recording, root.Position)
	end
	local path = ghostPath
	if path and #path > 1 then
		local g = ghost
		if not g then
			local p = Instance.new("Part")
			p.Name = "TrialGhost"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Shape = Enum.PartType.Ball
			p.Material = Enum.Material.ForceField
			p.Color = Color3.fromHex("#7CFFB2")
			p.Size = Vector3.new(3, 3, 3)
			p.Parent = folder
			ghost = p
			g = p
		end
		local f = math.clamp(t / GHOST_STEP + 1, 1, #path)
		local i = math.floor(f)
		local a, b = path[i], path[math.min(i + 1, #path)];
		(g :: BasePart).Position = a:Lerp(b, f - i)
	end
end

function TrialController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalTrial"
	folder.Parent = Workspace
	buildHud()
	player:GetAttributeChangedSignal("TrialRun"):Connect(sync)
	sync()
	RunService.Heartbeat:Connect(step)
end

return TrialController
