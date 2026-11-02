-- Time in Night City: one answer for every mod to "what time and day is it?"
--
-- Read from the game's own clock, so sleeping and skipping time count. If the
-- game clock can't be read, play time stands in at the game's normal speed
-- (8 game seconds to a real one).
--
--   time.now()        { seconds, day, hour, minute, weekday (1-7), weekdayName, night }
--   time.hour(), time.day(), time.weekday(), time.isNight()
--   time.between(from, to, hour?)   is the hour inside from..to (wraps past midnight: 22..6)
--
-- Events: "time.hour" { day, hour } on the hour, "time.day" { day, weekday } at midnight.

return function(Core)
	local time = { lastHour = nil, lastDay = nil }
	local DAY = 86400
	time.weekdayNames = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	time.nightFrom, time.nightTo = 21, 6

	function time.seconds()
		local t = Core.host.gameSeconds and Core.host.gameSeconds()
		if type(t) == "number" then return t end
		local s = Core.state()
		return (s and s.playClock or 0) * 8
	end

	function time.now()
		local t = time.seconds()
		local day = math.floor(t / DAY)
		local within = t % DAY
		local hour = math.floor(within / 3600)
		local weekday = (day % 7) + 1
		return {
			seconds = t, day = day, hour = hour, minute = math.floor((within % 3600) / 60),
			weekday = weekday, weekdayName = time.weekdayNames[weekday],
			night = time.between(time.nightFrom, time.nightTo, hour),
		}
	end

	function time.hour() return time.now().hour end
	function time.day() return time.now().day end
	function time.weekday() return time.now().weekday end
	function time.isNight() return time.now().night end

	-- Is `hour` (default: now) within from..to? to is exclusive; 22..6 wraps past midnight.
	function time.between(from, to, hour)
		hour = hour or time.hour()
		if from == to then return true end
		if from < to then return hour >= from and hour < to end
		return hour >= from or hour < to
	end

	function time.update(dt)
		local s = Core.state()
		if s == nil then return end
		s.playClock = (s.playClock or 0) + dt
		-- a save was loaded: start counting from its time, without firing for the jump
		if time.boundTo ~= s then time.boundTo, time.lastHour, time.lastDay = s, nil, nil end
		local now = time.now()
		if time.lastHour ~= nil and now.hour ~= time.lastHour then
			Core.emit("time.hour", { day = now.day, hour = now.hour })
		end
		if time.lastDay ~= nil and now.day ~= time.lastDay then
			Core.emit("time.day", { day = now.day, weekday = now.weekday })
		end
		time.lastHour, time.lastDay = now.hour, now.day
	end

	return time
end
