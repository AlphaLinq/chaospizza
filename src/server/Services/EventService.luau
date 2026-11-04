--!strict
-- City events (brief ch. 12, 1.0 ch. 10): one shared, server-driven state
-- machine per server:  calm → warning → buildUp → active → windDown → reset → calm
--
-- Event implementations live in src/server/Events/<Id>.luau (not auto-started)
-- and follow the EventModule interface below. Every phase runs in pcall; any
-- error ends the event and runs its cleanup, so the city always returns to a
-- safe state (AGENTS.md 4.6).
--
-- Replication: ReplicatedStorage.CityState attributes
--   EventId, EventPhase, PhaseEndsAt (Workspace:GetServerTimeNow()), Announcement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DebugService = require(script.Parent.DebugService)

export type Phase = "calm" | "warning" | "buildUp" | "active" | "windDown" | "reset"

export type Context = {
	id: string,
	folder: Folder, -- parent for every temporary instance; destroyed on reset
	rng: Random,
	-- Register cleanup: connections, instances, threads or functions.
	track: (item: any) -> (),
	isRunning: () -> boolean,
	phase: () -> Phase,
	announce: (text: string) -> (),
	-- Replicated event-specific state (CityState attribute), cleared on reset.
	setState: (name: string, value: any) -> (),
	activeSeconds: number,
}

export type EventModule = {
	id: string,
	-- Seconds spent in build-up (props appearing). Default 3.
	buildUpSeconds: number?,
	warning: ((ctx: Context) -> ())?,
	buildUp: ((ctx: Context) -> ())?,
	active: ((ctx: Context) -> ())?, -- may yield; should return when ctx.phase() ~= "active"
	windDown: ((ctx: Context) -> ())?,
	cleanup: ((ctx: Context) -> ())?,
}

local EventService = {}

local cityState: Configuration
local modules: { [string]: EventModule } = {}
local currentId: string? = nil
local currentPhase: Phase = "calm"
local queue: { { id: string, by: string? } } = {}
local forceStart: string? = nil
local stopRequested = false
local calmEndsAt = 0
local lastEventId: string? = nil
local lastEventEndedAt = -math.huge

local startedCallbacks: { (id: string, by: string?) -> () } = {}
local endedCallbacks: { (id: string) -> () } = {}

local function setPhase(phase: Phase, seconds: number)
	currentPhase = phase
	cityState:SetAttribute("EventPhase", phase)
	cityState:SetAttribute("EventId", currentId)
	cityState:SetAttribute("PhaseEndsAt", Workspace:GetServerTimeNow() + seconds)
end

local function randomRange(rng: Random, a: number, b: number): number
	return a + rng:NextNumber() * (b - a)
end

local function enabledIds(): { string }
	local ids = {}
	for _, def in Events do
		if def.enabled and modules[def.id] then
			table.insert(ids, def.id)
		end
	end
	return ids
end

local function pickNext(rng: Random): (string?, string?)
	if #queue > 0 then
		local entry = table.remove(queue, 1) :: { id: string, by: string? }
		return entry.id, entry.by
	end
	local ids = enabledIds()
	if #ids == 0 then
		return nil, nil
	end
	local candidates = {}
	for _, id in ids do
		if id ~= lastEventId or #ids == 1 then
			table.insert(candidates, id)
		end
	end
	return candidates[rng:NextInteger(1, #candidates)], nil
end

local function cleanupList(items: { any })
	for i = #items, 1, -1 do
		local item = items[i]
		local kind = typeof(item)
		local ok, err = pcall(function()
			if kind == "RBXScriptConnection" then
				item:Disconnect()
			elseif kind == "Instance" then
				item:Destroy()
			elseif kind == "thread" then
				task.cancel(item)
			elseif kind == "function" then
				item()
			end
		end)
		if not ok then
			warn(`[EventService] cleanup item failed: {err}`)
		end
	end
	table.clear(items)
end

local function runEvent(id: string, by: string?, rng: Random)
	local module = modules[id]
	if not module then
		return
	end
	currentId = id
	stopRequested = false

	local folder = Instance.new("Folder")
	folder.Name = `Event_{id}`
	folder.Parent = Workspace
	local tracked: { any } = {}
	local stateKeys: { [string]: true } = {}
	local t = Tuning.Events
	local activeSeconds = randomRange(rng, t.activeMinSeconds, t.activeMaxSeconds)

	local ctx: Context = {
		id = id,
		folder = folder,
		rng = rng,
		track = function(item)
			table.insert(tracked, item)
		end,
		isRunning = function()
			return currentId == id and not stopRequested
		end,
		phase = function()
			return currentPhase
		end,
		announce = function(text)
			cityState:SetAttribute("Announcement", text)
		end,
		setState = function(name, value)
			stateKeys[name] = true
			cityState:SetAttribute(name, value)
		end,
		activeSeconds = activeSeconds,
	}

	for _, callback in startedCallbacks do
		task.spawn(callback, id, by)
	end

	local function step(phase: Phase, seconds: number, fn: ((Context) -> ())?): boolean
		if stopRequested then
			return false
		end
		setPhase(phase, seconds)
		local finishAt = os.clock() + seconds
		if fn then
			local thread = task.spawn(function()
				local ok, err = pcall(fn, ctx)
				if not ok then
					warn(`[EventService] {id}.{phase} failed: {err}`)
					stopRequested = true
				end
			end)
			table.insert(tracked, thread)
		end
		while os.clock() < finishAt and not stopRequested do
			task.wait(0.1)
		end
		return not stopRequested
	end

	local _ = step(
		"warning",
		randomRange(rng, t.warningMinSeconds, t.warningMaxSeconds),
		module.warning
	) and step("buildUp", module.buildUpSeconds or 3, module.buildUp) and step(
		"active",
		activeSeconds,
		module.active
	) and step(
		"windDown",
		randomRange(rng, t.cleanupMinSeconds, t.cleanupMaxSeconds),
		module.windDown
	)

	-- Reset always runs, even after an error or a forced stop.
	setPhase("reset", 1)
	if module.cleanup then
		local ok, err = pcall(module.cleanup, ctx)
		if not ok then
			warn(`[EventService] {id}.cleanup failed: {err}`)
		end
	end
	cleanupList(tracked)
	folder:Destroy()
	cityState:SetAttribute("Announcement", nil)
	for name in stateKeys do
		cityState:SetAttribute(name, nil)
	end

	lastEventId = id
	lastEventEndedAt = os.clock()
	currentId = nil
	stopRequested = false
	for _, callback in endedCallbacks do
		task.spawn(callback, id)
	end
end

local function scheduler()
	local rng = Random.new()
	local t = Tuning.Events
	while true do
		-- Calm phase
		local calm = randomRange(rng, t.calmMinSeconds, t.calmMaxSeconds)
		calmEndsAt = os.clock() + calm
		currentId = nil
		setPhase("calm", calm)
		while os.clock() < calmEndsAt and not forceStart do
			task.wait(0.25)
			-- keep PhaseEndsAt honest if calmEndsAt was shortened
			cityState:SetAttribute(
				"PhaseEndsAt",
				Workspace:GetServerTimeNow() + math.max(0, calmEndsAt - os.clock())
			)
		end
		local id, by
		if forceStart then
			id, by = forceStart, "debug"
			forceStart = nil
		else
			id, by = pickNext(rng)
		end
		if id then
			runEvent(id, by, rng)
		end
	end
end

-- Public API ---------------------------------------------------------------

function EventService.register(module: EventModule)
	modules[module.id] = module
end

function EventService.getActiveEvent(): string?
	if
		currentId
		and (currentPhase == "active" or currentPhase == "buildUp" or currentPhase == "warning")
	then
		return currentId
	end
	return nil
end

-- MEGA CHAOS (M6). Until the chaos meter exists this is always false.
local megaActive = false
function EventService.isMega(): boolean
	return megaActive
end

function EventService.setMega(active: boolean)
	megaActive = active
	if cityState then
		cityState:SetAttribute("Mega", active or nil)
	end
end

-- True only while the hazard is live (bonus tips, event customers).
function EventService.isHazardActive(): boolean
	return currentId ~= nil and (currentPhase == "active" or currentPhase == "buildUp")
end

function EventService.getPhase(): Phase
	return currentPhase
end

-- Queue an event (ordered disasters, M8). Returns false when the queue is full.
function EventService.enqueue(id: string, by: string?): boolean
	if not modules[id] or #queue >= Tuning.OrderedEvents.queueLimit then
		return false
	end
	table.insert(queue, { id = id, by = by })
	return true
end

-- Shorten the current calm so an event starts in `delay` seconds (onboarding).
-- Ignored if an event is running or one ended very recently.
function EventService.requestSoon(id: string, delay: number): boolean
	if currentId ~= nil or not modules[id] then
		return false
	end
	if os.clock() - lastEventEndedAt < 30 then
		return false
	end
	if calmEndsAt - os.clock() > delay then
		table.insert(queue, 1, { id = id, by = "onboarding" })
		calmEndsAt = os.clock() + delay
	end
	return true
end

function EventService.onStarted(callback: (id: string, by: string?) -> ())
	table.insert(startedCallbacks, callback)
end

function EventService.onEnded(callback: (id: string) -> ())
	table.insert(endedCallbacks, callback)
end

function EventService.init()
	local existing = ReplicatedStorage:FindFirstChild("CityState")
	if existing then
		existing:Destroy()
	end
	cityState = Instance.new("Configuration")
	cityState.Name = "CityState"
	cityState.Parent = ReplicatedStorage

	-- Load event implementations from the sibling Events folder.
	local eventsFolder = script.Parent.Parent:FindFirstChild("Events")
	if eventsFolder then
		for _, child in eventsFolder:GetChildren() do
			if child:IsA("ModuleScript") then
				local ok, module = pcall(function(): any
					return (require :: any)(child)
				end)
				if ok and typeof(module) == "table" and typeof(module.id) == "string" then
					EventService.register(module)
				else
					warn(`[EventService] failed to load event {child.Name}: {module}`)
				end
			end
		end
	end

	DebugService.register(
		"event",
		"Start / stop events",
		"event <HorseRace|Tornado|Flood|stop>",
		function(_, args)
			local id = args[1]
			if id == "stop" then
				if currentId then
					stopRequested = true
					return true, `stopping {currentId}`
				end
				return true, "no event running"
			end
			if not id or not modules[id] then
				local names = {}
				for name in modules do
					table.insert(names, name)
				end
				table.sort(names)
				return false, `usage: event <{table.concat(names, "|")}|stop>`
			end
			if currentId then
				return false, `{currentId} is running; use 'event stop' first`
			end
			forceStart = id
			return true, `starting {id}`
		end
	)
	DebugService.register("eventstate", "Show the event state", "eventstate", function()
		return true,
			`phase={currentPhase} event={currentId or "-"} queue={#queue} calmLeft={math.max(
				0,
				math.floor(calmEndsAt - os.clock())
			)}s`
	end)
end

function EventService.start()
	task.spawn(scheduler)
end

return EventService
