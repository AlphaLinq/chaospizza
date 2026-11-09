--!strict
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Policy = require(ReplicatedStorage.Shared.Util.SoundPolicy)
local AudioMixer = {}
function AudioMixer.new(config: any)
	local folder = Instance.new("Folder")
	folder.Name = "PizzaAudio"
	folder.Parent = SoundService
	local groups: { [string]: SoundGroup } = {}
	for _, channel in { "music", "sfx" } do
		local group = Instance.new("SoundGroup")
		group.Name = channel
		group.Parent = folder
		groups[channel] = group
	end
	local voices: { any } = {}
	local last: { [string]: number } = {}
	local music: string? = nil
	local beat = -1
	local alive = true
	local ownWarnings = false
	local legacyVolumes: { [Sound]: number } = {}
	local ambient: { [string]: Sound } = {}
	local detailBeats: { [string]: number } = {}
	local spatial: Part? = nil
	local spatialKey: string? = nil
	local api = {}
	function api.setSpatialLoop(key: string?, position: Vector3?)
		local clip = key and config.clips[key]
		if not alive or not position or not clip or not clip.loop or not clip.spatial then
			if spatial then
				spatial:Destroy()
			end
			spatial, spatialKey = nil, nil
			return
		end
		if spatialKey ~= key or not spatial then
			if spatial then
				spatial:Destroy()
			end
			local emitter = Instance.new("Part")
			emitter.Name = "PizzaAudioEmitter"
			emitter.Size = Vector3.new(0.1, 0.1, 0.1)
			emitter.Anchored, emitter.CanCollide, emitter.CanTouch, emitter.CanQuery =
				true, false, false, false
			emitter.Transparency, emitter.CastShadow = 1, false
			emitter.Position = position
			local sound = Instance.new("Sound")
			sound.Name, sound.SoundId = key :: string, clip.asset
			sound.SoundGroup, sound.Volume, sound.PlaybackSpeed =
				groups.sfx, clip.volume, clip.speed
			sound.RollOffMode = Enum.RollOffMode.Linear
			sound.RollOffMinDistance, sound.RollOffMaxDistance = clip.minDistance, clip.maxDistance
			sound.Looped = true
			sound.Parent = emitter
			emitter.Parent = workspace
			sound:Play()
			spatial, spatialKey = emitter, key
		end
		if spatial then
			spatial.Position = position
		end
	end
	function api.setAmbience(keys: { string })
		local wanted: { [string]: boolean } = {}
		for index, key in keys do
			if index > config.maxAmbientVoices then
				break
			end
			local clip = config.clips[key]
			if not clip or not clip.loop then
				continue
			end
			wanted[key] = true
			if not ambient[key] then
				local sound = Instance.new("Sound")
				sound.Name = key
				sound.SoundId = clip.asset
				sound.SoundGroup = groups.sfx
				sound.Volume, sound.PlaybackSpeed = clip.volume, clip.speed
				sound.Looped = true
				sound.Parent = folder
				ambient[key] = sound
				sound:Play()
			end
		end
		for key, sound in ambient do
			if not wanted[key] then
				sound:Destroy()
				ambient[key] = nil
				detailBeats[key] = nil
			end
		end
	end
	function api.volume(channel: string, value: unknown)
		groups[channel].Volume = Policy.volume(value)
	end
	function api.play(key: string, now: number, pitch: number?): boolean
		local clip = config.clips[key]
		if not alive or not clip or groups[clip.channel].Volume <= 0 then
			return false
		end
		if last[key] and now - last[key] < clip.cooldown then
			return false
		end
		last[key] = now
		local voice: any = nil
		for _, item in voices do
			if not item.sound.IsPlaying then
				voice = item
				break
			end
		end
		if not voice and #voices < config.maxVoices then
			local sound = Instance.new("Sound")
			sound.Name = `Voice{#voices + 1}`
			sound.Parent = folder
			voice = { sound = sound, token = 0, started = now }
			table.insert(voices, voice)
		elseif not voice then
			voice = voices[1]
			for _, item in voices do
				if item.started < voice.started then
					voice = item
				end
			end
		end
		local sound = voice.sound :: Sound
		sound:Stop()
		sound.SoundId = clip.asset
		sound.SoundGroup = groups[clip.channel]
		sound.Volume = clip.volume
		sound.PlaybackSpeed = clip.speed * (pitch or 1)
		voice.channel = clip.channel
		voice.token += 1
		voice.started = now
		local token = voice.token
		sound:SetAttribute("Cue", key)
		sound:Play()
		task.delay(clip.seconds, function()
			if alive and voice.token == token then
				sound:Stop()
			end
		end)
		return true
	end
	function api.setMusic(key: string?)
		if music == key then
			return
		end
		music, beat = key, -1
		for _, voice in voices do
			if voice.channel == "music" then
				voice.sound:Stop()
				voice.token += 1
			end
		end
		folder:SetAttribute("Music", key)
	end
	function api.tick(now: number)
		for key in ambient do
			local detail = config.clips[key].detail
			if detail then
				local cue, nextBeat = Policy.detail(detail, now)
				if detailBeats[key] ~= nextBeat then
					detailBeats[key] = nextBeat
					if cue then
						api.play(cue, now)
					end
				end
			end
		end
		local track = music and config.music[music]
		if not track then
			return
		end
		local nextBeat, note = Policy.note(track, now)
		if nextBeat == beat then
			return
		end
		-- Never replay missed beats after a slow frame or background suspension.
		beat = nextBeat
		api.play("MegaNote", now, 2 ^ (note / 12))
		if beat % 4 == 0 then
			api.play("MegaBass", now, 2 ^ (track.notes[math.floor(beat / 8) % 4 * 8 + 1] / 12))
		end
	end
	function api.legacy(sound: Sound): (() -> ())?
		-- The old EventController ping remains source-owned by Claude. Route its
		-- output into this mixer; the distinct event cue replaces that generic ping.
		if sound.Parent == SoundService and sound.SoundId == config.legacyWarningId then
			local oldVolume, oldGroup = sound.Volume, sound.SoundGroup
			legacyVolumes[sound] = oldVolume
			sound.SoundGroup = groups.sfx
			sound.Volume = if ownWarnings then 0 else oldVolume
			return function()
				legacyVolumes[sound] = nil
				if sound.Parent then
					sound.SoundGroup, sound.Volume = oldGroup, oldVolume
				end
			end
		end
		return nil
	end
	function api.ownWarnings(enabled: boolean)
		ownWarnings = enabled
		for sound, value in legacyVolumes do
			if sound.Parent then
				sound.Volume = if enabled then 0 else value
			end
		end
	end
	function api.destroy()
		alive = false
		api.setSpatialLoop(nil, nil)
		folder:Destroy()
		table.clear(voices)
	end
	task.spawn(function()
		local assets: { string } = {}
		local samples: { Sound } = {}
		for _, clip in config.clips do
			if not table.find(assets, clip.asset) then
				table.insert(assets, clip.asset)
				local sample = Instance.new("Sound")
				sample.Name = "Preload"
				sample.SoundId = clip.asset
				sample.Volume = 0
				sample.Parent = folder
				table.insert(samples, sample)
			end
		end
		local fetched = true
		local ok, err = pcall(function()
			-- Sound instances preserve the content type of bundled rbxasset paths.
			ContentProvider:PreloadAsync(samples, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then
					fetched = false
				end
			end)
		end)
		for _, sample in samples do
			sample:Destroy()
		end
		if alive then
			folder:SetAttribute("PreloadFinished", true)
			folder:SetAttribute("PreloadSucceeded", ok and fetched)
			if not ok or not fetched then
				warn(
					`[SoundController] Audio preload failed: {tostring(err or "asset unavailable")}`
				)
			end
		end
	end)
	return api
end
return AudioMixer
