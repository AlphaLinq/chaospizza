--!strict
-- Finale hero crown (#208): a "🏆 FINALE HERO" tag over the head of whoever
-- has the player attribute "FinaleHeroUntil" (server time) in the future.
-- Everyone sees it; visual only (FinaleService picks the hero).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FinaleHeroController = {}

local CROWN = "FinaleHeroCrown"

local function crown(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local untilAt = player:GetAttribute("FinaleHeroUntil")
	local left = if typeof(untilAt) == "number" then untilAt - Workspace:GetServerTimeNow() else 0
	local existing = head and head:FindFirstChild(CROWN)
	if not head or left <= 0 then
		if existing then
			existing:Destroy()
		end
		return
	end
	if not existing then
		local gui = Instance.new("BillboardGui")
		gui.Name = CROWN
		gui.Size = UDim2.fromOffset(170, 34)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 150
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromHex("#FFD23F")
		text.TextStrokeTransparency = 0.2
		text.Text = "🏆 FINALE HERO"
		text.Parent = gui
		gui.Parent = head
	end
	-- Take it off when the time is up (also covers a respawn in between).
	task.delay(left + 0.1, function()
		local h = player.Character and player.Character:FindFirstChild("Head")
		local c = h and h:FindFirstChild(CROWN)
		local until2 = player:GetAttribute("FinaleHeroUntil")
		if c and (typeof(until2) ~= "number" or until2 <= Workspace:GetServerTimeNow()) then
			c:Destroy()
		end
	end)
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("FinaleHeroUntil"):Connect(function()
		crown(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		crown(player)
	end)
	crown(player)
end

function FinaleHeroController.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return FinaleHeroController
