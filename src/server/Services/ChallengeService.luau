--!strict
-- Event challenges (#200, docs/GAMEPLAY_LOOP.md G2). While an event runs,
-- every courier gets one optional mini-task for it (Config/EventChallenges):
-- dodge horses up close, ride a bubble, catch pizzas… Done = tips, a
-- profile counter (claims["challenges.done"]) and a HUD tick. The server
-- tracks everything; event modules report custom progress with
-- ChallengeService.progress(player, key, n).
--
-- Replication: player attribute "EventChallenge" = JSON { event, text, goal,
-- progress, done }.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Challenges = require(ReplicatedStorage.Shared.Config.EventChallenges)
local EventChallenge = require(ReplicatedStorage.Shared.Util.EventChallenge)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)
local StyleService = require(script.Parent.StyleService)

local ChallengeService = {}

local cfg = Tuning.Challenges
local currentEvent: string? = nil
local states: { [Player]: EventChallenge.State } = {}
local runId = 0

local function def(): Challenges.Challenge?
	return if currentEvent then Challenges[currentEvent] else nil
end

local function publish(player: Player)
	local d = def()
	local state = states[player]
	if not d or not state then
		player:SetAttribute("EventChallenge", nil)
		return
	end
	player:SetAttribute(
		"EventChallenge",
		HttpService:JSONEncode({
			event = state.event,
			text = d.text,
			goal = state.goal,
			progress = EventChallenge.shown(state),
			done = state.done,
		})
	)
end

local function complete(player: Player)
	local d = def()
	if not d then
		return
	end
	local tips = d.tips or cfg.tips
	EconomyService.addTips(player, tips, "event_challenge")
	DataService.update(player, function(profile)
		profile.claims["challenges.done"] = (profile.claims["challenges.done"] or 0) + 1
	end)
	AnalyticsService.custom(player, `challenge_done_{currentEvent}`)
	Net.event("Hint"):FireClient(player, `🎯 Challenge done: {d.text}! +{tips} tips`)
end

local function add(player: Player, amount: number)
	local state = states[player]
	if not state then
		return
	end
	local before = EventChallenge.shown(state)
	if EventChallenge.add(state, amount) then
		complete(player)
		publish(player)
	elseif EventChallenge.shown(state) ~= before then
		publish(player)
	end
end

-- Custom progress from an event module (stardust, pizza, bowl…).
function ChallengeService.progress(player: Player, key: string, amount: number?)
	local d = def()
	if d and d.kind == "custom" and d.key == key then
		add(player, amount or 1)
	end
end

local function begin(player: Player)
	local d = def()
	if not d or not currentEvent then
		return
	end
	states[player] = EventChallenge.new(currentEvent, d.goal)
	publish(player)
end

local function startFor(id: string)
	currentEvent = if Challenges[id] then id else nil
	runId += 1
	table.clear(states)
	for _, player in Players:GetPlayers() do
		if currentEvent then
			begin(player)
		else
			publish(player)
		end
	end
end

local function stop()
	runId += 1
	local myRun = runId
	-- Keep the line (with its tick) visible for a moment, then clear.
	task.delay(cfg.clearDelaySeconds, function()
		if runId ~= myRun then
			return
		end
		currentEvent = nil
		table.clear(states)
		for _, player in Players:GetPlayers() do
			publish(player)
		end
	end)
end

local function poll()
	local d = def()
	if not d or (d.kind ~= "near" and d.kind ~= "rooftop") then
		return
	end
	local target: Vector3? = nil
	if d.kind == "near" then
		local state = ReplicatedStorage:FindFirstChild("CityState")
		local v = state and state:GetAttribute(d.state or "")
		if typeof(v) ~= "Vector3" then
			return
		end
		target = v
	end
	for player in states do
		local root = CharacterService.getRootPart(player)
		if not root then
			continue
		end
		local p = root.Position
		if d.kind == "near" and target then
			local flat = Vector3.new(p.X - target.X, 0, p.Z - target.Z).Magnitude
			if flat <= (d.radius or 30) then
				add(player, cfg.pollSeconds)
			end
		elseif d.kind == "rooftop" then
			local feet = p.Y - 3 - MapLayout.streetY
			if
				feet >= (d.minFeet or 12)
				and not EventChallenge.overStreet(p.X, p.Z, MapLayout.streets :: any)
			then
				add(player, 1)
			end
		end
	end
end

function ChallengeService.getState(player: Player): EventChallenge.State?
	return states[player]
end

function ChallengeService.init()
	DebugService.register(
		"challenge",
		"Event challenge: show it, or complete it now",
		"challenge [show|complete]",
		function(player, args)
			local state = states[player]
			local d = def()
			if not state or not d then
				return false, "no challenge (no event with one running)"
			end
			if args[1] == "complete" then
				add(player, state.goal)
				return true, `completed: {d.text}`
			end
			return true,
				`{d.text} {EventChallenge.shown(state)}/{state.goal}{if state.done
					then " ✔"
					else ""}`
		end
	)
end

function ChallengeService.start()
	EventService.onStarted(function(id)
		startFor(id)
	end)
	EventService.onEnded(function()
		stop()
	end)
	StyleService.onHazard(function(player, kind)
		local d = def()
		local state = states[player]
		if d and state and d.kind == "hazard" and d.hazard == kind then
			local before = state.progress
			if EventChallenge.hazard(state, os.clock(), cfg.hazardCooldownSeconds) then
				complete(player)
				publish(player)
			elseif state.progress ~= before then
				publish(player)
			end
		end
	end)
	OrderService.onDelivered(function(player, order)
		local d = def()
		if not d or not states[player] then
			return
		end
		if d.kind == "deliver" then
			add(player, 1)
		elseif d.kind == "deliverZone" then
			local address = MapService.getAddress(order.addressId)
			local zone = (MapLayout.zones :: any)[d.zone or ""]
			if address and zone then
				local door = address.doorPosition
				if
					math.abs(door.X - zone.x) <= zone.sx / 2 + 10
					and math.abs(door.Z - zone.z) <= zone.sz / 2 + 10
				then
					add(player, 1)
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		if currentEvent then
			begin(player) -- joining mid-event still gets the challenge
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(cfg.pollSeconds)
			poll()
		end
	end)
end

return ChallengeService
