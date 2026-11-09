--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Sounds)
local Net = require(ReplicatedStorage.Shared.Net)
local Mixer = require(script.Parent.Parent.Util.AudioMixer)
local Caption = require(script.Parent.Parent.Util.AudioCaption)
local SoundController = {}
local mixer: any = nil
local caption: any = nil
local connections: { RBXScriptConnection } = {}
local buttons: { [Instance]: RBXScriptConnection } = {}
local restores: { () -> () } = {}
function SoundController.play(key: string): boolean
	local clip = Config.clips[key]
	if not mixer or not clip then
		return false
	end
	-- Captions are deliberately independent of both mixer channels and assets.
	if clip.caption then
		caption.show(clip.caption)
	end
	local played = mixer.play(key, Workspace:GetServerTimeNow())
	Players.LocalPlayer:SetAttribute("AudioLastCue", key)
	return played
end
function SoundController.setMusic(key: string?)
	if mixer then
		mixer.setMusic(key)
	end
end
function SoundController.isReady(): boolean
	return mixer ~= nil and caption ~= nil
end
function SoundController.setAmbience(keys: { string })
	if mixer then
		mixer.setAmbience(keys)
	end
end
function SoundController.setSpatialLoop(key: string?, position: Vector3?, scope: string?)
	if mixer then
		mixer.setSpatialLoop(key, position, scope)
	end
end
function SoundController.setBed(key: string?)
	if mixer then
		mixer.setBed(key)
	end
end
function SoundController.ownWarnings(enabled: boolean)
	if mixer then
		mixer.ownWarnings(enabled)
	end
end
function SoundController.start()
	mixer = Mixer.new(Config)
	caption = Caption.new(Config.captionSeconds)
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local function volume()
		mixer.volume("music", player:GetAttribute("MusicVolume"))
		mixer.volume("sfx", player:GetAttribute("SfxVolume"))
	end
	volume()
	for _, name in { "MusicVolume", "SfxVolume" } do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(volume))
	end
	local function button(instance: Instance)
		if not instance:IsA("GuiButton") or instance.Name == "Backdrop" or buttons[instance] then
			return
		end
		local screen = instance:FindFirstAncestorOfClass("ScreenGui")
		if screen and Config.uiScreens[screen.Name] then
			buttons[instance] = instance.Activated:Connect(function()
				SoundController.play("Ui")
			end)
		end
	end
	for _, instance in pg:GetDescendants() do
		button(instance)
	end
	table.insert(connections, pg.DescendantAdded:Connect(button))
	table.insert(
		connections,
		pg.DescendantRemoving:Connect(function(instance)
			local connection = buttons[instance]
			if connection then
				connection:Disconnect()
				buttons[instance] = nil
			end
		end)
	)
	table.insert(
		connections,
		Net.event("DeliveryResult").OnClientEvent:Connect(function(result: any)
			if type(result) == "table" then
				SoundController.play(if result.isNew then "NewCustomer" else "Delivery")
			end
		end)
	)
	table.insert(
		connections,
		player:GetAttributeChangedSignal("AudioPreview"):Connect(function()
			local raw = player:GetAttribute("AudioPreview")
			if type(raw) ~= "string" then
				return
			end
			local ok, value = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(value) == "table" and type(value.cue) == "string" then
				SoundController.play(value.cue)
			end
		end)
	)
	local function legacy(instance: Instance)
		if instance:IsA("Sound") then
			local restore = mixer.legacy(instance)
			if restore then
				table.insert(restores, restore)
			end
		end
	end
	for _, instance in SoundService:GetChildren() do
		legacy(instance)
	end
	table.insert(
		connections,
		SoundService.ChildAdded:Connect(function(instance)
			task.defer(legacy, instance)
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			mixer.tick(Workspace:GetServerTimeNow())
		end)
	)
end
function SoundController.destroy()
	for _, c in connections do
		c:Disconnect()
	end
	for _, c in buttons do
		c:Disconnect()
	end
	for _, restore in restores do
		restore()
	end
	table.clear(connections)
	table.clear(buttons)
	table.clear(restores)
	if mixer then
		mixer.destroy()
		mixer = nil
	end
	if caption then
		caption.destroy()
		caption = nil
	end
end
return SoundController
