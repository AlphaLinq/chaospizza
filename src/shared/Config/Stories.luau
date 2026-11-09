--!strict
-- Story orders (#254): short 3-chapter stories about the city's everyday
-- people. Only Common / Uncommon customers, so rarity odds and the Customer
-- Book stay untouched. `address` ids are MapLayout addresses; `line` is what
-- the customer says when the chapter is delivered. Ids are saved in player
-- profiles (claims["story.<id>"]): keep them stable.

export type Chapter = { customer: string, address: string, line: string }
export type Story = { id: string, title: string, chapters: { Chapter }, ending: string }

local function ch(customer: string, address: string, line: string): Chapter
	return table.freeze({ customer = customer, address = address, line = line })
end

return table.freeze({
	table.freeze({
		id = "GrandpaMarathon",
		title = "Grandpa's Marathon",
		chapters = table.freeze({
			ch("JoggingGrandpa", "A13", "Training starts today. Carbo-loading, young one!"),
			ch("GardenerAuntie", "A07", "He sent me a slice? He's sweet on me, isn't he."),
			ch(
				"JoggingGrandpa",
				"A04",
				"I finished the marathon! Auntie was cheering at the line!"
			),
		}),
		ending = "Grandpa ran his marathon — and got a date.",
	}),
	table.freeze({
		id = "LostTouristHome",
		title = "The Lost Tourist",
		chapters = table.freeze({
			ch("LostTourist", "A09", "Where am I? Never mind. Pizza first, questions later."),
			ch("MailDog", "A11", "Woof! (He's guarding a crumpled map. It says 'TOURIST'.)"),
			ch("LostTourist", "A02", "My map! I can finally go home. ...Maybe one more slice."),
		}),
		ending = "The tourist found the way home. Probably.",
	}),
	table.freeze({
		id = "ExamWeek",
		title = "Exam Week",
		chapters = table.freeze({
			ch("SleepyStudent", "A03", "Exam tomorrow. I need brain pizza. Lots of brain pizza."),
			ch("GamerKid", "A06", "His notes? I, uh, used them as a mousepad. Here."),
			ch("SleepyStudent", "A12", "I PASSED! Celebration slice! Then a nap. Mostly the nap."),
		}),
		ending = "The student passed. The mousepad notes helped, somehow.",
	}),
	table.freeze({
		id = "StatueManFan",
		title = "Statue Man's Secret Fan",
		chapters = table.freeze({
			ch(
				"StatueMan",
				"A10",
				"...  (A note on the plinth: 'Bring a slice to my biggest fan.')"
			),
			ch(
				"SelfieInfluencer",
				"A14",
				"OMG the STATUE sent me pizza?! This is so much content!"
			),
			ch("StatueMan", "A01", "...  (He smiled. You're sure he smiled this time.)"),
		}),
		ending = "Statue Man has a fan club now. He still won't move.",
	}),
}) :: { Story }
