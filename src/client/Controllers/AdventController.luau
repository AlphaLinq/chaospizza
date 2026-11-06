--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Config = require(ReplicatedStorage.Shared.Config.Advent)
local Net = require(ReplicatedStorage.Shared.Net)
local View = require(script.Parent.Parent.Util.AdventView)
local Paint = require(script.Parent.Parent.Util.ShopView)
local Controller = {}
local connections: { RBXScriptConnection } = {}
local alive = false
local ui: any = nil
local pending: string? = nil
local message: string? = nil
local sequence = 0
function Controller.start()
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local function language(): any
		local locale = pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
		return Config.labels[if string.sub(string.lower(tostring(locale)), 1, 2) == "hu"
			then "hu"
			else "en"]
	end
	local function read(): any
		local raw = player:GetAttribute("AdventState")
		local ok, state = pcall(function()
			return HttpService:JSONDecode(if type(raw) == "string" then raw else "")
		end)
		return if ok
				and type(state) == "table"
				and state.season == Config.season
			then state
			else nil
	end
	local function render()
		if not alive or not ui or not ui.root.Parent then
			return
		end
		local copy, state = language(), read()
		ui.title.Text = copy.title
		ui.info.Text = (
			if not state
				then copy.loading
				elseif state.preview then copy.preview
				elseif state.active then copy.rules
				else copy.outside
		)
			.. "\n"
			.. copy.duplicate
		ui.notice.Text = if pending then copy.busy else if message then copy[message] else ""
		ui.notice.Visible = ui.notice.Text ~= ""
		for day, cell in ui.cells do
			local gift = Config.rewards[day]
			local status = if state and state.rows[day] then state.rows[day].state else "locked"
			local enabled = pending == nil and (status == "claimable" or status == "catchup")
			cell.date.Text = `{copy.day} {day}`
			local parts = {}
			if gift.tips then
				table.insert(parts, `{gift.tips} {copy.tips}`)
			end
			if gift.boost then
				table.insert(parts, copy.boost)
			end
			if gift.cosmetic then
				table.insert(parts, copy[gift.cosmetic])
			end
			cell.reward.Text = table.concat(parts, " + ")
			cell.status.Text = copy[status] or copy.locked
			cell.button.Active, cell.button.AutoButtonColor = enabled, enabled
			cell.button.BackgroundColor3 = if enabled then Paint.colors.cheese else Paint.colors.row
			for _, label in { cell.date, cell.reward, cell.status } do
				label.TextColor3 = if enabled then Paint.colors.panel else Paint.colors.cream
			end
		end
	end
	local function claim(day: number)
		local state = read()
		local row = state and state.rows[day]
		if pending or not row or (row.state ~= "claimable" and row.state ~= "catchup") then
			return
		end
		pending = `advent:claim.{day}`
		message = nil
		sequence += 1
		local token, key = sequence, pending
		render()
		Net.event("RequestPurchase"):FireServer(key)
		task.delay(Config.requestTimeoutSeconds, function()
			if alive and pending == key and sequence == token then
				pending, message = nil, "timeout"
				render()
			end
		end)
	end
	local function ensure()
		if not alive or ui and ui.root.Parent then
			return
		end
		local daily = pg:FindFirstChild("Daily")
		local calendar = daily and daily:FindFirstChild("Calendar", true)
		if not calendar then
			return
		end
		ui = View.new(calendar)
		for day, cell in ui.cells do
			cell.button.Activated:Connect(function()
				claim(day)
			end)
		end
		ui.root.Destroying:Connect(function()
			task.defer(ensure)
		end)
		render()
	end
	table.insert(connections, player:GetAttributeChangedSignal("AdventState"):Connect(render))
	table.insert(connections, pg:GetAttributeChangedSignal("UILocaleOverride"):Connect(render))
	table.insert(
		connections,
		LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(render)
	)
	table.insert(
		connections,
		pg.DescendantAdded:Connect(function(instance)
			if instance.Name == "Calendar" then
				task.defer(ensure)
			end
		end)
	)
	table.insert(
		connections,
		Net.event("PurchaseResult").OnClientEvent:Connect(function(ok: any, _, key: any)
			if pending and key == pending then
				sequence += 1
				pending, message = nil, if ok == true then "saved" else "failed"
				render()
			end
		end)
	)
	ensure()
end
function Controller.destroy()
	alive = false
	sequence += 1
	pending, message = nil, nil
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if ui then
		ui.root:Destroy()
		ui = nil
	end
end
return Controller
