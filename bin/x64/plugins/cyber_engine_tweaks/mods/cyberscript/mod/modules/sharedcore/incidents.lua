-- Incidents: what happens in Night City, with who, where and who did it.
--
--   incidents.report(def) -> id
--   def: { kind, text?, place?, district?, pos?, by?, severity = 1-5, news?,
--          people = { [personId] = role, ... } }
--     kind: "shooting", "robbery", "raid", "fire", "death", "rescue", "hack", ... (any word)
--     by: who did it: an organisation id, a person id, or "player" for V
--     roles: "victim", "killed", "hurt", "saved", "culprit", "witness", "involved" (or your own)
--     news: true to put `text` in the news feed (severity 4 and up always does)
--
-- What it does for you, so every mod's incidents have the same consequences:
--   * everyone involved remembers it (their history)
--   * "killed" people are marked dead, "hurt" people hurt
--   * if V did it: victims (and the people close to them) think less of V;
--     people V saved (and theirs) think more; the organisations victims openly
--     belong to take it badly too
--   * an organisation that did it gains a little street influence in the district
--
--   incidents.get(id), incidents.recent(n), incidents.find(query)
--   query keys: kind, district, place, by, person (anyone involved)
--
-- Event: "incidents.reported" (the whole incident). The latest 100 are kept.

return function(Core)
	local incidents = { keep = 100 }
	local CLOSE = { partner = true, spouse = true, sibling = true, parent = true, child = true, friend = true, crew = true }
	local HARMED = { victim = true, killed = true, hurt = true }

	local function list()
		local s = Core.state()
		if s == nil then return nil end
		s.incidents = s.incidents or { items = {}, nextId = 1 }
		return s.incidents
	end

	function incidents.report(def)
		local st = list()
		if st == nil or type(def) ~= "table" or def.kind == nil then return nil end
		local now = Core.time.now()
		local severity = math.max(1, math.min(5, math.floor(tonumber(def.severity) or 2)))
		local place = def.place and Core.places.get(def.place)
		local item = {
			id = st.nextId, kind = def.kind, text = def.text, place = def.place, pos = def.pos, by = def.by,
			severity = severity, day = now.day, hour = now.hour,
			district = def.district or (place and place.district) or (def.pos and Core.districts.at(def.pos)),
			people = {},
		}
		st.nextId = st.nextId + 1
		for id, role in pairs(def.people or {}) do item.people[id] = role end
		table.insert(st.items, item)
		while #st.items > incidents.keep do table.remove(st.items, 1) end

		local P = Core.people
		local text = def.text or def.kind
		for id, role in pairs(item.people) do
			if P.get(id) then
				P.remember(id, def.kind, text, def.by)
				if role == "killed" then P.update(id, { status = "dead" }, def.kind)
				elseif role == "hurt" then
					local p = P.get(id)
					if p and p.status == "alive" then P.update(id, { status = "hurt" }, def.kind) end
				end
				-- V's part in it
				if def.by == "player" and (HARMED[role] or role == "saved") then
					local sign = role == "saved" and 1 or -1
					P.changeOpinion(id, sign * 5 * severity, def.kind)
					for other, kind in pairs(P.relations(id)) do
						if CLOSE[kind] and P.get(other) then
							P.remember(other, "heard", "Heard what happened to " .. P.get(id).name .. ": " .. text, def.by)
							P.changeOpinion(other, sign * 3 * severity, def.kind)
						end
					end
					if sign < 0 then
						for _, a in ipairs(P.affiliations(id)) do
							if not a.secret then Core.standing.change(a.org, -severity, def.kind) end
						end
					end
				end
			end
		end

		if def.news or severity >= 4 then
			Core.news.add(text, { source = "incident", org = Core.orgs.get(def.by or "") and def.by or nil })
		end
		if item.district and def.by and Core.orgs.get(def.by) then
			Core.districts.push(item.district, def.by, severity, def.kind)
		end
		Core.emit("incidents.reported", item)
		return item.id
	end

	function incidents.get(id)
		for _, item in ipairs((list() or { items = {} }).items) do if item.id == id then return item end end
		return nil
	end

	-- The latest n incidents, oldest first.
	function incidents.recent(n)
		local items = (list() or { items = {} }).items
		local out = {}
		for i = math.max(1, #items - (n or #items) + 1), #items do table.insert(out, items[i]) end
		return out
	end

	function incidents.find(query)
		local out = {}
		for _, item in ipairs(incidents.recent()) do
			local ok = true
			for k, v in pairs(query or {}) do
				if k == "person" then ok = ok and item.people[v] ~= nil
				elseif item[k] ~= v then ok = false end
			end
			if ok then table.insert(out, item) end
		end
		return out
	end

	return incidents
end
