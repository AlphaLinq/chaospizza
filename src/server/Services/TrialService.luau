--!strict
-- Time trial (#163). A gate on the plaza starts a 6-checkpoint run through
-- town (MapLayout.trialCourse) and back. The server owns the clock and the
-- checkpoints: order, radius, impossible legs (faster than the fastest
-- courier, unless a pizza cannon fired you) and teleports (unstuck, safety)
-- void the run. Personal best: profile.claims["trial.best"] (ms). Weekly
-- ranking: ordered store TrialWeek_<week> with score = maxScoreMs - time.
--
-- Replication: player attribute "TrialRun" = JSON { state, t0, next, total,
-- splits } (server time); the plaza board shows this week's top runs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Trial = require(ReplicatedStorage.Shared.Util.Trial)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CannonService = require(script.Parent.CannonService)
local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local MapService = require(script.Parent.MapService)

local TrialService = {}

local cfg = Tuning.Trial
local BEST_KEY = "trial.best"

type Run = {
	state: "countdown" | "running",
	startsAt: number, -- server time
	nextIndex: number,
	legStart: number, -- os.clock() of the last checkpoint
	legFrom: Vector3,
	lastPos: Vector3?,
	cannonLeg: boolean,
	splits: { number },
	debug: boolean?, -- used the debug "next" jump: no best, no ranking
}

local checkpoints: { Vector3 } = {}
for _, c in MapLayout.trialCourse do
	table.insert(checkpoints, Vector3.new(c.x, c.y, c.z))
end
local gate = MapLayout.trialGate
local gatePos = Vector3.new(gate.x, gate.y, gate.z)
table.insert(checkpoints, gatePos) -- finish = back through the gate

local runs: { [Player]: Run } = {}
local boardText: TextLabel? = nil

local function fastestSpeed(): number
	return Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(player: Player, run: Run?)
	if not run then
		player:SetAttribute("TrialRun", nil)
		return
	end
	player:SetAttribute(
		"TrialRun",
		HttpService:JSONEncode({
			state = run.state,
			t0 = run.startsAt,
			next = run.nextIndex,
			total = #checkpoints,
			splits = run.splits,
		})
	)
end

local function point(v: Vector3): Trial.Point
	return { x = v.X, y = v.Y, z = v.Z }
end

function TrialService.getBest(player: Player): number?
	local profile = DataService.getProfile(player)
	local best = profile and profile.claims[BEST_KEY]
	return if typeof(best) == "number" and best > 0 then best else nil
end

-- Courier profile (#171): the personal best as a read-only attribute
-- ("TrialBestMs", ms; nil = no run yet): set on load and on a new record.
local function publishBest(player: Player)
	player:SetAttribute("TrialBestMs", TrialService.getBest(player))
end

local function cancel(player: Player, reason: string)
	if runs[player] then
		runs[player] = nil
		publish(player, nil)
		Net.event("Hint"):FireClient(player, `⏱️ Time trial cancelled: {reason}`)
	end
end

local function refreshBoard()
	local text = boardText
	if not text then
		return
	end
	local rows =
		DataService.readRanking(cfg.weeklyStorePrefix .. tostring(Trial.week(now())), cfg.boardRows)
	local lines = { "⏱️ TIME TRIAL · this week" }
	if rows then
		for i, row in rows do
			local userId = tonumber(row.key) or 0
			local ok, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			table.insert(
				lines,
				`{i}. {if ok then name else "Courier"}  {Trial.format(
					Trial.msFromScore(row.value, cfg :: any)
				)}`
			)
		end
	end
	if #lines == 1 then
		table.insert(lines, "No runs yet — be the first!")
	end
	text.Text = table.concat(lines, "\n")
end

local function finish(player: Player, run: Run)
	runs[player] = nil
	local ms = math.floor((now() - run.startsAt) * 1000)
	local best = TrialService.getBest(player)
	local record = not run.debug and (best == nil or ms < best)
	if record then
		DataService.update(player, function(profile)
			profile.claims[BEST_KEY] = ms
		end)
		publishBest(player)
	end
	if not run.debug then
		DataService.updateRanking(
			cfg.weeklyStorePrefix .. tostring(Trial.week(now())),
			player.UserId,
			Trial.score(ms, cfg :: any)
		)
	end
	local tips = if record then cfg.recordTips else cfg.finishTips
	EconomyService.addTips(player, tips, "time_trial")
	Net.event("Hint"):FireClient(
		player,
		if record
			then `🏁 NEW BEST! {Trial.format(ms)} · +{tips} tips`
			else `🏁 {Trial.format(ms)} (best {Trial.format(best or ms)}) · +{tips} tips`
	)
	player:SetAttribute(
		"TrialRun",
		HttpService:JSONEncode({
			state = "finished",
			ms = ms,
			best = if record then ms else best,
			record = record,
			splits = run.splits,
			total = #checkpoints,
		})
	)
	task.delay(5, function()
		if not runs[player] and player.Parent then
			publish(player, nil)
		end
	end)
	task.spawn(refreshBoard)
end

function TrialService.begin(player: Player): (boolean, string)
	if runs[player] then
		return false, "already running"
	end
	if not CharacterService.getRootPart(player) then
		return false, "no character"
	end
	local root = CharacterService.getRootPart(player) :: BasePart
	runs[player] = {
		state = "countdown",
		startsAt = now() + cfg.countdownSeconds,
		nextIndex = 1,
		legStart = os.clock() + cfg.countdownSeconds,
		legFrom = gatePos,
		lastPos = root.Position,
		cannonLeg = false,
		splits = {},
	}
	publish(player, runs[player])
	return true, `time trial starts in {cfg.countdownSeconds}s`
end

local function step()
	local t = now()
	local clock = os.clock()
	for player, run in runs do
		local root = CharacterService.getRootPart(player)
		if not root then
			cancel(player, "no character")
			continue
		end
		local p = root.Position
		local last = run.lastPos
		run.lastPos = p
		if run.state == "countdown" then
			if (p - gatePos).Magnitude > cfg.checkpointRadius * 2 then
				cancel(player, "left the start gate early")
			elseif t >= run.startsAt then
				run.state = "running"
				publish(player, run)
			end
			continue
		end
		if t - run.startsAt > cfg.timeoutSeconds then
			cancel(player, "too slow (time limit)")
			continue
		end
		if last and (p - last).Magnitude > cfg.jumpStuds and not run.cannonLeg then
			cancel(player, "teleported")
			continue
		end
		local target = checkpoints[run.nextIndex]
		if Trial.hits(point(p), point(target), cfg :: any) then
			local seconds = clock - run.legStart
			local distance = ((target - run.legFrom) * Vector3.new(1, 0, 1)).Magnitude
			if
				not run.cannonLeg
				and Trial.impossibleLeg(distance, seconds, fastestSpeed(), cfg :: any)
			then
				cancel(player, "impossible split")
				continue
			end
			table.insert(run.splits, math.floor((t - run.startsAt) * 1000))
			run.legStart = clock
			run.legFrom = target
			run.cannonLeg = false
			if run.nextIndex >= #checkpoints then
				finish(player, run)
			else
				run.nextIndex += 1
				publish(player, run)
			end
		end
	end
end

local function buildGate()
	local map = MapService.getMapFolder()
	local model = Instance.new("Model")
	model.Name = "TrialGate"
	local function part(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: string,
		neon: boolean?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = Color3.fromHex(color)
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local base = CFrame.new(gate.x, MapLayout.streetY + 0.2, gate.z)
	part("PostL", Vector3.new(1, 10, 1), base * CFrame.new(-5, 5, 0), "#2B2633")
	part("PostR", Vector3.new(1, 10, 1), base * CFrame.new(5, 5, 0), "#2B2633")
	local top =
		part("Banner", Vector3.new(11, 1.6, 0.6), base * CFrame.new(0, 10, 0), "#FF4FD8", true)
	top.CanCollide = false
	local board = part("Board", Vector3.new(9, 6, 0.4), base * CFrame.new(-11, 4, 0), "#2B2633")
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(450, 300)
		gui.LightInfluence = 0
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -20, 1, -20)
		text.Position = UDim2.fromOffset(10, 10)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromHex("#FFF3D6")
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = "⏱️ TIME TRIAL"
		text.Parent = gui
		gui.Parent = board
		if face == Enum.NormalId.Front then
			boardText = text
		else
			local front = boardText
			if front then
				front:GetPropertyChangedSignal("Text"):Connect(function()
					text.Text = front.Text
				end)
			end
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Start time trial"
	prompt.ObjectText = "6 checkpoints"
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent =
		part("Pad", Vector3.new(10, 0.2, 6), base * CFrame.new(0, 0.1, 0), "#FF4FD8", true)
	prompt.Triggered:Connect(function(player)
		local ok, message = TrialService.begin(player)
		if not ok then
			Net.event("Hint"):FireClient(player, `⏱️ {message}`)
		end
	end)
	model.Parent = map
end

function TrialService.init()
	DebugService.register(
		"trial",
		"Time trial: start, jump to the next checkpoint, cancel",
		"trial [start|next|cancel|best]",
		function(player, args)
			local sub = args[1] or "start"
			if sub == "start" then
				CharacterService.teleport(player, gatePos)
				return TrialService.begin(player)
			elseif sub == "next" then
				local run = runs[player]
				if not run then
					return false, "no run"
				end
				-- Debug walk: mark the leg as a cannon leg so the teleport is allowed.
				run.cannonLeg = true
				run.debug = true
				CharacterService.teleport(player, checkpoints[run.nextIndex])
				return true, `moved to checkpoint {run.nextIndex}/{#checkpoints}`
			elseif sub == "cancel" then
				cancel(player, "debug")
				return true, "cancelled"
			end
			local best = TrialService.getBest(player)
			return true, if best then `best {Trial.format(best)}` else "no best yet"
		end
	)
end

function TrialService.start()
	DataService.onLoaded(function(player)
		publishBest(player)
	end)
	for _, player in Players:GetPlayers() do
		publishBest(player)
	end
	buildGate()
	CannonService.onFired(function(player)
		local run = runs[player]
		if run then
			run.cannonLeg = true -- a cannon leg is fast by design
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			step()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
	end)
	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(60)
		end
	end)
end

return TrialService
