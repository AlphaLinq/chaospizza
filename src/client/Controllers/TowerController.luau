--!strict
-- Party tower visuals (#170): a stack of pizza boxes above the courier's head
-- (as many as "TowerBoxes"), leaning and wobbling with "TowerTilt" from the
-- server; the stack flashes red near the tipping point. Drawn for every
-- courier with a party order. Visual only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TowerController = {}

local BOX = Color3.fromHex("#E9D7B4")
local DANGER = Color3.fromHex("#FF5A4A")

type Stack = { model: Model, boxes: { BasePart }, count: number, phase: number }

local folder: Folder
local stacks: { [Player]: Stack } = {}

local function build(count: number): Stack
	local model = Instance.new("Model")
	model.Name = "PartyTower"
	local boxes = {}
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(2.2, 0.45, 2.2)
		p.Color = BOX
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		table.insert(boxes, p)
	end
	model.Parent = folder
	return { model = model, boxes = boxes, count = count, phase = math.random() * 6 }
end

local function step()
	local t = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local count = player:GetAttribute("TowerBoxes")
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local stack = stacks[player]
		if typeof(count) ~= "number" or count <= 0 or not head or not head:IsA("BasePart") then
			if stack then
				stack.model:Destroy()
				stacks[player] = nil
			end
			continue
		end
		if not stack or stack.count ~= count then
			if stack then
				stack.model:Destroy()
			end
			stack = build(count)
			stacks[player] = stack
		end
		local tiltValue = player:GetAttribute("TowerTilt")
		local tilt = if typeof(tiltValue) == "number" then tiltValue else 0
		local wobble = math.sin(t * (4 + tilt * 8) + stack.phase) * (0.04 + tilt * 0.22)
		local base = head.CFrame * CFrame.new(0, 1.2, 0)
		local flat = CFrame.new(base.Position)
			* CFrame.Angles(0, select(2, base:ToEulerAnglesYXZ()), 0)
		for i, box in stack.boxes do
			-- each box leans a bit more than the one below: a bending tower
			local lean = CFrame.Angles(wobble * i * 0.6, 0, wobble * i)
			box.CFrame = flat * lean * CFrame.new(0, (i - 1) * 0.5, 0)
			box.Color = if tilt > 0.7 and math.sin(t * 20) > 0 then DANGER else BOX
		end
	end
end

function TowerController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalTowers"
	folder.Parent = Workspace
	Players.PlayerRemoving:Connect(function(player)
		local s = stacks[player]
		if s then
			s.model:Destroy()
			stacks[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return TowerController
