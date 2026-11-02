-- People: one registry of who lives in Night City, shared by every mod.
--
-- A person gets into the registry three ways:
--   generated  people.populate(place, opts) makes the people of a place (a
--              workplace, a building, a gang's crew) from the save's seed: the
--              same save always gets the same people, a new save new ones.
--   hand-made  people.register(def): characters a mod writes on purpose.
--   promoted   people.promote(def): someone another mod already half-knows
--              (a network user, a bank account's owner, a boss) becomes a full
--              person the first time they matter. Same key, same person.
--
-- Only what has CHANGED is saved (generated people can always be rebuilt from
-- the seed), so saves stay small however many people there are.
--
-- A person: { id, name, first, last, gender, pronoun, look = { record, appearance },
--   age, home, place, job, org, district, traits = { ... }, status, source }
--   affiliations = { { org, role, secret }, ... }: the gangs, corporations and
--   other organisations they belong to (none at all for many people).
--   org is where they work; an affiliation is who they're with. A noodle cook
--   can be a Tyger Claw, an Arasaka clerk can secretly run for the Mox.
--   status: "alive" (default), "hurt", "missing", "dead", or anything a mod uses
--
-- Each person also has relationships with other people, a history of what
-- happened to them, and an opinion of V (-100 to 100).
--
-- The game's own story characters are not people here: their lives are written
-- by the game's quests. Mods can still name them in relationships or text.

return function(Core)
	local people = { list = {}, order = {}, populated = {}, registered = {} }
	local Rng = Core.Rng

	---------------------------------------------------------------------------
	-- Word lists (Night City is everyone)
	---------------------------------------------------------------------------

	local firstNames = {
		male = { "Aaron", "Akio", "Andrés", "Bao", "Carlos", "Dante", "Dmitri", "Emeka", "Felix", "Gus", "Hiro",
			"Ilya", "Jamal", "Javier", "Jun", "Kenji", "Kofi", "Lars", "Luis", "Marcus", "Mateo", "Nikolai", "Omar",
			"Pavel", "Quinn", "Rafael", "Ravi", "Rico", "Samir", "Tomas", "Tyrone", "Victor", "Wei", "Yusuf", "Zed" },
		female = { "Aiko", "Ana", "Bianca", "Chiara", "Dalia", "Esme", "Faye", "Gloria", "Hana", "Imani", "Ines",
			"Jade", "Kat", "Keiko", "Lena", "Lupe", "Marisol", "Mei", "Nadia", "Nia", "Oksana", "Priya", "Rosa",
			"Sakura", "Sofia", "Tamsin", "Uma", "Valentina", "Wen", "Yara", "Yuki", "Zainab", "Zoe" },
		other = { "Ash", "Blue", "Cass", "Echo", "Jules", "Kai", "Lux", "Nico", "Remy", "River", "Rook", "Sage", "Sky" },
	}
	local surnames = { "Alvarez", "Ahmed", "Brandt", "Castillo", "Cho", "Doyle", "Dubois", "Estrada", "Fujita",
		"Garza", "Gupta", "Hayes", "Herrera", "Ito", "Ivanova", "Jensen", "Kim", "Kowal", "Lima", "Lin", "Mbeki",
		"Morales", "Nakamura", "Novak", "Okafor", "Okoye", "Petrov", "Reyes", "Rossi", "Sato", "Silva", "Singh",
		"Tanaka", "Tran", "Vance", "Volkov", "Wu", "Yilmaz", "Zhou" }

	-- The game's crowd characters to look like, by way of life. A spawned crowd
	-- character picks a random appearance; whoever spawns a person first should
	-- save the one it got (people.update(id, { look = ... })) so they look the same after.
	people.looks = {
		corpo     = { male = { "Character.CorpoMan", "Character.CorpoManAfterWork", "Character.CorpoManCoffee" },
		              female = { "Character.CorpoWoman", "Character.CorpoWomanAfterWork", "Character.CorpoWomanBag" },
		              other = { "Character.NonBinaryMaleBodyCorpo", "Character.NonBinaryFemaleBodyCorpo" } },
		worker    = { male = { "Character.WorkerMale", "Character.WorkerSpecialistMale", "Character.TenantMale" },
		              female = { "Character.TenantWoman", "Character.WomanChubbyTenant" },
		              other = { "Character.NonBinaryMaleBody", "Character.NonBinaryFemaleBody" } },
		vendor    = { male = { "Character.VendorMale", "Character.AsianVendorMale", "Character.CreoleVendorMale" },
		              female = { "Character.VendorFemale", "Character.AsianVendorFemale", "Character.CreoleVendorFemale" },
		              other = { "Character.NonBinaryMaleBody", "Character.NonBinaryFemaleBody" } },
		nightlife = { male = { "Character.NightlifeMale", "Character.ObeseMaleNightlife" },
		              female = { "Character.NightlifeWoman" },
		              other = { "Character.NonBinaryMaleBodyNightlife", "Character.NonBinaryFemaleBodyNightlife" } },
		young     = { male = { "Character.YoungsterMale", "Character.YoungsterMaleBig" },
		              female = { "Character.YoungsterFemale", "Character.WomanChubbyYoungster" },
		              other = { "Character.NonBinaryMaleBodyYoungster", "Character.NonBinaryFemaleBodyYoungster" } },
		rich      = { male = { "Character.CitizenRichMale", "Character.CitizenRichMaleCasual" },
		              female = { "Character.CitizenRichFemale", "Character.CitizenRichFemaleCasual" },
		              other = { "Character.NonBinaryMaleBodyPosh", "Character.NonBinaryFemaleBodyPosh" } },
		street    = { male = { "Character.CitizenBikerMale", "Character.JunkieMale", "Character.HomelessMan" },
		              female = { "Character.CitizenBikerFemale", "Character.JunkieFemale", "Character.HomelessFemale" },
		              other = { "Character.NonBinaryMaleBody", "Character.NonBinaryFemaleBody" } },
		medical   = { male = { "Character.WorkerSpecialistMale" }, female = { "Character.NurseFemale" },
		              other = { "Character.NonBinaryFemaleBody" } },
		nomad     = { male = { "Character.CitizenAldecaldosMale", "Character.CitizenAldecaldosMaleMechanic" },
		              female = { "Character.CitizenAldecaldosFemale", "Character.CitizenAldecaldosFemaleNomad" },
		              other = { "Character.CitizenAldecaldosFemale" } },
	}

	-- Personality: each person gets a couple of these.
	people.traitList = { "loyal", "greedy", "brave", "cowardly", "kind", "cruel", "honest", "liar", "ambitious",
		"lazy", "curious", "paranoid", "hot-headed", "calm", "romantic", "cynical", "religious", "chromed-out",
		"addict", "gambler", "family-first", "loner", "gossip", "vengeful", "forgiving" }

	-- Relationship kinds. Two-way ones are kept on both people.
	people.relationKinds = {
		partner = true, spouse = true, sibling = true, friend = true, rival = true, enemy = true, coworker = true,
		roommate = true, crew = true, ex = true,
		parent = "child", child = "parent", boss = "employee", employee = "boss",
	}

	-- What a day's work pays, and what they usually have put by, by way of life (eddies).
	people.wages = {
		corpo = { 400, 900 }, rich = { 0, 0 }, worker = { 120, 250 }, vendor = { 100, 220 },
		nightlife = { 100, 300 }, young = { 30, 120 }, street = { 0, 80 }, medical = { 200, 400 }, nomad = { 60, 150 },
	}
	people.savings = {
		corpo = { 3000, 20000 }, rich = { 20000, 90000 }, worker = { 200, 3000 }, vendor = { 300, 4000 },
		nightlife = { 100, 3000 }, young = { 0, 800 }, street = { 0, 300 }, medical = { 1000, 8000 }, nomad = { 100, 2000 },
	}
	-- What a day of living costs them (rent, food, chrome upkeep).
	people.livingCost = {
		corpo = 250, rich = 600, worker = 90, vendor = 80, nightlife = 90, young = 40, street = 20, medical = 150, nomad = 50,
	}

	local function moneyFor(rng, lifestyle)
		local w = people.wages[lifestyle] or people.wages.worker
		local sv = people.savings[lifestyle] or people.savings.worker
		return rng:int(w[1], w[2]), rng:int(sv[1], sv[2])
	end

	-- Which gangs run each district's streets, for generated people's ties.
	people.districtGangs = {
		watson = { "maelstrom", "tygerclaws", "scavengers", "mox" },
		westbrook = { "tygerclaws", "mox" },
		heywood = { "valentinos", "sixthstreet" },
		santodomingo = { "sixthstreet", "valentinos", "maelstrom" },
		pacifica = { "voodooboys", "animals", "barghest" },
		citycenter = { "tygerclaws", "valentinos" },
		badlands = { "wraiths", "aldecaldos" },
	}

	-- Kinds of organisation whose staff count as affiliated with it.
	local AFFILIATING = { corp = true, gang = true, media = true, city = true }
	local function roleFor(orgId)
		local o = Core.orgs.get(orgId)
		if o == nil then return nil end
		if o.kind == "gang" then return "member" end
		if AFFILIATING[o.kind] then return "employee" end
		return nil
	end

	---------------------------------------------------------------------------
	-- Saved state: only what changed
	---------------------------------------------------------------------------

	local rebuild -- below: makes the known people again for a newly loaded save

	local function state()
		local s = Core.state()
		if s == nil then return nil end
		s.people = s.people or {}
		local p = s.people
		if people.boundTo ~= p then
			people.boundTo = p
			rebuild(p)
		end
		p.changes = p.changes or {}     -- id -> fields changed on a generated or hand-made person
		p.made = p.made or {}           -- id -> a promoted person, whole (nothing to rebuild them from)
		p.keys = p.keys or {}           -- promotion key -> id
		p.places = p.places or {}       -- place -> opts it was populated with (to rebuild after a load)
		p.relations = p.relations or {} -- id -> { otherId -> kind } changed or added
		p.history = p.history or {}     -- id -> { { time, kind, text, by } }
		p.opinion = p.opinion or {}     -- id -> opinion of V
		p.nextId = p.nextId or 1
		return p
	end

	local function copy(t)
		if type(t) ~= "table" then return t end
		local out = {}
		for k, v in pairs(t) do out[k] = copy(v) end
		return out
	end

	local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

	local function now()
		local s = Core.state()
		return s and s.market and s.market.clock or 0
	end

	---------------------------------------------------------------------------
	-- Generation
	---------------------------------------------------------------------------

	local function seed() local s = Core.state() return s and s.seed or "0" end

	local function pickGender(rng)
		local r = rng:next()
		if r < 0.47 then return "male", "he" elseif r < 0.94 then return "female", "she" end
		return "other", "they"
	end

	-- One generated person: the same for the same seed, place and number.
	local function generate(place, n, opts)
		local rng = Rng.new(seed(), "person", place, n)
		local gender, pronoun = pickGender(rng)
		local first, last = rng:pick(firstNames[gender]), rng:pick(surnames)
		local lifestyle = opts.lifestyle or "worker"
		local looks = people.looks[lifestyle] or people.looks.worker
		local traits = {}
		while #traits < 2 do
			local t = rng:pick(people.traitList)
			if traits[1] ~= t then table.insert(traits, t) end
		end
		local jobs = opts.jobs or { opts.job or "staff" }
		local wage, money = moneyFor(Rng.new(seed(), "money", place, n), lifestyle)
		-- who they're with: the place's own organisation, a street gang, or nobody
		local arng = Rng.new(seed(), "affiliation", place, n)
		local affiliations = {}
		if opts.affiliation then
			table.insert(affiliations, { org = opts.affiliation, role = opts.role or roleFor(opts.affiliation) or "member" })
		elseif opts.org and roleFor(opts.org) then
			table.insert(affiliations, { org = opts.org, role = roleFor(opts.org) })
		end
		local gangs = people.districtGangs[opts.district or ""] or {}
		local gangChance = opts.gangChance or (#affiliations == 0 and 0.2 or 0.05)
		if #gangs > 0 and arng:chance(gangChance) then
			local g = arng:pick(gangs)
			local already = false
			for _, a in ipairs(affiliations) do if a.org == g then already = true end end
			if not already then
				-- a gang tie on the side is often kept quiet
				table.insert(affiliations, { org = g, role = arng:chance(0.7) and "member" or "associate",
					secret = #affiliations > 0 or arng:chance(0.4) })
			end
		end
		return {
			id = "gen:" .. place .. ":" .. n, source = "generated",
			name = first .. " " .. last, first = first, last = last, gender = gender, pronoun = pronoun,
			look = { record = rng:pick(looks[gender] or looks.male) },
			age = rng:int(opts.minAge or 19, opts.maxAge or 64),
			place = place, home = opts.home, job = jobs[((n - 1) % #jobs) + 1], org = opts.org,
			district = opts.district, lifestyle = lifestyle, traits = traits, status = "alive",
			affiliations = affiliations,
			wage = opts.wage or wage, money = money, employed = opts.employed ~= false,
		}
	end

	-- Relationships within a place, decided once from the seed.
	local function baseRelations(place, ids)
		local rng = Rng.new(seed(), "relations", place)
		local rel = {}
		local function link(a, b, kind)
			rel[a] = rel[a] or {}
			rel[a][b] = kind
			local back = people.relationKinds[kind]
			rel[b] = rel[b] or {}
			rel[b][a] = type(back) == "string" and back or kind
		end
		for i = 1, #ids do
			for j = i + 1, #ids do
				local r = rng:next()
				if r < 0.08 then link(ids[i], ids[j], "partner")
				elseif r < 0.14 then link(ids[i], ids[j], "sibling")
				elseif r < 0.34 then link(ids[i], ids[j], "friend")
				elseif r < 0.40 then link(ids[i], ids[j], "rival")
				end
			end
		end
		return rel
	end

	local baseRel = {} -- id -> { otherId -> kind } from generation (rebuilt, never saved)

	local function remember(p)
		if people.list[p.id] == nil then table.insert(people.order, p.id) end
		people.list[p.id] = p
	end

	-- Makes the people of a place, or gives back the ones already made.
	-- place: any string a mod picks ("rn:watson.hotel-3a", "corp:arasaka:hr").
	-- opts: { count, lifestyle, job, jobs = { ... }, org, home, district, minAge, maxAge,
	--   affiliation, role, gangChance }
	--   org: where they work (a gang or corp's staff belong to it); affiliation: an
	--   organisation everyone here belongs to (a gang's crew); gangChance: how
	--   likely each is to have ties to one of the district's gangs (default 0.2,
	--   0.05 for people who already belong somewhere). Everyone else is unaffiliated.
	-- Returns the ids, in order. Populating the same place again returns the same people.
	function people.populate(place, opts)
		local st = state()
		if st == nil or type(place) ~= "string" then return {} end
		if people.populated[place] then return people.populated[place] end
		opts = opts or st.places[place] or {}
		st.places[place] = opts
		local ids = {}
		for n = 1, math.max(0, math.floor(opts.count or 3)) do
			local p = generate(place, n, opts)
			remember(p)
			table.insert(ids, p.id)
		end
		for a, links in pairs(baseRelations(place, ids)) do
			baseRel[a] = baseRel[a] or {}
			for b, kind in pairs(links) do baseRel[a][b] = kind end
		end
		people.populated[place] = ids
		Core.emit("people.populated", { place = place, ids = ids })
		return ids
	end

	-- Hand-made characters. def: a person's fields plus `id` (yours, prefixed with
	-- your mod's name: "mymod:fixer_rosa"). Register them again on every load,
	-- like organisations; what happens to them is saved.
	function people.register(def)
		if type(def) ~= "table" or type(def.id) ~= "string" then return nil end
		local p = copy(def)
		p.source = p.source or "registered"
		p.status = p.status or "alive"
		p.affiliations = p.affiliations or {}
		if p.name == nil then p.name = (((p.first or "") .. " " .. (p.last or "")):gsub("^%s+", ""):gsub("%s+$", "")) end
		people.registered[p.id] = p
		remember(p)
		Core.emit("people.added", { id = p.id, source = p.source })
		return p.id
	end

	-- Someone another mod already knows about, made a full person the first time
	-- they matter. def: { key (unique to them, e.g. "rn:watson.pc-1a2b:m.reyes"),
	-- name?, first?, last?, initial?, handle?, gender?, lifestyle?, job?, org?, place?, home?, district?,
	-- affiliations? }. Without affiliations, working for a gang or corp makes them one of its people.
	-- initial: the first letter of their first name, if that's all that's known;
	-- handle: a street name, kept in quotes in the full name.
	-- Missing details are filled in from the key, so the same key always gives
	-- the same person. Returns the id (the same one every time for the same key).
	function people.promote(def)
		local st = state()
		if st == nil or type(def) ~= "table" or type(def.key) ~= "string" then return nil end
		local existing = st.keys[def.key]
		if existing then return existing end
		local rng = Rng.new(seed(), "promote", def.key)
		local gender, pronoun = def.gender, def.pronoun
		if gender == nil then gender, pronoun = pickGender(rng) end
		pronoun = pronoun or (gender == "male" and "he" or gender == "female" and "she" or "they")
		local pool = firstNames[gender] or firstNames.other
		if def.initial then
			-- a first name that fits a known initial ("k.tanaka" -> Kenji, Keiko...)
			local fits = {}
			for _, n in ipairs(pool) do if n:sub(1, 1):lower() == def.initial:lower() then table.insert(fits, n) end end
			if #fits > 0 then pool = fits end
		end
		local first = def.first or rng:pick(pool)
		local last = def.last or rng:pick(surnames)
		local looks = people.looks[def.lifestyle or "worker"] or people.looks.worker
		local id = "p:" .. st.nextId
		st.nextId = st.nextId + 1
		local p = {
			id = id, key = def.key, source = def.source or "promoted",
			name = def.name or (def.handle and (first .. " \"" .. def.handle .. "\" " .. last) or (first .. " " .. last)),
			first = first, last = last, handle = def.handle, gender = gender, pronoun = pronoun,
			look = def.look or { record = rng:pick(looks[gender] or looks.male) },
			age = def.age or rng:int(19, 64), place = def.place, home = def.home, job = def.job, org = def.org,
			district = def.district, lifestyle = def.lifestyle or "worker",
			traits = def.traits or { rng:pick(people.traitList), rng:pick(people.traitList) }, status = "alive",
			wage = def.wage, money = def.money, employed = def.employed ~= false,
			affiliations = def.affiliations and copy(def.affiliations)
				or (def.org and roleFor(def.org) and { { org = def.org, role = roleFor(def.org) } }) or {},
		}
		if p.wage == nil or p.money == nil then
			local w, m = moneyFor(Rng.new(seed(), "money", def.key), p.lifestyle)
			p.wage, p.money = p.wage or w, p.money or m
		end
		-- nobody said who they're with: like generated people, some have ties to the district's gangs
		if def.affiliations == nil and #p.affiliations == 0 then
			local gangs = people.districtGangs[def.district or ""] or {}
			local arng = Rng.new(seed(), "affiliation", def.key)
			if #gangs > 0 and arng:chance(def.gangChance or 0.2) then
				table.insert(p.affiliations, { org = arng:pick(gangs), role = arng:chance(0.7) and "member" or "associate",
					secret = arng:chance(0.4) })
			end
		end
		st.made[id] = p
		st.keys[def.key] = id
		remember(p)
		Core.emit("people.added", { id = id, source = p.source, key = def.key })
		return id
	end

	-- A different save was loaded: start from its people. Promoted people come
	-- back from the save, populated places are made again from the seed, and
	-- hand-made characters stay registered.
	rebuild = function(st)
		st.changes = st.changes or {}
		st.made = st.made or {}
		st.keys = st.keys or {}
		st.places = st.places or {}
		st.relations = st.relations or {}
		st.history = st.history or {}
		st.opinion = st.opinion or {}
		st.nextId = st.nextId or 1
		people.list, people.order, people.populated, baseRel = {}, {}, {}, {}
		for _, p in pairs(people.registered) do remember(p) end
		local ids = {}
		for id in pairs(st.made) do table.insert(ids, id) end
		table.sort(ids)
		for _, id in ipairs(ids) do remember(st.made[id]) end
		local places = {}
		for place in pairs(st.places) do table.insert(places, place) end
		table.sort(places)
		for _, place in ipairs(places) do people.populate(place, st.places[place]) end
	end

	---------------------------------------------------------------------------
	-- Reading
	---------------------------------------------------------------------------

	-- A person as they are now (generated or hand-made details with every change on top).
	function people.get(id)
		local st = state()
		local base = people.list[id]
		if base == nil and st and st.made[id] then base = st.made[id] remember(base) end
		if base == nil then return nil end
		local p = copy(base)
		local changes = st and st.changes[id]
		if changes then for k, v in pairs(changes) do p[k] = copy(v) end end
		p.opinion = st and st.opinion[id] or 0
		return p
	end

	function people.byKey(key)
		local st = state()
		return st and st.keys[key]
	end

	-- People matching every field given: people.find({ org = "maelstrom", status = "alive" }).
	-- Special keys: affiliation = an org id (anyone with ties to it, secret or not),
	-- unaffiliated = true (nobody's people), trait = one of their traits.
	-- Only people already known (populated, registered or promoted) are searched.
	function people.find(query)
		local out = {}
		for _, id in ipairs(people.order) do
			local p = people.get(id)
			local ok = p ~= nil
			for k, v in pairs(query or {}) do
				if not ok then break end
				if k == "affiliation" then
					local has = false
					for _, a in ipairs(p.affiliations or {}) do if a.org == v then has = true end end
					ok = has
				elseif k == "unaffiliated" then
					ok = ((#(p.affiliations or {}) == 0) == (v == true))
				elseif k == "trait" then
					local has = false
					for _, t in ipairs(p.traits or {}) do if t == v then has = true end end
					ok = has
				elseif p[k] ~= v then ok = false end
			end
			if ok then table.insert(out, p) end
		end
		return out
	end

	function people.all() return people.find({}) end

	---------------------------------------------------------------------------
	-- Changing
	---------------------------------------------------------------------------

	-- Changes a person's details (status, job, home, org, look, anything). Saved.
	function people.update(id, fields, why)
		local st = state()
		if st == nil or type(fields) ~= "table" or people.get(id) == nil then return false end
		local before = people.get(id)
		if st.made[id] then
			for k, v in pairs(fields) do st.made[id][k] = copy(v) end
		else
			st.changes[id] = st.changes[id] or {}
			for k, v in pairs(fields) do st.changes[id][k] = copy(v) end
		end
		local changed = {}
		for k, v in pairs(fields) do changed[k] = { old = before[k], new = v } end
		Core.emit("people.changed", { id = id, changed = changed, why = why })
		return true
	end

	-- Adds to what happened to someone. kind: a short word ("robbed", "hired",
	-- "hurt", "met_v"); text: one line a person could read; by: who did it (an
	-- org id, a person id, or "player" for V). Keeps the latest 30 per person.
	function people.remember(id, kind, text, by)
		local st = state()
		if st == nil or people.get(id) == nil then return false end
		st.history[id] = st.history[id] or {}
		local h = st.history[id]
		local entry = { time = now(), kind = kind, text = text, by = by }
		table.insert(h, entry)
		while #h > 30 do table.remove(h, 1) end
		Core.emit("people.event", { id = id, kind = kind, text = text, by = by })
		return true
	end

	function people.history(id)
		local st = state()
		return copy(st and st.history[id] or {})
	end

	-- What a person thinks of V, -100 to 100.
	function people.opinion(id)
		local st = state()
		return st and st.opinion[id] or 0
	end

	function people.changeOpinion(id, amount, why)
		local st = state()
		if st == nil or people.get(id) == nil then return 0 end
		local before = st.opinion[id] or 0
		local after = clamp(math.floor(before + (tonumber(amount) or 0) + 0.5), -100, 100)
		st.opinion[id] = after
		if after ~= before then
			Core.host.setVariable("core_opinion", id, after)
			Core.emit("people.opinion", { id = id, value = after, change = after - before, why = why })
		end
		return after
	end

	---------------------------------------------------------------------------
	-- Money
	---------------------------------------------------------------------------

	function people.money(id)
		local p = people.get(id)
		return p and p.money or 0
	end

	-- Gives (or, with a negative amount, takes) eddies. Returns the new amount.
	-- Fires "people.money" { id, value, change, why }.
	function people.pay(id, amount, why)
		local p = people.get(id)
		if p == nil then return 0 end
		local after = math.floor((p.money or 0) + (tonumber(amount) or 0))
		people.update(id, { money = after }, why)
		Core.emit("people.money", { id = id, value = after, change = after - (p.money or 0), why = why })
		return after
	end

	-- The places a person owns (Core.places, owner = their id).
	function people.owns(id) return Core.places and Core.places.ownedBy(id) or {} end

	---------------------------------------------------------------------------
	-- Bodies: which spawned NPC in the game is which person
	---------------------------------------------------------------------------
	-- A mod that spawns a person says so with people.bind(id, entityId). The core
	-- then watches that NPC: if it dies the person is dead (and an incident is
	-- reported), if it's knocked down they're hurt, and when it despawns the link
	-- ends. Bindings last for the session (spawned NPCs don't survive a load).

	people.bodies = {}   -- person id -> entity id
	people.byBody = {}   -- tostring(entity hash) -> person id
	people.watchEvery = 1.0
	local watchTimer = 0

	local function bodyKey(entity)
		if entity == nil then return nil end
		if type(entity) == "table" or type(entity) == "userdata" then
			local ok, h = pcall(function() return entity.hash end)
			if ok and h ~= nil then return tostring(h) end
		end
		return tostring(entity)
	end

	function people.bind(id, entity)
		if people.get(id) == nil or entity == nil then return false end
		people.unbind(id)
		people.bodies[id] = entity
		people.byBody[bodyKey(entity)] = id
		Core.emit("people.bound", { id = id })
		return true
	end

	function people.unbind(id)
		local entity = people.bodies[id]
		if entity == nil then return false end
		people.byBody[bodyKey(entity)] = nil
		people.bodies[id] = nil
		Core.emit("people.unbound", { id = id })
		return true
	end

	-- Which person a spawned NPC is (its entity id, or its hash), or nil.
	function people.personFor(entity) return people.byBody[bodyKey(entity)] end
	function people.entityFor(id) return people.bodies[id] end

	function people.tick(dt)
		watchTimer = watchTimer + (dt or 0)
		if watchTimer < people.watchEvery or Core.host.entityState == nil then return end
		watchTimer = 0
		for id, entity in pairs(people.bodies) do
			local st = Core.host.entityState(entity)
			local p = people.get(id)
			if st == "gone" or p == nil then
				people.unbind(id)
			elseif st == "dead" and p.status ~= "dead" then
				people.update(id, { status = "dead" }, "died")
				people.unbind(id)
				if Core.incidents then
					Core.incidents.report({ kind = "death", text = p.name .. " died.", place = p.place, district = p.district,
						people = { [id] = "killed" }, severity = 4 })
				end
			elseif st == "down" and p.status == "alive" then
				people.update(id, { status = "hurt" }, "knocked down")
			end
		end
	end

	---------------------------------------------------------------------------
	-- Affiliations
	---------------------------------------------------------------------------

	-- The organisations a person belongs to: { { org, role, secret }, ... } (empty: nobody's).
	function people.affiliations(id)
		local p = people.get(id)
		return p and copy(p.affiliations or {}) or {}
	end

	-- Their role with an organisation ("member", "employee", "associate", "boss"...), or nil.
	function people.isAffiliated(id, org)
		for _, a in ipairs(people.affiliations(id)) do if a.org == org then return a.role, a.secret == true end end
		return nil
	end

	-- Joins someone to an organisation, or changes their role there. opts: { secret }.
	function people.affiliate(id, org, role, opts, why)
		if people.get(id) == nil or type(org) ~= "string" then return false end
		local list = people.affiliations(id)
		local entry
		for _, a in ipairs(list) do if a.org == org then entry = a end end
		if entry == nil then entry = { org = org } table.insert(list, entry) end
		entry.role = role or entry.role or roleFor(org) or "member"
		if opts and opts.secret ~= nil then entry.secret = opts.secret == true end
		people.update(id, { affiliations = list }, why)
		Core.emit("people.affiliation", { id = id, org = org, role = entry.role, secret = entry.secret == true, joined = true, why = why })
		return true
	end

	-- Takes someone out of an organisation (they quit, were thrown out, turned).
	function people.leave(id, org, why)
		local list, kept, left = people.affiliations(id), {}, false
		for _, a in ipairs(list) do if a.org == org then left = true else table.insert(kept, a) end end
		if not left then return false end
		people.update(id, { affiliations = kept }, why)
		Core.emit("people.affiliation", { id = id, org = org, joined = false, why = why })
		return true
	end

	-- Everyone known who belongs to an organisation.
	function people.members(org) return people.find({ affiliation = org }) end

	-- How someone is likely to treat V: their own opinion, pulled toward how the
	-- organisations they belong to (openly) feel about V. -100 to 100.
	function people.attitude(id)
		local own = people.opinion(id)
		local pull, n = 0, 0
		for _, a in ipairs(people.affiliations(id)) do
			if not a.secret then pull = pull + Core.standing.get(a.org) n = n + 1 end
		end
		if n == 0 then return own end
		return clamp(math.floor(own + (pull / n) * 0.5 + 0.5), -100, 100)
	end

	---------------------------------------------------------------------------
	-- Relationships
	---------------------------------------------------------------------------

	-- Everyone a person is tied to: { otherId -> kind }.
	function people.relations(id)
		local st = state()
		local out = {}
		for other, kind in pairs(baseRel[id] or {}) do out[other] = kind end
		for other, kind in pairs(st and st.relations[id] or {}) do
			if kind == false then out[other] = nil else out[other] = kind end
		end
		return out
	end

	-- Ties two people (kind from people.relationKinds, or your own word), or
	-- unties them with kind = nil. Both sides are updated.
	function people.relate(a, b, kind, why)
		local st = state()
		if st == nil or a == b or people.get(a) == nil or people.get(b) == nil then return false end
		-- false (not nil) marks an untied pair, so it also hides a tie made at generation
		local here, there = false, false
		if kind ~= nil then
			local back = people.relationKinds[kind]
			here, there = kind, (type(back) == "string" and back or kind)
		end
		st.relations[a] = st.relations[a] or {}
		st.relations[b] = st.relations[b] or {}
		st.relations[a][b] = here
		st.relations[b][a] = there
		Core.emit("people.relation", { a = a, b = b, kind = kind, why = why })
		return true
	end

	return people
end
