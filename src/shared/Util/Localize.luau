--!strict
local Localize = {}
function Localize.locale(raw: any): string
	return if type(raw) == "string" and string.sub(string.lower(raw), 1, 2) == "hu"
		then "hu"
		else "en"
end
function Localize.new(strings: any)
	local keys: { string } = {}
	for source in strings.hu do
		table.insert(keys, source)
	end
	table.sort(keys, function(a: string, b: string)
		return if #a == #b then a < b else #a > #b
	end)
	local function translate(text: string, locale: string): string
		if Localize.locale(locale) ~= "hu" then
			return text
		end
		if strings.hu[text] then
			return strings.hu[text]
		end
		-- UI decorations are outside the source sentence. Match an exact known
		-- sentence after a configured icon, including terminal punctuation.
		for _, icon in strings.decorativeIcons or {} do
			if string.sub(text, 1, #icon) == icon then
				local space, source = string.match(string.sub(text, #icon + 1), "^(%s+)(.+)$")
				if space and source and strings.hu[source] then
					return icon .. space .. strings.hu[source]
				end
			end
		end
		local amount, sentence = string.match(text, "^(%d+) tips · (.+)$")
		if amount and sentence == "Preview any look. Equip the ones you own." then
			return amount .. " borravaló · " .. translate(sentence, locale)
		end
		local name = string.match(text, "^View (.+)$")
		if name then
			return "Profil: " .. name
		end
		local viewed, rest = string.match(text, "^Viewing (.-) · (.+)$")
		if viewed and rest then
			return "Nézett futár: " .. viewed .. " · " .. translate(rest, locale)
		end
		local rarity = string.match(text, "^A (.+) customer in normal times$")
		if rarity then
			return "Nyugodt időben felbukkanó " .. translate(rarity, locale) .. " vendég."
		end
		local level = string.match(text, "^Reach courier level (%d+) first%.$")
		if level then
			return "Előbb érd el a(z) " .. level .. ". futárszintet."
		end
		local codeLevel = string.match(text, "^Reach courier level (%d+) to use this code%.$")
		if codeLevel then
			return "A kódhoz érd el a(z) " .. codeLevel .. ". futárszintet."
		end
		local price = string.match(text, "^Save (%d+) tips for this ride%.$")
		if price then
			return "Gyűjts " .. price .. " borravalót ehhez a járműhöz."
		end
		for _, source in keys do
			local pattern = "%f[%w]" .. string.gsub(source, "([^%w])", "%%%1") .. "%f[^%w]"
			text = string.gsub(text, pattern, function()
				return strings.hu[source]
			end)
		end
		text = string.gsub(
			text,
			"Reach courier level (%d+) first%.",
			"Előbb érd el a(z) %1. futárszintet."
		)
		return text
	end
	return translate
end
return Localize
