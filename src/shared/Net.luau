--!strict
-- The only place remotes are created and wired (AGENTS.md 4.4).
--
-- Adding a remote = add its name to EventName/FunctionName and the lists below.
-- Server: Net.setupServer() runs once in the bootstrap, before any service init.
-- Server handlers go through Net.onServerEvent / Net.onServerInvoke, which apply
-- a per-player rate limit and isolate errors. Argument validation is still the
-- handler's job (use Util/Validate) because only the handler knows the shape.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RateLimiter = require(script.Parent.Util.RateLimiter)

export type EventName =
	"DebugRun"
	| "DebugResult"
	| "DeliverOrder"
	| "DeliveryResult"
	| "Hint"
	| "Knockback"
	| "RequestUnstuck"
	| "CustomerBookUpdated"
	| "RequestPurchase"
	| "PurchaseResult"
	| "ThankBuyer"
	| "WishOpen"
	| "MakeWish"
	| "WishResult"
export type FunctionName = "DebugGetInfo" | "GetCustomerBook" | "GetShop"

local EVENT_NAMES: { EventName } = {
	"DebugRun",
	"DebugResult",
	"DeliverOrder",
	"DeliveryResult",
	"Hint",
	"Knockback",
	"RequestUnstuck",
	"CustomerBookUpdated",
	"RequestPurchase",
	"PurchaseResult",
	"ThankBuyer",
	"WishOpen",
	"MakeWish",
	"WishResult",
}
local FUNCTION_NAMES: { FunctionName } = { "DebugGetInfo", "GetCustomerBook", "GetShop" }

local FOLDER_NAME = "Remotes"
local CLIENT_WAIT_TIMEOUT = 30

export type RateOptions = {
	ratePerSecond: number,
	burst: number,
}

local DEFAULT_RATE: RateOptions = { ratePerSecond = 5, burst = 10 }

local Net = {}

local folder: Folder? = nil
local limiters: { RateLimiter.RateLimiter } = {}

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		error("[Net] setupServer() must run before remotes are used")
	end
	local found = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_TIMEOUT)
	if not found or not found:IsA("Folder") then
		error("[Net] Remotes folder not found; is the server bootstrap running?")
	end
	folder = found
	return found
end

function Net.setupServer()
	assert(RunService:IsServer(), "[Net] setupServer is server-only")
	if folder then
		return
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	for _, name in EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = newFolder
	end
	for _, name in FUNCTION_NAMES do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = newFolder
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:remove(player)
		end
	end)
end

function Net.event(name: EventName): RemoteEvent
	local remote = getFolder():WaitForChild(name, CLIENT_WAIT_TIMEOUT)
	assert(remote and remote:IsA("RemoteEvent"), `[Net] RemoteEvent {name} missing`)
	return remote
end

function Net.func(name: FunctionName): RemoteFunction
	local remote = getFolder():WaitForChild(name, CLIENT_WAIT_TIMEOUT)
	assert(remote and remote:IsA("RemoteFunction"), `[Net] RemoteFunction {name} missing`)
	return remote
end

-- Server: listen to a client->server event with rate limiting and error isolation.
-- The handler receives raw, untrusted arguments: validate every one of them.
function Net.onServerEvent(
	name: EventName,
	rate: RateOptions?,
	handler: (player: Player, ...unknown) -> ()
): RBXScriptConnection
	local options = rate or DEFAULT_RATE
	local limiter = RateLimiter.new(options.ratePerSecond, options.burst)
	table.insert(limiters, limiter)
	return Net.event(name).OnServerEvent:Connect(function(player: Player, ...: unknown)
		if not limiter:allow(player) then
			return
		end
		-- `handler` returns nothing; type pcall's results explicitly (new solver).
		local ok: boolean, err: any = pcall(handler :: any, player, ...)
		if not ok then
			warn(`[Net] {name} handler error for {player.UserId}: {err}`)
		end
	end)
end

-- Server: answer a client->server request. Returns nil when rate limited or on error.
-- Never invoke the client from the server (AGENTS.md 4.4).
function Net.onServerInvoke(
	name: FunctionName,
	rate: RateOptions?,
	handler: (player: Player, ...unknown) -> any
)
	local options = rate or DEFAULT_RATE
	local limiter = RateLimiter.new(options.ratePerSecond, options.burst)
	table.insert(limiters, limiter)
	Net.func(name).OnServerInvoke = function(player: Player, ...: unknown): any
		if not limiter:allow(player) then
			return nil
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`[Net] {name} invoke error for {player.UserId}: {result}`)
			return nil
		end
		return result
	end
end

return Net
