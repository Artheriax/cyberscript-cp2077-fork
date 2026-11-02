-- One news feed for the whole of Night City. Any mod, or a datapack, can post
-- to it; anything can read it. The newest stories are kept with the save.

return function(Core)
	local news = { keep = 60 }

	local function feed()
		local s = Core.state()
		if s == nil then return nil end
		if s.news == nil then s.news = {} end
		return s.news
	end

	-- opts: { source = "mymod", org = "arasaka" }
	function news.add(text, opts)
		local f = feed()
		if f == nil or text == nil or text == "" then return false end
		opts = opts or {}
		local s = Core.state()
		-- time: the market's clock (one step every half minute of play)
		local item = { text = tostring(text), source = opts.source, org = opts.org, time = s.market and s.market.clock or 0 }
		table.insert(f, item)
		while #f > news.keep do table.remove(f, 1) end
		Core.emit("news", item)
		return true
	end

	-- The latest n stories (all of them if n is nil), oldest first: { text, source, org, time }
	function news.list(n)
		local f = feed() or {}
		local out = {}
		for i = math.max(1, #f - (n or #f) + 1), #f do table.insert(out, f[i]) end
		return out
	end

	-- Just the text of the latest n stories, oldest first.
	function news.texts(n)
		local out = {}
		for _, item in ipairs(news.list(n)) do table.insert(out, item.text) end
		return out
	end

	return news
end
