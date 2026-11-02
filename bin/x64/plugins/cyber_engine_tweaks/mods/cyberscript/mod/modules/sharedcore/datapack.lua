-- The shared core for CyberScript datapacks: actions, triggers and variables.
--
-- Actions (in an action list):
--   { "name": "core:add_news",        "text": "Arasaka stock slides", "org": "arasaka" }
--   { "name": "core:add_heat",        "channel": "ncpd", "value": 10 }
--   { "name": "core:set_heat",        "channel": "ncpd", "value": 0 }
--   { "name": "core:change_standing", "org": "militech", "value": -15 }
--   { "name": "core:set_standing",    "org": "militech", "value": 50 }
--   { "name": "core:market_shock",    "ticker": "ARA", "value": -0.08 }
--   { "name": "core:give_shares",     "ticker": "MIL", "value": 10 }
--   { "name": "core:person_opinion",  "person": "p:12", "value": -20 }
--   { "name": "core:person_status",   "person": "p:12", "value": "hurt" }
--   { "name": "core:person_remember", "person": "p:12", "kind": "saved", "text": "V pulled them out of a fire", "by": "player" }
--   { "name": "core:person_relate",   "person": "p:12", "other": "p:13", "value": "friend" }
--   { "name": "core:person_affiliate", "person": "p:12", "org": "tygerclaws", "value": "member", "secret": true }
--   { "name": "core:person_leave",    "person": "p:12", "org": "tygerclaws" }
--   { "name": "core:district_push",   "district": "watson", "org": "maelstrom", "value": 10 }
--   { "name": "core:report_incident", "kind": "shooting", "text": "Shots fired outside Lizzie's", "place": "mymod:lizzies",
--                                     "person": "p:12", "role": "hurt", "by": "maelstrom", "severity": 3, "news": true }
--   { "name": "core:hire",            "person": "p:12", "org": "arasaka", "place": "mymod:office", "job": "analyst", "wage": 500 }
--   { "name": "core:fire",            "person": "p:12" }
--   { "name": "core:pay_person",      "person": "p:12", "value": 200 }
--   { "name": "core:place_owner",     "place": "mymod:lizzies", "owner": "mox" }
--
-- Triggers (in requirements; "expected" works as usual):
--   { "name": "core:heat_above",       "channel": "netwatch", "value": 50 }
--   { "name": "core:standing_above",   "org": "arasaka", "value": 20 }
--   { "name": "core:standing_below",   "org": "arasaka", "value": -20 }
--   { "name": "core:share_price_above", "ticker": "ARA", "value": 900 }
--   { "name": "core:owns_shares",      "ticker": "ARA", "value": 1 }
--   { "name": "core:person_opinion_above", "person": "p:12", "value": 30 }
--   { "name": "core:person_opinion_below", "person": "p:12", "value": -30 }
--   { "name": "core:person_status",    "person": "p:12", "value": "alive" }
--   { "name": "core:person_affiliated", "person": "p:12", "org": "tygerclaws" }
--   { "name": "core:person_attitude_above", "person": "p:12", "value": 20 }
--   { "name": "core:time_between",     "from": 22, "to": 6 }
--   { "name": "core:is_night" }
--   { "name": "core:district_leader",  "district": "watson", "org": "maelstrom" }
--   { "name": "core:influence_above",  "district": "watson", "org": "maelstrom", "value": 50 }
--   { "name": "core:place_owner",      "place": "mymod:lizzies", "owner": "mox" }
--   { "name": "core:person_at",        "person": "p:12", "place": "mymod:lizzies" }
--   { "name": "core:person_money_above", "person": "p:12", "value": 1000 }
--
-- Variables (kept in step automatically):
--   tag "core_heat", key = channel          tag "core_standing", key = organisation
--   tag "core_opinion", key = person id (what they think of V)

return function(Core)
	local datapack = {}
	local owner = "CyberScript shared core"

	local function num(v, default) return tonumber(v) or default or 0 end

	datapack.actions = {
		["core:add_news"] = function(a) Core.news.add(a.text or a.value, { source = "datapack", org = a.org }) end,
		["core:add_heat"] = function(a) Core.heat.add(a.channel or "netwatch", num(a.value), a.why or "datapack") end,
		["core:set_heat"] = function(a) Core.heat.set(a.channel or "netwatch", num(a.value), a.why or "datapack") end,
		["core:change_standing"] = function(a) Core.standing.change(a.org, num(a.value), a.why or "datapack") end,
		["core:set_standing"] = function(a) Core.standing.set(a.org, num(a.value), a.why or "datapack") end,
		["core:market_shock"] = function(a) Core.market.shock(tostring(a.ticker or ""):upper(), num(a.value), a.why or "datapack") end,
		["core:person_opinion"] = function(a) Core.people.changeOpinion(a.person, num(a.value), a.why or "datapack") end,
		["core:person_status"] = function(a) Core.people.update(a.person, { status = a.value }, a.why or "datapack") end,
		["core:person_remember"] = function(a) Core.people.remember(a.person, a.kind or "event", a.text or a.value, a.by) end,
		["core:person_relate"] = function(a) Core.people.relate(a.person, a.other, a.value, a.why or "datapack") end,
		["core:person_affiliate"] = function(a)
			Core.people.affiliate(a.person, a.org, a.value, { secret = a.secret }, a.why or "datapack")
		end,
		["core:person_leave"] = function(a) Core.people.leave(a.person, a.org, a.why or "datapack") end,
		["core:district_push"] = function(a) Core.districts.push(a.district, a.org, num(a.value), a.why or "datapack") end,
		["core:report_incident"] = function(a)
			local involved = {}
			if a.person then involved[a.person] = a.role or "involved" end
			Core.incidents.report({ kind = a.kind or "incident", text = a.text, place = a.place, district = a.district,
				by = a.by, severity = num(a.severity, 2), news = a.news == true, people = involved })
		end,
		["core:hire"] = function(a)
			Core.jobs.hire(a.person, { org = a.org, place = a.place, job = a.job, wage = tonumber(a.wage) }, a.why or "datapack")
		end,
		["core:fire"] = function(a) Core.jobs.fire(a.person, a.why or "datapack") end,
		["core:pay_person"] = function(a) Core.people.pay(a.person, num(a.value), a.why or "datapack") end,
		["core:place_owner"] = function(a) Core.places.setOwner(a.place, a.owner, a.why or "datapack") end,
		["core:give_shares"] = function(a)
			local s = Core.market.state()
			local c = Core.market.get(a.ticker)
			if s == nil or c == nil or num(a.value) <= 0 then return end
			local held = s.holdings[c.ticker] or 0
			s.cost[c.ticker] = ((s.cost[c.ticker] or 0) * held) / (held + num(a.value))
			s.holdings[c.ticker] = held + math.floor(num(a.value))
		end,
	}

	datapack.triggers = {
		["core:heat_above"] = function(t) return Core.heat.get(t.channel or "netwatch") > num(t.value) end,
		["core:standing_above"] = function(t) return Core.standing.get(t.org) > num(t.value) end,
		["core:standing_below"] = function(t) return Core.standing.get(t.org) < num(t.value) end,
		["core:share_price_above"] = function(t) return Core.market.price(tostring(t.ticker or ""):upper()) > num(t.value) end,
		["core:owns_shares"] = function(t) return Core.market.held(tostring(t.ticker or ""):upper()) >= num(t.value, 1) end,
		["core:person_opinion_above"] = function(t) return Core.people.opinion(t.person) > num(t.value) end,
		["core:person_opinion_below"] = function(t) return Core.people.opinion(t.person) < num(t.value) end,
		["core:person_affiliated"] = function(t) return Core.people.isAffiliated(t.person, t.org) ~= nil end,
		["core:person_attitude_above"] = function(t) return Core.people.attitude(t.person) > num(t.value) end,
		["core:time_between"] = function(t) return Core.time.between(num(t.from), num(t.to)) end,
		["core:is_night"] = function() return Core.time.isNight() end,
		["core:district_leader"] = function(t) return Core.districts.leader(t.district) == t.org end,
		["core:influence_above"] = function(t) return Core.districts.influence(t.district, t.org) > num(t.value) end,
		["core:place_owner"] = function(t)
			local p = Core.places.get(t.place)
			return p ~= nil and p.owner == t.owner
		end,
		["core:person_at"] = function(t)
			local w = Core.routines.whereIs(t.person)
			return w ~= nil and w.place == t.place
		end,
		["core:person_money_above"] = function(t) return Core.people.money(t.person) > num(t.value) end,
		["core:person_status"] = function(t)
			local p = Core.people.get(t.person)
			return p ~= nil and p.status == (t.value or "alive")
		end,
	}

	-- Called once CyberScript's extension layer is loaded.
	function datapack.register(extensions)
		if extensions == nil then return false end
		for name, fn in pairs(datapack.actions) do extensions.registerAction(name, function(a) fn(a) end, owner) end
		for name, fn in pairs(datapack.triggers) do extensions.registerTrigger(name, fn, owner) end
		return true
	end

	return datapack
end
