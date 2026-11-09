--!strict
-- City Rush strip (#219): "🔥 CITY RUSH ×4 · 12s" while CityState "CityRush"
-- is set. The number bumps a little when the combo grows. Visual only.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CityRushController = {}

local player = Players.LocalPlayer
local cityState: Instance
local label: TextLabel
local scale: UIScale
local data: { [string]: any }? = nil
local lastCombo = 0

local function sync()
	local raw = cityState:GetAttribute("CityRush")
	if typeof(raw) ~= "string" then
		data = nil
		label.Visible = false
		lastCombo = 0
		return
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" then
		return
	end
	data = d :: any
	local combo = (d :: any).combo or 0
	if combo > lastCombo then
		scale.Scale = 1.25 -- a little bump, eased back in step()
	end
	lastCombo = combo
	label.Visible = true
end

function CityRushController.start()
	cityState = ReplicatedStorage:WaitForChild("CityState")
	local gui = Instance.new("ScreenGui")
	gui.Name = "CityRush"
	gui.ResetOnSpawn = false
	label = Instance.new("TextLabel")
	label.Name = "Strip"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 212)
	label.Size = UDim2.fromOffset(260, 32)
	label.BackgroundColor3 = Color3.fromHex("#3A1A12")
	label.BackgroundTransparency = 0.1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 20
	label.TextColor3 = Color3.fromHex("#FF9B2F")
	label.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	scale = Instance.new("UIScale")
	scale.Parent = label
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	cityState:GetAttributeChangedSignal("CityRush"):Connect(sync)
	sync()
	RunService.Heartbeat:Connect(function(dt)
		local d = data
		if not d then
			return
		end
		scale.Scale = 1 + (scale.Scale - 1) * math.exp(-dt * 8)
		local left = math.max(0, math.ceil((d.endsAt or 0) - Workspace:GetServerTimeNow()))
		label.Text = `🔥 CITY RUSH ×{d.combo or 0} · {left}s`
	end)
end

return CityRushController
