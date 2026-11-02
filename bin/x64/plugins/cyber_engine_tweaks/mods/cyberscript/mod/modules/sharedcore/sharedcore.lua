--[[
CyberScript shared core

The parts of Night City that several mods share, kept in one place so they
all agree: what one mod does, the others see.

  orgs      corporations, gangs and other organisations, and world regions
  market    the stock exchange: listed companies, prices, V's shares
  news      one news feed every mod (and datapacks) can post to and read
  heat      how much attention V is drawing, per channel ("netwatch", "ncpd", ...)
  standing  V's standing with each organisation, -100 to 100

Everything is saved with the CyberScript save (currentSave.core), so each save
has its own world. Other CET mods reach it through cyberscript.api.core:

    local cs = GetMod("cyberscript")
    local core = cs and cs.api and cs.api.core
    if core then
        core.news.add("Arasaka stock slides", { source = "mymod", org = "arasaka" })
        core.on("heat", function(e) print(e.channel, e.value) end)
    end

Events (core.on(name, fn); also visible to api.on as "core.<name>"):
  "news"      { text, source, org, time }
  "heat"      { channel, value, change, why }
  "standing"  { org, value, change, why }
  "market.shock" { ticker, pct, why }
  "market.trade" { side, ticker, qty, price, tipped }
  "market.step"  { clock }
  "org.registered" { id }

Datapacks get actions, triggers and variables too (see sharedcore/datapack.lua).
]]--

local Core = { version = 2 } -- 2: time, districts, places, routines, incidents, jobs, people bodies and money
local dir = "mod/modules/sharedcore/"

---------------------------------------------------------------------------
-- The host: everything the core needs from CyberScript and the game, so the
-- core itself is plain Lua (and can be tested outside the game).
---------------------------------------------------------------------------

local function defaultHost()
	local host = {}
	function host.state()
		if currentSave == nil then return nil end
		if currentSave.core == nil then currentSave.core = {} end
		return currentSave.core
	end
	function host.emit(event, data)
		if cyberscriptExtensions then cyberscriptExtensions.emit(event, data) end
	end
	function host.on(event, fn)
		if cyberscriptExtensions then return cyberscriptExtensions.on(event, fn) end
	end
	function host.off(id)
		if cyberscriptExtensions then return cyberscriptExtensions.off(id) end
	end
	function host.setVariable(tag, key, value)
		if setVariable then pcall(setVariable, tag, key, value) end
	end
	function host.money()
		local ok, n = pcall(function()
			return Game.GetTransactionSystem():GetItemQuantity(Game.GetPlayer(), MarketSystem.Money())
		end)
		return ok and type(n) == "number" and n or 0
	end
	function host.giveMoney(n)
		return pcall(function() Game.AddToInventory("Items.money", math.floor(n)) end)
	end
	function host.takeMoney(n)
		n = math.floor(n)
		if host.money() < n then return false end
		local ok = pcall(function()
			Game.GetTransactionSystem():RemoveItemByTDBID(Game.GetPlayer(), TweakDBID.new("Items.money"), n)
		end)
		return ok
	end
	function host.paused()
		local ok, paused = pcall(function() return Game.GetSystemRequestsHandler():IsGamePaused() end)
		return ok and paused == true
	end
	function host.log(text)
		if logme then logme(1, "[CyberScript core] " .. tostring(text), true) else print("[CyberScript core] " .. tostring(text)) end
	end
	host.random = math.random
	-- the game's clock in seconds (moves when V sleeps or skips time)
	function host.gameSeconds()
		local ok, t = pcall(function() return Game.GetTimeSystem():GetGameTimeStamp() end)
		return ok and type(t) == "number" and t or nil
	end
	-- CyberScript's own variables, read without side effects (gang district
	-- scores and Affinity live here, shared with Gangs of Night City and others)
	function host.getVariable(tag, key)
		if currentSave == nil or currentSave.Variable == nil or currentSave.Variable[tag] == nil then return nil end
		return currentSave.Variable[tag][key]
	end
	-- CyberScript's own events (not the core's "core." ones)
	function host.onRaw(event, fn)
		if cyberscriptExtensions then return cyberscriptExtensions.on(event, fn) end
	end
	function host.readJson(path)
		local ok, data = pcall(function()
			local f = io.open(path)
			if f == nil then return nil end
			local text = f:read("*a")
			f:close()
			return json.decode(text)
		end)
		return ok and data or nil
	end
	-- is a CyberScript datapack loaded (by its tag)?
	function host.hasDatapack(tag)
		return arrayDatapack ~= nil and arrayDatapack[tag] ~= nil
	end
	-- "alive", "dead", "down" (defeated) or "gone" (despawned) for a spawned NPC
	function host.entityState(entity)
		local ok, state = pcall(function()
			local e = Game.FindEntityByID(entity)
			if e == nil then return "gone" end
			if e:IsDead() then return "dead" end
			if ScriptedPuppet.IsDefeated(e) then return "down" end
			return "alive"
		end)
		return ok and state or "gone"
	end
	return host
end

-- Deterministic random numbers (same results for the same save every load).
local Rng = {}
Rng.__index = Rng
local MOD, MUL = 2147483647, 16807
function Rng.hash(text)
	local h = 5381
	text = tostring(text)
	for i = 1, #text do h = (h * 33 + text:byte(i)) % MOD end
	if h == 0 then h = 1 end
	return h
end
function Rng.new(...)
	local parts = { ... }
	for i = 1, #parts do parts[i] = tostring(parts[i]) end
	local self = setmetatable({ state = Rng.hash(table.concat(parts, "|")) }, Rng)
	for _ = 1, 4 do self:next() end
	return self
end
function Rng:next() self.state = (self.state * MUL) % MOD return (self.state - 1) / (MOD - 1) end
function Rng:int(a, b) return a + math.floor(self:next() * (b - a + 1)) end
function Rng:pick(list) if #list == 0 then return nil end return list[self:int(1, #list)] end
function Rng:chance(p) return self:next() < p end
Core.Rng = Rng

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

-- host: optional, for tests; CyberScript passes nothing and gets the real one.
function Core.init(host, loader)
	Core.host = host or defaultHost()
	local load = loader or function(name) return dofile(dir .. name .. ".lua") end
	Core.orgs = load("orgs")(Core)
	Core.news = load("news")(Core)
	Core.heat, Core.standing = load("standing")(Core)
	Core.market = load("market")(Core)
	Core.time = load("time")(Core)
	Core.districts = load("districts")(Core)
	Core.places = load("places")(Core)
	Core.people = load("people")(Core)
	Core.routines = load("routines")(Core)
	Core.incidents = load("incidents")(Core)
	Core.jobs = load("jobs")(Core)
	Core.datapack = load("datapack")(Core)
	return Core
end

-- This save's core state (nil before a game is loaded).
function Core.state()
	local s = Core.host.state()
	if s == nil then return nil end
	if s.seed == nil then
		s.seed = tostring(os.time()) .. "-" .. tostring(math.floor(Core.host.random() * 1000000))
	end
	return s
end

-- Shared events. Other mods listen with core.on (or api.on("core.<name>")).
local prefix = "core."
function Core.emit(event, data) Core.host.emit(prefix .. event, data) end
function Core.on(event, fn) return Core.host.on(prefix .. event, fn) end
function Core.off(id) return Core.host.off(id) end

-- Called every frame by CyberScript. Nothing moves while the game is paused.
function Core.update(dt)
	if Core.state() == nil or Core.host.paused() then return end
	Core.market.update(dt)
	Core.heat.update(dt)
	Core.districts.hook()
	Core.standing.hook()
	Core.jobs.hook()
	Core.districts.seed()
	Core.time.update(dt)
	Core.people.tick(dt)
end

-- CyberScript's tag for an organisation (Gangs of Night City and other datapacks
-- keep gang scores and Affinity under these): "faction_<id>", with a few exceptions.
local FACTION_TAGS = { traumateam = "faction_trauma" }
function Core.factionTag(org)
	if org == nil then return nil end
	return FACTION_TAGS[org] or ("faction_" .. org)
end
function Core.orgForFactionTag(tag)
	if type(tag) ~= "string" then return nil end
	for org, t in pairs(FACTION_TAGS) do if t == tag then return org end end
	return tag:match("^faction_(.+)$")
end

-- Eddies, for mods that want the same rules (and the same fail-safes) as the core.
Core.money = {
	get = function() return Core.host.money() end,
	give = function(n) return Core.host.giveMoney(n) end,
	take = function(n) return Core.host.takeMoney(n) end,
}

return Core
