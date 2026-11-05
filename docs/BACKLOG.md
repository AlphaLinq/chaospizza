# Pizza Chaos 2.0 — Backlog

Generálva a `tools/backlog.py` + `tools/backlog_status.py` fájlokból. A GitHub issue-k az irányadók.

## M0 – Projektalap

Rojo, repó, CI, mappastruktúra, konfiguráció váza. Becslés: 6–10 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| Rojo projekt és mappastruktúra létrehozása | ✅ Kész | claude |
| StyLua + Selene + GitHub Actions CI | ✅ Kész | codex |
| Konfigurációs táblák váza (shared/Config) | ✅ Kész | claude |
| Hálózati réteg: szándék-alapú Remote-ok rate limittel | ✅ Kész | claude |
| Fejlesztői debug-panel (esemény indítás, pénz, reset) | ✅ Kész | claude |
| Típusdiagnosztikák javítása (luau-lsp 1.70.1) | ⬜ Nyitott | claude |

## M1 – Egy teljes kézbesítés

Szürkedobozos város, rendelés, céljelzés, átadás, borravaló, mobil vezérlés. Becslés: 25–40 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| Szürkedobozos Pepperoni negyed térkép | ✅ Kész | claude |
| OrderService: rendelés létrehozása, felvétele és jutalma | ✅ Kész | claude |
| Céljelzés: irány-nyíl, fénycsík, távolság | ✅ Kész | claude |
| Átadás interakció és szerveroldali ellenőrzés | ✅ Kész | claude |
| Mozgás és kamera hangolása | ✅ Kész | claude |
| Mobil vezérlés és gombkiosztás | 🟡 Részben kész | human |
| Alap HUD: cím, pizza, borravaló | ✅ Kész | claude |
| Onboarding: az első 3 perc | ✅ Kész | claude |
| „Hogyan játssz” súgópanel | ⬜ Nyitott | codex |

## M2 – Eseményrendszer + lóverseny

Állapotgép, ütemező, lóverseny, baleset/visszaállás. K1 döntési kapu. Becslés: 25–40 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| EventService: esemény-állapotgép és ütemező | ✅ Kész | claude |
| Lóverseny esemény | 🟡 Részben kész | claude |
| Baleset, ragdoll és visszaállás | ✅ Kész | claude |
| Elakadásból mentés (ingyenes) | ✅ Kész | claude |
| Esemény közbeni belépés és takarítás tesztelése | 🟡 Részben kész | claude |
| Esemény FX és hang alapok | 🟡 Részben kész | claude |
| K1 döntési kapu: lóverseny-játékteszt | ⬜ Nyitott | human |
| Lovak kliensoldali animálása | ⬜ Nyitott | claude |
| Hangrendszer és vizuális megfelelők | ⬜ Nyitott | codex |

## M3 – Tornádó + áradás/cápa

Két további esemény, átadási pont áthelyezés, takarítás. Becslés: 30–50 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| Tornádó esemény | ✅ Kész | claude |
| Áradás + cápa esemény | ✅ Kész | claude |
| Átadási pont áthelyezése áradáskor | ⬜ Nyitott | claude |

## M4 – Vendégek + Vendégkönyv

Vendégsorsolás, 24 vendég, Vendégkönyv UI, esemény-vendégek. K2 kapu. Becslés: 30–45 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| CustomerService: vendégsorsolás ritkasággal | ✅ Kész | claude |
| Kezdő 24 vendég: modellek, nevek, szövegek | 🟡 Részben kész | human |
| Vendégkönyv felület | ✅ Kész | codex |
| „ÚJ VENDÉG!” pillanat és mérföldkő-jutalmak | 🟡 Részben kész | claude |
| Esemény-vendégek, átcímzés és eseménybónusz | ✅ Kész | claude |
| Csillagrendszer (ismételt kiszolgálás) | ✅ Kész | claude |
| K2 döntési kapu: gyűjtés-játékteszt | ⬜ Nyitott | human |

## M5 – Pizzéria + törzsvendégek + mentés

Telkek, 6 szint, törzsvendégek, passzív/offline borravaló, mentés, mozgáseszközök. K3 kapu. Becslés: 35–55 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| DataService: mentés session lockkal | ✅ Kész | codex |
| Pizzériatelkek kiosztása a közös téren | ✅ Kész | claude |
| Pizzéria szintek 1–6 és átépülés-animáció | ✅ Kész | claude |
| Törzsvendég-helyek és elhelyezés | ✅ Kész | claude |
| Passzív borravaló és befőttesüveg-begyűjtés | 🟡 Részben kész | claude |
| Offline termelés | ✅ Kész | claude |
| Futárszint (XP) és szintjutalmak | ✅ Kész | codex |
| Mozgáseszköz-szintek (cipő → elektromos roller) | 🟡 Részben kész | codex |
| Pizzéria-látogatás és like | ✅ Kész | codex |
| Napi bejelentkezési naptár (7 nap) | ✅ Kész | codex |
| K3 döntési kapu: visszatérés-teszt | ⬜ Nyitott | human |
| Döntés: 3. mozgáseszköz — Roller vagy Roller Skates? | ⬜ Nyitott | human |

## M6 – Stílus + káosz-mérő + MEGA

Stílus-kézbesítés címkék, városi káosz-mérő, MEGA-KÁOSZ. Becslés: 20–30 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| Stílus-kézbesítés címkék és átadási képernyő | ✅ Kész | claude |
| Városi káosz-mérő és MEGA-KÁOSZ | ✅ Kész | claude |
| Heti kihívások | 🟡 Részben kész | codex |
| Heti kihívások: recordProgress a hiteles eseményeknél | ⬜ Nyitott | claude |

## M7 – Óriás rendelés

Kooperatív cipelés 2–4 játékosnak. Becslés: 20–35 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| Óriás rendelés: kooperatív cipelés | ✅ Kész | claude |
| Barát-bónusz | ✅ Kész | claude |
| Kétklienses QA: óriás rendelés, like, kozmetika, Thanks gomb | ⬜ Nyitott | human |

## M8 – Monetizáció

Gamepassok, developer productok, Rendelj katasztrófát, bolt, kozmetikák. Becslés: 25–40 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| MonetizationService: gamepassok és idempotens ProcessReceipt | ✅ Kész | codex |
| Gamepassok bekötése | 🟡 Részben kész | claude |
| Developer productok: boostok, pénzcsomagok, kezdőcsomag | 🟡 Részben kész | claude |
| „Rendelj egy katasztrófát!” – közös fizetős esemény | 🟡 Részben kész | codex |
| „MEGA-KÁOSZ most!” termék | ✅ Kész | claude |
| Bolt UI | ✅ Kész | codex |
| Kozmetikai rendszer: tulajdon, felszerelés, előnézet | ✅ Kész | codex |
| Borravaló-szorzók bekötése (DoubleTips, VIP, TipBoost) | ⬜ Nyitott | claude |
| Rendelt esemény: crash-biztos nyugtázás | ⬜ Nyitott | claude |
| Bolt: eseményválasztó a „Rendelj egy katasztrófát!”-hoz | ⬜ Nyitott | codex |

## M9 – Karácsony + indulás

Hóvihar, szezonális vendégek, analitika, mobil teljesítmény, store, zárt teszt. Becslés: 35–55 óra.

| Ticket | Állapot | Felelős |
|---|---|---|
| Hóvihar szezonális esemény | ✅ Kész | claude |
| Karácsonyi tartalom: 5 vendég + Mikulás-futár szett | 🟡 Részben kész | codex |
| Analitika: funnel és gazdasági események | ✅ Kész | codex |
| Mobil teljesítmény-optimalizálás | ⬜ Nyitott | claude |
| Bélyegképek, ikon, store-leírás | ⬜ Nyitott | human |
| Zárt teszt és hibajavító kör | ⬜ Nyitott | human |
| Publikálás: beállítások, korhatár-kérdőív, szerverméret | ⬜ Nyitott | human |
| EffectQuality alkalmazása az esemény-FX-ben | ⬜ Nyitott | claude |
| Mikulás-futár kozmetikai szett | ⬜ Nyitott | codex |
| Store-szöveg, leírás, ikon/bélyegkép terv | ⬜ Nyitott | codex |
| Teljesítmény-mérő debug parancs és budget | ⬜ Nyitott | codex |

**Összesen:** 74 ticket (39 kész), 10 mérföldkő.
