--!strict
-- Errand visuals (#218): a glowing pillar with the shop's icon and name where
-- the customer sent you, and a HUD line "📞 Hot sauce from the Hot Sauce Hut
-- · ×1.4". Ticks green once grabbed. Reads the player attribute "Errand"
-- (ErrandService); visual only.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local ErrandController = {}

local player = Players.LocalPlayer
local PENDING = Color3.fromHex("#FFB23F")
local DONE = Color3.fromHex("#7CFFB2")

local marker: Model? = nil
local line: TextLabel

local function clearMarker()
	if marker then
		marker:Destroy()
		marker = nil
	end
end

local function buildMarker(d: { [string]: any })
	clearMarker()
	local m = Instance.new("Model")
	m.Name = "ErrandMarker"
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.45
	pillar.Color = PENDING
	pillar.Size = Vector3.new(30, Tuning.Errand.pickupRadius, Tuning.Errand.pickupRadius)
	pillar.CFrame = CFrame.new(d.x, MapLayout.streetY + 15, d.z) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = m
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 18, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 1000
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromHex("#FFF3D6")
	text.TextStrokeTransparency = 0.2
	text.Text = `{d.icon} {d.name}`
	text.Parent = gui
	gui.Adornee = pillar
	gui.Parent = pillar
	m.Parent = Workspace
	marker = m
end

local function render()
	local raw = player:GetAttribute("Errand")
	if typeof(raw) ~= "string" then
		clearMarker()
		line.Visible = false
		return
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" then
		return
	end
	local data = d :: any
	if not marker then
		buildMarker(data)
	end
	local pillar = marker and marker:FindFirstChild("Pillar")
	if pillar and pillar:IsA("BasePart") then
		pillar.Color = if data.done then DONE else PENDING
		pillar.Transparency = if data.done then 0.75 else 0.45
	end
	line.Visible = true
	line.TextColor3 = if data.done then DONE else PENDING
	line.Text = if data.done
		then `✅ Got {data.item}! Deliver for ×{Tuning.Errand.tipMultiplier}`
		else `📞 {data.icon} Grab {data.item} at the {data.name} · ×{Tuning.Errand.tipMultiplier}`
end

function ErrandController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Errand"
	gui.ResetOnSpawn = false
	line = Instance.new("TextLabel")
	line.Name = "Line"
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.new(0.5, 0, 0, 178)
	line.Size = UDim2.new(0.9, 0, 0, 28)
	line.BackgroundColor3 = Color3.fromHex("#2B2633")
	line.BackgroundTransparency = 0.15
	line.Font = Enum.Font.FredokaOne
	line.TextSize = 17
	line.TextTruncate = Enum.TextTruncate.AtEnd
	line.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 28)
	limit.Parent = line
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = line
	line.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("Errand"):Connect(function()
		local raw = player:GetAttribute("Errand")
		if typeof(raw) ~= "string" then
			clearMarker()
		elseif marker then
			-- a new errand (different shop) rebuilds the marker
			local ok, d = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			local text = marker:FindFirstChild("Pillar")
			local label = text and text:FindFirstChildOfClass("BillboardGui")
			local tl = label and label:FindFirstChildOfClass("TextLabel")
			if ok and tl and not string.find(tl.Text, (d :: any).name, 1, true) then
				clearMarker()
			end
		end
		render()
	end)
	render()
end

return ErrandController
