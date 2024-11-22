logme(10,"CyberMod: sound module loaded")
cyberscript.module = cyberscript.module +1


function PlaySound(sound,isradio,needrepeat,entity,duration,effect)
	if(entity == nil) then entity = Game.GetPlayer() end
	local playsound = sound.tag
	
	if sound.language ~= nil then
		
		if sound.language[cyberscript.language] ~= nil then
		
			playsound = sound.language[cyberscript.language]
		
		else
			
			if sound.language["default"] ~= nil then
				playsound = sound.language["default"]
			end
		end
	
	end

	if(effect == nil) then
		Game.GetAudioSystemExt():Play(playsound,CName.new("V"));

	else
		Game.GetAudioSystemExt():Play(playsound,CName.new("V"));
		-- -- Create a mutable builder for audio settings
		-- local builder = AudioSettingsExtBuilder.Create()

		-- -- Set various properties on the builder

		-- builder:SetVolume(effect)

		-- -- Build the settings to get an immutable reference
		-- local settings = builder:Build()
		-- Game.GetAudioSystemExt():Play(playsound,CName.new("V"),setting);

	end
	-- local audioEvent = SoundPlayEvent.new()
	-- audioEvent.soundName = playsound
	-- entity:QueueEvent(audioEvent)
	local times = os.date()
	local durationsound = duration or sound.duration
	cyberscript.soundmanager[sound.tag] = {}
	cyberscript.soundmanager[sound.tag] = sound
	cyberscript.soundmanager[sound.tag].isplaying = true
	cyberscript.soundmanager[sound.tag].isradio = isradio
	cyberscript.soundmanager[sound.tag].needrepeat = needrepeat
	cyberscript.soundmanager[sound.tag].startplaying = os.time(os.date("!*t"))+0
	cyberscript.soundmanager[sound.tag].endplaying = os.time(os.date("!*t"))+durationsound+1
	
	
end

function PlaySoundAtEntity(sound,isradio,needrepeat,tag,duration,effect)
	
	local playsound = sound.tag
	
	if sound.language ~= nil then
		
		if sound.language[cyberscript.language] ~= nil then
		
			playsound = sound.language[cyberscript.language]
		
		else
			
			if sound.language["default"] ~= nil then
				playsound = sound.language["default"]
			end
		end
	
	end
	local obj = getEntityFromManager(tag)
	if(obj ~= nil) then
		local enti = Game.FindEntityByID(obj.id)
		if(enti ~= nil) then
			if Game.GetAudioSystemExt():IsRegisteredEmitter(obj.id) == false then
				Game.GetAudioSystemExt():RegisterEmitter(obj.id)
			end


			if(effect == nil) then
				Game.GetAudioSystemExt():PlayOnEmitter(playsound,obj.id,CName.new(tag));
		
			else
				Game.GetAudioSystemExt():PlayOnEmitter(playsound,obj.id,CName.new(tag));
				-- local test = AudioSettingsExtBuilder.new()
				-- -- Create a mutable builder for audio settings
				-- local builder = test:Create()
		
				-- -- Set various properties on the builder
		
				-- builder:SetVolume(effect)
		
				-- -- Build the settings to get an immutable reference
				-- local settings = builder:Build()
			
				-- Game.GetAudioSystemExt():PlayOnEmitter(playsound,obj.id,CName.new(tag),setting);
			end
			
			-- local audioEvent = SoundPlayEvent.new()
			-- audioEvent.soundName = playsound
			-- enti:QueueEvent(audioEvent)
			local times = os.date()
			
			cyberscript.soundmanager[sound.tag] = {}
			cyberscript.soundmanager[sound.tag] = sound
			cyberscript.soundmanager[sound.tag].isplaying = true
			cyberscript.soundmanager[sound.tag].emitter = tag
			cyberscript.soundmanager[sound.tag].emitterid = obj.id
			cyberscript.soundmanager[sound.tag].isradio = isradio
			cyberscript.soundmanager[sound.tag].needrepeat = needrepeat
			cyberscript.soundmanager[sound.tag].startplaying = os.time(os.date("!*t"))+0

			local durationsound = duration or sound.duration

			cyberscript.soundmanager[sound.tag].endplaying = os.time(os.date("!*t"))+durationsound+1
		end
	end
	
end

function Stop(sound)
	
	
	
	if(cyberscript.soundmanager[sound].emitter == nil) then

		Game.GetAudioSystem():Stop(sound);
	else
		local enti = Game.FindEntityByID(cyberscript.soundmanager[sound].emitterid)
		if(enti ~= nil) then
			Game.GetAudioSystemExt():StopOnEmitter(sound, cyberscript.soundmanager[sound].emitterid,cyberscript.soundmanager[sound].emitter);
		end
	end
	
	cyberscript.soundmanager[sound] = nil
	
	
end



function IsPlaying(sound)
	
local bool = (cyberscript.soundmanager[sound.tag] ~= nil and cyberscript.soundmanager[sound.tag].isplaying == true)
	
		
	
return bool
	
	
end

function SetSoundSettingValue(volumTag,value)
	
	local SfxVolume = Game.GetSettingsSystem():GetVar("/audio/volume", volumTag)
	SoundManager.SfxVolume = SfxVolume:GetValue()
	SfxVolume:SetValue(value)
	
end



