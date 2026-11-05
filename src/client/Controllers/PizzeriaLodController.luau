--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Perf)
local Policy = require(ReplicatedStorage.Shared.Util.VisualBudget)
local PizzeriaLodController = {}
local regulars: { [Model]: any } = {}
local pizzerias: { [Model]: any } = {}
local connections: { RBXScriptConnection } = {}
local alive = false
local function restoreRegular(model: Model, record: any)
	for part, original in record.parts do
		if part.Parent then
			part.LocalTransparencyModifier = original.alpha
			if record.removed then
				part.CFrame = original.frame
			end
		end
	end
	for gui, enabled in record.labels do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	if record.removed and model:IsDescendantOf(Workspace) then
		model:AddTag("PizzeriaRegular")
	end
	record.removed = false
end
local function addRegular(instance: Instance)
	if not instance:IsA("Model") or regulars[instance] then
		return
	end
	local body = instance:FindFirstChild("Body")
	local head = instance:FindFirstChild("Head")
	if
		not body
		or not body:IsA("BasePart")
		or not body.Anchored
		or not head
		or not head:IsA("BasePart")
	then
		return
	end
	local parts, labels = {}, {}
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			parts[child] = { alpha = child.LocalTransparencyModifier, frame = child.CFrame }
		elseif child:IsA("BillboardGui") then
			labels[child] = child.Enabled
		end
	end
	regulars[instance] =
		{ parts = parts, labels = labels, at = body.Position, visible = true, removed = false }
end
local function addPizzeria(instance: Instance)
	if
		not instance:IsA("Model")
		or type(instance:GetAttribute("OwnerUserId")) ~= "number"
		or pizzerias[instance]
	then
		return
	end
	local counter = instance:FindFirstChild("PizzeriaCounter")
	if not counter or not counter:IsA("BasePart") then
		return
	end
	local shadows = {}
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			shadows[child] = child.CastShadow
		end
	end
	pizzerias[instance] = { shadows = shadows, at = counter.Position, visible = true }
end
function PizzeriaLodController.start()
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	for _, instance in CollectionService:GetTagged("PizzeriaRegular") do
		addRegular(instance)
	end
	for _, instance in Workspace:GetDescendants() do
		addPizzeria(instance)
	end
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal("PizzeriaRegular"):Connect(addRegular)
	)
	table.insert(
		connections,
		Workspace.DescendantAdded:Connect(function(instance)
			addPizzeria(instance)
			if instance:IsA("BillboardGui") then
				local model = instance:FindFirstAncestorOfClass("Model")
				local regular = model and regulars[model]
				if regular then
					regular.labels[instance] = instance.Enabled
					if not regular.visible then
						instance.Enabled = false
					end
				end
			end
			if instance:HasTag("PizzeriaRegular") then
				addRegular(instance)
			end
			if instance:IsA("BasePart") then
				local parent = instance.Parent
				if parent and parent:IsA("Model") then
					if parent:HasTag("PizzeriaRegular") then
						addRegular(parent)
					end
					local regular = regulars[parent]
					if regular and not regular.parts[instance] then
						regular.parts[instance] =
							{ alpha = instance.LocalTransparencyModifier, frame = instance.CFrame }
						if not regular.visible then
							instance.LocalTransparencyModifier = 1
						end
					end
				end
				while parent and parent ~= Workspace do
					if
						parent:IsA("Model")
						and type(parent:GetAttribute("OwnerUserId")) == "number"
					then
						addPizzeria(parent)
						local pizzeria = pizzerias[parent]
						if pizzeria and pizzeria.shadows[instance] == nil then
							pizzeria.shadows[instance] = instance.CastShadow
							if not pizzeria.visible then
								instance.CastShadow = false
							end
						end
						break
					end
					parent = parent.Parent
				end
			end
		end)
	)
	table.insert(
		connections,
		Workspace.DescendantRemoving:Connect(function(instance)
			if instance:IsA("Model") then
				local regular, pizzeria = regulars[instance], pizzerias[instance]
				if regular then
					restoreRegular(instance, regular)
				end
				if pizzeria then
					for part, shadow in pizzeria.shadows do
						if part.Parent then
							part.CastShadow = shadow
						end
					end
				end
				regulars[instance], pizzerias[instance] = nil, nil
			end
		end)
	)
	task.spawn(function()
		while alive do
			local camera = Workspace.CurrentCamera
			if camera then
				local quality = player:GetAttribute("EffectQuality")
				local budget = Config.visualProfiles[if type(quality) == "string"
					then quality
					else "low"] or Config.visualProfiles.low
				local hidden, count = 0, 0
				for model, record in regulars do
					local visible = Policy.visible(
						(record.at - camera.CFrame.Position).Magnitude,
						record.visible,
						budget.regularDistance,
						Config.lodHysteresisStuds
					)
					if not visible then
						hidden += 1
						local changed = record.visible
						if model:HasTag("PizzeriaRegular") then
							-- Local tag removal suspends the existing renderer through its
							-- public removal signal. Server tags/data/income are unaffected.
							model:RemoveTag("PizzeriaRegular")
							record.removed = true
							changed = true
						end
						if changed then
							for part, original in record.parts do
								if part.Parent then
									part.LocalTransparencyModifier = 1
									part.CFrame = original.frame
								end
							end
							for gui in record.labels do
								if gui.Parent then
									gui.Enabled = false
								end
							end
						end
					elseif not record.visible then
						restoreRegular(model, record)
					end
					record.visible = visible
				end
				for _, record in pizzerias do
					local visible = Policy.visible(
						(record.at - camera.CFrame.Position).Magnitude,
						record.visible,
						budget.shadowDistance,
						Config.lodHysteresisStuds
					)
					if visible ~= record.visible then
						for part, shadow in record.shadows do
							if part.Parent then
								part.CastShadow = visible and shadow
							end
						end
					end
					record.visible = visible
					if not visible then
						count += 1
					end
				end
				pg:SetAttribute(
					"PizzeriaLod",
					HttpService:JSONEncode({
						hiddenRegulars = hidden,
						reducedShadowPizzerias = count,
						quality = quality,
					})
				)
			end
			task.wait(Config.lodIntervalSeconds)
		end
	end)
end
function PizzeriaLodController.destroy()
	alive = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for model, record in regulars do
		restoreRegular(model, record)
	end
	for _, record in pizzerias do
		for part, shadow in record.shadows do
			if part.Parent then
				part.CastShadow = shadow
			end
		end
	end
	table.clear(regulars)
	table.clear(pizzerias)
end
return PizzeriaLodController
