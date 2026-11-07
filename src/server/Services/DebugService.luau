--!strict
-- Gated QA / cheat commands (issue: "Fejlesztői debug-panel").
--
-- Authorization is decided ON THE SERVER in every request: everyone in Studio,
-- otherwise only DEV_USER_IDS. Hiding the client panel is not security.
--
-- Other services register their own commands in init():
--
--     DebugService.register("tips", "Give yourself tips", "tips <amount>", function(player, args)
--         local amount = Validate.integer(tonumber(args[1]), 1, 1_000_000)
--         if not amount then return false, "usage: tips <amount>" end
--         EconomyService.addTips(player, amount, "debug")   -- same API as real gameplay
--         return true, `+{amount} tips`
--     end)
--
-- Handlers must go through the same service APIs as real gameplay, never poke raw data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)

-- Add your Roblox UserId here to use the panel on live/private servers.
local DEV_USER_IDS: { [number]: true } = {
	-- [123456789] = true,
}

local MAX_COMMAND_LENGTH = 32
local MAX_ARG_LENGTH = 64
local MAX_ARGS = 4

export type Handler = (player: Player, args: { string }) -> (boolean, string)

type Command = {
	info: Types.DebugCommandInfo,
	handler: Handler,
}

local DebugService = {}

local commands: { [string]: Command } = {}
local startedAt = os.clock()

function DebugService.isAuthorized(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return DEV_USER_IDS[player.UserId] == true
end

function DebugService.register(name: string, description: string, usage: string, handler: Handler)
	assert(#name > 0 and #name <= MAX_COMMAND_LENGTH, "invalid debug command name")
	assert(commands[name] == nil, `debug command '{name}' registered twice`)
	commands[name] = {
		info = { name = name, description = description, usage = usage },
		handler = handler,
	}
end

local function listCommands(): { Types.DebugCommandInfo }
	local list: { Types.DebugCommandInfo } = {}
	for _, command in commands do
		table.insert(list, command.info)
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

local function registerBuiltIns()
	DebugService.register("help", "List all debug commands", "help", function()
		local names = {}
		for _, info in listCommands() do
			table.insert(names, info.usage)
		end
		return true, table.concat(names, " | ")
	end)

	DebugService.register(
		"echo",
		"Echo arguments back (remote round-trip test)",
		"echo <text>",
		function(_, args)
			return true, table.concat(args, " ")
		end
	)

	DebugService.register(
		"serverinfo",
		"Players, uptime and place version",
		"serverinfo",
		function()
			return true,
				string.format(
					"players=%d/%d uptime=%ds placeVersion=%d studio=%s",
					#Players:GetPlayers(),
					Players.MaxPlayers,
					math.floor(os.clock() - startedAt),
					game.PlaceVersion,
					tostring(RunService:IsStudio())
				)
		end
	)
end

function DebugService.init()
	registerBuiltIns()
end

local function runCommand(
	player: Player,
	name: string,
	command: Command,
	args: { string }
): (boolean, string)
	local ok, success, message = pcall(command.handler, player, args)
	if not ok then
		warn(`[DebugService] '{name}' failed: {success}`)
		return false, `error in '{name}' (see server output)`
	end
	print(`[DebugService] {player.Name} ran '{name}': {message}`)
	return success, message
end

-- Studio MCP bridge: Studio's MCP Luau threads cannot fire remotes, so in
-- Studio only a server snippet may set ServerStorage attribute "DebugCommand"
-- to a command line ("event Tornado"); it runs for the first player and the
-- reply lands in "DebugResult". ServerStorage never replicates, so clients
-- cannot reach this, and it is not wired up outside Studio at all.
local function startStudioBridge()
	local ServerStorage = game:GetService("ServerStorage")
	ServerStorage:GetAttributeChangedSignal("DebugCommand"):Connect(function()
		local line = ServerStorage:GetAttribute("DebugCommand")
		if typeof(line) ~= "string" or line == "" then
			return
		end
		ServerStorage:SetAttribute("DebugCommand", nil)
		local player = Players:GetPlayers()[1]
		local words = string.split(line, " ")
		local name = table.remove(words, 1) or ""
		local command = commands[name]
		if not player or not command then
			ServerStorage:SetAttribute("DebugResult", `FAIL: no player or unknown '{name}'`)
			return
		end
		local args = {}
		for _, w in words do
			if w ~= "" then
				table.insert(args, w)
			end
		end
		local success, message = runCommand(player, name, command, args)
		ServerStorage:SetAttribute("DebugResult", `{if success then "OK" else "FAIL"}: {message}`)
	end)
end

function DebugService.start()
	local resultRemote = Net.event("DebugResult")
	if RunService:IsStudio() then
		startStudioBridge()
	end

	Net.onServerInvoke(
		"DebugGetInfo",
		{ ratePerSecond = 1, burst = 3 },
		function(player): Types.DebugInfo
			if not DebugService.isAuthorized(player) then
				return { authorized = false, commands = {} }
			end
			return { authorized = true, commands = listCommands() }
		end
	)

	Net.onServerEvent("DebugRun", { ratePerSecond = 4, burst = 8 }, function(player, rawName, ...)
		if not DebugService.isAuthorized(player) then
			return -- silently drop: never tell an exploiter what exists
		end
		local name = Validate.string(rawName, MAX_COMMAND_LENGTH)
		if not name then
			return
		end
		local command = commands[name]
		if not command then
			resultRemote:FireClient(player, false, `unknown command '{name}'`)
			return
		end

		local args: { string } = {}
		local raw = table.pack(...)
		for i = 1, math.min(raw.n, MAX_ARGS) do
			local arg = Validate.optionalString(raw[i], MAX_ARG_LENGTH)
			if arg == nil then
				resultRemote:FireClient(player, false, "invalid argument")
				return
			end
			if arg ~= "" then
				table.insert(args, arg)
			end
		end

		local success, message = runCommand(player, name, command, args)
		resultRemote:FireClient(player, success, message)
	end)
end

return DebugService
