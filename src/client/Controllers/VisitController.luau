--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.Community)
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local VisitController = {}
local connections: { RBXScriptConnection } = {}
local gui: ScreenGui?
function VisitController.start()
	local ui = Panel.new("Visits", "Visit a pizzeria")
	gui = ui.screen
	local pending: string? = nil
	local generation = 0
	local function render()
		Panel.clear(ui.scroll)
		local map = Workspace:FindFirstChild("PizzaMap")
		local count = 0
		if map then
			for _, model in map:GetChildren() do
				if model:IsA("Model") then
					local id = model:GetAttribute("OwnerUserId")
					local owner = if type(id) == "number"
						then Players:GetPlayerByUserId(id)
						else nil
					if owner then
						count += 1
						local name =
							`{owner.DisplayName} · Level {model:GetAttribute("Level") or 1}\n{owner:GetAttribute(
								"PizzeriaLikes"
							) or 0} likes{if owner:GetAttribute("PizzeriaFavourite")
								then " · City favourite"
								else ""}`
						local row = Panel.row(ui.scroll, tostring(id), name, count)
						row.Active = pending == nil
						row.Activated:Connect(function()
							if pending then
								return
							end
							local key = `visit:{id}`
							pending = key
							generation += 1
							local token = generation
							ui.status.Text = "Checking the streets…"
							Net.event("RequestPurchase"):FireServer(key)
							task.delay(Config.requestTimeoutSeconds, function()
								if gui and generation == token and pending == key then
									pending = nil
									render()
									ui.status.Text = "No reply yet. Please try again."
								end
							end)
						end)
					end
				end
			end
		end
		if count == 0 then
			ui.status.Text = "The pizzerias are still opening. Try again shortly."
		end
	end
	table.insert(
		connections,
		Players.LocalPlayer.PlayerGui:GetAttributeChangedSignal("PizzaOverlay"):Connect(function()
			if Players.LocalPlayer.PlayerGui:GetAttribute("PizzaOverlay") == "Visits" then
				ui.status.Text = "Choose a pizzeria. Visits have a 20-second cooldown."
				render()
			end
		end)
	)
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(_, reason: any, key: any)
			if pending and pending == key then
				pending = nil
				generation += 1
				render()
				ui.status.Text = tostring(reason)
			end
		end)
	)
	table.insert(
		connections,
		Workspace.DescendantAdded:Connect(function(instance)
			if instance:IsA("Model") and instance:GetAttribute("OwnerUserId") then
				render()
			end
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function()
			task.defer(function()
				if gui then
					render()
				end
			end)
		end)
	)
	render()
end
function VisitController.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if gui then
		gui:Destroy()
		gui = nil
	end
end
return VisitController
