--!strict
-- Pizza Chaos client entry point. The only LocalScript in the game (AGENTS.md 4.2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait once for the shared folder; after this, modules may index it statically.
ReplicatedStorage:WaitForChild("Shared")
local Bootstrap = require(ReplicatedStorage.Shared.Util.Bootstrap)

Bootstrap.run(script:FindFirstChild("Controllers"), "Client")
