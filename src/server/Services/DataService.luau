--!strict
-- UpdateAsync owns both profile and lease. Never fall back to live mock data.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProfileSchema = require(ReplicatedStorage.Shared.Util.ProfileSchema)
local DebugService = require(script.Parent.DebugService)
local Persistence = require(ReplicatedStorage.Shared.Config.Progression).persistence
type Profile = ProfileSchema.Profile
type Session = { profile: Profile, token: string, busy: boolean, leaving: boolean }
local DataService = {}
local sessions: { [Player]: Session } = {}
local drafts: { [Player]: Profile } = {}
local callbacks: { (Player, Profile) -> () } = {}
local updatedCallbacks: { (Player) -> () } = {}
local memory: { [number]: Profile } = {}
local store: GlobalDataStore? = nil
local mock = false
local closing = false
local loading = 0
local orderedMemory: { [string]: { [string]: number } } = {}

local function retry(fn: () -> any): (boolean, any)
	local result: any
	for attempt = 1, Persistence.retries do
		local ok, value = pcall(fn)
		if ok then
			return true, value
		end
		result = value
		if attempt < Persistence.retries then
			task.wait(Persistence.retryBaseSeconds ^ (attempt - 1))
		end
	end
	return false, result
end
local function noYield(fn: () -> any): (boolean, any)
	local thread = coroutine.create(fn)
	local ok, value = coroutine.resume(thread)
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		return false, "profile callbacks must not yield"
	end
	return ok, value
end
local function write(player: Player, session: Session, profile: Profile, release: boolean): boolean
	if mock then
		memory[player.UserId] = ProfileSchema.migrate(profile)
		return true
	end
	local dataStore = store
	if not dataStore then
		return false
	end
	local snapshot = ProfileSchema.migrate(profile)
	local ok, saved = retry(function()
		return dataStore:UpdateAsync(`player_{player.UserId}`, function(raw: any)
			if
				type(raw) ~= "table"
				or type(raw.lock) ~= "table"
				or raw.lock.token ~= session.token
			then
				return nil
			end
			return {
				profile = snapshot,
				lock = if release
					then nil
					else {
						token = session.token,
						expires = os.time() + Persistence.leaseSeconds,
					},
			}
		end)
	end)
	return ok and saved ~= nil
end
function DataService.getProfile(player: Player): Profile?
	local session = sessions[player]
	local profile = drafts[player]
		or (if session and not session.leaving then session.profile else nil)
	-- Callers cannot mutate server data without update()/transaction().
	return if profile then ProfileSchema.migrate(profile) else nil
end
function DataService.isLoaded(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and not session.leaving
end
function DataService.onLoaded(callback: (Player, Profile) -> ()): () -> ()
	table.insert(callbacks, callback)
	return function()
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end
-- Runs only after a committed mutation, with no draft reference exposed.
function DataService.onUpdated(callback: (Player) -> ()): () -> ()
	table.insert(updatedCallbacks, callback)
	return function()
		local index = table.find(updatedCallbacks, callback)
		if index then
			table.remove(updatedCallbacks, index)
		end
	end
end
-- fn must be synchronous. Persisted transactions stage effects and the receipt
-- together; only a confirmed write publishes the draft to other systems.
function DataService.transaction(
	player: Player,
	fn: (Profile) -> boolean,
	persist: boolean?
): boolean
	local session = sessions[player]
	if not session or session.busy or session.leaving or closing then
		return false
	end
	session.busy = true
	local draft = ProfileSchema.migrate(session.profile)
	drafts[player] = draft
	local ok, accepted = noYield(function()
		return fn(draft)
	end)
	drafts[player] = nil
	local committed = ok and accepted == true
	if committed and persist then
		committed = write(player, session, draft, false)
		if not committed then
			-- A failed response may still have committed the draft in DataStore.
			-- Fence this session; saving its old profile could erase a paid grant.
			sessions[player] = nil
			session.leaving = true
			player:Kick("Your profile save could not be confirmed. Please rejoin shortly.")
		end
	end
	if committed then
		session.profile = ProfileSchema.migrate(draft)
	end
	session.busy = false
	if committed then
		for _, callback in table.clone(updatedCallbacks) do
			task.defer(callback, player)
		end
	end
	return committed
end
function DataService.update(player: Player, fn: (Profile) -> ()): boolean
	local draft = drafts[player]
	if draft then
		local ok = noYield(function()
			fn(draft)
			return nil
		end)
		if not ok then
			error("profile update failed inside transaction")
		end
		return true
	end
	return DataService.transaction(player, function(profile)
		fn(profile)
		return true
	end)
end
function DataService.save(player: Player): boolean
	local session = sessions[player]
	if not session or session.busy or session.leaving then
		return false
	end
	session.busy = true
	local ok = write(player, session, session.profile, false)
	session.busy = false
	return ok
end
-- Derived rankings still go through the single persistence boundary.
function DataService.updateRanking(name: string, userId: number, value: number): boolean
	if not DataService.isPersistent() then
		local values = orderedMemory[name] or {}
		values[tostring(userId)] = math.max(values[tostring(userId)] or 0, value)
		orderedMemory[name] = values
		return true
	end
	local ok = retry(function()
		return DataStoreService:GetOrderedDataStore(name)
			:UpdateAsync(tostring(userId), function(previous: any)
				return math.max(if type(previous) == "number" then previous else 0, value)
			end)
	end)
	return ok
end
function DataService.readRanking(name: string, limit: number): { { key: string, value: number } }?
	if not DataService.isPersistent() then
		local rows: { { key: string, value: number } } = {}
		local values: { [string]: number } = orderedMemory[name] or {}
		for key, value in values do
			table.insert(rows, { key = key, value = value })
		end
		table.sort(rows, function(a, b)
			return if a.value == b.value then a.key < b.key else a.value > b.value
		end)
		while #rows > limit do
			table.remove(rows)
		end
		return rows
	end
	local ok, rows = retry(function()
		return DataStoreService:GetOrderedDataStore(name)
			:GetSortedAsync(false, limit)
			:GetCurrentPage()
	end)
	return if ok then rows else nil
end
function DataService.isPersistent(): boolean
	return store ~= nil and not mock
end
local function release(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if session.leaving then
		return
	end
	session.leaving = true
	while session.busy do
		task.wait()
	end
	if sessions[player] ~= session then
		return
	end
	session.busy = true
	session.profile.lastSeen = os.time()
	if not write(player, session, session.profile, true) then
		warn(
			`[DataService] Final save failed for {player.UserId}; lease expires without overwriting another session`
		)
	end
	sessions[player] = nil
end
local function load(player: Player)
	if closing or sessions[player] then
		return
	end
	loading += 1
	local token = HttpService:GenerateGUID(false)
	local profile: Profile? = nil
	if mock then
		profile = ProfileSchema.migrate(memory[player.UserId])
	else
		local dataStore = store
		if dataStore then
			-- A fast reconnect waits for the previous server's final save/release.
			for _ = 1, Persistence.lockAttempts do
				if closing or player.Parent ~= Players then
					break
				end
				local ok, result = retry(function()
					return dataStore:UpdateAsync(`player_{player.UserId}`, function(raw: any)
						if
							type(raw) == "table"
							and type(raw.lock) == "table"
							and raw.lock.token ~= token
							and type(raw.lock.expires) == "number"
							and raw.lock.expires > os.time()
						then
							return nil
						end
						local migrated = ProfileSchema.migrate(
							if type(raw) == "table" and raw.profile ~= nil then raw.profile else raw
						)
						return {
							profile = migrated,
							lock = { token = token, expires = os.time() + Persistence.leaseSeconds },
						}
					end)
				end)
				if ok and result then
					profile = ProfileSchema.migrate(result.profile)
					break
				end
				if not ok then
					break
				end
				task.wait(Persistence.lockRetrySeconds)
			end
		end
	end
	if profile then
		sessions[player] = { profile = profile, token = token, busy = false, leaving = false }
		if closing or player.Parent ~= Players then
			release(player)
		else
			for _, callback in table.clone(callbacks) do
				task.spawn(callback, player, ProfileSchema.migrate(profile))
			end
		end
	elseif player.Parent == Players then
		player:Kick("Your pizza profile is busy or unavailable. Please rejoin shortly.")
	end
	loading -= 1
end
function DataService.init()
	DebugService.register("profile", "Show your saved profile", "profile", function(player)
		local profile = DataService.getProfile(player)
		return profile ~= nil,
			if profile then HttpService:JSONEncode(profile) else "profile not loaded"
	end)
	DebugService.register("wipe", "Reset your profile", "wipe", function(player)
		local ok = DataService.transaction(player, function(profile)
			-- Keep the purchase ledger: wiping must never grant a receipt twice.
			local purchases = profile.purchases
			for key, value in ProfileSchema.default() do
				(profile :: any)[key] = value
			end
			profile.purchases = purchases
			return true
		end, true)
		return ok, if ok then "profile reset (purchase history retained)" else "profile unavailable"
	end)
end
function DataService.start()
	local ok, result = pcall(function()
		local candidate = DataStoreService:GetDataStore(Persistence.storeName)
		if RunService:IsStudio() then
			candidate:GetAsync("__studio_access_probe")
		end
		return candidate
	end)
	if ok then
		store = result
	elseif RunService:IsStudio() then
		mock = true
		warn("[DataService] Studio DataStore unavailable; using memory mock (no real purchases)")
	else
		warn("[DataService] DataStore unavailable; profiles will not load")
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	task.spawn(function()
		while not closing do
			task.wait(Persistence.autosaveSeconds)
			for player, session in sessions do
				if closing then
					break
				end
				if not session.leaving then
					task.spawn(function()
						if
							not DataService.save(player)
							and not session.busy
							and not session.leaving
						then
							session.leaving = true
							player:Kick("Your profile could not be saved. Please rejoin.")
							-- Try release with the latest state even after a transient save failure.
							session.leaving = false
							release(player)
						end
					end)
				end
			end
		end
	end)
	game:BindToClose(function()
		closing = true
		for player in sessions do
			task.spawn(release, player)
		end
		while next(sessions) or loading > 0 do
			task.wait()
		end
	end)
end
return DataService
