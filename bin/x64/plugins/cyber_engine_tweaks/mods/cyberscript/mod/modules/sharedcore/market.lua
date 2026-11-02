-- The Night City stock exchange, shared by every mod.
--
-- Prices drift each step (every 30 seconds of play), pulled gently back towards
-- each company's listing price, and jump on shocks: any mod can shock a price
-- (a hack, a leak, a scandal, V's own company landing a contract). Insider tips
-- are shocks that hit later. V can buy and sell with real eddies.
--
-- Companies: { ticker, name, org, price (listing price), vol (how jumpy), rivals }
-- Mods list their own (V's corporation going public, say) with
-- market.listCompany; register them again on every load (prices are saved).

return function(Core)
	local market = { tickEvery = 30, timer = 0, feeRate = 0.01, companies = {}, byTicker = {}, byOrg = {} }
	local Rng = Core.Rng

	local builtin = {
		{ ticker = "ARA", name = "Arasaka",            org = "arasaka",     price = 820, vol = 0.012, rivals = { "MIL" } },
		{ ticker = "MIL", name = "Militech",           org = "militech",    price = 640, vol = 0.014, rivals = { "ARA" } },
		{ ticker = "KTC", name = "Kang Tao",           org = "kangtao",     price = 410, vol = 0.020, rivals = { "ARA" } },
		{ ticker = "TTI", name = "Trauma Team Int.",   org = "traumateam",  price = 330, vol = 0.010 },
		{ ticker = "BTC", name = "Biotechnica",        org = "biotechnica", price = 300, vol = 0.016 },
		{ ticker = "PTC", name = "Petrochem",          org = "petrochem",   price = 260, vol = 0.015, rivals = { "SOV" } },
		{ ticker = "SOV", name = "SovOil",             org = "sovoil",      price = 240, vol = 0.018, rivals = { "PTC" } },
		{ ticker = "ORB", name = "Orbital Air",        org = "orbitalair",  price = 390, vol = 0.013 },
		{ ticker = "KIR", name = "Kiroshi Opticals",   org = "kiroshi",     price = 180, vol = 0.022 },
		{ ticker = "ZTC", name = "Zetatech",           org = "zetatech",    price = 150, vol = 0.024 },
		{ ticker = "N54", name = "Network 54",         org = "network54",   price = 140, vol = 0.020, rivals = { "WNS" } },
		{ ticker = "WNS", name = "World News Service", org = "wns",         price = 110, vol = 0.020, rivals = { "N54" } },
		{ ticker = "DLM", name = "Delamain",           org = "delamain",    price = 90,  vol = 0.025 },
		{ ticker = "ESA", name = "European Space Agency", org = "esa",       price = 280, vol = 0.010 },
		{ ticker = "NCPD", name = "NCPD",              org = "ncpd",        price = 120, vol = 0.012, rivals = { "NWT" } },
		{ ticker = "NWT", name = "NetWatch",           org = "netwatch",    price = 360, vol = 0.011, rivals = { "NCPD" } },
		{ ticker = "RKA", name = "Rocklin Augmentics", org = "rocklin",     price = 210, vol = 0.020, rivals = { "DYN", "ZHI" } },
		{ ticker = "DYN", name = "Dynalar Technologies", org = "dynalar",   price = 190, vol = 0.021, rivals = { "RKA", "KIR" } },
		{ ticker = "ZHI", name = "Zhirafa Technical",  org = "zhirafa",     price = 160, vol = 0.022, rivals = { "RKA", "SOV" } },
		{ ticker = "SGT", name = "Segatari",           org = "segatari",    price = 130, vol = 0.023, rivals = { "ZTC", "KIR" } },
		{ ticker = "MDA", name = "Midnight Arms",      org = "midnightarms", price = 230, vol = 0.019, rivals = { "CNA", "BGA" } },
		{ ticker = "CNA", name = "Constitutional Arms", org = "constitutionalarms", price = 200, vol = 0.018, rivals = { "MDA", "DPT" } },
		{ ticker = "BGA", name = "Budget Arms",        org = "budgetarms",  price = 45,  vol = 0.030, rivals = { "MDA", "DPT" } },
		{ ticker = "DPT", name = "Darra Polytechnic",  org = "darra",       price = 240, vol = 0.019, rivals = { "TSU", "BGA" } },
		{ ticker = "TSU", name = "Tsunami Defense Systems", org = "tsunami", price = 270, vol = 0.018, rivals = { "DPT", "MIL", "ARA" } },
	}

	-- def: { ticker, name, org?, price, vol?, rivals? }. Returns the company, or nil and why.
	function market.listCompany(def)
		if type(def) ~= "table" or type(def.ticker) ~= "string" then return nil, "a company needs a ticker" end
		local ticker = def.ticker:upper():gsub("[^%w]", "")
		if ticker == "" or #ticker > 5 then return nil, "tickers are 1 to 5 letters or numbers" end
		if (tonumber(def.price) or 0) <= 0 then return nil, "a company needs a listing price" end
		local c = market.byTicker[ticker]
		if c == nil then
			c = { ticker = ticker }
			table.insert(market.companies, c)
			market.byTicker[ticker] = c
		end
		c.name = def.name or ticker
		c.org = def.org
		c.price = tonumber(def.price)
		c.vol = tonumber(def.vol) or 0.015
		c.rivals = def.rivals or {}
		if c.org then market.byOrg[c.org] = c end
		Core.emit("market.listed", { ticker = ticker })
		return c
	end

	function market.delist(ticker)
		local c = market.byTicker[ticker]
		if c == nil then return false end
		market.byTicker[ticker] = nil
		if c.org and market.byOrg[c.org] == c then market.byOrg[c.org] = nil end
		for i, x in ipairs(market.companies) do if x == c then table.remove(market.companies, i) break end end
		local s = market.state()
		if s then s.prices[ticker], s.history[ticker] = nil, nil end
		Core.emit("market.delisted", { ticker = ticker })
		return true
	end

	---------------------------------------------------------------------------
	-- State (saved per save)
	---------------------------------------------------------------------------

	function market.state()
		local root = Core.state()
		if root == nil then return nil end
		if root.market == nil then
			root.market = { clock = 0, prices = {}, history = {}, holdings = {}, cost = {}, shocks = {}, tips = {} }
		end
		local s = root.market
		for _, c in ipairs(market.companies) do
			if s.prices[c.ticker] == nil then
				s.prices[c.ticker] = c.price
				s.history[c.ticker] = { c.price }
			end
		end
		return s
	end

	function market.get(ticker) return market.byTicker[tostring(ticker or ""):upper()] end
	function market.forOrg(org) return market.byOrg[org] end

	function market.price(ticker)
		local s = market.state()
		return s and s.prices[ticker] or 0
	end

	-- Prices over the last steps, oldest first (up to 30).
	function market.history(ticker)
		local s = market.state()
		return s and s.history[ticker] or {}
	end

	-- Change over the last few steps, as a fraction.
	function market.change(ticker)
		local h = market.history(ticker)
		if #h < 2 then return 0 end
		local from = h[math.max(1, #h - 5)]
		return (h[#h] - from) / from
	end

	function market.held(ticker)
		local s = market.state()
		return s and s.holdings[ticker] or 0
	end

	---------------------------------------------------------------------------
	-- Price movement
	---------------------------------------------------------------------------

	-- Moves a price by pct (0.05 = up 5%), spread over the next few steps.
	-- Rivals move a little the other way.
	function market.shock(ticker, pct, why)
		local s = market.state()
		local c = market.get(ticker)
		if s == nil or c == nil then return false end
		table.insert(s.shocks, { ticker = c.ticker, remaining = pct })
		for _, rival in ipairs(c.rivals or {}) do
			table.insert(s.shocks, { ticker = rival, remaining = -pct * 0.25 })
		end
		Core.emit("market.shock", { ticker = c.ticker, pct = pct, why = why })
		return true
	end

	-- A shock that lands later, as news (steps from now). While it's pending,
	-- trading that stock counts as insider trading (see the trade event's tipped flag).
	-- headline: the news line when it lands (default: "<name> shares jump/slide on surprise news")
	function market.addTip(ticker, pct, steps, headline)
		local s = market.state()
		local c = market.get(ticker)
		if s == nil or c == nil then return false end
		table.insert(s.tips, { ticker = c.ticker, pct = pct, due = s.clock + math.max(1, steps or 3), headline = headline })
		return true
	end

	function market.tipped(ticker)
		local s = market.state()
		for _, tip in ipairs(s and s.tips or {}) do
			if tip.ticker == ticker then return true end
		end
		return false
	end

	function market.step()
		local s = market.state()
		if s == nil then return end
		s.clock = s.clock + 1
		local rng = Rng.new(Core.state().seed, "market", s.clock)

		for i = #s.tips, 1, -1 do
			local tip = s.tips[i]
			if s.clock >= tip.due then
				table.remove(s.tips, i)
				market.shock(tip.ticker, tip.pct, "news")
				local c = market.get(tip.ticker)
				Core.news.add(tip.headline or ((c and c.name or tip.ticker) ..
					(tip.pct > 0 and " shares jump on surprise news" or " shares slide on surprise news")),
					{ source = "market", org = c and c.org })
			end
		end

		local moves = {}
		for i = #s.shocks, 1, -1 do
			local shock = s.shocks[i]
			local part = shock.remaining * 0.5
			if math.abs(shock.remaining) < 0.002 then part = shock.remaining end
			moves[shock.ticker] = (moves[shock.ticker] or 0) + part
			shock.remaining = shock.remaining - part
			if math.abs(shock.remaining) < 0.0005 then table.remove(s.shocks, i) end
		end

		for _, c in ipairs(market.companies) do
			local price = s.prices[c.ticker]
			local noise = (rng:next() * 2 - 1) * c.vol
			local revert = (c.price - price) / c.price * 0.01
			local move = noise + revert + (moves[c.ticker] or 0)
			price = math.max(1, math.floor(price * (1 + move) * 100 + 0.5) / 100)
			s.prices[c.ticker] = price
			local h = s.history[c.ticker]
			table.insert(h, price)
			while #h > 30 do table.remove(h, 1) end
		end
		Core.emit("market.step", { clock = s.clock })
	end

	function market.update(dt)
		market.timer = market.timer + dt
		if market.timer >= market.tickEvery then
			market.timer = 0
			market.step()
		end
	end

	---------------------------------------------------------------------------
	-- Trading (real eddies)
	---------------------------------------------------------------------------

	-- Returns ok, message.
	function market.buy(ticker, qty)
		local s = market.state()
		local c = market.get(ticker)
		qty = math.floor(tonumber(qty) or 0)
		if s == nil then return false, "Market offline." end
		if c == nil then return false, "Unknown ticker '" .. tostring(ticker) .. "'." end
		if qty <= 0 then return false, "Quantity must be at least 1." end
		local price = s.prices[c.ticker]
		local total = math.ceil(price * qty * (1 + market.feeRate))
		if not Core.money.take(total) then
			return false, "Not enough eddies: " .. qty .. " " .. c.ticker .. " costs " .. total .. "."
		end
		local held = s.holdings[c.ticker] or 0
		s.cost[c.ticker] = ((s.cost[c.ticker] or 0) * held + price * qty) / (held + qty)
		s.holdings[c.ticker] = held + qty
		Core.emit("market.trade", { side = "buy", ticker = c.ticker, qty = qty, price = price, tipped = market.tipped(c.ticker) })
		return true, string.format("Bought %d %s at %.2f for %d eddies (fee included).", qty, c.ticker, price, total)
	end

	-- qty: a number or "all". Returns ok, message.
	function market.sell(ticker, qty)
		local s = market.state()
		local c = market.get(ticker)
		if s == nil then return false, "Market offline." end
		if c == nil then return false, "Unknown ticker '" .. tostring(ticker) .. "'." end
		local held = s.holdings[c.ticker] or 0
		qty = (qty == "all") and held or math.floor(tonumber(qty) or 0)
		if qty <= 0 then return false, "Quantity must be at least 1." end
		if qty > held then return false, "You only hold " .. held .. " " .. c.ticker .. "." end
		local price = s.prices[c.ticker]
		local total = math.floor(price * qty * (1 - market.feeRate))
		s.holdings[c.ticker] = held - qty
		if s.holdings[c.ticker] == 0 then
			s.holdings[c.ticker] = nil
			s.cost[c.ticker] = nil
		end
		Core.money.give(total)
		Core.emit("market.trade", { side = "sell", ticker = c.ticker, qty = qty, price = price, tipped = market.tipped(c.ticker) })
		return true, string.format("Sold %d %s at %.2f for %d eddies (fee included).", qty, c.ticker, price, total)
	end

	-- V's shares: rows { ticker, name, qty, price, cost, worth }, total worth.
	function market.portfolio()
		local s = market.state()
		local rows, value = {}, 0
		if s == nil then return rows, 0 end
		for _, c in ipairs(market.companies) do
			local qty = s.holdings[c.ticker]
			if qty then
				local worth = qty * s.prices[c.ticker]
				value = value + worth
				table.insert(rows, { ticker = c.ticker, name = c.name, qty = qty, price = s.prices[c.ticker],
					cost = s.cost[c.ticker] or 0, worth = worth })
			end
		end
		return rows, value
	end

	for _, def in ipairs(builtin) do market.listCompany(def) end
	return market
end
