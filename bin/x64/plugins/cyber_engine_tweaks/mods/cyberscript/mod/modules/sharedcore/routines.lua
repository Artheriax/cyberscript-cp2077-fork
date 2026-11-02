-- Routines: where people are, and what they're doing, at each hour.
--
-- One shared way to write a day, so a person made by any mod follows the same rules.
-- A routine is a list of blocks, checked in order (the first that fits wins):
--   { from = 9, to = 17, activity = "work", place = "work", days = { 1, 2, 3, 4, 5 } }
--   from/to: game hours, to exclusive; 22..6 wraps past midnight
--   activity: "sleep", "work", "leisure", "errands", "street", or any word a mod uses
--   place: a place id (Core.places), or "home" / "work" (the person's own), or nil
--   days: weekdays 1-7 it applies on (none = every day)
--
--   routines.get(id)              their routine: one a mod set, or one made from their way of life
--   routines.set(id, routine, why) / routines.clear(id, why)
--   routines.whereIs(id, hour?, weekday?)   { activity, place, district } (nil if they're nowhere: dead, missing)
--   routines.at(placeId, hour?)   the known people who should be at a place
--   routines.default(person)      the routine their way of life gives them
--
-- Events: "routines.changed" { id, why }
-- Nothing here moves anybody: a mod that spawns people asks where they should be.

return function(Core)
	local routines = {}
	local WEEKDAYS = { 1, 2, 3, 4, 5 }

	local function state()
		local s = Core.state()
		if s == nil then return nil end
		s.routines = s.routines or {}
		return s.routines
	end

	-- Somewhere to unwind near home, the same one each time for the same person.
	local function leisureSpot(person)
		if Core.places == nil then return nil end
		local spots = Core.places.find({ kinds = { "bar", "club", "arcade", "restaurant" }, district = person.district })
		if #spots == 0 then return nil end
		local rng = Core.Rng.new("leisure", person.id)
		return spots[rng:int(1, #spots)].id
	end

	-- What a way of life usually looks like. Some people work nights.
	function routines.default(person)
		local rng = Core.Rng.new("routine", person.id)
		local fun = leisureSpot(person)
		local life = person.lifestyle or "worker"
		local working = person.employed ~= false and person.job ~= "unemployed"
		if life == "nightlife" or (life == "medical" and rng:chance(0.3)) then
			return {
				{ from = 6, to = 14, activity = "sleep", place = "home" },
				{ from = 20, to = 4, activity = working and "work" or "leisure", place = working and "work" or fun },
				{ from = 14, to = 20, activity = "leisure", place = fun },
				{ from = 4, to = 6, activity = "errands", place = nil },
			}
		end
		if life == "street" then
			return {
				{ from = 4, to = 12, activity = "sleep", place = "home" },
				{ from = 12, to = 4, activity = "street", place = rng:chance(0.5) and fun or nil },
			}
		end
		if life == "rich" then
			return {
				{ from = 1, to = 9, activity = "sleep", place = "home" },
				{ from = 19, to = 1, activity = "leisure", place = fun },
				{ from = 9, to = 19, activity = "errands", place = nil },
			}
		end
		local start = (life == "corpo") and 8 or rng:int(7, 10)
		local stop = start + ((life == "corpo") and 10 or 8)
		local plan = {
			{ from = 23, to = (start - 1) % 24, activity = "sleep", place = "home" },
		}
		if working then
			table.insert(plan, { from = start, to = stop % 24, activity = "work", place = "work",
				days = life == "vendor" and nil or WEEKDAYS })
		end
		table.insert(plan, { from = stop % 24, to = 23, activity = "leisure", place = rng:chance(0.6) and fun or "home" })
		table.insert(plan, { from = (start - 1) % 24, to = 23, activity = "errands", place = nil })
		return plan
	end

	function routines.get(id)
		local st = state()
		if st and st[id] then return st[id] end
		local p = Core.people.get(id)
		return p and routines.default(p) or nil
	end

	function routines.set(id, routine, why)
		local st = state()
		if st == nil or type(routine) ~= "table" or Core.people.get(id) == nil then return false end
		st[id] = routine
		Core.emit("routines.changed", { id = id, why = why })
		return true
	end

	function routines.clear(id, why)
		local st = state()
		if st == nil or st[id] == nil then return false end
		st[id] = nil
		Core.emit("routines.changed", { id = id, why = why })
		return true
	end

	local function onDay(block, weekday)
		if block.days == nil then return true end
		for _, d in ipairs(block.days) do if d == weekday then return true end end
		return false
	end

	-- Where someone should be at an hour (default now): { activity, place, district }.
	-- Dead or missing people are nowhere (nil); hurt people stay home.
	function routines.whereIs(id, hour, weekday)
		local p = Core.people.get(id)
		if p == nil or p.status == "dead" or p.status == "missing" then return nil end
		local now = Core.time.now()
		hour, weekday = hour or now.hour, weekday or now.weekday
		local function resolve(place)
			if place == "home" then return p.home end
			if place == "work" then return p.place end
			return place
		end
		if p.status == "hurt" then return { activity = "recovering", place = p.home, district = p.district } end
		for _, block in ipairs(routines.get(id) or {}) do
			if onDay(block, weekday) and Core.time.between(block.from, block.to, hour) then
				local place = resolve(block.place)
				local where = place and Core.places and Core.places.get(place)
				return { activity = block.activity, place = place, district = where and where.district or p.district }
			end
		end
		return { activity = "around", place = nil, district = p.district }
	end

	-- The known people whose routine puts them at a place at an hour (default now).
	function routines.at(placeId, hour, weekday)
		local out = {}
		for _, p in ipairs(Core.people.all()) do
			local w = routines.whereIs(p.id, hour, weekday)
			if w and w.place == placeId then table.insert(out, p) end
		end
		return out
	end

	return routines
end
