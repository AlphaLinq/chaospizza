--!strict
-- Two-phase loader shared by the server and client entry points.
--   1. require every ModuleScript in `container` (sorted by name: deterministic)
--   2. call init() on all of them (synchronous wiring, no yielding)
--   3. call start() on all of them in their own thread (loops, connections)
-- One failing module is reported by name and does not stop the others.

export type Module = {
	init: (() -> ())?,
	start: (() -> ())?,
}

local Bootstrap = {}

function Bootstrap.run(container: Instance?, label: string): number
	if container == nil then
		warn(`[{label}] no module container found`)
		return 0
	end

	local scripts: { ModuleScript } = {}
	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(scripts, child)
		end
	end
	table.sort(scripts, function(a, b)
		return a.Name < b.Name
	end)

	local loaded: { { name: string, module: Module } } = {}
	for _, moduleScript in scripts do
		-- Dynamic require: cast through any so --!strict accepts it.
		local ok, result = pcall(function(): any
			return (require :: any)(moduleScript)
		end)
		if ok and typeof(result) == "table" then
			table.insert(loaded, { name = moduleScript.Name, module = result :: Module })
		else
			warn(`[{label}] failed to load {moduleScript.Name}: {result}`)
		end
	end

	for _, entry in loaded do
		local init = entry.module.init
		if init then
			local ok: boolean, err: any = pcall(init :: any)
			if not ok then
				warn(`[{label}] {entry.name}.init failed: {err}`)
			end
		end
	end

	for _, entry in loaded do
		local start = entry.module.start
		if start then
			task.spawn(function()
				local ok: boolean, err: any = pcall(start :: any)
				if not ok then
					warn(`[{label}] {entry.name}.start failed: {err}`)
				end
			end)
		end
	end

	print(`[{label}] Started {#loaded} {label == "Server" and "services" or "controllers"}`)
	return #loaded
end

return Bootstrap
