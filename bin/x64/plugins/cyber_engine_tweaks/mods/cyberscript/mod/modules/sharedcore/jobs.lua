-- Jobs: who works where, for what, and the money moving through the city.
--
-- Everyone in the people registry has `money` (what they have put by), a daily
-- `wage` and a way of life that costs something to live. At the start of every
-- in-game day the known people are paid and pay their way: wage in, living
-- costs out. Someone who runs out is marked `broke` (and comes back off it once
-- they're in the black again).
--
--   jobs.hire(personId, { org, place, job, wage }, why)
--       they work there now; a gang or corp employer makes them one of its people
--   jobs.fire(personId, why)              out of work (and out of the employer's ranks)
--   jobs.employees(orgOrPlace)            the known people working for an org or at a place
--   jobs.closePlace(placeId, why)         everyone working there loses their job
--   jobs.payday()                         a day's wages and costs (the core runs it at midnight)
--
-- Events: "jobs.hired" { id, org, place, job, wage, why }, "jobs.fired" { id, org, place, job, why },
--         "jobs.payday" { day, paid, broke }

return function(Core)
	local jobs = {}

	function jobs.hire(id, def, why)
		local P = Core.people
		local p = P.get(id)
		if p == nil or type(def) ~= "table" then return false end
		if p.employed and p.org and p.org ~= def.org then jobs.fire(id, "changed jobs") end
		P.update(id, { org = def.org, place = def.place or p.place, job = def.job or p.job or "staff",
			wage = def.wage or p.wage or 0, employed = true }, why)
		local o = def.org and Core.orgs.get(def.org)
		if o and (o.kind == "gang" or o.kind == "corp" or o.kind == "media" or o.kind == "city") then
			if P.isAffiliated(id, def.org) == nil then P.affiliate(id, def.org, nil, nil, why or "hired") end
		end
		P.remember(id, "hired", "Started work" .. (def.job and (" as " .. def.job) or "") ..
			(o and (" for " .. o.name) or ""), def.org)
		Core.emit("jobs.hired", { id = id, org = def.org, place = def.place, job = def.job, wage = def.wage, why = why })
		return true
	end

	function jobs.fire(id, why)
		local P = Core.people
		local p = P.get(id)
		if p == nil or p.employed == false then return false end
		local role = p.org and P.isAffiliated(id, p.org)
		if role == "employee" then P.leave(id, p.org, why or "lost their job") end
		P.update(id, { employed = false, job = "unemployed", wage = 0 }, why)
		P.remember(id, "fired", "Lost their job" .. (why and (": " .. why) or ""), p.org)
		Core.emit("jobs.fired", { id = id, org = p.org, place = p.place, job = p.job, why = why })
		return true
	end

	function jobs.employees(orgOrPlace)
		local out = {}
		for _, p in ipairs(Core.people.all()) do
			if p.employed ~= false and p.job ~= "unemployed" and (p.org == orgOrPlace or p.place == orgOrPlace) then
				table.insert(out, p)
			end
		end
		return out
	end

	function jobs.closePlace(placeId, why)
		local n = 0
		for _, p in ipairs(Core.people.find({ place = placeId })) do
			if p.employed ~= false and p.job ~= "unemployed" and jobs.fire(p.id, why or "the place closed") then n = n + 1 end
		end
		return n
	end

	function jobs.payday()
		local P = Core.people
		local paid, broke = 0, 0
		for _, p in ipairs(P.all()) do
			if p.status ~= "dead" and p.status ~= "missing" then
				local income = (p.employed ~= false and p.job ~= "unemployed") and (p.wage or 0) or 0
				local cost = P.livingCost[p.lifestyle or "worker"] or 80
				local after = (p.money or 0) + income - cost
				local fields = { money = after }
				if after < 0 and not p.broke then
					fields.broke = true
					broke = broke + 1
				elseif after >= 0 and p.broke then
					fields.broke = false
				end
				P.update(p.id, fields, "payday")
				if fields.broke == true then P.remember(p.id, "broke", "Ran out of money.", nil) end
				if income > 0 then paid = paid + 1 end
			end
		end
		local day = Core.time.day()
		Core.emit("jobs.payday", { day = day, paid = paid, broke = broke })
		return paid, broke
	end

	-- midnight: pay day (hooked once, on the core's own time event)
	local hooked = false
	function jobs.hook()
		if hooked then return end
		hooked = Core.on("time.day", function() jobs.payday() end) ~= nil
	end
	jobs.hook()

	return jobs
end
