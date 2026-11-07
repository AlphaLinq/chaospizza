# Hangrendszer és eseményhangok

A Config/Sounds a klienssel szállított `rbxasset://sounds/` mintákat használja. Nincs harmadik féltől származó ID, feltöltés vagy privát audioengedély. A MEGA saját, 32 lépéses arcade dallama ezekből a mintákból készül; nem külső zeneszám. A klipenkénti hangerő, hangmagasság, hossz, cooldown és a 12 hangos közös korlát konfigurálható.

A `SoundController.play(cue)` API lejátssza az ismert klipet, fontos jelzésnél a Configban megadott feliratot is mutatja. A felirat mindkét hangerő nullájánál és sikertelen hangbetöltésnél is megmarad. UI-gomb, kézbesítés és új vendég automatikusan bekötött; a meglévő HUD további vizuális részleteket ad. A `SoundController.setMusic("Mega" | nil)` idempotens zenekezelés; a `SoundController.ownWarnings(true | false)` átadja/visszaadja a régi EventController pingjét, a forrás módosítása nélkül. A zenei óra szerveridőn alapul, késés után nincs utólagos hangroham.

Settings → Music / Sound effects: külön 0–100% menthető; ± léptetés, középen némítás/visszaállítás. Az `audio:music.<százalék>` és `audio:sfx.<százalék>` meglévő, rate-limites intentcsatornán jut szerverre. Az AudioSettingsService validál, DataService-en át ír; a meglévő schema music/sfx mezői megmaradnak. MusicVolume/SfxVolume attribútumok a SoundGroupokra hatnak; karakterhangot, beszédet vagy más fejlesztő hangját nem némítja globálisan.

DEV: `audio music 0`, `audio sfx 50`, `sound Delivery`, `sound NewCustomer`, `sound HorseWarning`, `sound TornadoWarning`, `sound FloodWarning`, `sound BlizzardWarning`, `sound MegaWarning`. Ezek a valódi beállítás-/lejátszó API-t használják. A kliens AudioLastCue attribútuma, SoundService.PizzaAudio, annak Music/Preload attribútumai és az AudioCaptions GUI olvasható ellenőrzési pontok.

A forrás az új saját hangmodulokban van; az Event/HUD/Net/Debug controller forrása nem változik. Az eseményhangok integrációja a #19 feladat saját EventAudioControllerében van. Privát audio ID-ra váltáskor külön jogosultsági és telefonos hallgatási próba szükséges.

API-háttér: [Roblox SoundGroup](https://create.roblox.com/docs/reference/engine/classes/SoundGroup), [Sound objektumok](https://create.roblox.com/docs/sound/objects).

## #19 Eseménybekötés

Az EventAudioController a CityState publikus attribútumait figyeli; a replikációs változásokat egy frissítésbe vonja össze. Warning alatt eseményspecifikus hang és a némítástól független felirat jár, buildUp/active alatt a megfelelő háttérhangok. MEGA-ban legfeljebb két háttérhang és a saját arcade-zene szól. A `setAmbience({clipKeys})` idempotens, legfeljebb két loopot tart; windDown/reset/calm és destroy mindent leállít. A legfeljebb12 rövid voice mellett ez2 állandó loop, nem eseményenkénti korlátlan Sound-létrehozás.

Későn csatlakozó kliens az aktuális állapothoz igazodik, nem vár a következő fázisra. A régi EventController általános pingje ebben a módban néma, helyét a külön figyelmeztetések veszik át; destroy visszaadja az eredeti állapotát. A meglévő eseménybanner, visszaszámláló, tint és lóverseny-bemondó változatlanul ad vizuális párt. Nincs fizikai, veszély-, szerveres jutalom- vagy eseményidőzítés-módosítás.

A mixer a tartós hangerő-attribútumok megérkezéséig néma; késői MEGA-csatlakozás sem kerüli meg a mentett mute preferenciát.


## #146 Új események

CheeseWheel: mély landolási koppanás és lassított lépésminta ad gördülő-dübörgő karaktert. BubbleStorm: gyorsított úszás-warning és gyors vízminta. Blackout: lekapcsolás-jelzés, halk mély hang és három rövid, magas ciripelés 1,92 másodperces mintában. Minden minta a Roblox klienssel szállított hangokból készül; a ciripelés saját hangszintézis, nem külső felvétel. Figyelmeztetéseik magyarul is megjelennek, némításkor is.

A BlackoutAmbience opcionális detail mintája a meglévő, legfeljebb12 rövid SFX-voice-ot használja. Nem nyit harmadik ambience-loopot, MEGA-ban is2loop marad a korlát. A detail üteme szerveridős, ugyanazon lépés nem játszható újra, késés után nem pótolja a kihagyott ciripelést. A háttérhang eltávolítása törli a detail ütemállapotát, a rövid voice saját lejárata leállítja a már elindult hangot.

DEV: event CheeseWheel / Blackout / BubbleStorm; külön figyelmeztetéshez sound CheeseWarning / BlackoutWarning / BubbleWarning. A bolti változatok DisasterCheeseWheel / DisasterBlackout / DisasterBubbleStorm, egyedi, jelenleg0productId-val. QA: product <kulcs> a valódi pending-effect API-n indít, fizetés nélkül. A receipt élesítéséhez minden termék külön Creator Hub ID-t és valódi vásárlási próbát igényel.

## #188 Holdséta, meteor, pizzaeső, UFO és macska

Mind az öt esemény saját warning/ambience kulcsot és EN/HU figyelmeztetést kapott a korábbi helyettesítő profilok helyett. A holdséta lassított elektronikus csengés és halk mély hang; a meteor mély robbanásjelzés, szél és ritka távoli dübörgés; a pizzaeső magas koppanás és gyors, halk pergés; az UFO magas jel, búgás és rövid pásztázó pulzus; a macska mély jel és saját, szaggatott dorombolást idéző hangszintézis. Ezek a klienssel szállított minták hangmagasság-/ritmusváltozatai, nem állathangfelvételek vagy külső assetek.

A MeteorRumble/UfoPulse/CatPurr detail a meglévő12voice-os közös poolt használja, legfeljebb két ambience-loop mellett. A ritmus háttértextúra, nem egy tényleges becsapódás/mancscsapás/vonósugár időzítését jelzi; a veszélyek pontos helyét és idejét továbbra a meglévő vizuális jelölés adja. Némításkor is megjelenik a fontos warning-felirat. A detail nem tesz minden ütemre új feliratot a képernyőre, külön `sound <detail>` QA-előnézetnek van kétnyelvű szövege.

DEV: `event LowGravity`, `event MeteorShower`, `event PizzaRain`, `event UfoAbduction`, `event GiantCat`; az `event stop` a valódi reseten át törli a loopokat. Külön hangpróba: `sound MoonWarning|MeteorWarning|PizzaRainWarning|UfoWarning|CatWarning` (egy kulcsot válassz). A bolti kulcsok `DisasterLowGravity`, `DisasterMeteorShower`, `DisasterPizzaRain`, `DisasterUfoAbduction`, `DisasterGiantCat`, mindegyik49Robux árhipotézis és0productId, ezért éles vásárlásra még nem elérhetők. A külön, immutable eventId az outbox/újratöltés után is ugyanazt az eseményt választja; QA: `product <kulcs>`.
