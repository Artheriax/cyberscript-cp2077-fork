-- Organisations and regions: one list of who's who in Night City and beyond.
--
-- Each organisation: { id, name, kind, region, about, ticker }
--   kind:   "corp", "gang", "city", "media", "device", "civilian", or anything a mod adds
--   region: where it's based (see regions); ticker: its stock, if it's listed
-- Mods add their own (V's corporation, say) with orgs.register; those last for
-- the session, so register them again on every load.

return function(Core)
	local orgs = { list = {}, order = {} }

	local builtin = {
		{ id = "arasaka",     name = "Arasaka",                   kind = "corp",  region = "pacific", ticker = "ARA" },
		{ id = "militech",    name = "Militech",                  kind = "corp",  region = "nusa",    ticker = "MIL" },
		{ id = "kangtao",     name = "Kang Tao",                  kind = "corp",  region = "pacific", ticker = "KTC" },
		{ id = "traumateam",  name = "Trauma Team International", kind = "corp",  region = "nc",      ticker = "TTI" },
		{ id = "biotechnica", name = "Biotechnica",               kind = "corp",  region = "eu",      ticker = "BTC" },
		{ id = "petrochem",   name = "Petrochem",                 kind = "corp",  region = "nusa",    ticker = "PTC" },
		{ id = "sovoil",      name = "SovOil",                    kind = "corp",  region = "eu",      ticker = "SOV" },
		{ id = "orbitalair",  name = "Orbital Air",               kind = "corp",  region = "orbit",   ticker = "ORB" },
		{ id = "kiroshi",     name = "Kiroshi Opticals",          kind = "corp",  region = "pacific", ticker = "KIR" },
		{ id = "zetatech",    name = "Zetatech",                  kind = "corp",  region = "nusa",    ticker = "ZTC" },
		{ id = "delamain",    name = "Delamain",                  kind = "corp",  region = "nc",      ticker = "DLM" },
		{ id = "esa",         name = "European Space Agency",     kind = "corp",  region = "orbit", ticker = "ESA" },
		{ id = "rocklin", name = "Rocklin Augmentics", kind = "corp", region = "nc", ticker = "RKA" },
		{ id = "dynalar", name = "Dynalar Technologies", kind = "corp", region = "nusa", ticker = "DYN" },
		{ id = "zhirafa", name = "Zhirafa Technical Manufacturing", kind = "corp", region = "eu", ticker = "ZHI" },
		{ id = "segatari", name = "Segatari", kind = "corp", region = "pacific", ticker = "SGT" },
		{ id = "midnightarms", name = "Midnight Arms", kind = "corp", region = "nusa", ticker = "MDA" },
		{ id = "constitutionalarms", name = "Constitutional Arms", kind = "corp", region = "nusa", ticker = "CNA" },
		{ id = "budgetarms", name = "Budget Arms", kind = "corp", region = "nc", ticker = "BGA" },
		{ id = "darra", name = "Darra Polytechnic", kind = "corp", region = "pacific", ticker = "DPT" },
		{ id = "tsunami", name = "Tsunami Defense Systems", kind = "corp", region = "pacific", ticker = "TSU" },
		{ id = "network54",   name = "Network 54",                kind = "media", region = "nc",      ticker = "N54" },
		{ id = "wns",         name = "World News Service",        kind = "media", region = "nusa",    ticker = "WNS" },
		{ id = "ncpd",        name = "NCPD",                      kind = "city",  region = "nc", ticker = "NCPD" },
		{ id = "netwatch",    name = "NetWatch",                  kind = "city",  region = "nc", ticker = "NWT" },
		{ id = "maelstrom",   name = "Maelstrom",                 kind = "gang",  region = "nc" },
		{ id = "tygerclaws",  name = "Tyger Claws",               kind = "gang",  region = "nc" },
		{ id = "valentinos",  name = "Valentinos",                kind = "gang",  region = "nc" },
		{ id = "sixthstreet", name = "6th Street",                kind = "gang",  region = "nc" },
		{ id = "mox",         name = "Mox",                       kind = "gang",  region = "nc" },
		{ id = "animals",     name = "Animals",                   kind = "gang",  region = "nc" },
		{ id = "voodooboys",  name = "Voodoo Boys",               kind = "gang",  region = "nc" },
		{ id = "scavengers",  name = "Scavengers",                kind = "gang",  region = "nc" },
		{ id = "wraiths",     name = "Wraiths",                   kind = "gang",  region = "nc" },
		{ id = "aldecaldos",  name = "Aldecaldos",                kind = "gang",  region = "nc" },
		{ id = "barghest",    name = "Barghest",                  kind = "gang",  region = "nc" },
		{ id = "unregistered", name = "Unregistered",             kind = "device", region = "nc" },
		{ id = "civilian",    name = "Independent",               kind = "civilian", region = "nc" },
	}

	orgs.regions = {
		nc      = { name = "Night City" },
		nusa    = { name = "New United States" },
		pacific = { name = "Pacific Rim" },
		eu      = { name = "EuroTheater" },
		orbit   = { name = "Orbit" },
	}
	orgs.regionOrder = { "nc", "nusa", "pacific", "eu", "orbit" }

	-- def: { id, name, kind, region?, about?, ticker? } plus any fields a mod wants.
	-- Registering an existing id adds to it (fields given replace fields there).
	function orgs.register(def)
		if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then return nil end
		local org = orgs.list[def.id]
		if org == nil then
			org = { id = def.id }
			orgs.list[def.id] = org
			table.insert(orgs.order, def.id)
		end
		for k, v in pairs(def) do org[k] = v end
		org.name = org.name or def.id
		org.kind = org.kind or "corp"
		org.region = org.region or "nc"
		Core.emit("org.registered", { id = def.id })
		return org
	end

	function orgs.get(id) return orgs.list[id] end

	-- Every organisation (optionally only one kind), in the order they were added.
	function orgs.all(kind)
		local out = {}
		for _, id in ipairs(orgs.order) do
			local org = orgs.list[id]
			if kind == nil or org.kind == kind then table.insert(out, org) end
		end
		return out
	end

	function orgs.region(id) return orgs.regions[id] end

	-- def: { id, name }
	function orgs.registerRegion(id, def)
		if orgs.regions[id] == nil then table.insert(orgs.regionOrder, id) end
		orgs.regions[id] = def
	end

	for _, def in ipairs(builtin) do orgs.register(def) end
	return orgs
end
