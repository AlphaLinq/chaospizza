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
local Season = require(ReplicatedStorage.Shared.Util.Season)

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
local currentCombo: string? = nil
local megaPending: string? = nil -- who requested the MEGA ("meter", "purchase", "debug")
local currentPhase: Phase = "calm"
-- effectId: the paid receipt's pending effect; it is acknowledged only when the
-- event actually starts (crash-safe: an unstarted order stays pending).
type QueueEntry = { id: string, by: string?, buyerId: number?, buyerName: string?, effectId: string? }
export type OrderInfo = { userId: number, name: string, effectId: string? }
local queue: { QueueEntry } = {}
-- Buyer of the running ordered event ("Order a Disaster!", brief ch. 16).
local currentOrder: OrderInfo? = nil
-- Buyer of a pending / running purchased MEGA (nil for meter/debug MEGAs).
local megaRequest: OrderInfo? = nil
local currentMegaBuyer: OrderInfo? = nil
local calmStartedAt = 0
local forceStart: string? = nil
local stopRequested = false
local calmEndsAt = 0
local lastEventId: string? = nil
local lastEventEndedAt = -math.huge

local startedCallbacks: { (id: string, by: string?) -> () } = {}
local endedCallbacks: { (id: string, by: string?) -> () } = {}

local function setPhase(phase: Phase, seconds: number)
	currentPhase = phase
	-- Ids first, so clients never see a new phase with a stale event id.
	cityState:SetAttribute("EventId", currentId)
	cityState:SetAttribute("ComboId", currentCombo)
	cityState:SetAttribute("EventPhase", phase)
	cityState:SetAttribute("PhaseEndsAt", Workspace:GetServerTimeNow() + seconds)
end

local function randomRange(rng: Random, a: number, b: number): number
	return a + rng:NextNumber() * (b - a)
end

local function enabledIds(): { string }
	local ids = {}
	local today = os.date("!*t")
	for _, def in Events do
		local inSeason = not def.seasonal
			or Season.isActive((def :: any).season, today.month, today.day)
		if def.enabled and inSeason and modules[def.id] then
			table.insert(ids, def.id)
		end
	end
	return ids
end

local function pickNext(rng: Random): (string?, string?)
	if #queue > 0 then
		local entry = table.remove(queue, 1) :: QueueEntry
		if entry.buyerId and entry.buyerName then
			currentOrder =
				{ userId = entry.buyerId, name = entry.buyerName, effectId = entry.effectId }
		end
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
		local ok: boolean, err: any = pcall(function()
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

local function displayName(id: string): string
	for _, def in Events do
		if def.id == id then
			return def.displayName
		end
	end
	return id
end

-- Runs one event, or two at once for MEGA CHAOS (`comboId`). Each module gets
-- its own context and folder; the phases are shared.
local function runEvent(id: string, by: string?, rng: Random, comboId: string?)
	local module = modules[id]
	if not module then
		return
	end
	local mega = by == "mega"
	currentId = id
	currentCombo = if comboId and modules[comboId] and comboId ~= id then comboId else nil
	stopRequested = false

	local tracked: { any } = {}
	local stateKeys: { [string]: true } = {}
	local t = Tuning.Events
	local activeSeconds = if mega
		then Tuning.ChaosMeter.megaDurationSeconds
		else randomRange(rng, t.activeMinSeconds, t.activeMaxSeconds)

	type Run = { module: EventModule, ctx: Context }
	local runs: { Run } = {}
	local function addRun(eventId: string)
		local folder = Instance.new("Folder")
		folder.Name = `Event_{eventId}`
		folder.Parent = Workspace
		table.insert(tracked, folder)
		local ctx: Context = {
			id = eventId,
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
		table.insert(runs, { module = modules[eventId], ctx = ctx })
	end
	addRun(id)
	if currentCombo then
		addRun(currentCombo)
	end
	if mega then
		EventService.setMega(true)
	end

	for _, callback in startedCallbacks do
		task.spawn(callback, id, by)
	end

	local function step(phase: Phase, seconds: number, after: (() -> ())?): boolean
		if stopRequested then
			return false
		end
		setPhase(phase, seconds)
		local finishAt = os.clock() + seconds
		for _, run in runs do
			local fn = (run.module :: any)[phase] :: ((Context) -> ())?
			if fn then
				local thread = task.spawn(function()
					local ok: boolean, err: any = pcall(fn :: any, run.ctx)
					if not ok then
						warn(`[EventService] {run.ctx.id}.{phase} failed: {err}`)
						stopRequested = true
					end
				end)
				table.insert(tracked, thread)
			end
		end
		if after then
			after()
		end
		while os.clock() < finishAt and not stopRequested do
			task.wait(0.1)
		end
		return not stopRequested
	end

	local function megaBanner()
		local order = currentOrder
		if order and not mega then
			cityState:SetAttribute("OrderedBy", order.name)
			cityState:SetAttribute("OrderedById", order.userId)
			cityState:SetAttribute(
				"Announcement",
				`🍕 {order.name} ordered a {string.upper(displayName(id))}! +{math.floor(
					Tuning.OrderedEvents.tipBonusForEveryone * 100
				)}% tips for everyone!`
			)
		end
		if mega then
			local names = displayName(id)
			if currentCombo then
				names ..= ` + {displayName(currentCombo)}`
			end
			cityState:SetAttribute(
				"Announcement",
				`💥 MEGA CHAOS! {names} — tips ×{Tuning.ChaosMeter.megaTipMultiplier}!`
			)
		end
	end

	local buildUp = 0
	for _, run in runs do
		buildUp = math.max(buildUp, run.module.buildUpSeconds or 3)
	end
	local warningSeconds = if mega
		then Tuning.ChaosMeter.megaWarningSeconds
		else randomRange(rng, t.warningMinSeconds, t.warningMaxSeconds)

	local _ = step("warning", warningSeconds, megaBanner)
		and step("buildUp", buildUp)
		and step("active", activeSeconds, megaBanner)
		and step("windDown", randomRange(rng, t.cleanupMinSeconds, t.cleanupMaxSeconds))

	-- Reset always runs, even after an error or a forced stop.
	setPhase("reset", 1)
	for _, run in runs do
		if run.module.cleanup then
			local ok: boolean, err: any = pcall(run.module.cleanup :: any, run.ctx)
			if not ok then
				warn(`[EventService] {run.ctx.id}.cleanup failed: {err}`)
			end
		end
	end
	cleanupList(tracked)
	cityState:SetAttribute("Announcement", nil)
	for name in stateKeys do
		cityState:SetAttribute(name, nil)
	end
	if mega then
		EventService.setMega(false)
	end
	currentOrder = nil
	currentMegaBuyer = nil
	cityState:SetAttribute("OrderedBy", nil)
	cityState:SetAttribute("OrderedById", nil)

	lastEventId = id
	lastEventEndedAt = os.clock()
	currentId = nil
	currentCombo = nil
	stopRequested = false
	for _, callback in endedCallbacks do
		task.spawn(callback, id, by)
	end
end

-- Picks two events that may be combined (Config.Events megaCombos), or a single
-- one if no valid pair is enabled.
local function pickMegaPair(rng: Random): (string?, string?)
	local ids = enabledIds()
	if #ids == 0 then
		return nil, nil
	end
	local enabled: { [string]: boolean } = {}
	for _, eventId in ids do
		enabled[eventId] = true
	end
	local pairs_: { { string } } = {}
	for _, def in Events do
		if enabled[def.id] then
			for _, other in def.megaCombos do
				if enabled[other] then
					table.insert(pairs_, { def.id, other })
				end
			end
		end
	end
	if #pairs_ == 0 then
		return ids[rng:NextInteger(1, #ids)], nil
	end
	local chosen = pairs_[rng:NextInteger(1, #pairs_)]
	return chosen[1], chosen[2]
end

local function hasOrderQueued(): boolean
	for _, entry in queue do
		if entry.buyerId then
			return true
		end
	end
	return false
end

local function scheduler()
	local rng = Random.new()
	local t = Tuning.Events
	while true do
		-- Calm phase
		local calm = if megaPending
			then Tuning.ChaosMeter.megaCalmSeconds
			elseif hasOrderQueued() then Tuning.OrderedEvents.minCalmBetweenSeconds
			else randomRange(rng, t.calmMinSeconds, t.calmMaxSeconds)
		calmStartedAt = os.clock()
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
		local id: string?, by: string?, combo: string? = nil, nil, nil
		if megaPending then
			id, combo = pickMegaPair(rng)
			by = "mega"
			megaPending = nil
			currentMegaBuyer = megaRequest
			megaRequest = nil
		elseif forceStart then
			id, by = forceStart, "debug"
			forceStart = nil
		else
			id, by = pickNext(rng)
		end
		if id then
			runEvent(id, by, rng, combo)
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

-- Both running events during MEGA CHAOS (primary first), else just the one.
function EventService.getActiveEvents(): { string }
	local id = EventService.getActiveEvent()
	if not id then
		return {}
	end
	return if currentCombo then { id, currentCombo } else { id }
end

-- MEGA CHAOS (brief ch. 15): started by the chaos meter, a purchase (M8) or debug.
-- If an event is running, the MEGA starts right after it ends.
function EventService.requestMega(by: string, buyer: Player?, effectId: string?): boolean
	if megaPending or EventService.isMega() then
		return false
	end
	megaPending = by
	megaRequest = if buyer
		then { userId = buyer.UserId, name = buyer.DisplayName, effectId = effectId }
		else nil
	-- Already calm: start soon (the calm after a running event is short anyway).
	if currentId == nil then
		calmEndsAt = math.min(calmEndsAt, os.clock() + Tuning.ChaosMeter.megaCalmSeconds)
	end
	return true
end

function EventService.isMegaPending(): boolean
	return megaPending ~= nil
end

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

-- Can `id` be ordered right now? Call BEFORE prompting a purchase (brief ch. 16:
-- never sell when the queue is full or during MEGA CHAOS).
function EventService.canOrder(id: string): (boolean, string)
	if not modules[id] or not table.find(enabledIds(), id) then
		return false, "That disaster isn't available right now."
	end
	if megaActive or megaPending then
		return false, "MEGA CHAOS is on — try again after it!"
	end
	if #queue >= Tuning.OrderedEvents.queueLimit then
		return false, "The disaster queue is full — try again in a few minutes."
	end
	return true, ""
end

-- Ordered disaster (paid, after the receipt is recorded). Queued in order; the
-- calm before it is shortened to the minimum.
function EventService.orderEvent(id: string, buyer: Player, effectId: string?): (boolean, string)
	if effectId and EventService.isOrderQueued(effectId) then
		return true, "already in the queue"
	end
	local ok, reason = EventService.canOrder(id)
	if not ok then
		return false, reason
	end
	table.insert(queue, {
		id = id,
		by = "order",
		buyerId = buyer.UserId,
		buyerName = buyer.DisplayName,
		effectId = effectId,
	})
	if currentId == nil then
		calmEndsAt = math.min(
			calmEndsAt,
			math.max(os.clock() + 3, calmStartedAt + Tuning.OrderedEvents.minCalmBetweenSeconds)
		)
	end
	local position = 0
	for i, entry in queue do
		if entry.buyerId == buyer.UserId and entry.id == id then
			position = i
		end
	end
	return true,
		if position <= 1 and currentId == nil then "coming up next" else `#{position} in the queue`
end

-- The running ordered event's buyer, if any.
function EventService.getOrderedBy(): OrderInfo?
	return if currentId then currentOrder else nil
end

-- The running purchased MEGA's buyer, if any.
function EventService.getMegaBuyer(): OrderInfo?
	return if currentId then currentMegaBuyer else nil
end

function EventService.isOrderQueued(effectId: string): boolean
	for _, entry in queue do
		if entry.effectId == effectId then
			return true
		end
	end
	-- The running order counts too, until its receipt is acknowledged.
	if currentOrder and currentOrder.effectId == effectId then
		return true
	end
	if currentMegaBuyer and currentMegaBuyer.effectId == effectId then
		return true
	end
	return megaRequest ~= nil and megaRequest.effectId == effectId
end

-- The buyer left before their order started: drop it from this server so the
-- still-pending purchase runs on their next server instead of twice.
function EventService.cancelOrdersBy(userId: number)
	for i = #queue, 1, -1 do
		if queue[i].buyerId == userId and queue[i].effectId then
			table.remove(queue, i)
		end
	end
	if megaRequest and megaRequest.userId == userId and megaRequest.effectId then
		megaRequest = nil
		megaPending = nil
	end
end

-- +100% tips for everyone while an ordered event's hazard is live.
function EventService.isOrderedActive(): boolean
	return currentOrder ~= nil and EventService.isHazardActive()
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

function EventService.onEnded(callback: (id: string, by: string?) -> ())
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
		"event <HorseRace|Tornado|Flood|Blizzard|mega|stop>",
		function(_, args)
			local id = args[1]
			if id == "mega" then
				local ok = EventService.requestMega("debug")
				return ok, if ok then "MEGA CHAOS requested" else "MEGA already pending/running"
			end
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
			`phase={currentPhase} event={currentId or "-"}{if currentCombo
				then "+" .. currentCombo
				else ""} mega={megaActive} queue={#queue} calmLeft={math.max(
				0,
				math.floor(calmEndsAt - os.clock())
			)}s`
	end)
end

function EventService.start()
	task.spawn(scheduler)
end

return EventService
