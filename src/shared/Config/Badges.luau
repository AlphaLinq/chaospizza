--!strict
return table.freeze({
	retries = 3,
	retrySeconds = 2,
	items = table.freeze({
		{ key = "FirstDelivery", badgeId = 0, deliveries = 1 },
		{ key = "TornadoAir", badgeId = 0 },
		{ key = "FirstMega", badgeId = 0 },
		{ key = "Book10", badgeId = 0, book = 10 },
		{ key = "Book24", badgeId = 0, book = 24 },
		{ key = "Pizzeria6", badgeId = 0, pizzeria = 6 },
		{ key = "GiantDelivery", badgeId = 0 },
	}),
})
