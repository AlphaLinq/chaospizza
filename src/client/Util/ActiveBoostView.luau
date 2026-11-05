--!strict
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ActiveBoostView = {}
function ActiveBoostView.new(player: Player, parent: Instance, visible: () -> boolean): () -> ()
	local frame = Instance.new("Frame")
	frame.Name = "ActiveBoosts"
	frame.LayoutOrder = -1
	frame.Size = UDim2.new(1, -8, 0, 110)
	frame.BackgroundColor3 = Color3.fromHex("#302936")
	frame.Visible = false
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Text = "Active boosts"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromHex("#FFD24A")
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Parent = frame
	local timers = title:Clone()
	timers.Name = "Timers"
	timers.Font = Enum.Font.GothamMedium
	timers.TextSize = 15
	timers.TextWrapped = true
	timers.TextYAlignment = Enum.TextYAlignment.Top
	timers.TextColor3 = Color3.fromHex("#FFF3D6")
	timers.Position = UDim2.fromOffset(12, 40)
	timers.Parent = frame
	local note = timers:Clone()
	note.Name = "OfflineNote"
	note.Text = "Timers keep running while you are away."
	note.TextSize = 13
	note.Size = UDim2.new(1, -24, 0, 36)
	note.Parent = frame
	local previous: any = nil
	local state: { any } = {}
	return function()
		local raw = player:GetAttribute("ActiveBoosts")
		if raw ~= previous then
			previous = raw
			state = {}
			if type(raw) == "string" then
				local ok, decoded = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if ok and type(decoded) == "table" then
					state = decoded
				end
			end
		end
		local now = Workspace:GetServerTimeNow()
		local lines: { string } = {}
		for _, item in state do
			if
				type(item) == "table"
				and type(item.name) == "string"
				and type(item.expiresAt) == "number"
				and item.expiresAt > now
			then
				local remaining = math.ceil(item.expiresAt - now)
				table.insert(
					lines,
					`{item.name} · {math.floor(remaining / 60)}:{string.format(
						"%02d",
						remaining % 60
					)}`
				)
			end
		end
		frame.Visible = visible() and #lines > 0
		timers.Text = table.concat(lines, "\n")
		timers.Size = UDim2.new(1, -24, 0, #lines * 44)
		note.Position = UDim2.fromOffset(12, 42 + #lines * 44)
		frame.Size = UDim2.new(1, -8, 0, 86 + #lines * 44)
	end
end
return ActiveBoostView
