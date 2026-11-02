-- Heat and standing: the consequences of what V does, kept where every mod can
-- see them.
--
-- Heat: how much attention V is drawing, 0 to 100, per channel. Any mod can
-- raise a channel and act on it: "netwatch" (Real Netrunning), "ncpd", a
-- corporation's security, anything. A channel can cool down on its own.
--
-- Standing: how an organisation feels about V, -100 (enemy) to 100 (ally).
-- Hire V, buy property from them, hack them, crash their stock: it all lands here.
--
-- Both are mirrored into CyberScript variables so datapacks can read them:
-- tag "core_heat" (key = channel) and tag "core_standing" (key = organisation).

return function(Core)
	local heat = { decay = {}, timer = 0 }
	local standing = {}

	local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

	local function heatState()
		local s = Core.state()
		if s == nil then return nil end
		if s.heat == nil then s.heat = {} end
		return s.heat
	end

	function heat.get(channel)
		local h = heatState()
		return h and h[channel or "netwatch"] or 0
	end

	function heat.set(channel, value, why)
		local h = heatState()
		if h == nil then return 0 end
		channel = channel or "netwatch"
		local before = h[channel] or 0
		local after = clamp(math.floor((tonumber(value) or 0) + 0.5), 0, 100)
		h[channel] = after
		if after ~= before then
			Core.host.setVariable("core_heat", channel, after)
			Core.emit("heat", { channel = channel, value = after, change = after - before, why = why })
		end
		return after
	end

	function heat.add(channel, amount, why)
		return heat.set(channel, heat.get(channel) + (tonumber(amount) or 0), why)
	end

	-- Every channel with any heat: { channel = value }
	function heat.all()
		local out = {}
		for k, v in pairs(heatState() or {}) do out[k] = v end
		return out
	end

	-- A channel loses perMinute heat for every minute of play (0 or nil: never cools).
	function heat.setDecay(channel, perMinute) heat.decay[channel] = perMinute end

	function heat.update(dt)
		heat.timer = heat.timer + dt
		if heat.timer < 60 then return end
		heat.timer = heat.timer - 60
		for channel, per in pairs(heat.decay) do
			if per and per > 0 and heat.get(channel) > 0 then heat.add(channel, -per, "cooling") end
		end
	end

	local function standingState()
		local s = Core.state()
		if s == nil then return nil end
		if s.standing == nil then s.standing = {} end
		return s.standing
	end

	-- Gangs of Night City and other datapacks keep how each faction feels about V
	-- as CyberScript's "Affinity" (key "faction_<org>"). The core reads and writes
	-- the same number, so there is one standing whichever mod changes it.
	local function affinity(org)
		if Core.host.getVariable == nil or Core.factionTag == nil then return nil end
		local v = Core.host.getVariable("Affinity", Core.factionTag(org))
		return type(v) == "number" and v or nil
	end

	function standing.get(org)
		local a = affinity(org)
		if a ~= nil then return clamp(math.floor(a + 0.5), -100, 100) end
		local st = standingState()
		return st and st[org] or 0
	end

	function standing.set(org, value, why)
		local st = standingState()
		if st == nil or org == nil then return 0 end
		local before = standing.get(org)
		local after = clamp(math.floor((tonumber(value) or 0) + 0.5), -100, 100)
		st[org] = after
		if after ~= before then
			standing.writing = true
			if Core.factionTag then Core.host.setVariable("Affinity", Core.factionTag(org), after) end
			standing.writing = false
			Core.host.setVariable("core_standing", org, after)
			Core.emit("standing", { org = org, value = after, change = after - before, why = why })
		end
		return after
	end

	function standing.change(org, amount, why)
		return standing.set(org, standing.get(org) + (tonumber(amount) or 0), why)
	end

	-- Affinity changed by a datapack (a Gangs of Night City choice) is a standing change too.
	local hooked = false
	function standing.hook()
		if hooked or Core.host.onRaw == nil then return end
		hooked = true
		Core.host.onRaw("variable", function(e)
			if type(e) ~= "table" or e.tag ~= "Affinity" or standing.writing then return end
			local org = Core.orgForFactionTag(e.key)
			if org == nil then return end
			local old, new = tonumber(e.old) or 0, tonumber(e.new) or 0
			local st = standingState()
			if st then st[org] = clamp(math.floor(new + 0.5), -100, 100) end
			Core.host.setVariable("core_standing", org, clamp(math.floor(new + 0.5), -100, 100))
			Core.emit("standing", { org = org, value = clamp(math.floor(new + 0.5), -100, 100), change = new - old, why = "cyberscript" })
		end)
	end

	-- Every organisation V has any standing with: { org = value }
	function standing.all()
		local out = {}
		for k, v in pairs(standingState() or {}) do out[k] = v end
		return out
	end

	-- A word for a standing value, for UIs.
	function standing.describe(value)
		value = value or 0
		if value <= -60 then return "Enemy" end
		if value <= -20 then return "Hostile" end
		if value < 20 then return "Neutral" end
		if value < 60 then return "Friendly" end
		return "Ally"
	end

	return heat, standing
end
