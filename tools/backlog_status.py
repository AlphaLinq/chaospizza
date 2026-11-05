"""A backlog aktuális állapota és a felelősök (2026-11-05).

STATUS: az ISSUES lista 1-alapú sorszáma → (állapot, felelős, megjegyzés).
  állapot: "done"    → létrehozás után lezárjuk, a megjegyzés kommentbe kerül
           "partial" → nyitva marad, a megjegyzés kommentben mondja meg, mi van kész és mi hiányzik
           "open"    → nyitva, még nem kezdtük
  felelős: "claude" | "codex" | "human" → owner:<x> label

NEW_ISSUES: az eredeti 60 ticketen felüli, munka közben kiderült feladatok.
"""

from backlog import M, X, POST, body, issue

DONE_NOTE = "Kész és Studio MCP-n ellenőrizve (lásd `docs/HANDOFF.md`)."

STATUS = {
    # M0
    1: ("done", "claude", DONE_NOTE),
    2: ("done", "codex", "CI: StyLua 2.0.2, Selene, Luau-tesztek, Rojo build; luau-lsp típusjob advisory."),
    3: ("done", "claude", DONE_NOTE),
    4: ("done", "claude", "Net.luau: egyetlen remote-regisztráció, token bucket rate limit, Validate. " + DONE_NOTE),
    5: ("done", "claude", "DEV panel + DebugRun parancsok (order, deliver, event, chaos, giant, style, …)."),
    # M1
    6: ("done", "claude", "A szürkedobozos térkép kódból épül (Config/MapLayout → MapService). 14 cím, plaza, 12 telek, felüljáró."),
    7: ("done", "claude", "Idempotens jutalom, minimum utazási idő a teleport-farmolás ellen. " + DONE_NOTE),
    8: ("done", "claude", "Helyi célgyűrű, billboard, beam, képernyőszéli ▲ nyíl + távolság."),
    9: ("done", "claude", "Helyi Deliver prompt → DeliverOrder(orderId); szerveres távolság- és magasságellenőrzés."),
    10: ("done", "claude", "Coyote time + jump buffer. A kamera az alapértelmezett; finomhangolás játékteszt után."),
    11: ("partial", "human", "Alap Roblox-vezérlés + ≥44 px gombok. **Hiányzik:** valódi telefonos teszt (gombok átfedése, hüvelykujj-zóna)."),
    12: ("done", "claude", DONE_NOTE),
    13: ("done", "claude", "loading → pickup → deliver → again → done lépések; az első kézbesítés után lóverseny. Analytics funnel."),
    # M2
    14: ("done", "claude", "warning → buildUp → active → windDown → reset, pcall + takarítás; MEGA-kombináció és rendelt események sora."),
    15: ("partial", "claude", "Lovak, telegráfsávok, korlátok ajtórésekkel; működik. **Hiányzik:** a lovak mozgatása szerver-Heartbeat helyett kliensoldali animációval (teljesítmény)."),
    16: ("done", "claude", "KnockbackService: szerver dönt, a kliens alkalmazza; védelmi ablak, esésmentés."),
    17: ("done", "claude", "Unstuck gomb 10 s cooldownnal."),
    18: ("partial", "claude", "A CityState attribútumok replikálódnak. **Hiányzik:** célzott teszt arra, hogy esemény közben belépő játékos biztonságos helyen spawnol."),
    19: ("partial", "claude", "Banner, visszaszámláló, ping, égbolt-tint, hóesés. **Hiányzik:** eseményenkénti hangok és erősebb FX, EffectQuality-skálázással."),
    20: ("open", "human", "Játékteszt barátokkal: érthető-e a lóverseny figyelmeztetés nélkül?"),
    # M3
    21: ("done", "claude", "Útvonalkövető tölcsér, behúzás, ballisztikus kidobás biztonságos pontra, ajtó-menedék."),
    22: ("done", "claude", "Víz, ~41 úszó platform, mentés, cápauszony."),
    23: ("open", "claude", "Az áradás alatt az elárasztott címek ajtópontja most nem kerül magasabbra (`MapGeometry.highPoint` már megvan)."),
    # M4
    24: ("done", "claude", "CustomerOdds (normal/event/mega tábla) + pizzériaszint-bónusz + boost provider."),
    25: ("partial", "human", "24 + 5 szezonális vendég név/szöveg/ritkaság kész. **Hiányzik:** 3D modellek/animációk (most a vendégnek nincs modellje)."),
    26: ("done", "codex", "CustomerBookController: rács, ritkaságszínek, csillagok, ???/sziluett, mobilon is."),
    27: ("partial", "claude", "„NEW RARITY CUSTOMER!” popup + mérföldkő-jutalmak (Codex: ProgressRewardService) kész. **Hiányzik:** Legendary/Epic külön FX a HUD-ban."),
    28: ("done", "claude", "Eseményvendégek csak az eseményük alatt rendelnek; +50% eseménybónusz."),
    29: ("done", "claude", "stars = min(5, served-1)."),
    30: ("open", "human", "Gyűjtés-játékteszt (K2 kapu)."),
    # M5
    31: ("done", "codex", "Saját UpdateAsync session lock, verziózott séma (most v5), Studio memória-mock."),
    32: ("done", "claude", DONE_NOTE),
    33: ("done", "claude", "Eljárásos modellek az 1–6. szinthez, celebrate tween, F-es fejlesztés (első 75)."),
    34: ("done", "claude", "Ritka+ vendég első kiszolgáláskor leül, ha van hely."),
    35: ("partial", "claude", "A passzív bevétel 15 s-onként jóváírásra kerül. **Hiányzik:** a „befőttesüveg” begyűjtési mechanika (most automatikus jóváírás)."),
    36: ("done", "claude", "Offline bevétel betöltéskor (Tuning.Regulars offline*)."),
    37: ("done", "codex", "XP-görbe + szintenkénti tips jutalom (ProgressRewardService)."),
    38: ("partial", "codex", "4 szint, Ride fül, díszítő modellek, sebességek. **Nyitott:** a brief 3. szintje „Roller”, a Config/Movement „Roller Skates” — döntés kell."),
    39: ("done", "codex", "Napi 1 like látogatónként, „City favourite”. Kétklienses teszt hátra (#QA issue)."),
    40: ("done", "codex", "7 napos naptár, kihagyás nem nulláz, 7. nap kozmetika."),
    41: ("open", "human", "Visszatérés-teszt (K3 kapu)."),
    # M6
    42: ("done", "claude", "StyleService: Air delivery, Shark escape, Hoofbeat, Flawless, Lightning, Juggler; popup kiírja."),
    43: ("done", "claude", "Plaza-mérő + HUD-sáv; MEGA: két esemény, 75 s, ×3, top 3 kiírás."),
    44: ("partial", "codex", "WeeklyChallenges + DailyService + UI kész. **Hiányzik (Claude):** `DailyService.recordProgress` hívása a valódi kézbesítéseknél."),
    # M7
    45: ("done", "claude", "GiantOrderService: 2–4 cipelő, leesés/újrafelvétel, Rare+ vendég, +25%, Juggler, teleport elleni védelem. Solo-debug módban tesztelve; kétklienses teszt a QA issue-ban."),
    46: ("done", "claude", "+10% Roblox-baráttal (IsFriendsWith, cache-elve)."),
    # M8
    47: ("done", "codex", "Idempotens ProcessReceipt, ReceiptLedger, pending effects outbox."),
    48: ("partial", "claude", "Gamepass-tulajdon lekérdezhető (`hasPass`). **Hiányzik:** DoubleTips/VIP hatás bekötése az Order/Giant borravalóba (`getTipMultiplier`)."),
    49: ("partial", "claude", "Codex: boostok, csomagok, StarterPack, időzítők a boltban. **Hiányzik (Claude):** TipBoost szorzó a kézbesítési borravalóban."),
    50: ("partial", "codex", "Eseményoldal kész (sor, canOrder, +100% mindenkinek, Rare+ vásárlói bónusz, „Thanks!” gomb). **Hiányzik:** eseményválasztó a boltban (most fix Tornado) + `EventService.canOrder` a prompt előtt; Claude: crash-biztos nyugtázás."),
    51: ("done", "claude", "MegaChaosNow pending → `EventService.requestMega(\"purchase\")`. Valódi Robux még nem tesztelt (ID=0)."),
    52: ("done", "codex", "Passes/Boosts/Tips/Looks/Ride fülek, odds, tiltási okok, timeoutok."),
    53: ("done", "codex", "Tulajdon/felszerelés, ViewportFrame előnézet, tips-vásárlás, díszítő modellek."),
    # M9
    54: ("done", "claude", "Dec 1 – jan 6 ablak, jeges utak, hógolyók, hóesés."),
    55: ("partial", "codex", "5 karácsonyi vendég kész. **Hiányzik:** Mikulás-futár kozmetikai szett."),
    56: ("done", "codex", "AnalyticsService: funnel + economy + custom események; second_session."),
    57: ("open", "claude", "Mérés kell: part/instance budget eseményenként, részecskék EffectQuality szerint, MicroProfiler telefonon."),
    58: ("open", "human", "Codex előkészíti a store-szövegeket; a bélyegképekhez képernyőképek/render kell."),
    59: ("open", "human", "Zárt teszt barátokkal, hibalista issue-kba."),
    60: ("open", "human", "Creator Hub: termék/gamepass ID-k a Config/Products-ba, korhatár-kérdőív, szerverméret 12."),
}

C, CX, H = "owner:claude", "owner:codex", "owner:human"

NEW_ISSUES = [
    # ── Claude ──
    issue("Borravaló-szorzók bekötése (DoubleTips, VIP, TipBoost)", M[8], ["type:monetization", "P0", X, C], body(
        "A Codex `MonetizationService.getTipMultiplier(player)` API-ja kész, de a kézbesítési borravaló még nem használja.",
        ["OrderService és GiantOrderService: tips × getTipMultiplier a plafonok után, MEGA előtt",
         "A popup jelezze a boostot (pl. „×2 BOOST”)",
         "Debug: `product TipBoost` után kézbesítés → dupla borravaló"],
        ["Aktív TipBoost mellett a kézbesítés kétszer annyit ad, lejárat után normál",
         "A szorzó nem halmozódik a plafon fölé (Codex: plafon 4)"])),
    issue("Heti kihívások: recordProgress a hiteles eseményeknél", M[6], ["type:feature", "P1", X, C], body(
        "A `DailyService.recordProgress(player, event, amount)` Codex API-t hívni kell a szerveres kézbesítésekből.",
        ["delivery: minden normál és óriás kézbesítés", "eventDelivery: veszély alatti kézbesítés",
         "newCustomer: új vendég a könyvben", "Egy kézbesítés csak egyszer számít"],
        ["A heti CityCourier feladat valódi kézbesítéssel halad (nem csak debuggal)"])),
    issue("EffectQuality alkalmazása az esemény-FX-ben", M[9], ["type:tech", "P1", X, C], body(
        "A Codex SettingsController beállítja a `EffectQuality` attribútumot (low/medium/high), az FX még nem olvassa.",
        ["EventController: hóesés, tint, részecskék × Settings.particleScale",
         "Low: kevesebb részecske, nincs extra effekt"],
        ["Low beállítással a hóesés rate ~25%, Highnál 100%"])),
    issue("Rendelt esemény: crash-biztos nyugtázás", M[8], ["type:monetization", "P1", X, C], body(
        "A Codex jelezte: a DisasterOrderService a pending effectet előbb fogyasztja el, csak utána állítja sorba az eseményt. Ha közben összeomlik a szerver, a vásárlás elveszhet.",
        ["Idempotens enqueue effect-id alapján, utána consumePending",
         "Szerverleállásnál a sorban álló, még el nem indult rendelt esemény maradjon pending"],
        ["Kétszer futó pump nem indít két eseményt", "Leállás után a vásárlás nem vész el"])),
    issue("Típusdiagnosztikák javítása (luau-lsp 1.70.1)", M[0], ["type:tech", "P2", C], body(
        "A Codex C18-ban listázott 13 diagnosztika a Claude-fájlokban (Net, Bootstrap, EventService, StyleService, CustomerService, GiantOrderService, DisasterOrderService).",
        ["pcall-visszatérési értékek típusai", "StyleService hazard-tábla típus", "GiantOrderService rarityWeights union",
         "IsFriendsWith → IsFriendsWithAsync"],
        ["A teljes src luau-lsp elemzése 0 hibát ad"])),
    issue("Lovak kliensoldali animálása", M[2], ["type:tech", "P1", X, C], body(
        "Most a szerver Heartbeatben mozgatja a lómodelleket (sok replikált CFrame). A szerver csak a pályát és az időt küldje, a kliens animáljon, a találatot a szerver számolja.",
        ["Pályaadat attribútumban (sáv, irány, indulási idő)", "Kliens: helyi modell + tween", "Szerver: találat a számolt pozícióval"],
        ["Hálózati forgalom lóverseny alatt jelentősen csökken", "A találatok ugyanott történnek, mint eddig"])),
    # ── Codex ──
    issue("Bolt: eseményválasztó a „Rendelj egy katasztrófát!”-hoz", M[8], ["type:ui", "P0", X, CX], body(
        "Most a OrderDisaster fix Tornado eseményt ad. A játékos válasszon: lóverseny / tornádó / áradás (+ hóvihar szezonban).",
        ["A választás a pending effect `eventId` mezőjébe kerül", "Prompt előtt `EventService.canOrder(eventId)` → tiltás okkal",
         "Csak engedélyezett, szezonban lévő események látszanak"],
        ["Teli sornál / MEGA alatt nem lehet vásárolni, és a bolt megmondja, miért"])),
    issue("Mikulás-futár kozmetikai szett", M[9], ["type:content", "P1", X, CX], body(
        "A brief szerint a karácsonyi tartalom része a Mikulás-futár szett (doboz, táska, sapka-szerű díszítés, pizzériadísz).",
        ["Config/Cosmetics bejegyzések, szezonális jelölés", "Megszerzés: tips vagy hóvihar-kihívás", "Előnézet a Looks fülön"],
        ["Hóvihar szezonon kívül nem vásárolható, de a tulajdon megmarad"])),
    issue("Store-szöveg, leírás, ikon/bélyegkép terv", M[9], ["type:launch", "P0", X, CX], body(
        "Angol és magyar store-leírás, rövid pitch, kulcsszavak; bélyegkép- és ikon-képterv (mit mutasson, milyen szöveg).",
        ["docs/STORE.md: cím, rövid és hosszú leírás EN/HU", "3 bélyegkép-koncepció, 1 ikon-koncepció",
         "Kerülendő: „Steal a…” stílusú elnevezés (AGENTS 9)"],
        ["A szövegek a briefhez igazodnak, és nem ígérnek olyat, ami nincs a játékban"])),
    issue("Teljesítmény-mérő debug parancs és budget", M[9], ["type:tech", "P0", X, CX], body(
        "Mobilteljesítményhez: `perf` debug parancs (instance-szám, eseménymappák mérete, aktív részecske-emitterek, hálózati becslés), budget a Configban.",
        ["Új saját PerfService + Config/Perf", "Figyelmeztetés, ha egy esemény túllépi a budgetet", "docs/PERF.md mérési útmutató telefonon"],
        ["`perf` mindhárom esemény alatt értelmes számokat ad"])),
    issue("Hangrendszer és vizuális megfelelők", M[2], ["type:feature", "P1", X, CX], body(
        "Config/Sounds + SoundController: UI-hangok, kézbesítés, új vendég, MEGA. Minden fontos hangnak legyen vizuális párja (AGENTS 4.8).",
        ["Csak Roblox által engedélyezett hangazonosítók, Configban", "Hangerő a Settingsben", "API az eseményhangokhoz (Claude köti be)"],
        ["Némítva is minden fontos jelzés látható"])),
    issue("„Hogyan játssz” súgópanel", M[1], ["type:ui", "P2", X, CX], body(
        "Rövid, képes súgó: rendelés, események, vendégkönyv, pizzéria, óriás rendelés.",
        ["Gomb a Settings alatt vagy a Settings panelben", "Mobilon görgethető"],
        ["Új játékos 30 mp alatt átlátja a játék célját"])),
    # ── Ember ──
    issue("Kétklienses QA: óriás rendelés, like, kozmetika, Thanks gomb", M[7], ["type:playtest", "P0", X, H], body(
        "A Studio MCP csak egy játékost tud; ezeket Studio → Test → Clients and Servers (2 kliens) módban kell kipróbálni.",
        ["Óriás rendelés 2 cipelővel (E prompt!), leejtés, újrafelvétel", "Pizzéria-like a másik játékos telkén",
         "Rendelt esemény: a másik kliensen „Thanks” gomb", "Kozmetikák látszanak a másik kliensen"],
        ["Minden pont működik, vagy a hibák külön issue-ba kerülnek"])),
    issue("Döntés: 3. mozgáseszköz — Roller vagy Roller Skates?", M[5], ["type:content", "P2", X, H], body(
        "A brief 3. szintje „Roller”, a Config/Movement „Roller Skates”. A Codex a configot valósította meg.",
        ["Döntés kommentben", "A Config vagy a brief igazítása"],
        ["A brief és a config egyezik"])),
]

# ── 2. kör: további Codex-feature-ök (2026-11-05) ──
OWN = ("Csak saját új fájlok; Claude fájljaihoz (Order/Event/Style/Chaos/Giant/Disaster/Pizzeria/Map/HUD/"
       "Event/Order controller, Tuning, MapLayout, Net) ne nyúlj. Ha bekötési pont kell, a publikus API-kat "
       "használd (pl. `OrderService.onDelivered`, `EventService.onStarted/onEnded`, `CustomerService` jelek), "
       "vagy kérd a HANDOFF-ban / issue-kommentben.")

NEW_ISSUES += [
    issue("Promóciós kódok (Codes) rendszer", M[8], ["type:feature", "P1", X, CX], body(
        "Roblox-játékokban a kódok (Twitter/Discord/YouTube) a legolcsóbb marketing. Egyszer beváltható kódok tips/kozmetika jutalommal.",
        ["Config/Codes: kód → jutalom, lejárat (UTC), opcionális minimum szint", "CodesService: beváltás egy DataService-tranzakcióban, profilban ledger",
         "UI a Settings panelben: beíró mező + visszajelzés", "Rate limit és kis-/nagybetű-független összehasonlítás", OWN],
        ["Ugyanaz a kód játékosonként csak egyszer működik, újracsatlakozás után is", "Lejárt / ismeretlen kódnál barátságos hibaüzenet",
         "Tesztek: lejárat, ismétlés, rossz bemenet, plafon"])),
    issue("Roblox-badge-ek (achievementek)", M[9], ["type:feature", "P1", X, CX], body(
        "Badge-ek az első pillanatokra: első kézbesítés, első tornádós légi kézbesítés, első MEGA, 10/24 vendég, pizzéria 6. szint, óriás rendelés.",
        ["Config/Badges (badgeId=0, amíg nincs létrehozva)", "BadgeService burkoló: AwardBadge retry-jal, a profilban ledger, hogy ne hívja feleslegesen",
         "Triggerek a publikus jelekből (onDelivered, EventService.onEnded, Book/Pizzeria attribútumok)", OWN],
        ["ID=0-nál nem hív Roblox API-t, csak logol", "Minden trigger debug paranccsal kipróbálható"])),
    issue("Barát meghívása + csatlakozási jutalom", M[7], ["type:feature", "P1", X, CX], body(
        "„Hívd be a barátodat” mechanika (a brief 13. fejezete): meghívó gomb és kis jutalom, ha egy barát ténylegesen csatlakozik.",
        ["SocialService:PromptGameInvite gomb (mobilon is)", "Ha egy Roblox-barát ugyanarra a szerverre jön: mindkettő +tips, naponta limitálva",
         "Profilban napi ledger a visszaélés ellen", OWN],
        ["Ugyanaz a barát naponta csak egyszer ad jutalmat", "Alt-fiókokkal nem farmolható (barátság + minimum játékidő)"])),
    issue("Roblox-csoport (közösség) jutalom", M[8], ["type:monetization", "P2", X, CX], body(
        "Egyszeri kozmetikai jutalom, ha a játékos tagja a játék Roblox-csoportjának. Statisztikai előnyt nem ad.",
        ["Config: groupId (0, amíg nincs csoport)", "Belépéskor IsInGroup pcall-lal, egyszer jóváírva", "„Join our group” tipp a boltban", OWN],
        ["groupId=0 esetén a funkció kikapcsol", "A jutalom tartós és egyszeri"])),
    issue("Futárprofil és statisztika panel", M[5], ["type:ui", "P2", X, CX], body(
        "Saját és mások profilja: kézbesítések, futárszint, a legritkább vendég, a könyv kitöltöttsége, a pizzéria szintje, like-ok, cím.",
        ["ProfileController: panel a HUD-overlay szabály szerint", "Más játékosra koppintva (vagy a listából) a profilja nyílik",
         "Szerveroldali, csak olvasható összesítő a meglévő profiladatokból", OWN],
        ["Mobilon 360 px szélességben is olvasható", "Nincs új adat, amit a kliens írhatna"])),
    issue("Pizzéria-látogató menü (teleport a telkekhez)", M[5], ["type:feature", "P2", X, CX], body(
        "A szerveren lévő pizzériák listája (tulajdonos, szint, like-ok), egy gombbal odateleportál a telek elé.",
        ["Lista az OwnerUserId attribútumos pizzériamodellekből", "Teleport: a `CharacterService.teleport`-ot hívja, esemény alatt tiltva",
         "„City favourite” kiemelés a listában", OWN],
        ["Aktív esemény alatt nem lehet teleportálni (ne legyen menekülési exploit)", "Cooldown"])),
    issue("Emote-kerék (ingyenes + kozmetikai emote-ok)", M[8], ["type:feature", "P2", POST, CX], body(
        "Klipelhető pillanatok: tánc, pizzadobás-póz, integetés. Néhány ingyenes, a többi kozmetikaként (tips).",
        ["EmoteController: kerék, mobilon érinthető", "A Cosmetics katalógusba új kategória", "Szerveres tulajdonellenőrzés", OWN],
        ["Az emote nem ad előnyt, és nem szakít meg rendelést"])),
    issue("Heti ranglista-jutalom és cím", M[6], ["type:feature", "P2", POST, CX], body(
        "A heti kiszállítási ranglista top 10-e hétfőn címet és kozmetikát kap.",
        ["Hétváltáskor a LeaderboardService rögzíti a top 10-et", "Jutalom a következő belépéskor (pending)", "Cím a profilban"],
        ["Egy hét jutalma csak egyszer jár", "Több szerveres rangsor mellett is konzisztens"])),
    issue("Gazdaság-szimulátor (hangolási eszköz)", M[5], ["type:tech", "P1", X, CX], body(
        "Tiszta Luau/Python szimuláció a Config alapján: mennyi idő az első fejlesztés, a 6. szint, egy teljes Vendégkönyv átlagos, lelkes és pénzköltő játékossal.",
        ["tools/economy_sim.luau: a valódi Config- és Util-modulokat használja", "Kimenet: docs/ECONOMY.md táblázat + javaslatok",
         "Események, stílusbónusz, törzsvendégek, boostok figyelembevétele"],
        ["A brief 5. fejezetének célja (első fejlesztés < 3 perc) ellenőrizhető", "Futtatható CI-ben is (advisory)"])),
    issue("Automatikus Studio-füstteszt (debug parancs-sorozat)", M[0], ["type:tech", "P1", X, CX], body(
        "Egyetlen `smoke` debug parancs, ami végigfuttatja a fő folyamatokat (rendelés, kézbesítés, események, bolt-preview, napi jutalom), és PASS/FAIL listát ad.",
        ["SmokeService: csak Studióban / DEV_USER_IDS mellett", "A meglévő debug API-kat hívja, a játékállapotot a végén visszaállítja",
         "docs/QA.md: hogyan futtasd MCP-vel"],
        ["Egy futás < 2 perc, és minden lépéshez ad eredményt", "Élesben elérhetetlen"])),
    issue("Akadálymentesség: színvak-barát ritkaságjelölés + szövegméret", M[9], ["type:ui", "P1", X, CX], body(
        "A ritkaság ne csak színnel látsszon (ikon/betű), a Settingsben legyen szövegméret-állítás.",
        ["Ritkaság-ikonok a Book/Shop UI-ban", "Settings: szövegméret (normál/nagy), a Codex UI-kra alkalmazva",
         "Claude-nak API a HUD-hoz: `Settings.textScale(player)`"],
        ["Nagy szövegnél 360 px-en sincs levágás"])),
    issue("Lokalizáció: magyar + angol UI-szövegek", M[9], ["type:content", "P2", POST, CX], body(
        "A Codex által készített UI-k szövegei LocalizationTable-be kerülnek (en, hu), és utána a Claude-féle HUD-szövegek is.",
        ["Config/Strings vagy LocalizationTable-generátor", "Fallback angolra", "A bolt/odds szövegei pontosak maradnak"],
        ["Magyar nyelvű Roblox-fiókkal magyarul jelenik meg a saját UI"])),
    issue("Konzol/gamepad navigáció a Codex UI-kban", M[9], ["type:ui", "P2", X, CX], body(
        "Book, Shop, Daily, Settings és Looks panel kontrollerrel is kezelhető legyen (SelectionGroup, NextSelection, B = bezárás).",
        ["GuiService.SelectedObject kezelése nyitáskor/záráskor", "Gombok fókuszjelzése"],
        ["Minden panel egérrel és érintéssel sem romlik el", "Gamepaddal minden művelet elérhető"])),
]

OWNER_LABELS = {
    "owner:claude": ("7057ff", "Claude dolgozik rajta"),
    "owner:codex": ("10a37f", "Codex dolgozik rajta"),
    "owner:human": ("f9d0c4", "Fejlesztő (ember) teendője: teszt, döntés, Creator Hub"),
}
