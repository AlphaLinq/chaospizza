--!strict
return table.freeze({
	title = "How to play",
	summary = "Grab a pizza, brave the chaos, deliver it. Collect customers and grow your pizzeria.",
	pages = table.freeze({
		{ id = "pickup", title = "Pick up", body = "Use the counter prompt to pick up a pizza." },
		{
			id = "deliver",
			title = "Deliver",
			body = "Follow the arrow. Deliver to the marked door for tips.",
		},
		{
			id = "chaos",
			title = "Brave the chaos",
			body = "Watch the warnings. Use safe routes through each disaster.",
		},
		{
			id = "book",
			title = "Collect customers",
			body = "New customers fill your Book. Regulars earn passive tips.",
		},
		{
			id = "pizzeria",
			title = "Grow your pizzeria",
			body = "Visit your pizzeria to collect tips and buy upgrades.",
		},
		{
			id = "giant",
			title = "Carry together",
			body = "Carry giant pizzas with friends. Stay together to deliver.",
		},
	}),
})
