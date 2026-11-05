--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Sounds)
local Plan = require(ReplicatedStorage.Shared.Util.EventAudioPlan)
local SoundController = require(script.Parent.SoundController)
local EventAudioController = {}
local alive = false
local observed: RBXScriptConnection? = nil
function EventAudioController.start()
	alive = true
	while alive and not SoundController.isReady() do
		task.wait(Config.readyPollSeconds)
	end
	if not alive then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CityState", Config.stateTimeoutSeconds)
	if not state then
		return
	end
	SoundController.ownWarnings(true)
	local lastWarning: string? = nil
	local lastPhase: any = nil
	local queued = false
	local function refresh()
		queued = false
		if not alive then
			return
		end
		local plan = Plan.get(Config, {
			id = state:GetAttribute("EventId"),
			combo = state:GetAttribute("ComboId"),
			phase = state:GetAttribute("EventPhase"),
			endsAt = state:GetAttribute("PhaseEndsAt"),
			mega = state:GetAttribute("Mega") == true,
		})
		if plan.warning and plan.warningToken ~= lastWarning then
			lastWarning = plan.warningToken
			SoundController.play(plan.warning)
		elseif plan.phase == "windDown" and lastPhase and lastPhase ~= "windDown" then
			SoundController.play("EventEnd")
		end
		lastPhase = plan.phase
		SoundController.setMusic(plan.music)
		SoundController.setAmbience(plan.ambience)
		Players.LocalPlayer:SetAttribute("AudioEventState", HttpService:JSONEncode(plan))
	end
	observed = state.AttributeChanged:Connect(function()
		if not queued then
			queued = true
			task.defer(refresh)
		end
	end)
	refresh()
end
function EventAudioController.destroy()
	alive = false
	if observed then
		observed:Disconnect()
		observed = nil
	end
	SoundController.setMusic(nil)
	SoundController.setAmbience({})
	SoundController.ownWarnings(false)
end
return EventAudioController
