-- Districts and who controls their streets.
--
-- The seven districts, their sub-districts and their outlines on the map come
-- from CyberScript's own district data (mod/data/districts.json), so
-- districts.at(pos) knows which district any point is in.
--
-- Street control is each organisation's influence in a district. It is kept in
-- CyberScript's own variables (tag "faction_<org>", key "district_<name>"), the
-- same numbers Gangs of Night City and other datapacks read and change. There
-- is one picture of who runs Night City's streets, whichever mod moves it.
--
--   districts.get(id), districts.all(), districts.byTag(tag)
--   districts.at(pos)                    the district id at { x, y }, or nil
--   districts.influence(id, org)         an organisation's influence there (0 if none)
--   districts.control(id)                { { org, score }, ... } strongest first
--   districts.leader(id)                 org, score of whoever's strongest (nil if nobody)
--   districts.push(id, org, amount, why) raise (or lower) influence
--   districts.set(id, org, value, why)
--
-- Events: "districts.influence" { district, org, value, change, why },
--         "districts.leader" { district, org, old, why } when the strongest changes.

return function(Core)
	local districts = { list = {}, order = {} }

	-- id -> CyberScript's tag and the sub-districts it lists
	local builtin = {
		{ id = "watson", name = "Watson", tag = "district_watson",
			subdistricts = { "ArasakaWaterfront", "Northside", "LittleChina", "Kabuki" } },
		{ id = "westbrook", name = "Westbrook", tag = "district_westbrook", subdistricts = { "CharterHill", "NorthOaks", "JapanTown" } },
		{ id = "citycenter", name = "City Center", tag = "district_downtown", subdistricts = { "CorpoPlaza", "Downtown" } },
		{ id = "heywood", name = "Heywood", tag = "district_heywood", subdistricts = { "Wellsprings", "VistaDelRey", "Glen" } },
		{ id = "santodomingo", name = "Santo Domingo", tag = "district_santodomingo", subdistricts = { "Arroyo", "RanchoCoronado" } },
		{ id = "pacifica", name = "Pacifica", tag = "district_pacifica", subdistricts = { "Coastview", "WestWindEstate" } },
		{ id = "badlands", name = "Badlands", tag = "district_badland", subdistricts = {} },
	}
	for _, d in ipairs(builtin) do
		districts.list[d.id] = d
		table.insert(districts.order, d.id)
	end

	-- outlines from CyberScript's data, when it can be read
	local polygonsLoaded = false
	local function loadPolygons()
		if polygonsLoaded then return end
		polygonsLoaded = true
		local data = Core.host.readJson and Core.host.readJson("mod/data/districts.json")
		for _, entry in ipairs(type(data) == "table" and data or {}) do
			local d = districts.byTag(entry.Tag)
			if d then
				d.polygon = entry.Polygon
				if type(entry.SubDistrict) == "table" and #entry.SubDistrict > 0 then d.subdistricts = entry.SubDistrict end
			end
		end
	end

	function districts.get(id) return districts.list[id] end

	function districts.all()
		local out = {}
		for _, id in ipairs(districts.order) do table.insert(out, districts.list[id]) end
		return out
	end

	function districts.byTag(tag)
		for _, d in pairs(districts.list) do if d.tag == tag then return d end end
		return nil
	end

	-- Adds a district (a mod's own area). def: { id, name, tag?, polygon? = { { x, y }, ... } }
	function districts.register(def)
		if type(def) ~= "table" or type(def.id) ~= "string" then return false end
		if districts.list[def.id] == nil then table.insert(districts.order, def.id) end
		def.tag = def.tag or ("district_" .. def.id)
		def.subdistricts = def.subdistricts or {}
		districts.list[def.id] = def
		return true
	end

	local function inside(poly, x, y)
		local hit, j = false, #poly
		for i = 1, #poly do
			local a, b = poly[i], poly[j]
			if ((a.y > y) ~= (b.y > y)) and (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) then hit = not hit end
			j = i
		end
		return hit
	end

	-- Which district a point is in ({ x, y } or { x = , y = }), or nil.
	function districts.at(pos)
		if type(pos) ~= "table" then return nil end
		loadPolygons()
		local x, y = pos.x or pos[1], pos.y or pos[2]
		if x == nil or y == nil then return nil end
		for _, id in ipairs(districts.order) do
			local d = districts.list[id]
			if d.polygon and #d.polygon >= 3 and inside(d.polygon, x, y) then return id end
		end
		return nil
	end

	---------------------------------------------------------------------------
	-- Street control (CyberScript variables, shared with other datapacks)
	---------------------------------------------------------------------------

	local function readScore(d, org)
		local v = Core.host.getVariable and Core.host.getVariable(Core.factionTag(org), d.tag)
		if type(v) == "number" then return v end
		-- without CyberScript (tests), the core keeps its own copy
		local s = Core.state()
		local own = s and s.districts and s.districts[d.id]
		return own and own[org] or 0
	end

	local writing = false
	local function writeScore(d, org, value)
		local s = Core.state()
		if s then
			s.districts = s.districts or {}
			s.districts[d.id] = s.districts[d.id] or {}
			s.districts[d.id][org] = value
		end
		writing = true
		Core.host.setVariable(Core.factionTag(org), d.tag, value)
		writing = false
	end

	-- Everyone who might hold a district: gangs, corporations, the city's forces,
	-- and any other organisation that already has influence somewhere.
	local function contenders(d)
		local list, seen = {}, {}
		for _, kind in ipairs({ "gang", "corp", "city" }) do
			for _, o in ipairs(Core.orgs.all(kind)) do
				if not seen[o.id] then seen[o.id] = true table.insert(list, o.id) end
			end
		end
		local s = Core.state()
		for org in pairs(s and s.districts and s.districts[d.id] or {}) do
			if not seen[org] then seen[org] = true table.insert(list, org) end
		end
		return list
	end

	function districts.influence(id, org)
		local d = districts.list[id]
		if d == nil or org == nil then return 0 end
		return readScore(d, org)
	end

	function districts.control(id)
		local d = districts.list[id]
		if d == nil then return {} end
		local out = {}
		for _, org in ipairs(contenders(d)) do
			local score = readScore(d, org)
			if score > 0 then table.insert(out, { org = org, score = score }) end
		end
		table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.org < b.org end)
		return out
	end

	function districts.leader(id)
		local top = districts.control(id)[1]
		if top == nil then return nil, 0 end
		return top.org, top.score
	end

	function districts.set(id, org, value, why)
		local d = districts.list[id]
		if d == nil or org == nil then return 0 end
		local before = readScore(d, org)
		local oldLeader = districts.leader(id)
		local after = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
		writeScore(d, org, after)
		if after ~= before then
			Core.emit("districts.influence", { district = id, org = org, value = after, change = after - before, why = why })
			local newLeader = districts.leader(id)
			if newLeader ~= oldLeader then
				Core.emit("districts.leader", { district = id, org = newLeader, old = oldLeader, why = why })
			end
		end
		return after
	end

	function districts.push(id, org, amount, why)
		return districts.set(id, org, districts.influence(id, org) + (tonumber(amount) or 0), why)
	end

	-- A save where nobody holds a district yet (no gang mod has set it up) gets
	-- the district's gangs a starting share, once (districts with any influence
	-- already are left as they are).
	-- Gangs of Night City sets up its own turf, so the core leaves it alone then.
	districts.seedUnless = { "Gangs of Night City" }
	function districts.seed()
		local s = Core.state()
		if s == nil or s.districtsSeeded then return end
		s.districtsSeeded = true
		for _, tag in ipairs(districts.seedUnless) do
			if Core.host.hasDatapack and Core.host.hasDatapack(tag) then return end
		end
		local gangsBy = Core.people and Core.people.districtGangs or {}
		for _, id in ipairs(districts.order) do
			if #districts.control(id) == 0 then
				local rng = Core.Rng.new(s.seed or "0", "district", id)
				for _, org in ipairs(gangsBy[id] or {}) do
					local d = districts.list[id]
					writeScore(d, org, rng:int(10, 40))
				end
			end
		end
	end

	-- Changes other mods make to CyberScript's district scores (Gangs of Night City's
	-- turf wars) become the core's events too.
	local hooked = false
	function districts.hook()
		if hooked or Core.host.onRaw == nil then return end
		hooked = true
		Core.host.onRaw("variable", function(e)
			if type(e) ~= "table" or writing then return end
			local d = districts.byTag(e.key)
			local org = d and Core.orgForFactionTag(e.tag)
			if d == nil or org == nil then return end
			local old, new = tonumber(e.old) or 0, tonumber(e.new) or 0
			Core.emit("districts.influence", { district = d.id, org = org, value = new, change = new - old, why = "cyberscript" })
		end)
	end

	return districts
end
