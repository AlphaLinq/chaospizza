--!nonstrict
-- Deterministic advisory model; stdout is the generated Hungarian report.
local Config = require("../src/shared/Config/EconomySimulation")
local ProgressionConfig = require("../src/shared/Config/Progression")
local Pizzeria = require("../src/shared/Config/Pizzeria")
local Rarities = require("../src/shared/Config/Rarities")
local Customers = require("../src/shared/Config/Customers")
local Progression =
	require("../src/shared/Util/Progression").new(ProgressionConfig, Rarities, Pizzeria)
local m = {
	config = Config,
	progressionConfig = table.clone(ProgressionConfig),
	progression = Progression,
	pizzeria = Pizzeria,
	rarities = Rarities,
	customers = Customers,
	schema = require("../src/shared/Util/ProfileSchema"),
	daily = require("../src/shared/Config/DailyRewards"),
	boosts = require("../src/shared/Util/Boosts").new(require("../src/shared/Config/Products")),
	odds = require("../src/shared/Util/CustomerOdds"),
	style = require("../src/shared/Util/StyleLogic"),
	styleConfig = require("../src/shared/Config/Style"),
	tuning = require("../src/shared/Config/Tuning"),
	events = require("../src/shared/Config/Events"),
	season = require("../src/shared/Util/Season"),
	rewards = require("../src/shared/Util/ProgressRewards").new(
		require("../src/shared/Config/ProgressRewards"),
		Customers,
		Progression.levelFromXp
	),
}
-- PizzeriaService currently grants +0.1 rarity modifier per level after level 3.
m.progressionConfig.pizzeriaOddsBonusPerLevel = Config.pizzeriaOddsBonusPerLevel
local Simulator = require("../src/shared/Util/EconomySimulator")
local function median(values)
	table.sort(values)
	if #values == 0 then
		return "nem érte el"
	end
	return string.format(
		"%.1f perc (%d/%d)",
		values[math.ceil(#values / 2)] / 60,
		#values,
		Config.runs
	)
end
print("# Gazdasági szimuláció\n")
print(
	`Generálás: luau tools/economy_sim.luau > docs/ECONOMY.md. Seed: {Config.seed}, {Config.runs} futás/eset, {Config.maxSeconds / 3600} órás horizont. Ez modell, nem mért játékosadat.\n`
)
print(
	"| Játékos | Első fejlesztés | 6. pizzériaszint | Teljes vendégkönyv | Első fejlesztés <3 perc |\n|---|---:|---:|---:|---|"
)
for _, scenario in Config.scenarios do
	local first, tower, book = {}, {}, {}
	local under = 0
	for run = 1, Config.runs do
		local result = Simulator.run(m, scenario, Config.seed + run, Config.maxSeconds)
		if result.firstUpgrade then
			table.insert(first, result.firstUpgrade)
			if result.firstUpgrade < 180 then
				under += 1
			end
		end
		if result.tower then
			table.insert(tower, result.tower)
		end
		if result.book then
			table.insert(book, result.book)
		end
	end
	print(
		`| {scenario.name} | {median(first)} | {median(tower)} | {median(book)} | {under}/{Config.runs} |`
	)
end
print("\n## Feltételezések és korlátok\n")
print(
	"- Átlagos/lelkes:70/40 másodperc/fuvar; hibaarány20%/5%, légi stílus2%/15%. Kezdéskor az első napi jutalom, majd a valódi XP-, könyv- és szintjutalmak. Nincs ingyen pénz kódokból/barátokból."
)
print(
	"- December15-i eseménykészlet; átlagos fázishosszak,10 percenként75s MEGA,10 fős közös szerver feltételezés. A vendégsorsolás, szorzók, lejáratok, csillagok és slotok tényleges Config/Util számolása fut."
)
print(
	"- A költő DoubleTips passt, egyszeri StarterPackot és egyetlen PizzaScentCloudot kap; a boostok a valódi időben lejárnak. Nincs végtelen Robux-vásárlás."
)
print(
	"- A ritka törzsvendégek legjobb termelői automatikusan leülnek és az üveg azonnal begyűlik. Nincs offline szünet, like-, napiheti- vagy óriásrendelés-farm. A pályabejárás/időjárás útvesztése nem fizikai szimuláció."
)
print(
	"- A teljes könyv eredménye csak a horizonton belüli teljes futások mediánja; a zárójel megmutatja a cenzorált futásokat, így a táblázat nem ígér garantált teljesítést."
)
print(
	"\n## Hangolási javaslatok\n\n- Az első fejlesztés <3 perc oszlopa közvetlenül ellenőrzi a brief célját; ár helyett először a tényleges onboarding fuvaridőt mérjük.\n- A torony és a teljes könyv közötti eltérést zárt teszttel validáljuk; a kapott eredmény önmagában nem indok automatikus ármódosításra.\n- Szezonon kívül a Blizzard-vendégek nem húzhatók: a teljes29-es könyv idejét ilyenkor nem szabad végesnek ígérni.\n- A CI-futás advisory; Config-változás után ezt a dokumentumot újra kell generálni."
)
