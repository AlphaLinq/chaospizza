# Pizza Chaos 2.0 — Backlog

Generálva a `tools/backlog.py`-ból. A GitHub issue-k az irányadók.

## M0 – Projektalap

Rojo, repó, CI, mappastruktúra, konfiguráció váza. Becslés: 6–10 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | Rojo projekt és mappastruktúra létrehozása | type:tech, P0, xmas-scope |
| 2 | StyLua + Selene + GitHub Actions CI | type:tech, P1, xmas-scope |
| 3 | Konfigurációs táblák váza (shared/Config) | type:tech, P0, xmas-scope |
| 4 | Hálózati réteg: szándék-alapú Remote-ok rate limittel | type:tech, P0, xmas-scope |
| 5 | Fejlesztői debug-panel (esemény indítás, pénz, reset) | type:tech, P1, xmas-scope |

## M1 – Egy teljes kézbesítés

Szürkedobozos város, rendelés, céljelzés, átadás, borravaló, mobil vezérlés. Becslés: 25–40 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | Szürkedobozos Pepperoni negyed térkép | type:content, P0, xmas-scope |
| 2 | OrderService: rendelés létrehozása, felvétele és jutalma | type:feature, P0, xmas-scope |
| 3 | Céljelzés: irány-nyíl, fénycsík, távolság | type:ui, P0, xmas-scope |
| 4 | Átadás interakció és szerveroldali ellenőrzés | type:feature, P0, xmas-scope |
| 5 | Mozgás és kamera hangolása | type:feature, P0, xmas-scope |
| 6 | Mobil vezérlés és gombkiosztás | type:ui, P0, xmas-scope |
| 7 | Alap HUD: cím, pizza, borravaló | type:ui, P0, xmas-scope |
| 8 | Onboarding: az első 3 perc | type:feature, P0, xmas-scope |

## M2 – Eseményrendszer + lóverseny

Állapotgép, ütemező, lóverseny, baleset/visszaállás. K1 döntési kapu. Becslés: 25–40 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | EventService: esemény-állapotgép és ütemező | type:tech, P0, xmas-scope |
| 2 | Lóverseny esemény | type:feature, P0, xmas-scope |
| 3 | Baleset, ragdoll és visszaállás | type:feature, P0, xmas-scope |
| 4 | Elakadásból mentés (ingyenes) | type:feature, P1, xmas-scope |
| 5 | Esemény közbeni belépés és takarítás tesztelése | type:tech, P0, xmas-scope |
| 6 | Esemény FX és hang alapok | type:feature, P1, xmas-scope |
| 7 | K1 döntési kapu: lóverseny-játékteszt | type:playtest, P0, xmas-scope |

## M3 – Tornádó + áradás/cápa

Két további esemény, átadási pont áthelyezés, takarítás. Becslés: 30–50 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | Tornádó esemény | type:feature, P0, xmas-scope |
| 2 | Áradás + cápa esemény | type:feature, P1, xmas-scope |
| 3 | Átadási pont áthelyezése áradáskor | type:feature, P1, xmas-scope |

## M4 – Vendégek + Vendégkönyv

Vendégsorsolás, 24 vendég, Vendégkönyv UI, esemény-vendégek. K2 kapu. Becslés: 30–45 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | CustomerService: vendégsorsolás ritkasággal | type:feature, P0, xmas-scope |
| 2 | Kezdő 24 vendég: modellek, nevek, szövegek | type:content, P0, xmas-scope |
| 3 | Vendégkönyv felület | type:ui, P0, xmas-scope |
| 4 | „ÚJ VENDÉG!” pillanat és mérföldkő-jutalmak | type:feature, P1, xmas-scope |
| 5 | Esemény-vendégek, átcímzés és eseménybónusz | type:feature, P0, xmas-scope |
| 6 | Csillagrendszer (ismételt kiszolgálás) | type:feature, P2, xmas-scope |
| 7 | K2 döntési kapu: gyűjtés-játékteszt | type:playtest, P0, xmas-scope |

## M5 – Pizzéria + törzsvendégek + mentés

Telkek, 6 szint, törzsvendégek, passzív/offline borravaló, mentés, mozgáseszközök. K3 kapu. Becslés: 35–55 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | DataService: mentés session lockkal | type:tech, P0, xmas-scope |
| 2 | Pizzériatelkek kiosztása a közös téren | type:feature, P0, xmas-scope |
| 3 | Pizzéria szintek 1–6 és átépülés-animáció | type:feature, P0, xmas-scope |
| 4 | Törzsvendég-helyek és elhelyezés | type:feature, P0, xmas-scope |
| 5 | Passzív borravaló és befőttesüveg-begyűjtés | type:feature, P0, xmas-scope |
| 6 | Offline termelés | type:feature, P1, xmas-scope |
| 7 | Futárszint (XP) és szintjutalmak | type:feature, P1, xmas-scope |
| 8 | Mozgáseszköz-szintek (cipő → elektromos roller) | type:feature, P1, xmas-scope |
| 9 | Pizzéria-látogatás és like | type:feature, P2, xmas-scope |
| 10 | Napi bejelentkezési naptár (7 nap) | type:feature, P2, xmas-scope |
| 11 | K3 döntési kapu: visszatérés-teszt | type:playtest, P0, xmas-scope |

## M6 – Stílus + káosz-mérő + MEGA

Stílus-kézbesítés címkék, városi káosz-mérő, MEGA-KÁOSZ. Becslés: 20–30 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | Stílus-kézbesítés címkék és átadási képernyő | type:feature, P1, xmas-scope |
| 2 | Városi káosz-mérő és MEGA-KÁOSZ | type:feature, P1, xmas-scope |
| 3 | Heti kihívások | type:feature, P2, post-launch |

## M7 – Óriás rendelés

Kooperatív cipelés 2–4 játékosnak. Becslés: 20–35 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | Óriás rendelés: kooperatív cipelés | type:feature, P1, post-launch |
| 2 | Barát-bónusz | type:feature, P2, post-launch |

## M8 – Monetizáció

Gamepassok, developer productok, Rendelj katasztrófát, bolt, kozmetikák. Becslés: 25–40 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | MonetizationService: gamepassok és idempotens ProcessReceipt | type:monetization, P0, xmas-scope |
| 2 | Gamepassok bekötése | type:monetization, P0, xmas-scope |
| 3 | Developer productok: boostok, pénzcsomagok, kezdőcsomag | type:monetization, P0, xmas-scope |
| 4 | „Rendelj egy katasztrófát!” – közös fizetős esemény | type:monetization, P0, xmas-scope |
| 5 | „MEGA-KÁOSZ most!” termék | type:monetization, P1, xmas-scope |
| 6 | Bolt UI | type:ui, P0, xmas-scope |
| 7 | Kozmetikai rendszer: tulajdon, felszerelés, előnézet | type:monetization, P1, xmas-scope |

## M9 – Karácsony + indulás

Hóvihar, szezonális vendégek, analitika, mobil teljesítmény, store, zárt teszt. Becslés: 35–55 óra.

| # | Ticket | Labelek |
|---|---|---|
| 1 | Hóvihar szezonális esemény | type:feature, P0, xmas-scope |
| 2 | Karácsonyi tartalom: 5 vendég + Mikulás-futár szett | type:content, P0, xmas-scope |
| 3 | Analitika: funnel és gazdasági események | type:analytics, P0, xmas-scope |
| 4 | Mobil teljesítmény-optimalizálás | type:tech, P0, xmas-scope |
| 5 | Bélyegképek, ikon, store-leírás | type:launch, P0, xmas-scope |
| 6 | Zárt teszt és hibajavító kör | type:playtest, P0, xmas-scope |
| 7 | Publikálás: beállítások, korhatár-kérdőív, szerverméret | type:launch, P0, xmas-scope |

**Összesen:** 60 ticket, 10 mérföldkő.
