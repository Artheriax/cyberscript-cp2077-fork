-- Places: the locations of Night City every mod can point at.
--
-- A place: { id, name, kind, district, subdistrict, pos = { x, y, z }, owner,
--   org, open = { from, to }, capacity, tags = { ... } }
--   kind: "bar", "club", "clinic", "shop", "restaurant", "apartment", "office",
--         "garage", "hideout", "street", ... (any word a mod uses)
--   owner: who owns it: an organisation id, a person id, or "player" for V
--   org: who runs it day to day (often the owner)
--   open: opening hours (game hours; 22..6 wraps past midnight); none = always open
--
-- Two ways in:
--   places.register(def)  places a mod knows about (the Afterlife, its own
--                         businesses). Register again on every load, like
--                         organisations. What changes about them is saved.
--   places.add(def)       a place made during play (V's new safehouse, a club
--                         that just opened). Saved whole, nothing to register.
--
--   places.get(id), places.find(query), places.near(pos, radius, query)
--   places.update(id, fields, why), places.setOwner(id, owner, why), places.remove(id, why)
--   places.isOpen(id, hour?), places.ownedBy(owner)
--
-- Events: "places.added" { id }, "places.changed" { id, changed, why },
--         "places.owner" { id, owner, old, why }, "places.removed" { id, why }

return function(Core)
	local places = { registered = {}, order = {} }

	local function copy(t)
		if type(t) ~= "table" then return t end
		local out = {}
		for k, v in pairs(t) do out[k] = copy(v) end
		return out
	end

	local function state()
		local s = Core.state()
		if s == nil then return nil end
		s.places = s.places or {}
		local p = s.places
		p.changes = p.changes or {} -- id -> changed fields of a registered place
		p.made = p.made or {}       -- id -> a place added during play
		p.removed = p.removed or {} -- id -> true (closed down, demolished)
		return p
	end

	local function fill(def)
		if def.district == nil and def.pos then def.district = Core.districts.at(def.pos) end
		def.tags = def.tags or {}
		return def
	end

	function places.register(def)
		if type(def) ~= "table" or type(def.id) ~= "string" then return nil end
		local p = fill(copy(def))
		p.source = p.source or "registered"
		if places.registered[p.id] == nil then table.insert(places.order, p.id) end
		places.registered[p.id] = p
		Core.emit("places.added", { id = p.id })
		return p.id
	end

	function places.add(def)
		local st = state()
		if st == nil or type(def) ~= "table" or type(def.id) ~= "string" then return nil end
		local p = fill(copy(def))
		p.source = p.source or "added"
		st.made[p.id] = p
		st.removed[p.id] = nil
		Core.emit("places.added", { id = p.id })
		return p.id
	end

	function places.get(id)
		local st = state()
		if st and st.removed[id] then return nil end
		local base = places.registered[id] or (st and st.made[id])
		if base == nil then return nil end
		local p = copy(base)
		for k, v in pairs(st and st.changes[id] or {}) do p[k] = copy(v) end
		return p
	end

	local function allIds()
		local st = state()
		local ids, seen = {}, {}
		for _, id in ipairs(places.order) do if not seen[id] then seen[id] = true table.insert(ids, id) end end
		local made = {}
		for id in pairs(st and st.made or {}) do if not seen[id] then table.insert(made, id) end end
		table.sort(made)
		for _, id in ipairs(made) do table.insert(ids, id) end
		return ids
	end

	function places.isOpen(id, hour)
		local p = type(id) == "table" and id or places.get(id)
		if p == nil then return false end
		if p.open == nil then return true end
		return Core.time.between(p.open.from or p.open[1], p.open.to or p.open[2], hour)
	end

	-- Places matching every field given. Special keys: tag = one of its tags,
	-- open = true (open right now), kinds = { "bar", "club" } (any of these).
	function places.find(query)
		local out = {}
		query = query or {}
		for _, id in ipairs(allIds()) do
			local p = places.get(id)
			local ok = p ~= nil
			for k, v in pairs(query) do
				if not ok then break end
				if k == "tag" then
					local has = false
					for _, t in ipairs(p.tags or {}) do if t == v then has = true end end
					ok = has
				elseif k == "open" then
					ok = places.isOpen(p) == (v == true)
				elseif k == "kinds" then
					local has = false
					for _, kind in ipairs(v) do if p.kind == kind then has = true end end
					ok = has
				elseif p[k] ~= v then ok = false end
			end
			if ok then table.insert(out, p) end
		end
		return out
	end

	-- Places within `radius` metres of pos (that match query), nearest first.
	function places.near(pos, radius, query)
		local out = {}
		if type(pos) ~= "table" then return out end
		local x, y, z = pos.x or pos[1] or 0, pos.y or pos[2] or 0, pos.z or pos[3] or 0
		for _, p in ipairs(places.find(query)) do
			if p.pos then
				local dx, dy, dz = (p.pos.x or p.pos[1] or 0) - x, (p.pos.y or p.pos[2] or 0) - y, (p.pos.z or p.pos[3] or 0) - z
				local d = math.sqrt(dx * dx + dy * dy + dz * dz)
				if d <= (radius or 50) then p.distance = d table.insert(out, p) end
			end
		end
		table.sort(out, function(a, b) return a.distance < b.distance end)
		return out
	end

	function places.update(id, fields, why)
		local st = state()
		local before = places.get(id)
		if st == nil or before == nil or type(fields) ~= "table" then return false end
		if st.made[id] then
			for k, v in pairs(fields) do st.made[id][k] = copy(v) end
		else
			st.changes[id] = st.changes[id] or {}
			for k, v in pairs(fields) do st.changes[id][k] = copy(v) end
		end
		local changed = {}
		for k, v in pairs(fields) do changed[k] = { old = before[k], new = v } end
		Core.emit("places.changed", { id = id, changed = changed, why = why })
		return true
	end

	function places.setOwner(id, owner, why)
		local before = places.get(id)
		if before == nil then return false end
		places.update(id, { owner = owner }, why)
		Core.emit("places.owner", { id = id, owner = owner, old = before.owner, why = why })
		return true
	end

	-- Closed down, burned out, demolished: gone from every search.
	function places.remove(id, why)
		local st = state()
		if st == nil or places.get(id) == nil then return false end
		st.removed[id] = true
		Core.emit("places.removed", { id = id, why = why })
		return true
	end

	function places.ownedBy(owner) return places.find({ owner = owner }) end

	return places
end
