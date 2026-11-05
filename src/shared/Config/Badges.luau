--!strict
type Badge = { key: string, badgeId: number, deliveries: number?, book: number?, pizzeria: number? }
local function badge(value: Badge): Badge
	return table.freeze(value)
end
return table.freeze({
	retries = 3,
	retrySeconds = 2,
	items = table.freeze({
		badge({ key = "FirstDelivery", badgeId = 0, deliveries = 1 }),
		badge({ key = "TornadoAir", badgeId = 0 }),
		badge({ key = "FirstMega", badgeId = 0 }),
		badge({ key = "Book10", badgeId = 0, book = 10 }),
		badge({ key = "Book24", badgeId = 0, book = 24 }),
		badge({ key = "Pizzeria6", badgeId = 0, pizzeria = 6 }),
		badge({ key = "GiantDelivery", badgeId = 0 }),
	}),
})
