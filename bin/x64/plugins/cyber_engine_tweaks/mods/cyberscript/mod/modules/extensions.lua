--[[
CyberScript extension layer

Lets other CET mods
  - listen to what CyberScript does (events),
  - add their own actions and triggers that datapacks can use,
  - read loaded datapack content.

Other mods reach all of this through cyberscript.api (see api.lua):

    local cs = GetMod("cyberscript")
    if cs and cs.api and cs.api.apiVersion and cs.api.apiVersion >= 1 then
        cs.api.on("variable", function(e) print(e.tag, e.key, e.old, e.new) end)
        cs.api.registerAction("mymod:do_thing", function(action, ctx) ... end)
    end

Events
  "action"   after a datapack action runs
             { name, tag, source, executortag, success, error, custom }
  "variable" after a CyberScript variable (scores, gang/faction values) changes
             { tag, key, old, new }

Custom action and trigger names must contain a ":" (for example "netrunner:breach_node")
so they can never clash with CyberScript's built-in names, which never use ":".
]]--

logme(10, "CyberScript: extensions module loaded")
cyberscript.module = cyberscript.module + 1

-- Modules are loaded again on every save load. Keep the one extension layer, so
-- the listeners, actions and triggers other mods registered aren't lost.
if cyberscriptExtensions ~= nil then return cyberscriptExtensions end

local extensions = {
	listeners = {},   -- event name -> { id -> callback }
	listenerCount = {}, -- event name -> number of listeners
	actions = {},     -- custom action name -> { handler, owner }
	triggers = {},    -- custom trigger name -> { handler, owner }
	nextId = 0,
	-- Guards against an event listener changing a variable and re-emitting forever.
	emitDepth = 0,
	maxEmitDepth = 8,
}

local function isNamespaced(name)
	return type(name) == "string" and name:find(":", 1, true) ~= nil
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function extensions.on(event, callback)
	if type(event) ~= "string" or type(callback) ~= "function" then
		logme(1, "[CyberScript extensions] on() needs an event name and a function", true)
		return nil
	end
	extensions.nextId = extensions.nextId + 1
	local id = extensions.nextId
	if extensions.listeners[event] == nil then
		extensions.listeners[event] = {}
		extensions.listenerCount[event] = 0
	end
	extensions.listeners[event][id] = callback
	extensions.listenerCount[event] = extensions.listenerCount[event] + 1
	return id
end

function extensions.off(id)
	for event, list in pairs(extensions.listeners) do
		if list[id] ~= nil then
			list[id] = nil
			extensions.listenerCount[event] = extensions.listenerCount[event] - 1
			return true
		end
	end
	return false
end

-- Cheap check so hot paths (every action, every variable write) cost nothing
-- when no other mod is listening.
function extensions.hasListeners(event)
	local count = extensions.listenerCount[event]
	return count ~= nil and count > 0
end

function extensions.emit(event, data)
	if not extensions.hasListeners(event) then return end
	if extensions.emitDepth >= extensions.maxEmitDepth then
		logme(1, "[CyberScript extensions] event '" .. event .. "' skipped: listeners are re-triggering each other too deeply", true)
		return
	end
	extensions.emitDepth = extensions.emitDepth + 1
	for id, callback in pairs(extensions.listeners[event]) do
		local ok, err = pcall(callback, data)
		if not ok then
			logme(1, "[CyberScript extensions] listener " .. tostring(id) .. " for '" .. event .. "' failed: " .. tostring(err), true)
		end
	end
	extensions.emitDepth = extensions.emitDepth - 1
end

---------------------------------------------------------------------------
-- Custom actions and triggers
---------------------------------------------------------------------------

local function register(registry, kind, name, handler, owner)
	if not isNamespaced(name) then
		logme(1, "[CyberScript extensions] custom " .. kind .. " '" .. tostring(name) .. "' rejected: names must contain ':' (for example 'mymod:" .. tostring(name) .. "')", true)
		return false
	end
	if type(handler) ~= "function" then
		logme(1, "[CyberScript extensions] custom " .. kind .. " '" .. name .. "' rejected: handler must be a function", true)
		return false
	end
	if registry[name] ~= nil and registry[name].owner ~= (owner or "unknown") then
		logme(1, "[CyberScript extensions] custom " .. kind .. " '" .. name .. "' was already registered by " .. tostring(registry[name].owner) .. "; replacing it", true)
	end
	registry[name] = { handler = handler, owner = owner or "unknown" }
	return true
end

function extensions.registerAction(name, handler, owner)
	return register(extensions.actions, "action", name, handler, owner)
end

function extensions.registerTrigger(name, handler, owner)
	return register(extensions.triggers, "trigger", name, handler, owner)
end

function extensions.unregisterAction(name)
	local existed = extensions.actions[name] ~= nil
	extensions.actions[name] = nil
	return existed
end

function extensions.unregisterTrigger(name)
	local existed = extensions.triggers[name] ~= nil
	extensions.triggers[name] = nil
	return existed
end

-- Runs a custom action. Returns handled, result.
-- handled is false when no mod registered this name.
-- A handler may return false to stop the rest of the action list (same as built-in
-- actions that return false); anything else counts as success.
function extensions.runAction(action, ctx)
	local entry = extensions.actions[action.name]
	if entry == nil then return false, true end
	local ok, ret = pcall(entry.handler, action, ctx)
	if not ok then
		error("custom action '" .. action.name .. "' from " .. tostring(entry.owner) .. " failed: " .. tostring(ret), 0)
	end
	return true, ret ~= false
end

-- Runs a custom trigger. Returns handled, result (a boolean).
function extensions.runTrigger(trigger)
	local entry = extensions.triggers[trigger.name]
	if entry == nil then return false, false end
	local ok, ret = pcall(entry.handler, trigger)
	if not ok then
		logme(1, "[CyberScript extensions] custom trigger '" .. trigger.name .. "' from " .. tostring(entry.owner) .. " failed: " .. tostring(ret), true)
		return true, false
	end
	return true, ret == true
end

---------------------------------------------------------------------------
-- Datapack content (read only)
---------------------------------------------------------------------------

local function copyOf(value)
	if type(value) ~= "table" then return value end
	if deepcopy ~= nil then return deepcopy(value, nil) end
	local out = {}
	for k, v in pairs(value) do out[k] = copyOf(v) end
	return out
end

function extensions.getContentTypes()
	local types = {}
	for objtype, _ in pairs(cyberscript.cache or {}) do
		table.insert(types, objtype)
	end
	table.sort(types)
	return types
end

-- Lists the items of one content type, for example "webpage", "faction", "corpo", "node".
-- Returns { { tag, datapack }, ... } sorted by tag.
function extensions.listContent(objtype)
	local list = {}
	local bucket = cyberscript.cache and cyberscript.cache[objtype]
	if bucket == nil then return list end
	for tag, entry in pairs(bucket) do
		table.insert(list, { tag = tag, datapack = type(entry) == "table" and entry.datapack or nil })
	end
	table.sort(list, function(a, b) return tostring(a.tag) < tostring(b.tag) end)
	return list
end

-- Returns a copy of one item's data, plus which datapack it came from, or nil.
-- It is a copy so other mods can't change CyberScript's loaded content by accident.
function extensions.getContent(objtype, tag)
	local bucket = cyberscript.cache and cyberscript.cache[objtype]
	if bucket == nil then return nil end
	local entry = bucket[tag]
	if type(entry) ~= "table" then return nil end
	return {
		tag = tag,
		data = copyOf(entry.data),
		datapack = entry.datapack,
		scripttype = entry.scripttype,
	}
end

cyberscriptExtensions = extensions
return extensions
