"""Pizza Chaos 2.0 — fejlesztési backlog (GitHub issue-k forrása).

A tickets a docs/PIZZA_CHAOS_2_GAME_BRIEF.md 23. fejezetének mérföldköveit követik.
Feldolgozza: tools/create_backlog.py
"""

BRIEF = "docs/PIZZA_CHAOS_2_GAME_BRIEF.md"

LABELS = {
    # típus
    "type:feature": ("1f6feb", "Játékfunkció"),
    "type:tech": ("6e7781", "Technikai alap, infrastruktúra"),
    "type:content": ("a371f7", "Tartalom: vendégek, modellek, szövegek"),
    "type:ui": ("0e8a16", "Felület / HUD"),
    "type:monetization": ("d4a72c", "Bevétel: gamepass, developer product, bolt"),
    "type:analytics": ("bfd4f2", "Mérés, analitika"),
    "type:playtest": ("fbca04", "Játékteszt / döntési kapu"),
    "type:launch": ("e99695", "Kiadás, store, publikálás"),
    # prioritás
    "P0": ("b60205", "Nélküle nincs indulás"),
    "P1": ("d93f0b", "Fontos, indulásra kell"),
    "P2": ("c5def5", "Indulás után is jöhet"),
    # terjedelem
    "xmas-scope": ("2da44e", "A karácsonyi soft launch része"),
    "post-launch": ("ededed", "Indulás utáni frissítés"),
}

MILESTONES = [
    ("M0 – Projektalap", "Rojo, repó, CI, mappastruktúra, konfiguráció váza. Becslés: 6–10 óra."),
    ("M1 – Egy teljes kézbesítés", "Szürkedobozos város, rendelés, céljelzés, átadás, borravaló, mobil vezérlés. Becslés: 25–40 óra."),
    ("M2 – Eseményrendszer + lóverseny", "Állapotgép, ütemező, lóverseny, baleset/visszaállás. K1 döntési kapu. Becslés: 25–40 óra."),
    ("M3 – Tornádó + áradás/cápa", "Két további esemény, átadási pont áthelyezés, takarítás. Becslés: 30–50 óra."),
    ("M4 – Vendégek + Vendégkönyv", "Vendégsorsolás, 24 vendég, Vendégkönyv UI, esemény-vendégek. K2 kapu. Becslés: 30–45 óra."),
    ("M5 – Pizzéria + törzsvendégek + mentés", "Telkek, 6 szint, törzsvendégek, passzív/offline borravaló, mentés, mozgáseszközök. K3 kapu. Becslés: 35–55 óra."),
    ("M6 – Stílus + káosz-mérő + MEGA", "Stílus-kézbesítés címkék, városi káosz-mérő, MEGA-KÁOSZ. Becslés: 20–30 óra."),
    ("M7 – Óriás rendelés", "Kooperatív cipelés 2–4 játékosnak. Becslés: 20–35 óra."),
    ("M8 – Monetizáció", "Gamepassok, developer productok, Rendelj katasztrófát, bolt, kozmetikák. Becslés: 25–40 óra."),
    ("M9 – Karácsony + indulás", "Hóvihar, szezonális vendégek, analitika, mobil teljesítmény, store, zárt teszt. Becslés: 35–55 óra."),
]


def body(cel, feladatok, elfogadas, ref=None, megjegyzes=None):
    parts = [f"## Cél\n{cel}\n", "## Feladatok"]
    parts += [f"- [ ] {f}" for f in feladatok]
    parts.append("\n## Elfogadási feltételek")
    parts += [f"- [ ] {e}" for e in elfogadas]
    if megjegyzes:
        parts.append(f"\n## Megjegyzés\n{megjegyzes}")
    if ref:
        parts.append(f"\n**Terv:** `{BRIEF}` — {ref}")
    return "\n".join(parts)


def issue(title, milestone, labels, b):
    return {"title": title, "milestone": milestone, "labels": labels, "body": b}


M = [m[0] for m in MILESTONES]
X = "xmas-scope"
POST = "post-launch"

ISSUES = [
    # ───────────────────────── M0 ─────────────────────────
    issue("Rojo projekt és mappastruktúra létrehozása", M[0], ["type:tech", "P0", X], body(
        "Fájlalapú Roblox-projekt, amit Gitben verziózunk és Studióba szinkronizálunk.",
        ["Rojo telepítése (Aftman/Rokit) és `default.project.json`",
         "`src/server/Services`, `src/client/Controllers`, `src/shared/{Config,Types,Util}` létrehozása",
         "Egyszerű service/controller betöltő (bootstrap) szerver és kliens oldalon",
         "`.gitignore` a Roblox/Rojo build fájlokra",
         "README: hogyan indítsd a `rojo serve`-öt és csatlakozz Studióból"],
        ["`rojo serve` után Studióban megjelenik a struktúra",
         "Egy próba service és controller kiír egy sort az Outputba",
         "Új fejlesztő a README alapján 10 percen belül elindítja"],
        "21.1–21.2. fejezet")),
    issue("StyLua + Selene + GitHub Actions CI", M[0], ["type:tech", "P1", X], body(
        "Egységes kódstílus és automatikus ellenőrzés minden PR-on.",
        ["`stylua.toml`, `selene.toml` (roblox std)",
         "GitHub Actions workflow: stylua --check, selene",
         "Rövid leírás a README-ben"],
        ["Egy szándékosan rosszul formázott PR elbukik a CI-on", "A main branch zöld"],
        "21.1. fejezet")),
    issue("Konfigurációs táblák váza (shared/Config)", M[0], ["type:tech", "P0", X], body(
        "Minden hangolható szám egy helyen legyen, hogy kód nélkül lehessen egyensúlyozni.",
        ["`Tuning.lua` (mozgás, esemény-időzítések, borravaló alapértékek)",
         "`Rarities.lua`, `Customers.lua`, `Events.lua`, `Pizzeria.lua`, `Movement.lua`, `Products.lua` üres/minimális váza típusokkal",
         "Típusdefiníciók a `shared/Types` alatt"],
        ["A szerver és a kliens is be tudja tölteni a configot",
         "A brief kiinduló értékei (pl. ritkasági esélyek, pizzéria-költségek) szerepelnek"],
        "9.2, 11, 12.1, 18. fejezet")),
    issue("Hálózati réteg: szándék-alapú Remote-ok rate limittel", M[0], ["type:tech", "P0", X], body(
        "A kliens csak szándékot küldjön, a szerver ellenőrizzen; alap védelem spam ellen.",
        ["Központi Remote-regiszter (RemoteEvent/RemoteFunction létrehozás egy helyen)",
         "Játékosonkénti rate limit segédfüggvény",
         "Argumentum-típusellenőrzés segédfüggvény"],
        ["Másodpercenként 30+ kérés egy Remote-ra nem okoz hibát, csak eldobódik",
         "Rossz típusú argumentum nem dob kezeletlen hibát a szerveren"],
        "21.3. fejezet")),
    issue("Fejlesztői debug-panel (esemény indítás, pénz, reset)", M[0], ["type:tech", "P1", X], body(
        "Gyors tesztelés Studióban és privát szerveren.",
        ["Csak engedélyezett UserId-k / Studio számára látható panel",
         "Gombok: esemény indítása, borravaló adása, profil reset, idő gyorsítása"],
        ["Publikus szerveren nem érhető el (szerveroldali jogosultság-ellenőrzés)"],
        "1.0 brief 23.B")),

    # ───────────────────────── M1 ─────────────────────────
    issue("Szürkedobozos Pepperoni negyed térkép", M[1], ["type:content", "P0", X], body(
        "Egyszerű geometriájú város, amin a teljes játékmenet tesztelhető.",
        ["Közös tér (Plaza) középen, körülötte 12 pizzériatelek helye",
         "Széles főutca (lóverseny), mélyebb alsóváros (áradás), szökőkutas tér (tornádó)",
         "Oldalutcák, kapualjak, erkélyek, napellenzők, felüljáró",
         "12–16 kézbesítési cím fix azonosítóval + mindegyiknél jelölt magasabb átadási pont",
         "Biztonságos visszaállási pontok jelölése"],
        ["Átlagos fuvar a Plazáról 60–120 mp gyalog",
         "Minden fontos címhez legalább két útvonal vezet",
         "Nincs elakadásra alkalmas rés vagy láthatatlan fal a fő utakon"],
        "6. fejezet")),
    issue("OrderService: rendelés létrehozása, felvétele és jutalma", M[1], ["type:feature", "P0", X], body(
        "Szerveroldali rendeléskezelés, ami a teljes játék gerince.",
        ["Rendelés objektum: id, játékos, cím, vendég (egyelőre placeholder), típus, állapot",
         "Felvétel a pizzéria pultjánál",
         "Egy aktív rendelés játékosonként",
         "Kézbesítéskor borravaló + XP jóváírás (EconomyService váz)",
         "Kilépéskor a rendelés törlődik"],
        ["Ugyanazért a rendelésért ismételt kérésre sem jár második jutalom",
         "Két játékos rendelése soha nem keveredik",
         "Más játékos nem tudja leadni az én rendelésemet"],
        "8. fejezet")),
    issue("Céljelzés: irány-nyíl, fénycsík, távolság", M[1], ["type:ui", "P0", X], body(
        "A játékos mindig tudja, hová viszi a pizzát.",
        ["Világban látható jelölő a cím felett",
         "Képernyő-szélső irány-nyíl, ha a cél nem látszik",
         "Opcionális fénycsík a talajon az első 2 fuvarnál",
         "Áradáskor a jelölő a magasabb átadási pontra ugrik"],
        ["Mobilon sem takarja a veszélyeket", "Az első tesztelők segítség nélkül megtalálják a címet"],
        "8., 20. fejezet")),
    issue("Átadás interakció és szerveroldali ellenőrzés", M[1], ["type:feature", "P0", X], body(
        "Egyetlen kontextusfüggő gombbal lehessen felvenni és átadni.",
        ["ProximityPrompt vagy saját kontextusgomb PC-n (E) és mobilon",
         "Szerver: távolság-, rendelés- és címellenőrzés",
         "Átadási animáció ≤ 2 mp, nem blokkolja a mozgást"],
        ["Távolról / rossz címen nem lehet leadni", "Mozgás közben is működik"],
        "8., 21.3. fejezet")),
    issue("Mozgás és kamera hangolása", M[1], ["type:feature", "P0", X], body(
        "Megbocsátó, kellemes harmadik személyű mozgás.",
        ["Coyote time és jump buffer (0,10–0,15 mp, configból)",
         "Alap futósebesség hangolása, nincs sprint",
         "Harmadik személyű kamera, ütközés-kezelés szűk utcákban",
         "Ragdoll utáni gyors irányítás-visszaadás előkészítése"],
        ["A karakter nem akad be díszítőelemekbe", "Peremről lelépés után is lehet ugrani"],
        "7. fejezet")),
    issue("Mobil vezérlés és gombkiosztás", M[1], ["type:ui", "P0", X], body(
        "A mobil az elsődleges platform.",
        ["Nagy ugrás- és kontextusgomb, joystick", "Gombok nem takarják az ugrási felületeket",
         "Teszt valódi telefonon (iOS vagy Android)"],
        ["Egy teljes kézbesítés kényelmesen teljesíthető telefonon",
         "Az eredmény és a tesztelt eszköz le van írva az issue-ban"],
        "7., 21.5. fejezet")),
    issue("Alap HUD: cím, pizza, borravaló", M[1], ["type:ui", "P0", X], body(
        "Minimális, olvasható felület futás közben.",
        ["Aktív cím + vendég neve", "Pizza birtoklás ikon", "Borravaló számláló pörgő animációval",
         "Helyfoglaló a káosz-mérőnek és esemény-figyelmeztetésnek"],
        ["Kis mobilképernyőn sem lóg ki / nem fed át"],
        "20. fejezet")),
    issue("Onboarding: az első 3 perc", M[1], ["type:feature", "P0", X], body(
        "3 percen belül: kézbesítés, első vendég, első esemény, első fejlesztés.",
        ["Megjelenés a saját büfékocsi mellett, rövid felirat",
         "Első rendelés közeli címre, fénycsíkkal",
         "Második rendelés közben garantált lóverseny (ha a szerveren épp nincs esemény)",
         "Második kézbesítés után elég pénz az első fejlesztésre",
         "Funnel analitika esemény minden lépésnél (M9-ben bekötve)"],
        ["Új tesztelő segítség nélkül végigmegy", "Nincs bolt-felugró az első 3 percben"],
        "5. fejezet",
        "A vendégkönyv és pizzériafejlesztés lépése az M4/M5 után kerül élesbe; addig helyfoglaló.")),

    # ───────────────────────── M2 ─────────────────────────
    issue("EventService: esemény-állapotgép és ütemező", M[2], ["type:tech", "P0", X], body(
        "Közös, szerveroldali eseményrendszer, amire minden katasztrófa épül.",
        ["Állapotok: előjel → felépülés → aktív → lecsengés → visszaállítás",
         "Ütemező: nyugodt szakasz 90–150 mp, aktív 30–45 mp (configból)",
         "Esemény-interfész (Start/Tick/Stop/Cleanup), regisztráció",
         "Sor (queue) a későbbi megrendelt eseményekhez",
         "Állapot replikálása klienseknek"],
        ["Két normál esemény soha nem fut egyszerre",
         "Egy esemény hibája után a város biztonságos alapállapotba kerül",
         "Debug-panelről bármelyik esemény indítható"],
        "12. fejezet, 1.0 brief 10. fejezet")),
    issue("Lóverseny esemény", M[2], ["type:feature", "P0", X], body(
        "Az első, legolvashatóbb katasztrófa: a főutca lóversenypályává válik.",
        ["Előjel: bemondó, zászlók, korlátok megjelennek",
         "Lovak előre megadott útvonalon, hullámokban (nincs AI)",
         "Átkelési rések a hullámok között, felüljáró mint biztonságos kerülő",
         "Ütközés: rövid, túlzó kilökés, majd visszaállás",
         "Takarítás: minden ideiglenes elem eltűnik"],
        ["A következő hullám iránya és ideje felismerhető",
         "A korlátok soha nem zárnak el minden utat",
         "Mobilon stabil a képkockaszám"],
        "12.3. fejezet, 1.0 brief 13. fejezet")),
    issue("Baleset, ragdoll és visszaállás", M[2], ["type:feature", "P0", X], body(
        "A baleset vicces és rövid legyen.",
        ["Ragdoll / túlzó animáció, automatikus felállás", "A pizza a futárnál marad",
         "2–3 mp védelem azonnali ismételt találat ellen",
         "Térképről kiesés esetén visszahelyezés biztonságos pontra"],
        ["Nincs megszakíthatatlan elkapási ciklus", "A baleset után < 3 mp-en belül újra irányítható"],
        "1.0 brief 15. fejezet")),
    issue("Elakadásból mentés (ingyenes)", M[2], ["type:feature", "P1", X], body(
        "Menüből elérhető, ingyenes kimentés.",
        ["Gomb a menüben, cooldownnal", "Legközelebbi biztonságos pontra visz, ami nem közelebb a célhoz"],
        ["Nem használható rövidítésként"],
        "1.0 brief 15. fejezet")),
    issue("Esemény közbeni belépés és takarítás tesztelése", M[2], ["type:tech", "P0", X], body(
        "Robusztus eseményrendszer több klienssel.",
        ["Esemény közben belépő játékos a jelenlegi állapotot kapja",
         "Kilépő kliens nem állítja meg az eseményt",
         "Tesztforgatókönyv leírása (Studio: több kliens)"],
        ["10 egymást követő esemény után sincs ottmaradt tárgy", "A belépő védett ponton indul aktív esemény alatt"],
        "21.4. fejezet")),
    issue("Esemény FX és hang alapok", M[2], ["type:feature", "P1", X], body(
        "Az előjel hang nélkül és hanggal is érthető legyen.",
        ["Eseményenként: hangjelzés, ég színváltás, képernyő-figyelmeztetés ikonnal",
         "Bemondó szövegbuborékok a lóversenyhez",
         "Effekt-minőség beállítás (alacsony/normál)"],
        ["A fontos hangjelzéseknek van vizuális megfelelője"],
        "20. fejezet, 1.0 brief 20. fejezet")),
    issue("K1 döntési kapu: lóverseny-játékteszt", M[2], ["type:playtest", "P0", X], body(
        "Igazolni, hogy a káosz közbeni kézbesítés vicces és érthető.",
        ["3–5 tesztelő, legalább 2 mobilon", "Megfigyelés a brief 22. fejezete és az 1.0 26. fejezete kérdései alapján",
         "Eredmények és döntés leírása ebben az issue-ban",
         "Karácsonyi terjedelem újragondolása a tényleges tempó alapján"],
        ["Döntés: tovább / javítás / irányváltás — dokumentálva"],
        "23.2. fejezet")),

    # ───────────────────────── M3 ─────────────────────────
    issue("Tornádó esemény", M[3], ["type:feature", "P0", X], body(
        "Mozgó veszélyzóna, ami felkap és ellenőrzött területre dob ki.",
        ["Kijelölt útvonalak a téren és utcákon", "Külső zóna: sodró hatás; belső zóna: felemelés pár mp-re",
         "Kidobás előre ellenőrzött, használható területre",
         "Menedékek (kapualjak) jelölése", "Repülő díszelemek korlátozott számban"],
        ["Senki nem esik ki a térképről", "Nincs végtelen elkapási ciklus", "A rendelés folytatható marad"],
        "1.0 brief 11. fejezet")),
    issue("Áradás + cápa esemény", M[3], ["type:feature", "P1", X], body(
        "Az alsóváros vízzé válik, úszó platformokkal és cápával.",
        ["Emelkedő vízfelület (nincs vízszimuláció)", "Állapotot váltó platformok: autótetők, bútorok",
         "Cápa előre megadott útvonalon, jelzett közeledéssel", "Vízbe esés: komikus mentés biztonságos pontra"],
        ["Minden aktív címhez van járható út", "A víz levonulásakor senki nem szorul be"],
        "1.0 brief 12. fejezet",
        "Ha a karácsonyi dátum szűk, ez januárra csúszhat (23.1. fejezet) — döntés a K1 kapunál.")),
    issue("Átadási pont áthelyezése áradáskor", M[3], ["type:feature", "P1", X], body(
        "Áradáskor egyetlen cím se legyen teljesíthetetlen.",
        ["Címenként magasabb átadási pont aktiválása áradáskor", "Céljelzés és szerver-ellenőrzés követi"],
        ["Áradás közben minden cím teljesíthető"], "1.0 brief 7.3. fejezet")),

    # ───────────────────────── M4 ─────────────────────────
    issue("CustomerService: vendégsorsolás ritkasággal", M[4], ["type:feature", "P0", X], body(
        "Minden rendelés egy vendéghez szól, akit a szerver sorsol.",
        ["Vendégkészlet a configból (név, ritkaság, esemény, szöveg, modell)",
         "Súlyozott sorsolás: normál / esemény / MEGA táblák",
         "Módosítók: pizzériaszint, futárszint, aktív csalogató",
         "Determinisztikus tesztelhetőség (seed a debug-panelből)"],
        ["10 000 szimulált sorsolás eloszlása a configot követi (±1%)", "A kliens nem befolyásolhatja a sorsolást"],
        "9.1–9.2. fejezet")),
    issue("Kezdő 24 vendég: modellek, nevek, szövegek", M[4], ["type:content", "P0", X], body(
        "A gyűjtés tartalma.",
        ["12 normál + 4 tornádó + 4 áradás + 4 lóverseny vendég (lista a briefben)",
         "Nagy fejű, túlzó sziluettű modellek (lehet egyszerű R15 + kiegészítők)",
         "Átadáskori 1 soros vicces szöveg (angol + magyar)",
         "Póz / idle animáció a pizzériába"],
        ["Minden vendég távolról felismerhető", "Mind szerepel a Customers configban"],
        "9.3. fejezet")),
    issue("Vendégkönyv felület", M[4], ["type:ui", "P0", X], body(
        "A gyűjtemény, amit ki akarnak tölteni.",
        ["Rács, ritkaság szerinti színekkel", "Ismeretlen vendég sziluettel és tippel",
         "Vendég részletei: csillagok, hányszor kiszolgálva", "Haladás kijelzése (x/24)"],
        ["Mobilon görgethető, olvasható", "Az új vendég azonnal megjelenik"],
        "9.4. fejezet")),
    issue("„ÚJ VENDÉG!” pillanat és mérföldkő-jutalmak", M[4], ["type:feature", "P1", X], body(
        "Az új vendég első kiszolgálása legyen ünnepélyes.",
        ["Átadáskor ÚJ! animáció, ritkaság szerinti effekt (Legendásnál a szerver is látja)",
         "Mérföldkövek: 5/10/15/20/24 → pénz, kozmetika, cím"],
        ["Egy mérföldkő jutalma egyszer jár"], "9.4. fejezet")),
    issue("Esemény-vendégek, átcímzés és eseménybónusz", M[4], ["type:feature", "P0", X], body(
        "A legjobb vendégek a veszélyben vannak.",
        ["Esemény alatt az eseménytábla él", "Aktív rendelés opcionális átcímzése esemény-vendéghez",
         "+50% borravaló esemény alatti kézbesítésért (config)"],
        ["Esemény végén a még élő esemény-rendelés teljesíthető marad"], "12.2. fejezet")),
    issue("Csillagrendszer (ismételt kiszolgálás)", M[4], ["type:feature", "P2", X], body(
        "Ok arra, hogy ugyanazt a ritka vendéget újra elkapd.",
        ["Vendégenként 1–5 csillag ismételt kiszolgálásért", "Csillag növeli a törzsvendég termelését (+20%/csillag)"],
        ["Mentve van, megjelenik a könyvben"], "9.1., 10. fejezet")),
    issue("K2 döntési kapu: gyűjtés-játékteszt", M[4], ["type:playtest", "P0", X], body(
        "Igazolni, hogy a vendéggyűjtés motivál.",
        ["Mennek-e a veszélybe ritka vendégért?", "Megnyitják-e a Vendégkönyvet önként?",
         "Eredmény + döntés dokumentálása"],
        ["Döntés dokumentálva"], "23.2. fejezet")),

    # ───────────────────────── M5 ─────────────────────────
    issue("DataService: mentés session lockkal", M[5], ["type:tech", "P0", X], body(
        "Biztonságos, tartós játékosadat.",
        ["ProfileStore (vagy saját burkoló session lockkal)",
         "Séma verzióval + migráció", "Adat: pénz, XP, vendégkönyv, csillagok, pizzéria, törzsvendégek, mozgás, kozmetikák, vásárlások",
         "Kilépéskori és periodikus mentés, BindToClose"],
        ["Szerverváltás / gyors újracsatlakozás nem duplikál és nem veszít adatot",
         "Studio-ban mock DataStore-ral tesztelhető"],
        "21.1. fejezet")),
    issue("Pizzériatelkek kiosztása a közös téren", M[5], ["type:feature", "P0", X], body(
        "Minden játékos kap egy telket a szerveren.",
        ["12 telek, belépéskor szabad telek kiosztása", "Kilépéskor a telek felszabadul és kiürül",
         "A telek a játékos mentett szintjén épül fel"],
        ["Teli szerveren sincs ütközés"], "11. fejezet")),
    issue("Pizzéria szintek 1–6 és átépülés-animáció", M[5], ["type:feature", "P0", X], body(
        "A fő fejlődési cél: büfékocsiból neon torony.",
        ["6 szint modellje (kezdetben egyszerű, később szép)", "Fejlesztés gomb, költségek configból",
         "Látványos átépülés, amit a szomszédok is látnak", "Szintenként nyíló funkciók (helyek, rendeléstípusok)"],
        ["Fejlesztés szerveroldalon ellenőrzött", "Mobilon nem esik a képkockaszám 12 pizzériával"],
        "11. fejezet")),
    issue("Törzsvendég-helyek és elhelyezés", M[5], ["type:feature", "P0", X], body(
        "A ritka vendégek beülnek a pizzériába.",
        ["Ritka+ vendég első kiszolgálása után felajánlás: beülhet egy szabad helyre",
         "Helyek kezelése (csere, eltávolítás) egyszerű UI-val", "Idle animáció a helyén",
         "Távolságfüggő elrejtés / LOD"],
        ["Helyek száma a pizzériaszinttől és a gamepasstól függ"], "10. fejezet")),
    issue("Passzív borravaló és befőttesüveg-begyűjtés", M[5], ["type:feature", "P0", X], body(
        "Törzsvendégek termelése.",
        ["Termelés: alap × ritkasági szorzó × (1 + 0,2 × csillag), szerveren számolva",
         "Gyűlik a pizzéria borravaló-üvegébe, érintéssel begyűjthető",
         "Üveg telítettség kijelzése"],
        ["A kliens nem befolyásolhatja a termelést"], "10. fejezet")),
    issue("Offline termelés", M[5], ["type:feature", "P1", X], body(
        "Ok a visszatérésre.",
        ["Max. 2 óra, 50% (gamepass: 8 óra, 100%)", "Visszatéréskor összegző ablak",
         "Időbélyeg szerveroldali (os.time), csalás elleni korlát"],
        ["Rendszeróra-állítás nem ad extra pénzt"], "10. fejezet")),
    issue("Futárszint (XP) és szintjutalmak", M[5], ["type:feature", "P1", X], body(
        "Folyamatos kis jutalmak.",
        ["XP forrásai: kézbesítés, stílus, óriás rendelés", "Szintgörbe configból (1. óra: 5–8 szint)",
         "Szintenkénti jutalom, szintlépés effekt"],
        ["Szint mentve, HUD-on látszik"], "17. fejezet")),
    issue("Mozgáseszköz-szintek (cipő → elektromos roller)", M[5], ["type:feature", "P1", X], body(
        "Gyorsabb mozgás fejlesztésként, plafonnal.",
        ["5 szint a brief táblázata szerint", "Gördeszka/roller modell és animáció",
         "Sebességplafon, hogy az események kezelhetők maradjanak"],
        ["Elektromos rollerrel is teljesíthetők az események"], "7. fejezet")),
    issue("Pizzéria-látogatás és like", M[5], ["type:feature", "P2", X], body(
        "Mutogatás és társas elismerés.",
        ["Más pizzériájába be lehet sétálni", "Like gomb (játékosonként pizzériánként naponta 1)",
         "Legtöbb like a szerveren → kiemelés"],
        ["Like nem farmolható alt fiókkal azonnal (min. játékidő)"], "11. fejezet")),
    issue("Napi bejelentkezési naptár (7 nap)", M[5], ["type:feature", "P2", X], body(
        "Napi visszatérés ösztönzése.",
        ["7 napos naptár, kihagyás nem törli a haladást", "Jutalmak: pénz, boost, 7. nap: kozmetika"],
        ["Szerveridő alapján működik"], "17. fejezet")),
    issue("K3 döntési kapu: visszatérés-teszt", M[5], ["type:playtest", "P0", X], body(
        "Visszajönnek-e másnap a pizzéria és törzsvendégek miatt?",
        ["Tesztelők 2 napon át", "Gazdasági tempó mérése (mikor érik el a 3. és 4. szintet)",
         "Költségek/termelés hangolása"],
        ["Döntés és config-változások dokumentálva"], "23.2. fejezet")),

    # ───────────────────────── M6 ─────────────────────────
    issue("Stílus-kézbesítés címkék és átadási képernyő", M[6], ["type:feature", "P1", X], body(
        "A klip-pillanat: trükkös átadásért bónusz.",
        ["Szerveroldali feltételek: légi, cápa elől, patadobogás, hibátlan, villám",
         "Összeadódó bónusz, max +150% (config)", "Látványos címkesor az átadási képernyőn ≤ 2 mp"],
        ["A címkék nem csalhatók ki kliensről"], "14. fejezet")),
    issue("Városi káosz-mérő és MEGA-KÁOSZ", M[6], ["type:feature", "P1", X], body(
        "Közös cél a szerveren.",
        ["Kézbesítések töltik (esemény alatt dupla), óriás kijelző a Plazán",
         "Teli mérő → MEGA: két engedélyezett esemény, ×3 borravaló, legendás 3%",
         "Top 3 hozzájáruló kiírása"],
        ["8–12 fős szerveren átlag 8–12 percenként telik (hangolva)", "A kombinációk mindig hagynak járható utat"],
        "15. fejezet",
        "Karácsonyi terjedelemben egyszerűsített változat is elég (pl. csak ×3 borravaló, kombináció nélkül).")),
    issue("Heti kihívások", M[6], ["type:feature", "P2", POST], body(
        "Választható heti célok.",
        ["3 kihívás hetente, configból", "Jutalom: pénz / kozmetika"],
        ["Hét váltása szerveridő alapján"], "17. fejezet")),

    # ───────────────────────── M7 ─────────────────────────
    issue("Óriás rendelés: kooperatív cipelés", M[7], ["type:feature", "P1", POST], body(
        "2–4 játékos visz egy óriás pizzát — a fő „hívd be a barátod” elem.",
        ["Indítópont a Plazán, csatlakozás 2–4 főnek", "Fizikailag billegő doboz (constraint-ek, hálózati tulajdon a szerveren)",
         "Leesés után 3 mp-en belül bárki felveheti", "Ritka+ célvendég, mindenkinek teljes borravaló + 25%"],
        ["Nem lehet egyedül kihasználni", "Lag mellett is játszható"],
        "13. fejezet")),
    issue("Barát-bónusz", M[7], ["type:feature", "P2", POST], body(
        "Roblox-barátokkal közös játék jutalmazása.",
        ["Barát a szerveren: +10% borravaló közös óriás rendelésnél", "Barát meghívása gomb (SocialService)"],
        ["A bónusz csak tényleges barátságnál él"], "13. fejezet")),

    # ───────────────────────── M8 ─────────────────────────
    issue("MonetizationService: gamepassok és idempotens ProcessReceipt", M[8], ["type:monetization", "P0", X], body(
        "Biztonságos vásárlási alap.",
        ["Gamepass-tulajdon ellenőrzés belépéskor és vásárláskor (cache-elve)",
         "`ProcessReceipt`: PurchaseId alapján egyszeri teljesítés, mentés után PurchaseGranted",
         "Vásárlási napló a profilban"],
        ["Ismételt receipt hívás nem ad dupla terméket", "Szerver összeomlás után a vásárlás újra feldolgozódik, egyszer"],
        "21.3. fejezet")),
    issue("Gamepassok bekötése", M[8], ["type:monetization", "P0", X], body(
        "6 gamepass a brief szerint.",
        ["Dupla borravaló, VIP Futár, +4 törzsvendéghely, Hosszú műszak, E-roller korán, Auto-gyűjtés",
         "Gamepass-ikonok és leírások"],
        ["Mindegyik hatása működik és mentés nélkül is érvényes (tulajdon-ellenőrzésből)"], "18.2. fejezet")),
    issue("Developer productok: boostok, pénzcsomagok, kezdőcsomag", M[8], ["type:monetization", "P0", X], body(
        "Ismételhető vásárlások.",
        ["Pizzaillat-felhő (10 perc, Ritka+ ×2), Borravaló-boost (15 perc)",
         "Pénzcsomagok (kicsi/közepes/nagy)", "Kezdőcsomag (első 3 napban, egyszer)",
         "Aktív boostok kijelzése és mentése (kilépésnél megáll vagy fut — döntés és leírás)"],
        ["Esélyt módosító terméknél az esélyek megjelennek"], "18.3. fejezet")),
    issue("„Rendelj egy katasztrófát!” – közös fizetős esemény", M[8], ["type:monetization", "P0", X], body(
        "A fő bevételi elem: társas, látványos, mindenkinek jó.",
        ["Vásárlás → esemény az EventService sorába", "Bejelentés mindenkinek a vevő nevével + fanfár + „Köszi!” gomb",
         "Az esemény alatt mindenkinek +100% borravaló; vevőnek garantált Ritka+ vendég",
         "Sorkorlát (max 3), min. 60 mp szünet, MEGA alatt tiltva", "Ha a sor tele, a vásárlás gombja inaktív"],
        ["Nem célozható játékos, nem ad immunitást", "Teli sornál nem lehet vásárolni"],
        "16. fejezet")),
    issue("„MEGA-KÁOSZ most!” termék", M[8], ["type:monetization", "P1", X], body(
        "Drágább, azonnali MEGA.",
        ["A sor elejére kerül, mindenkinek ×3 borravaló", "Szerverenként cooldown"],
        ["Csak ha a MEGA rendszer (M6) él"], "16. fejezet")),
    issue("Bolt UI", M[8], ["type:ui", "P0", X], body(
        "Átlátható, könnyen megtalálható bolt.",
        ["Fülek: Gamepassok, Boostok, Pénz, Kozmetikák", "Előnézet (animációknál mozgó)",
         "Esélyek megjelenítése", "Nincs felugró ajánlat esemény közben és az első 3 percben"],
        ["Mobilon kényelmes", "Minden termék ára és tartalma egyértelmű"], "18.1. fejezet")),
    issue("Kozmetikai rendszer: tulajdon, felszerelés, előnézet", M[8], ["type:monetization", "P1", X], body(
        "Mások előtt látható megjelenés.",
        ["Kategóriák: pizzásdoboz, futártáska, munkaruha-szett, mozgáseszköz-skin, pizzériadísz, üveg-skin",
         "Első 2 szett: Classic Courier + Extra Cheese", "Megszerezhető (játékból) és vásárolható tárgyak"],
        ["A kozmetika nem ad játékmeneti előnyt", "Mások látják"], "18.4. fejezet")),

    # ───────────────────────── M9 ─────────────────────────
    issue("Hóvihar szezonális esemény", M[9], ["type:feature", "P0", X], body(
        "Karácsonyi katasztrófa.",
        ["Csúszós utcák (súrlódás csökkentése), hógolyó-lavina sávok, hóbuckák mint menedék",
         "Havazás FX alacsony grafikai szinten is", "Szezonális Vendégkönyv-oldal"],
        ["Ugyanazok a robusztussági feltételek, mint a többi eseménynél"], "12.3. fejezet")),
    issue("Karácsonyi tartalom: 5 vendég + Mikulás-futár szett", M[9], ["type:content", "P0", X], body(
        "Limitált szezonális tartalom.",
        ["5 vendég (köztük a Mikulás mint Legendás)", "Mikulás-futár kozmetikai szett",
         "Szezon vége előre jelezve a játékban"],
        ["A limitált vendégek a szezon után nem sorsolhatók (configból kapcsolható)"], "18.5. fejezet")),
    issue("Analitika: funnel és gazdasági események", M[9], ["type:analytics", "P0", X], body(
        "Mérés nélkül nincs hangolás.",
        ["AnalyticsService funnel: join → first_pickup → first_delivery → first_customer_new → first_event_seen → first_upgrade",
         "Gazdasági események: borravaló források és elköltés", "Egyedi események: rendelt katasztrófa, óriás rendelés, baleset típusa"],
        ["Az adatok megjelennek a Creator Hub analitikában"], "22. fejezet")),
    issue("Mobil teljesítmény-optimalizálás", M[9], ["type:tech", "P0", X], body(
        "12 fős szerveren is stabil mobilon.",
        ["Profilozás MicroProfilerrel eseményekben", "Részecske/tárgy korlátok, effekt-szintek",
         "StreamingEnabled döntés", "Pizzéria és törzsvendég LOD"],
        ["Középkategóriás telefonon 30+ FPS minden eseményben (mért eredmény az issue-ban)"], "21.5. fejezet")),
    issue("Bélyegképek, ikon, store-leírás", M[9], ["type:launch", "P0", X], body(
        "A felfedezés első lépése.",
        ["3 bélyegkép-változat A/B-teszthez (futár a levegőben, tornádó, cápauszony)", "Ikon: pizzásdoboz viharfelhővel",
         "Angol leírás + kulcsszavak, rövid trailer/klipek"],
        ["Kis méretben is olvasható"], "20. fejezet")),
    issue("Zárt teszt és hibajavító kör", M[9], ["type:playtest", "P0", X], body(
        "Indulás előtti stabilitás.",
        ["10–20 tesztelő, privát szerver", "Hibák felvétele külön issue-ként", "Gazdaság utolsó hangolása"],
        ["Nincs ismert adatvesztő vagy vásárlási hiba"], "25. fejezet")),
    issue("Publikálás: beállítások, korhatár-kérdőív, szerverméret", M[9], ["type:launch", "P0", X], body(
        "Soft launch.",
        ["Maturity & Compliance kérdőív kitöltése", "Szerverméret 12, platformok (mobil, PC, konzol, tablet)",
         "Gamepass/product árak élesítése", "Indulási ellenőrzőlista a brief 25. fejezetéből"],
        ["A játék nyilvános, minden ellenőrzőlista-pont kipipálva"], "25. fejezet")),
]
