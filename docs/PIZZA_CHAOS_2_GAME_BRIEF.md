# PIZZA CHAOS 2.0 — részletes játékterv

**Verzió:** 2.0 — 2026. november 4.

**Munkacím:** PIZZA CHAOS. A végleges név és elérhetősége későbbi ellenőrzés.

**Előzmény:** ez a dokumentum a [PIZZA_CHAOS_GAME_BRIEF.md](PIZZA_CHAOS_GAME_BRIEF.md) (1.0) továbbfejlesztése. Az 1.0 alapelvei (érthető cél, olvasható veszélyek, gyors visszaállás, szerveroldali hitelesség) érvényesek maradnak. Ahol a két dokumentum eltér, a 2.0 az irányadó.

**Fejlesztési helyzet:** egyszemélyes Roblox-fejlesztés AI-segítséggel (Claude, Codex).

> **A játék ígérete: Vidd ki a pizzát. Bármi történik. És gyűjtsd össze a város legfurább vendégeit.**

---

## 1. Mi változott az 1.0-hoz képest?

| Terület | 1.0 | 2.0 |
|---|---|---|
| Fő körforgás | Kézbesítés → pénz → következő rendelés | Kézbesítés → **vendég gyűjtése** → **törzsvendég passzív borravalója** → **pizzéria fejlesztése** → jobb rendelések |
| Hosszú távú cél | Kozmetikák, futárszint | **Vendégkönyv** (gyűjtemény), **saját pizzéria** a közös téren, futárszint, kozmetikák |
| Események | Szerver ütemezi | Szerver ütemezi **+ városi káosz-mérő → MEGA-KÁOSZ** **+ játékos által „megrendelhető” katasztrófa** |
| Ügyesség | Csak teljesítés | **Stílus-kézbesítés**: trükkös átadásért bónusz borravaló |
| Közös játék | Közös esemény, külön rendelés | Ugyanez **+ Óriás rendelés** 2–4 játékosnak |
| Szerverméret | 6 játékos | **12** játékos (tesztelendő, 10–16 között) |
| Bevétel | Csak kozmetika | Gamepassok + egyszeri vásárlások + kozmetika + szezonális tartalom |
| Mozgás | Csak gyalog | Gyalog alapból, **gördeszka / roller / roller-kickboard** mint fejlesztés (autó továbbra sincs) |

**Ami szándékosan nincs:** lopás, más játékos pizzájának elvétele, pet-tojás, „Steal a…” típusú elnevezés vagy bélyegkép. A versengés baráti (ranglista, stílus, pizzéria-mutogatás), nem elvevős.

## 2. A játék egy bekezdésben

A játékos egy apró pizzéria futárja egy városban, ahol pár percenként valami abszurd történik: végigsöpör egy tornádó, cápás áradás önti el az utcákat, vagy lóverseny indul a főúton. A rendelések furcsa vendégekhez szólnak — egy részük csak egy adott katasztrófa közben jelenik meg. Akit kiszolgálsz, bekerül a **Vendégkönyvedbe**, a ritkák pedig **törzsvendégként** beülnek a pizzériádba, és borravalót termelnek. A pénzből a pizzériád büfékocsiból neon pizzatoronnyá nő a város közös terén, ahol mindenki láthatja.

**Angol rövid leírás (store):**

> Deliver pizza through tornadoes, shark floods and surprise horse races. Serve the weirdest customers in town, collect them, and grow your pizza shop into a neon tower!

**Egy játékos története, amit el akarunk érni:**

> „Már azt hittem, vége, mert elkapott a tornádó — de a levegőben kézbesítettem a pizzát a viharvadász nagymamának, és dupla borravalót kaptam. Most ő ül a pizzériám tetején.”

## 3. Alapelvek

1. **Egyszerű cél, nagy felfordulás.** Mindig világos, kié a pizza és hová megy.
2. **A káosz lehetőség, nem csak büntetés.** A legjobb vendégek és a legnagyobb borravalók a veszélyben vannak.
3. **A baleset vicces és rövid.** Pár másodperc ragdoll, a pizza megmarad, mehetsz tovább.
4. **Mindig van következő cél.** Új vendég a könyvben, következő pizzériaszint, következő mozgáseszköz.
5. **Mások jelenléte jobbá teszi.** Közös katasztrófa, közös káosz-mérő, óriás rendelés, a „katasztrófát rendelő” játékos mindenkinek bónuszt ad.
6. **A pénz gyorsít és díszít, nem kötelező.** Minden tartalom megszerezhető fizetés nélkül; a fizetős termékek idő, kényelem, megjelenés vagy közös látványosság.

## 4. Fő játékmeneti körforgás

```text
                ┌──────────────────────────────────────────┐
                ▼                                          │
Pizzéria (saját telek) ── rendelés felvétele ──► Kézbesítés a közös városban
      ▲                                              │
      │                                    katasztrófa / stílus / veszély
      │                                              ▼
Fejlesztés (pizzéria, mozgás,          Átadás: borravaló + XP + vendég a könyvbe
  törzsvendég-helyek) ◄── pénz ◄──────────── │
      ▲                                       ▼
      └──────── passzív borravaló ◄── ritka vendég → TÖRZSVENDÉG
```

**Rövid ciklus (60–120 mp):** rendelés → kézbesítés → borravaló.
**Közepes ciklus (5–15 perc):** új vendégek, pizzériafejlesztés, MEGA-KÁOSZ a szerveren.
**Hosszú ciklus (napok–hetek):** Vendégkönyv kitöltése, pizzériatorony, szezonális vendégek, futárszint.

## 5. Az első 3 perc (onboarding)

| Idő | Mi történik | Miért |
|---|---|---|
| 0–10 mp | A játékos a saját büfékocsija mellett jelenik meg a közös téren. Felirat: „Az első rendelésed vár!” | Azonnal van saját helye és feladata |
| 10–40 mp | Felveszi a pizzát, nyíl és fénycsík vezet egy közeli címre. Közönséges vendég (pl. „Álmos Diák”) | Alapmozgás és kézbesítés megtanulása |
| 40–70 mp | Átadás → borravaló-animáció, „Új vendég a Vendégkönyvben! 1/24” | A gyűjtés megmutatása |
| 70–120 mp | Második rendelés közben **garantáltan** elindul az első esemény (lóverseny, mert a legolvashatóbb) | Az egyedi élmény korán jöjjön |
| 120–180 mp | A második kézbesítés után: „Elég pénzed van az első fejlesztésre!” → a büfékocsi kap egy napernyőt + 1 törzsvendéghelyet | Az első „szám nő” élmény 3 percen belül |

Új belépő esetén a szerver már futó eseményét **nem** indítjuk újra. Ha épp katasztrófa van, a belépő a védett téren indul, és a garantált első eseményt a következő nyugodt szakasz után kapja meg (csak neki szóló „mini” változat nincs — a közös esemény a lényeg).

Az első 3 percben nincs bolt-felugró ablak és nincs vásárlási ajánlat.

## 6. A város (1. térkép: „Pepperoni negyed”)

- **Közös tér (Plaza):** a térkép közepe. Körülötte **12 pizzériatelek**, egy játékosonként. Itt van a ranglista, a káosz-mérő óriás kijelzője és az Óriás rendelés indítópontja.
- **Főutca:** egyenes, széles — a lóverseny pályája.
- **Alsóváros:** mélyebben fekvő utcák — az áradás itt a legerősebb.
- **Nagy tér a szökőkúttal:** a tornádó fő útvonala.
- **Oldalutcák, kapualjak, erkélyek, napellenzők, felüljáró:** menedékek és alternatív utak.
- **Kézbesítési címek:** induláskor 12–16 ház/ajtó/erkély, mindegyik fix azonosítóval. Áradáskor minden címnek van egy jelölt magasabb átadási pontja.

Méret: rövid távolságok, egy átlagos fuvar 60–120 mp. Nem nyílt világ; a város kicsi, de minden eseményben másképp kell bejárni.

**Későbbi térképek / negyedek** (frissítésként): Kikötő (cápák, hullámok), Hegyi falu (lavina, kecskeroham), Neon belváros (UFO-támadás).

## 7. Mozgás

- Harmadik személyű kamera, jól látható avatar és pizzásdoboz.
- Alap futás, megbocsátó ugrás (coyote time és jump buffer 0,10–0,15 mp), nincs külön sprint.
- **Mozgáseszköz-fejlesztések** (szigorú sebességplafonnal, hogy az események kezelhetők maradjanak):

| Szint | Eszköz | Sebességbónusz (kiinduló) | Megszerzés |
|---|---|---|---|
| 0 | Edzőcipő | — | Alap |
| 1 | Futócipő | +8% | Borravaló |
| 2 | Gördeszka | +15%, kis ugrásbónusz | Borravaló |
| 3 | Roller | +22% | Borravaló + futárszint |
| 4 | Elektromos roller | +30% | Borravaló + futárszint (vagy gamepass korábban) |

A mozgáseszköz megjelenése kozmetikailag cserélhető (skin), a statisztika a szinthez kötött.

Falfutás, grappling hook és összetett parkour nincs.

## 8. Rendelések

- Játékosonként egy aktív rendelés. Más nem veheti el, nem semmisítheti meg.
- A rendelés a szerveren jön létre: cím + vendég + rendeléstípus.
- Baleset után a pizza a futárnál marad.
- Egy rendelésért egyszer jár jutalom (idempotens szerverlogika).
- Nincs kötelező időlimit. A gyorsaság csak bónuszt ad.

### 8.1. Rendeléstípusok

| Típus | Elérhető | Különlegesség |
|---|---|---|
| Normál pizza | Alap | — |
| Dupla rendelés | Pizzéria 2. szint | Két címet érint egy úton, nagyobb borravaló |
| Sietős rendelés | Pizzéria 2. szint | Opcionális időbónusz; lejárat után is teljesíthető, csak kisebb borravalóval |
| Törékeny torta | Pizzéria 3. szint | Bónusz, ha baleset nélkül érkezik |
| Óriás pizza | Közös téren, 2–4 játékos | Lásd 13. fejezet |
| Esemény-rendelés | Csak katasztrófa alatt | Esemény-specifikus vendéghez szól, nagyobb ritkasági esély |

## 9. Vendégek és Vendégkönyv (a fő gyűjtőrendszer)

### 9.1. Működés

- Minden rendelés egy **vendéghez** szól, akit a szerver sorsol a vendégkészletből.
- A sorsolást befolyásolja: aktív esemény, pizzériaszint, futárszint, aktív csalogató (lásd monetizáció).
- Kiszolgáláskor a vendég **bekerül a Vendégkönyvbe** (első alkalommal „ÚJ!” animáció).
- **Ritka (Rare) és afölötti** vendég első kiszolgálása után a vendég **törzsvendéggé** tehető: beül a pizzériába egy szabad helyre.
- Ismételt kiszolgálás: „csillag” gyűlik a vendéghez (1–5 csillag). A csillag a törzsvendég termelését növeli → ok arra, hogy ugyanazt a ritka vendéget újra elkapd.

### 9.2. Ritkasági szintek (kiinduló)

| Szint | Szín | Alap esély normál időben | Esély eseményben | Passzív borravaló törzsvendégként |
|---|---|---:|---:|---|
| Közönséges (Common) | Szürke | 70% | 45% | — (nem ül be) |
| Szokatlan (Uncommon) | Zöld | 22% | 30% | — |
| Ritka (Rare) | Kék | 7% | 18% | 1× |
| Epikus (Epic) | Lila | 1% | 6% | 3× |
| Legendás (Legendary) | Arany | 0% | 1% (MEGA-ban 3%) | 8× |
| Mitikus (Mythic, később) | Szivárvány | 0% | csak szezonális / MEGA | 20× |

Az értékek hangolandók. Minden százalékot és a passzív borravaló alapértékét konfigurációs táblában tartjuk.

**Robux-szal kapcsolatos esélyeket mindig meg kell jeleníteni** (Roblox fizetős véletlen elemekre vonatkozó szabályai miatt). A pizzaillat-felhő nem tárgy-sorsolás, hanem esélynövelés — az esélyeket ennek ellenére is mutatjuk.

### 9.3. Kezdő vendégkészlet (24 vendég)

**Normál időben (12):**
Álmos Diák, Kocogó Nagypapa, Szelfiző Influenszer, Bőröndös Turista, Kertész Néni, Gamer Srác (Uncommon), Postás Kutya (Uncommon), Szobor-Ember (Uncommon), Titkos Ügynök (Rare), Bűvész (Rare), Mozgólépcső-szerelő Robot (Epic), A Polgármester (Epic).

**Tornádó (4):** Viharvadász Nagymama (Rare), Repülő Tehén (Epic), Szélkakas Lovag (Rare), Tornádó Kölyök (Legendary).

**Áradás (4):** Sellő az erkélyen (Rare), Gumikacsa Kapitány (Uncommon), Búvár Pincér (Epic), A Cápa Maga (Legendary — igen, ő is rendel).

**Lóverseny (4):** Zsoké (Uncommon), Lóverseny-bemondó (Rare), Pónipaparazzi (Epic), Arany Patkós Ló (Legendary).

Minden vendégnek: név, ritkaság, 1 soros vicces szöveg átadáskor, egyedi póz/animáció a pizzériában.

**Tartalomszabály:** minden új esemény 4 új vendéggel érkezik; minden szezonális frissítés 3–6 limitált vendéggel. Ez az olcsó, ismételhető tartalommotor.

### 9.4. Vendégkönyv felület

- Rács nézet, ritkaság szerint színezve; ismeretlen vendég sziluettel és tipppel („Áradáskor keresd az erkélyeken…”).
- Mérföldkő-jutalmak: 5 / 10 / 15 / 20 / 24 vendég → pénz, kozmetika, cím (pl. „Vendéglátóipari Legenda”).
- Teljes negyed kitöltése → exkluzív pizzériadísz.

## 10. Törzsvendégek és passzív borravaló

- A pizzériában **törzsvendég-helyek** vannak (kezdetben 1, pizzériaszinttel max. 8, gamepass-szal +4).
- A törzsvendég percenként borravalót termel: `alap × ritkasági szorzó × (1 + 0,2 × csillag)`.
- A termelt borravaló a pizzéria **borravaló-befőttesüvegébe** gyűlik; oda kell sétálni és megérinteni a begyűjtéshez (ez visszahozza a játékost a közös térre, ahol mások látják).
- **Offline termelés:** kilépéskor a termelés folytatódik, legfeljebb 2 óráig, 50%-os rátával. Visszatéréskor: „Amíg távol voltál, a törzsvendégeid 1 240 borravalót hagytak!” (Gamepass: 8 óra, 100%.)
- A törzsvendégek láthatóan ülnek, esznek, reagálnak (pl. a Cápa a medencében ül a pizzéria tetején). Ez a mutogatás fő eleme.

## 11. A saját pizzéria (tycoon-réteg)

Minden játékos kap egy telket a közös téren a szerveren töltött idejére; a fejlődés mentve van, belépéskor a pizzéria a saját szintjén épül fel.

| Szint | Név | Költség (kiinduló) | Nyit |
|---|---|---:|---|
| 1 | Büfékocsi | — | 1 törzsvendéghely |
| 2 | Pizzás standa | 500 | 2 hely, dupla és sietős rendelés |
| 3 | Kis pizzázó | 2 500 | 3 hely, torta, első dekorhely |
| 4 | Családi pizzéria | 10 000 | 4 hely, emelet, jobb vendégesély (+) |
| 5 | Pizzapalota | 40 000 | 6 hely, terasz |
| 6 | Neon Pizzatorony | 150 000 | 8 hely, tetőterasz, saját fényjáték |

- Minden szinten látványos átépülés-animáció (a szomszédok is látják).
- **Dekorációk** (borravalóért vagy kozmetikaként): neon felirat, óriás pizzaszobor, szökőkút, fényfüzér.
- **Látogatás:** más játékos besétálhat a pizzériádba, megnézheti a törzsvendégeidet és a Vendégkönyved arányát. „Like” gomb → a legtöbb like-ot kapó pizzéria a szerveren kiemelést kap.
- **Rebirth / „Franchise”** (későbbi, nem MVP): a toronyszint után új negyedben nyithatsz franchise-t, tartós borravaló-szorzóért cserébe a pizzéria újrakezdődik. Csak akkor építjük, ha az adatok szerint a játékosok elérik a 6. szintet.

## 12. Katasztrófák (eseményrendszer)

Az 1.0 eseményleírásai (tornádó, áradás + cápa, lóverseny) érvényesek, az öt állapottal: **előjel → felépülés → aktív → lecsengés → visszaállítás**.

### 12.1. Ütemezés

- Nyugodt szakasz: 90–150 mp.
- Előjel: 5–8 mp (hang, ég színe, felirat, ikon).
- Aktív szakasz: 30–45 mp.
- Lecsengés + visszaállítás: 5–10 mp.
- A szerver soha nem futtat két „normál” eseményt egyszerre; kombináció csak MEGA-ban.

### 12.2. Esemény alatt

- Esemény-vendégek kerülnek a sorsolásba; minden aktív rendelés egy része **átcímződik** esemény-vendéghez („A Sellő is kér egyet! +borravaló”) — opcionálisan elfogadható.
- Esemény alatti kézbesítés: **+50% borravaló** (kiinduló).

### 12.3. Kiadási sorrend

1. Lóverseny (legolvashatóbb, első prototípus).
2. Tornádó.
3. Áradás + cápa.
4. **Karácsonyi szezonális:** Hóvihar (csúszós utcák, hógolyó-lavina, hóember-vendégek, a Mikulás mint Legendás vendég).
5. Később: meteoreső, óriás macska a városban, UFO-elrablás, sajtláva.

## 13. Óriás rendelés (kooperatív)

- A közös téren pár percenként megjelenik egy **óriás pizza** rendelés (vagy a pizzéria 3. szintjétől bármikor indítható 2+ játékossal).
- 2–4 játékos fogja meg a dobozt; a doboz fizikailag billeg, ha valaki elesik vagy lemarad, a doboz megdől.
- A célpont mindig ritka+ vendég, eseményben akár legendás.
- Jutalom: mindenki megkapja a teljes borravalót **+25% társas bónusz**, a vendég mindenkinek bekerül a Vendégkönyvbe.
- Ha a doboz leesik: 3 mp-en belül bárki felveheti újra; nem vész el.
- Barát-bónusz: Roblox-baráttal közösen +10% extra.

Ez a fő „hívd be a barátodat” mechanika és a legjobb klip-generátor.

## 14. Stílus-kézbesítés

Átadáskor a szerver ellenőrzi a kézbesítés körülményeit, és címkéket ad:

| Címke | Feltétel (szerveroldali) | Borravaló |
|---|---|---:|
| Légi kézbesítés | A játékos levegőben van az átadáskor (tornádó / ugrás) | +50% |
| Cápa elől | 5 mp-en belül cápa-veszélyzónában volt | +40% |
| Patadobogás | Lóhullámon átkelve, 5 mp-en belül | +30% |
| Hibátlan | Nem volt baleset a fuvar alatt | +20% |
| Villám | A rendelés célideje alatt | +20% |
| Zsonglőr | Óriás rendelés baleset nélkül | +30% |

A címkék összeadódnak, felső határral (kiinduló: max +150%). Az átadási képernyő látványosan felsorolja őket („LÉGI KÉZBESÍTÉS! CÁPA ELŐL!”). Ez a klip-pillanat.

## 15. Városi káosz-mérő és MEGA-KÁOSZ

- A közös téren óriás mérőóra. Minden kézbesítés a szerveren tölti (esemény alatt dupla).
- Kiinduló cél: átlagosan 8–12 percenként teljen meg egy 8–12 fős szerveren.
- **MEGA-KÁOSZ (60–90 mp):** két engedélyezett esemény egyszerre (az 1.0 14. fejezet szabályaival), háromszoros borravaló, legendás esély 3%, egyedi zene és fényeffekt.
- A mérő töltéséhez legtöbbet hozzájáruló 3 játékos kiírása a MEGA végén.

## 16. „Rendelj egy katasztrófát!” — közös fizetős esemény

- A játékos Robuxért **megrendel** egy eseményt (lóverseny, tornádó, áradás, később a többi).
- Bejelentés mindenkinek: **„🍕 Dani rendelt egy TORNÁDÓT!”** — a név, egy rövid fanfár és egy „Köszi, Dani!” gomb a többieknek.
- A rendelt esemény alatt **mindenki** +100% borravalót kap (nem csak a vásárló). A vásárló extra: garantált Ritka+ vendég a következő rendelésére.
- Szabályok:
  - Szerverenként sorban állnak, egyszerre egy; minimum 60 mp nyugodt szakasz két esemény között.
  - MEGA-KÁOSZ alatt nem indítható.
  - Nem ad immunitást, nem célozhat meg játékost, nem rontja el senki rendelését.
  - Ha a sor tele (pl. 3 várakozó), a vásárlás nem indítható (ne vegyen semmit feleslegesen).
- **„MEGA-KÁOSZ most!”** drágább változat: azonnal (vagy a sor elején) MEGA-t indít.

Ez a legfontosabb bevételi elem: társas, látványos, mindenkinek jó, ezért a vásárló hős lesz, nem ellenség.

## 17. Fejlődés összefoglaló

| Rendszer | Mi nő | Mentve |
|---|---|---|
| Borravaló (pénz) | Kézbesítés, törzsvendégek | Igen |
| Futárszint (XP) | Kézbesítés, stílus, óriás rendelés | Igen |
| Vendégkönyv | Új vendégek, csillagok | Igen |
| Pizzéria | Szint, dekor, helyek | Igen |
| Mozgáseszköz | Szint | Igen |
| Kozmetikák | Tulajdon + felszerelés | Igen |
| Napi bejelentkezés | 7 napos naptár, kihagyás nem törli | Igen |
| Heti kihívások | 3 választható feladat (pl. „Szolgálj ki 5 vendéget áradásban”) | Igen |

Futárszintenként kis jutalom (pénz, kozmetika, mozgáseszköz-feltétel). Célzott tempó: az első órában 5–8 szint, utána lassul.

## 18. Monetizáció

### 18.1. Alapelvek

- Minden tartalom ingyen is elérhető; fizetéssel gyorsabb, kényelmesebb, látványosabb.
- Nincs fizetős immunitás, nincs mások elleni fizetős előny.
- Esélyek mindig láthatók.
- Esemény közben nincs felugró vásárlási ajánlat.
- Az árak kiinduló hipotézisek; indulás után A/B-teszttel és adatok alapján módosítjuk.

### 18.2. Gamepassok (egyszeri, tartós)

| Gamepass | Tartalom | Kiinduló ár (Robux) |
|---|---|---:|
| Dupla borravaló | ×2 minden borravaló (passzív is) | 299 |
| VIP Futár | VIP sapka + névcímke, +10% XP, VIP pizzériadísz, VIP szerverhelyi chat-cím | 199 |
| +4 törzsvendéghely | Több passzív termelés | 249 |
| Hosszú műszak | Offline termelés 8 óra, 100% | 149 |
| Elektromos roller korán | A 4-es mozgáseszköz szint azonnal (a plafon ugyanaz) | 199 |
| Automatikus borravaló-gyűjtés | Nem kell az üveghez sétálni | 99 |

### 18.3. Egyszeri vásárlások (developer product)

| Termék | Tartalom | Kiinduló ár |
|---|---|---:|
| Rendelj egy katasztrófát | Választott esemény a sorba, mindenkinek +100% | 49 |
| MEGA-KÁOSZ most | Azonnali MEGA, mindenkinek ×3 | 199 |
| Pizzaillat-felhő (10 perc) | Ritka+ esély ×2 a saját rendeléseidre | 39 |
| Borravaló-boost (15 perc) | ×2 borravaló | 29 |
| Pénzcsomagok | Kis / közepes / nagy borravaló-csomag | 25 / 99 / 399 |
| Kezdőcsomag (egyszer vehető, első 3 napban) | Pénz + egy kozmetikai doboz-skin + 30 perc boost | 99 |

### 18.4. Kozmetikák

Az 1.0 kozmetikai termékjelöltjei maradnak (doboz-skin, futártáska, munkaruha-szett, átadási animáció, esés-/felállásanimáció, emote), kiegészítve:

- Mozgáseszköz-skinek (gördeszka, roller).
- Pizzériadekorációk (neon felirat, szobor, fényjáték).
- Borravaló-üveg skinek.
- Szezonális szettek (Karácsony: „Mikulás-futár”, Halloween: „Szellemfutár”).

### 18.5. Szezonális / limitált tartalom

- Szezononként (4–6 hét): 1 új esemény, 3–6 limitált vendég, 1 kozmetikai szett, szezonális Vendégkönyv-oldal.
- Limitált vendégek a szezon után nem sorsolhatók → gyűjtési sürgetés. (Kezelni kell, hogy ne legyen agresszív: a szezon végét előre jelezzük.)

### 18.6. Roblox Creator Rewards

A napi aktivitás és a játékidő alapján járó Creator Rewards külön bevétel; nem építünk rá, de a rövid, visszatérős alkalmak (törzsvendég-borravaló, napi naptár) segítik.

## 19. Egyszerű bevételi modell (frissítendő)

Képlet (a Neon Rush becslés logikájával):

```text
havi DevEx-érték (USD) ≈ átlagos DAU × 30 × (Robux-költés / aktív játékosnap) × 0,70 × 0,0038
```

A különbség a Neon Rushhoz képest: itt nemcsak kozmetika van, hanem ismételhető, társas fizetős termék (Rendelj egy katasztrófát) és kényelmi gamepassok. Ezért a költés/aktív játékosnap feltételezést három sávban vizsgáljuk:

| Feltételezés | Robux / aktív játékosnap | 1 000 DAU havonta | 10 000 DAU havonta |
|---|---:|---:|---:|
| Gyenge | 1,5 | ~120 USD | ~1 200 USD |
| Közepes | 4 | ~320 USD | ~3 190 USD |
| Erős | 8 | ~640 USD | ~6 380 USD |

**Ezek nem előrejelzések**, hanem modellbemenetek, amelyeket az első két hét valós adatával cserélünk le. A DAU elérése a legnagyobb bizonytalanság; azt a megtartás (D1, D7) és az ajánlórendszer dönti el, nem a bolt.

**Saját költség:** AI-előfizetések (Claude 20 USD/hó + Codex), opcionális hirdetés (Roblox sponsored ads), opcionális zene/modell. A pénzügyi tervben az első 2–3 hónap bevétele legyen 0.

## 20. Látvány, hang, kamera, felület

Az 1.0 19–21. fejezete érvényes. Kiegészítések:

- **Bélyegkép-irány:** egy futár a levegőben pizzával, mögötte tornádó, lent cápauszony az utcán. Erős kontraszt, kevés szöveg. 3 változat A/B-tesztre.
- **Ikonok:** a játék ikonja maga a pizzás doboz egy kis viharfelhővel.
- **Vendégek stílusa:** nagy fejű, túlzó sziluettű karakterek, hogy távolról is felismerhetők legyenek.
- **Átadási képernyő:** borravaló-szám pörög, stílus-címkék egymás után, vendég reakció. Max. 2 mp, mozgás közben is.
- **HUD:** aktív cím + irány, pizza ikon, borravaló, káosz-mérő kicsiben, esemény-figyelmeztetés. Mobilon nagy gombok, nem takarják az ugrási felületeket.

## 21. Technikai felépítés

### 21.1. Eszközök

- **Roblox Studio + Rojo** (fájlalapú projekt, verziókezelés Gitben).
- **Luau**, `--!strict` ahol ésszerű.
- **StyLua** (formázás), **Selene** (lint), GitHub Actions CI.
- Adatmentés: **ProfileStore** vagy saját DataStore-burkoló session lockkal.
- Analitika: Roblox **AnalyticsService** (funnel, gazdasági és egyedi események).

### 21.2. Mappastruktúra (javaslat)

```text
src/
  server/
    Services/      OrderService, CustomerService, EventService, ChaosMeterService,
                   PizzeriaService, RegularsService, StyleService, GiantOrderService,
                   EconomyService, DataService, MonetizationService, AnalyticsService
  client/
    Controllers/   HUDController, CameraController, InputController, CustomerBookUI,
                   PizzeriaUI, ShopUI, DeliveryFX, EventFX
  shared/
    Config/        Customers, Rarities, Events, Pizzeria, Movement, Products, Tuning
    Types/
    Util/
```

### 21.3. Szerveroldali hitelesség (kötelező)

- Rendelés, vendégsorsolás, borravaló, XP, stílus-címkék, pizzériaszint, törzsvendégek, eseményállapot, káosz-mérő: **csak szerveren**.
- Kézbesítés ellenőrzése: távolság + aktív rendelés + jogosult cím; ismételt kérés nem ad jutalmat.
- `ProcessReceipt` idempotens: egy vásárlás egyszer teljesül, mentés után ad `PurchaseGranted`-et.
- RemoteEvent-ek rate limittel; kliens csak szándékot küld („felveszem”, „átadom”), eredményt nem.

### 21.4. Események robusztussága

Az 1.0 24. fejezete szerint: teljes takarítás, közbelépő játékos szinkronja, hibánál biztonságos alapállapot.

### 21.5. Teljesítmény

Mobil a fő célplatform. Korlátozott ló/törmelék/részecske, StreamingEnabled megfontolása, alacsony grafikai szinten is olvasható veszélyek. 12 játékos + 12 pizzéria + törzsvendégek: a törzsvendégek egyszerű animált modellek, LOD-dal / távolságfüggő elrejtéssel.

## 22. Mérési terv

### 22.1. Kulcsmutatók (a Roblox ajánlórendszere is ezeket figyeli)

- Minősített első játék (az első kézbesítés teljesítése) aránya.
- D1 és D7 megtartás.
- 7 napos játékidő.
- Fizető játékosok aránya, átlagos költés fizetőnként.
- Közös játék: barátokkal érkezők aránya, óriás rendelések száma.

### 22.2. Funnel események

`join → first_order_pickup → first_delivery → first_customer_new → first_event_seen → first_upgrade → second_session`

### 22.3. Gazdasági események

Borravaló forrásai (kézbesítés, passzív, stílus, MEGA) és elköltése (pizzéria, mozgás, dekor) — a gazdaság egyensúlyához.

### 22.4. Célértékek (első belső célok, nem garanciák)

| Mutató | Első cél |
|---|---:|
| Első kézbesítés teljesítése | > 85% |
| Első 3 percben első fejlesztés | > 70% |
| D1 | > 25% |
| D7 | > 8% |
| Átlagos alkalom hossza | 12–20 perc |

## 23. Fejlesztési ütemterv és mérföldkövek

Óraszámok: aktív munka, AI-segítséggel, 25% tartalékkal együtt; kiinduló becslés, az első 20–30 óra után újra kell becsülni.

| # | Mérföldkő | Tartalom | Óra |
|---|---|---|---:|
| M0 | Projektalap | Rojo, repó, CI, mappastruktúra, konfigurációs táblák váza | 6–10 |
| M1 | Egy teljes kézbesítés | Szürkedobozos város, rendelés, céljelzés, átadás, borravaló, mobil vezérlés | 25–40 |
| M2 | Eseményrendszer + lóverseny | Állapotgép, ütemező, lóverseny, baleset/visszaállás, debug-indítás | 25–40 |
| M3 | Tornádó + áradás/cápa | Két további esemény, átcímzés magasabb pontra, takarítás | 30–50 |
| M4 | Vendégek + Vendégkönyv | Vendégkonfig, sorsolás, könyv UI, 24 vendég (egyszerű modellek) | 30–45 |
| M5 | Pizzéria + törzsvendégek + mentés | Telkek, 6 szint, helyek, passzív/offline borravaló, DataService | 35–55 |
| M6 | Stílus + káosz-mérő + MEGA | Stílus-címkék, mérő, MEGA kombinációk | 20–30 |
| M7 | Óriás rendelés | Kooperatív cipelés, fizika, jutalom | 20–35 |
| M8 | Monetizáció | Gamepassok, developer productok, Rendelj katasztrófát, bolt UI, ProcessReceipt | 25–40 |
| M9 | Karácsonyi esemény + indulás | Hóvihar, 5 szezonális vendég, bélyegképek, ikon, store-leírás, analitika, mobil teljesítmény, zárt teszt | 35–55 |
| M10 | Indulás utáni élő üzem | Heti frissítések, hibajavítás, árak hangolása | folyamatos |
| **Össz. (M0–M9)** | | | **~250–400** |

### 23.1. Karácsonyi indulási cél

Ma 2026. november 4. A karácsonyi szünet a Robloxon kiemelt forgalmú időszak.

- **Heti ~35 óra:** M0–M9 ≈ 7–11 hét → december közepe – január eleje. **Szűk.**
- **Javasolt „karácsonyi terjedelem”:** M0–M5 + M8 (alap) + M9; az M6 (stílus, káosz-mérő) egyszerűsítve, az M7 (óriás rendelés) januári frissítés. Ez ≈ 220–350 óra → heti 35 órával 7–10 hét → legkorábban **december 20. körül**, reálisan január eleje.
- **Ha a karácsony fontos:** az áradás + cápa is januárra csúszik (a karácsonyi változat: lóverseny, tornádó, hóvihar), vagy heti 45–50 óra kell. Erről az M2 végén döntünk, a tényleges tempó alapján.
- Ha az M2 végén (≈ 3. hét) a lóverseny-teszt nem meggyőző, a karácsonyi dátumot elengedjük, és az alapélményt javítjuk.

### 23.2. Döntési kapuk

| Kapu | Mikor | Kérdés | Ha nem |
|---|---|---|---|
| K1 | M2 vége | Vicces és érthető-e a lóverseny közbeni kézbesítés 3–5 tesztelőnek? | Esemény/mozgás javítása, mielőtt továbbmegyünk |
| K2 | M4 vége | Akarják-e a tesztelők kitölteni a Vendégkönyvet? Mennek-e a veszélybe ritka vendégért? | Esélyek, jutalmak, vendégek láthatóságának javítása |
| K3 | M5 vége | Visszajönnek-e másnap a pizzéria/törzsvendégek miatt? | Fejlődési tempó hangolása |
| K4 | Soft launch + 7 nap | D1, D7, fizetési arány | Onboarding, ár, tartalom igazítása |

## 24. Kockázatok

| Kockázat | Jel | Válasz |
|---|---|---|
| Túl sok rendszer egy embernek | Csúsznak a mérföldkövek | Karácsonyi terjedelem, M6–M7 későbbre |
| A gyűjtés nem érdekes | Nem nyitják meg a könyvet | Erősebb „ÚJ!” pillanat, sziluettek, mérföldkő-jutalmak |
| A káosz bosszantó | Kilépés baleset után | Rövidebb ragdoll, ismételt találat elleni védelem |
| A gazdaság túl gyors/lassú | Mindenki 1 nap alatt toronyszint / senki nem éri el a 3. szintet | Konfigban hangolható költségek, analitika |
| A fizetős esemény mérges reakciót vált ki | Panaszok, kilépés rendelt esemény alatt | Mindenkinek bónusz, sorkorlát, nem indítható MEGA alatt |
| Mobil teljesítmény | FPS esés eseményben | Effekt-szintek, kevesebb aktív tárgy, LOD a pizzériáknál |
| Nincs forgalom indulás után | Kevés látogatás | Bélyegkép A/B, kis Roblox-hirdetési teszt, TikTok/Shorts klipek a stílus-kézbesítésekről |

## 25. Elfogadási lista a karácsonyi soft launch-hoz

- [ ] Új játékos 3 percen belül kézbesít, gyűjt egy vendéget és fejleszt.
- [ ] Három normál esemény + hóvihar stabilan fut, takarítással.
- [ ] 24 + 5 szezonális vendég sorsolható, könyvben megjelenik.
- [ ] Pizzéria 1–6. szint, törzsvendégek, passzív és offline borravaló mentve.
- [ ] Mobilon minden alapfunkció kényelmes.
- [ ] Gamepassok és developer productok működnek, `ProcessReceipt` idempotens.
- [ ] Rendelj katasztrófát: sor, bejelentés, mindenki bónusza.
- [ ] Esélyek láthatók minden esélyt befolyásoló terméknél.
- [ ] Analitika funnel és gazdasági események élnek.
- [ ] 12 fős szerveren stabil teljesítmény mobilon.
- [ ] Bélyegkép, ikon, leírás kész; korhatár-besorolási kérdőív kitöltve.

## 26. Másolható fejlesztési prompt (AI-fejlesztőnek)

```text
Roblox Studio / Luau játékot készítünk Rojo-val, egyedüli fejlesztőként AI-segítséggel.
Olvasd végig a docs/PIZZA_CHAOS_2_GAME_BRIEF.md dokumentumot (2.0, ez az irányadó),
és háttérként a docs/PIZZA_CHAOS_GAME_BRIEF.md-t (1.0).

A munkát GitHub issue-kban követjük. Mindig egy issue-n dolgozz, az issue
elfogadási feltételei szerint. A kész munkát külön branchen, a issue-ra
hivatkozó PR-ban add át.

Elvek:
- Minden, ami pénzt, XP-t, vendéget, tulajdont vagy eseményállapotot érint: szerveren.
- A kliens csak szándékot küld; a szerver ellenőriz.
- Minden hangolható szám a src/shared/Config alatt legyen.
- Mobil az elsődleges platform.
- Egy esemény mindig: előjel → felépülés → aktív → lecsengés → visszaállítás.
- Ne építs előre olyan rendszert, amelyet a jelenlegi issue nem kér.
- Írd le, mit teszteltél és mi maradt ellenőrizetlen.
```
