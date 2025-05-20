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
	local id = entity:GetEntityID()
	Game.GetAudioSystemExt():Play(playsound,id);
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
	tag = tag or "player"

	local enti = Game.GetPlayer()
	local obj = getEntityFromManager(tag)
	if(tag ~= "player")then
		
		if(obj ~= nil) then
			
			enti = Game.FindEntityByID(obj.id)
		end
	end
	if(enti ~= nil) then
		local id = enti:GetEntityID()
		CName.add("Cyberscript")
		if Game.GetAudioSystemExt():IsRegisteredEmitter(id,"Cyberscript") == false  then
			
			Game.GetAudioSystemExt():RegisterEmitter(id,"Cyberscript")
		end

		if(tag ~= "player")then
				Game.GetAudioSystemExt():PlayOnEmitter(playsound,id,"Cyberscript");
				
			else
				
				Game.GetAudioSystemExt():Play(playsound,id);
			end
		
		
		local times = os.date()
		
		cyberscript.soundmanager[sound.tag] = {}
		cyberscript.soundmanager[sound.tag] = sound
		cyberscript.soundmanager[sound.tag].isplaying = true
		cyberscript.soundmanager[sound.tag].emitter = tag
		cyberscript.soundmanager[sound.tag].emitterid = id
		cyberscript.soundmanager[sound.tag].isradio = isradio
		cyberscript.soundmanager[sound.tag].needrepeat = needrepeat
		cyberscript.soundmanager[sound.tag].startplaying = os.time(os.date("!*t"))+0

		local durationsound = duration or sound.duration

		cyberscript.soundmanager[sound.tag].endplaying = os.time(os.date("!*t"))+durationsound+1
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



