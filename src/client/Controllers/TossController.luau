--!strict
-- Pizza toss (#236), client side. While you carry an order and stand
-- between the delivery radius and Tuning.Toss.maxStuds from the doorstep
-- with a clear view of it, a big round "🍕 Toss!" button shows (PC: F).
-- It only asks the server (Net "TossOrder"); the server decides. Every
-- client draws tossed boxes flying in an arc (Net "PizzaToss").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Toss = require(ReplicatedStorage.Shared.Util.Toss)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local TossController = {}

local player = Players.LocalPlayer
local cfg = Tuning.Toss
local BOX = Color3.fromHex("#E3B778")
local ACCENT = Color3.fromHex("#FFD23F")
local DARK = Color3.fromHex("#2B2633")

local button: TextButton
local canToss = false

local function request()
	local id = player:GetAttribute("OrderId")
	if canToss and typeof(id) == "string" then
		canToss = false -- one tap = one request; the next check re-enables it
		button.Visible = false
		Net.event("TossOrder"):FireServer(id)
	end
end

local function clearView(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local local_ = Workspace:FindFirstChild("LocalOrderTarget")
	if local_ then
		table.insert(ignore, local_)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(from, to - from, params)
	return hit == nil or (hit.Position - to).Magnitude <= 4
end

local function check()
	local target = player:GetAttribute("OrderTarget")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		typeof(target) ~= "Vector3"
		or typeof(player:GetAttribute("OrderId")) ~= "string"
		or not root
		or not root:IsA("BasePart")
		or player:GetAttribute("Knocked") == true
	then
		canToss = false
	else
		local kind = player:GetAttribute("OrderKind")
		local flat = ((target - root.Position) * Vector3.new(1, 0, 1)).Magnitude
		canToss = Toss.inRange(
			if typeof(kind) == "string" then kind else nil,
			flat,
			root.Position.Y - target.Y,
			Tuning.Orders.deliveryRadiusStuds,
			cfg :: any
		) and clearView(root.Position + Vector3.new(0, 1.5, 0), target)
	end
	button.Visible = canToss
end

local function fly(from: Vector3, to: Vector3)
	local box = Instance.new("Part")
	box.Name = "TossedPizza"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Size = Vector3.new(2.4, 0.5, 2.4)
	box.Color = BOX
	box.Material = Enum.Material.SmoothPlastic
	box.Parent = Workspace
	local a = { x = from.X, y = from.Y, z = from.Z }
	local b = { x = to.X, y = to.Y, z = to.Z }
	local t0 = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local k = (os.clock() - t0) / cfg.flightSeconds
		if k >= 1 or not box.Parent then
			connection:Disconnect()
			box:Destroy()
			return
		end
		local p = Toss.arc(a, b, k, cfg.arcHeight)
		box.CFrame = CFrame.new(p.x, p.y, p.z) * CFrame.Angles(0, k * math.pi * 4, 0)
	end)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PizzaToss"
	gui.ResetOnSpawn = false
	button = Instance.new("TextButton")
	button.Name = "Toss"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -18, 0.5, 0) -- right edge, clear of the jump button
	button.Size = UDim2.fromOffset(96, 96)
	button.BackgroundColor3 = ACCENT
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 22
	button.TextColor3 = DARK
	button.Text = if UserInputService.KeyboardEnabled then "🍕\nToss! (F)" else "🍕\nToss!"
	button.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.Activated:Connect(request)
	button.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

function TossController.start()
	build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			request()
		end
	end)
	Net.event("PizzaToss").OnClientEvent:Connect(function(from, to)
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
			fly(from, to)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.15 then
			elapsed = 0
			check()
		end
	end)
end

return TossController
