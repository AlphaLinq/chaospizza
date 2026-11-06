--!strict
local Ticker = {}
function Ticker.clip(text: string, limit: number): string
	local clean = string.gsub(text, "%c", " ")
	local length = utf8.len(clean)
	if not length then
		return "?"
	end
	if length <= limit then
		return clean
	end
	local cut = utf8.offset(clean, limit + 1) :: number
	return string.sub(clean, 1, cut - 1) .. "…"
end
function Ticker.format(row: any, copy: any, compact: boolean, config: any): string
	if row.kind == "mega" then
		return if compact then copy.megaCompact else copy.mega
	end
	local names = {}
	for _, name in row.names do
		table.insert(
			names,
			Ticker.clip(name, if compact then config.compactCharacters else config.nameCharacters)
		)
		if compact then
			break
		end
	end
	local crew = if #names > 0 then table.concat(names, " + ") else copy.team
	if row.kind == "giant" then
		return string.format(if compact then copy.giantCompact else copy.giant, crew)
	end
	return if compact
		then string.format(copy.rareCompact, crew, copy[row.rarity])
		else string.format(copy.rare, crew, copy[row.rarity], row.customer)
end
function Ticker.new(config: any)
	local rows: { any } = {}
	local seen: { [string]: number } = {}
	local history: { { key: string, at: number } } = {}
	local sequence, last = 0, -math.huge
	local api = {}
	function api.rows(now: number): { any }
		local live = {}
		for _, row in rows do
			if row.expiresAt > now then
				table.insert(live, row)
			end
		end
		rows = live
		return live
	end
	function api.push(
		kind: string,
		key: string,
		names: { string },
		customer: string?,
		rarity: string?,
		now: number
	): boolean
		if now ~= now or now < 0 or now >= math.huge then
			return false
		end
		if
			kind ~= "giant"
			and kind ~= "mega"
			and not (kind == "rare" and config.rare[rarity or ""])
		then
			return false
		end
		if
			now - last < config.minGapSeconds
			or seen[key] and now - seen[key] < config.repeatSeconds
		then
			return false
		end
		while #history >= config.maxDedupe do
			local old = table.remove(history, 1)
			if old and seen[old.key] == old.at then
				seen[old.key] = nil
			end
		end
		seen[key] = now
		table.insert(history, { key = key, at = now })
		last = now
		sequence += 1
		local safe = {}
		for _, name in names do
			table.insert(safe, Ticker.clip(name, config.nameCharacters))
			if #safe >= config.maxNames then
				break
			end
		end
		api.rows(now)
		table.insert(rows, {
			id = sequence,
			kind = kind,
			names = safe,
			customer = if customer then Ticker.clip(customer, config.customerCharacters) else "",
			rarity = rarity,
			expiresAt = now + config.seconds,
		})
		while #rows > config.maxRows do
			table.remove(rows, 1)
		end
		return true
	end
	return api
end
return Ticker
