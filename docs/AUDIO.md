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

## #201 Mikro-káosz, szavazás és finálé

A saját LoopAudioController a publikus CityState MicroChaos/EventVote/FinaleAt/Finale attribútumait és a meglévő Hint eseményt olvassa. Nincs új remote, szavazatküldés, jutalomosztás vagy Claude-forrásmódosítás. Config/LoopAudio a gyakoriságokat/távolságot, Util/LoopAudio a tiszta egyszeri jelzés- és időzítési állapotot tartja.

Cart: egyetlen, láthatatlan, anchored helyi hangforrás követi a szerveridős pályát,16–70stud lineáris rolloff-fal és a közös SFX SoundGrouppal. Csak calm alatt,70studon belül él; távolodás, karakter hiánya, esemény/stop/lejárat vagy destroy eltávolítja. Ez egy helyi part és egy loop; a normál események legfeljebb2ambience-loopját nem növeli MEGA alatt. A geese hang a legközelebbi még látható libához mért közelségen alapul,2.4s kapuval. A gejzír warning és kilövés egyszer szól az adott, közelről megfigyelt szakaszban; késői belépő nem kap elmaradt kilövésjelzést. A liba-/kocsitextúra bundled Roblox-mintából készült hangszintézis, nem felvett állathang.

A dobozfelvételt, szavazási győztest és „Finale survived!” jelzést kizárólag a tényleges szerver-Hint megfelelő előtagja indítja. A szavazat kattanása a Vote1–3 gomb Activated, illetve7/8/9 billentyűs **kiválasztási szándék** visszajelzése nyitott ballotnál; nem szerveres elfogadási nyugta. A finálé notice a Tuning.Finale.noticeSeconds küszöbén egyszer szól, a legutolsó10másodpercben másodpercenként legfeljebb1tick, induláskor1kezdőhang. Az óra szerveridős, nincs utólagos tick-/honk-visszapótlás, a deadline apró elmozdulása sem játszik újra korábbi tick-et. Már futó fináléhoz csatlakozó nem hall utólag kezdőhangot.

Minden új one-shot a meglévő12voice-os poolban/SFX-csatornán fut, HU/EN felirattal, amely némításkor is megmarad. Az alap vizuális pár a kocsi/liba/tócsa/gejzír/doboz, illetve a meglévő szavazó- és finálé-HUD. A VoiceN Sound Cue attribútuma a QA-ban megmondja, melyik klipet használja az újrahasznált voice.

QA a meglévő debug API-kon: `micro cart|geese|sprinkler|boxes here`, `micro stop`, `tp A14`, `audio sfx 0|100`; `vote open`, a valódi HUD-gombok vagy7/8/9, majd a természetes calm-vége; `finale in 180`, `finale in 10`, `order new normal`, `deliver`, `event stop`. Az utóbbi rövidített QA, nem teljes75s finálétúlélés. Külön klippróba: `sound VoteCast|VoteWinner|FinaleNotice|FinaleTick|FinaleStart|FinaleSurvived` (egy kulcs egyszerre).

A régi párhuzamos munkamappában hiányzó MicroChaos/Tuning.Finale/Tuning.MicroChaos esetén az adapter egyszer figyelmeztet és letiltva marad; a Bootstrap többi modulját nem töri el. A saját hangfájlokat mindig a megfelelő producerverzióval integráld. Végső hallás szerinti hangerő/hangszín-hangolás, telefon/gamepad és natív szavazás-QA továbbra szükséges.

## #229 Arany pizza, roham, kitérő, éjszaka és címek

A BatchAudioController a qa-batch meglévő publikus állapotait figyeli: CityRush, Errand, FinaleHeroUntil, DayOffset és GoldenOrder. Az arany pizzát és a címet a szerver eredeti Hint-je jelenti be, így nincs attribútum-sorrendtől függő téves jingle. A roham kezdése széljel+dob, növekvő kombója egyetlen tick (ugráskor sem játssza vissza a kihagyott lépéseket), vége fanfár. A telefon csak új, el nem végzett kitérőnél cseng, a csomag felvétele egyszer jelez; törléskor nincs sikert jelző hang. A hőscsengő csak a saját új, még élő határidejére szól. Induló snapshot nem játszik vissza korábbi rohamot/telefont/hősjegyet.

A `setSpatialLoop(key?,position?,scope?)` két engedélyezett, fix helyet használ: alapértelmezett micro és golden. Az arany pizza loopja a legközelebbi tényleges PizzaBoxot követi (shiny vagy scuffed), 0.2 másodperces frissítéssel, 12–40 stud lineáris elhalkulással. Egyszerre legfeljebb egy aranydoboz szól; hiányzó karakter/doboz/attribútum, kézbesítés és destroy eltávolítja. Ez nem zavarja a kocsi külön emitterét. A két helyi part nem ütközik, nem query/touch és nem vet árnyékot.

A `setBed("NightAmbience" | nil)` halk éjszakai város/tücsök szintézis. Csak calm és a DayCycle szerint night állapotban él, esemény-ambience mellett a mixer is letiltja. Így a két globális eseményloop korlátja megmarad; a ciripelés a régi 12-es rövid voice-poolt használja, kihagyott ütemek pótlása nélkül. Hiányzó DayCycle producer esetén csak ez a háttér marad inaktív. Minden új klip a meglévő SFX-hangerőn szól, a fontos jelzésekhez EN/HU felirat jár némításkor is. A hangok bundled minták változatai, nem külső zene/felvétel.

QA: `golden`, `rush bot` / `rush end`, `errand call` / `errand grab`, `daytime night|day`, `titles bump loop.daredevil 10`, `finale now` → `order new normal` / `deliver` → `event stop`. A finálé leállítása után várd meg a windDown végét és a valódi hero-jutalmazást. Ezek a meglévő debug API-k, nem közvetlen szolgáltatás-require vagy attribútum-jutalom injektálás.
