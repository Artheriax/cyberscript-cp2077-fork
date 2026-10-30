logme(10,"CyberMod: api module loaded")
cyberscript.module = cyberscript.module +1
local api = {}

-- B-13 fix: every public api.* entry point wraps the internal call in pcall
-- and logs the failure with enough context for downstream-mod authors to
-- debug spawn failures (GH #17 — dependent mods reported "no NPC spawns" with
-- no diagnostic). The api surface (argument count, return value) is unchanged
-- so existing downstream mods are not broken. Failures return nil; callers
-- that already check for nil continue to work; callers that ignored errors
-- now at least leave a trace in cyberscript.log.

function api.spawn(chara,appearance, tag, x, y ,z, spawnlevel, isprevention, isMPplayer, scriptlevel, isitem, rotation) 
        local ok, err = pcall(function()
                spawnNPC(chara,appearance, tag, x, y ,z, spawnlevel, isprevention, isMPplayer, scriptlevel, isitem, rotation)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.spawn failed for chara=" .. tostring(chara) .. " tag=" .. tostring(tag) .. " err=" .. tostring(err))
        end
end

function api.spawnVehicle(chara, appearance, tag, x, y ,z, spawnlevel, spawn_system ,isAV,from_behind,isMP,wait_for_vehicule, scriptlevel, wait_for_vehicle_second)
        
        
        
        local ok, err = pcall(function()
                spawnVehicleV2(chara, appearance, tag, x, y ,z, spawnlevel, spawn_system ,isAV,from_behind,isMP,wait_for_vehicule, scriptlevel, wait_for_vehicle_second)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.spawnVehicle failed for chara=" .. tostring(chara) .. " tag=" .. tostring(tag) .. " err=" .. tostring(err))
        end
end

function api.despawn(tag) 
        
        local ok, err = pcall(function()
                despawnEntity(tag)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.despawn failed for tag=" .. tostring(tag) .. " err=" .. tostring(err))
        end
        
end

function api.move(targetPuppet, targetPosition, targetDistance, movementType, v2)
        
        local ok, err = pcall(function()
                MoveTo(targetPuppet, targetPosition, targetDistance, movementType, v2)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.move failed err=" .. tostring(err))
        end
        
end

function api.teleport(objlook, position, rotation, isplayer)
        
        local ok, err = pcall(function()
                teleportTo(objlook, position, rotation, isplayer)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.teleport failed err=" .. tostring(err))
        end
        
end

function api.getEntitybyTag(tag)
        
        local ok, result = pcall(function()
                return getEntityFromManager(tag)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.getEntitybyTag failed for tag=" .. tostring(tag) .. " err=" .. tostring(err))
                return nil
        end
        return result
        
end

function api.runActionList(actionlist, tag, source,isquest,executortag,bypassMenu)
        
        local ok, err = pcall(function()
                runActionList(actionlist, tag, source,isquest,executortag,bypassMenu)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.runActionList failed for tag=" .. tostring(tag) .. " err=" .. tostring(err))
        end
        
end

function api.checkTriggerRequirement(requirement,triggerlist)
        
        local ok, result = pcall(function()
                return checkTriggerRequirement(requirement,triggerlist)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.checkTriggerRequirement failed err=" .. tostring(err))
                return false
        end
        return result
        
end


function api.setVariable(tag,key,score)
        
        local ok, err = pcall(function()
                setVariable(tag,key,score)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.setVariable failed for tag=" .. tostring(tag) .. " key=" .. tostring(key) .. " err=" .. tostring(err))
        end
        
end

function api.getVariableKey(tag,key)
        
        local ok, result = pcall(function()
                return getVariableKey(tag,key)
        end)
        if not ok then
                logme(1, "[Cyberscript API] api.getVariableKey failed for tag=" .. tostring(tag) .. " key=" .. tostring(key) .. " err=" .. tostring(err))
                return nil
        end
        return result

end

---------------------------------------------------------------------------
-- Extension API (events, custom actions and triggers, datapack content)
-- Check api.apiVersion before using these, so your mod still loads on older
-- CyberScript builds that don't have them.
---------------------------------------------------------------------------

api.apiVersion = 1

-- Listen to a CyberScript event. Returns an id to pass to api.off.
--   "action"   { name, tag, source, executortag, success, error, custom }
--   "variable" { tag, key, old, new }
function api.on(event, callback)
        return cyberscriptExtensions.on(event, callback)
end

function api.off(id)
        return cyberscriptExtensions.off(id)
end

-- Add an action datapacks can use: { "name": "mymod:my_action", ... }.
-- handler(action, ctx) gets the action's JSON fields and
-- ctx = { tag, parent, index, source, executortag }.
-- Return false to stop the rest of the action list; anything else continues.
-- Names must contain ":" so they never clash with built-in actions.
function api.registerAction(name, handler, owner)
        return cyberscriptExtensions.registerAction(name, handler, owner)
end

function api.unregisterAction(name)
        return cyberscriptExtensions.unregisterAction(name)
end

-- Add a trigger datapacks can use in requirements: { "name": "mymod:my_trigger", ... }.
-- handler(trigger) gets the trigger's JSON fields and returns true or false.
-- The usual "expected" field still works on custom triggers.
function api.registerTrigger(name, handler, owner)
        return cyberscriptExtensions.registerTrigger(name, handler, owner)
end

function api.unregisterTrigger(name)
        return cyberscriptExtensions.unregisterTrigger(name)
end

-- Loaded datapack content, read only. Types include "webpage", "interfaces",
-- "faction", "corpo", "node", "shard", "mission" and more; see api.getContentTypes().
function api.getContentTypes()
        return cyberscriptExtensions.getContentTypes()
end

function api.listContent(objtype)
        return cyberscriptExtensions.listContent(objtype)
end

function api.getContent(objtype, tag)
        return cyberscriptExtensions.getContent(objtype, tag)
end

return api