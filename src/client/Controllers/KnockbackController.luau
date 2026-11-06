--!strict
-- Applies server-decided knockbacks to the local character (the client owns
-- its character physics): a short ragdoll-like tumble, then a quick get-up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local KnockbackController = {}

local player = Players.LocalPlayer
local DEFAULT_CAP = 200
local HARD_CAP = 500

local busyToken = 0

local MAX_START_OFFSET = 30 -- studs; a launch may only move us a little first

local function apply(impulse: Vector3, duration: number, cap: number, startAt: Vector3?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return
	end
	if impulse.Magnitude > cap then
		impulse = impulse.Unit * cap
	end
	busyToken += 1
	local token = busyToken

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	-- Launches (pizza cannon) start from a fixed point so the arc is the one
	-- the server checked; this client owns the character, so it moves it.
	if startAt and (startAt - root.Position).Magnitude <= MAX_START_OFFSET then
		root.CFrame = CFrame.new(startAt) * root.CFrame.Rotation
	end
	root.AssemblyLinearVelocity = impulse
	root.AssemblyAngularVelocity =
		Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))

	task.delay(duration, function()
		if token ~= busyToken or humanoid.Health <= 0 then
			return
		end
		root.AssemblyAngularVelocity = Vector3.zero
		-- Stand up facing the same horizontal direction.
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			flat = Vector3.new(0, 0, -1)
		end
		root.CFrame = CFrame.lookAt(
			root.Position + Vector3.new(0, 1.5, 0),
			root.Position + Vector3.new(0, 1.5, 0) + flat.Unit
		)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

function KnockbackController.start()
	Net.event("Knockback").OnClientEvent:Connect(
		function(
			impulse: unknown,
			duration: unknown,
			_source: unknown,
			cap: unknown,
			startAt: unknown
		)
			if typeof(impulse) == "Vector3" and typeof(duration) == "number" then
				local limit = if typeof(cap) == "number"
					then math.clamp(cap, 1, HARD_CAP)
					else DEFAULT_CAP
				apply(
					impulse,
					math.clamp(duration, 0.2, 4),
					limit,
					if typeof(startAt) == "Vector3" then startAt else nil
				)
			end
		end
	)
end

return KnockbackController
