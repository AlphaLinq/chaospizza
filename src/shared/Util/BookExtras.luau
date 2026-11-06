--!strict
local Extras = {}
function Extras.snapshot(book: any, golden: any, spots: { any }): any
	local customers = {}
	for _, c in book.customers do
		local row: any = { known = c.known == true }
		if c.known and c.quirk then
			row.title, row.request, row.done = c.quirk.title, c.quirk.request, c.quirkDone == true
		end
		customers[c.id] = row
	end
	local rows, found, remaining = {}, 0, 0
	for _, spot in spots do
		local collected = golden.foundIds[spot.id] == true
		local active = table.find(golden.active, spot.id) ~= nil
		if collected then
			found += 1
		end
		if active then
			remaining += 1
		end
		table.insert(rows, { id = spot.id, hint = spot.hint, found = collected, active = active })
	end
	return {
		customers = customers,
		rows = rows,
		found = found,
		remaining = remaining,
		day = golden.day,
	}
end
return Extras
