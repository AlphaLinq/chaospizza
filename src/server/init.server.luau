--!strict
-- Pizza Chaos server entry point. The only Script in the game (AGENTS.md 4.2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Bootstrap = require(ReplicatedStorage.Shared.Util.Bootstrap)

-- Remotes must exist before any service registers handlers.
Net.setupServer()

Bootstrap.run(script:FindFirstChild("Services"), "Server")
