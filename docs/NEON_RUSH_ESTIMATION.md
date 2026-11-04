# NEON RUSH — fejlesztési, játékosszám- és bevételi becslés

**Készült:** 2026. november 4.

**Kapcsolódó terv:** [NEON_RUSH_GAME_BRIEF.md](NEON_RUSH_GAME_BRIEF.md)

**Munkamód:** egy fejlesztő, AI-segítséggel. A felhasználónak már van Codex-előfizetése és saját közlése szerint havi 20 USD-s Claude-előfizetése. A heti fejlesztési óraszám, a Roblox-tapasztalat, a Codex díja és a marketingkeret még nem ismert.

> Ez döntést segítő forgatókönyvmodell. A fejlesztési órák szakmai becslések; a játékosszámok és vásárlási arányok tesztelendő feltételezések. Nem rendelkezünk saját játékadatokkal vagy megfelelő összehasonlító mintával ahhoz, hogy várható bevételt, siker-valószínűséget vagy biztos növekedési pályát adjunk meg.

## 1. Rövid következtetés

- **Az első értékelhető, egypályás prototípus:** körülbelül 90–150 aktív munkaóra, tartalékkal.
- **A brief szerinti hárompályás, mobilon is használható, monetizálható kis kiadás:** körülbelül 375–650 aktív munkaóra, tartalékkal.
- **Heti 35 órával:** a prototípus nagyjából 3–5 hét; a kis kereskedelmi kiadás 11–19 hét a fejlesztés kezdetétől.
- **Heti 20 órával:** a prototípus nagyjából 5–8 hét; a kis kereskedelmi kiadás 19–33 hét a fejlesztés kezdetétől.
- **A pénzügyi tervben kezdetben 0 bevétellel érdemes fedezni a kiadásokat.** Ez költségtervezési szabály, nem állítás a bukás valószínűségéről.
- A középső vásárlási feltételezéssel **1 000 napi aktív játékos kb. 120 USD/hó**, **10 000 napi aktív kb. 1 197 USD/hó** kozmetikai bevételnek felel meg a Roblox részesedése után, saját költségek és adó előtt.
- **1 000 egyszerre online játékos egészen más lépték:** napi 20 perc játékidővel átlagosan kb. 72 000 napi aktívat jelentene, és a középső modellben kb. 8 618 USD/hót.

Az első célnak a 90–150 órás prototípus és a visszatérési hajlandóság igazolása javasolt. A teljes játékra szánt időt ennek eredménye alapján érdemes felszabadítani.

## 2. Mit becsülünk, és mit nem tudunk még?

| Tényező | Jelenlegi státusz |
|---|---|
| Egyedüli fejlesztés AI-val | Felhasználó által megadva |
| Claude-előfizetés | Felhasználó által megadott 20 USD/hó |
| Codex-előfizetés | Meglévő, pontos díja nincs megadva; a képletekben `C` |
| Heti munkamennyiség | Több változatban számoljuk |
| Roblox/Luau-tapasztalat | Nem ismert; az időbecslés feltételezi az alapvető Studio-munkavégzést |
| Kezdeti közönség | Nincs igazolt meglévő közönség a modellben |
| Hirdetés és külsős munka | Nincs jóváhagyott vagy megadott keret |
| Fizetővé válás és költés | Saját tesztadat helyett érzékenységi feltételezések |
| Organikus ajánlások | Nem garantáltak és nincs rájuk előrejelzés |

Az AI a kódírásban, szerkesztésben, hibakeresésben és dokumentálásban segít. A jó mozgás, a pályaritmus, az eszközteszt és a játékos-visszajelzés továbbra is iterációt igényel. Nem alkalmazunk bizonyítatlan „AI-val tízszer gyorsabb” szorzót.

Ha a Studio és a kliens–szerver működés tanulása is most kezdődik, a megadott időkeretek felfelé módosulhatnak. Az első 20–30 tényleges munkaóra után újra kell becsülni a hátralévő munkát.

## 3. Fejlesztési munkaóra-becslés

Az alábbiak egymás után értendő munkacsomagok. A korábbi fázisok munkáját nem kell újra hozzáadni egy későbbi mérföldkőhöz.

| Munkacsomag | Mit tartalmaz? | Aktív óra, tartalék előtt |
|---|---|---:|
| 1. Mozgási alap | Futás, ugrás, dash, falon futás, kamera, első mobilos bemenet | 30–50 |
| 2. Egy teljes tesztpálya | Egy fegyver, drón, dash-visszatöltés, checkpoint, HUD, újraindítás | 40–70 |
| 3. Közös játék | Gyakorlótér, elkülönített célpontok, játékosok megjelenítése, hálózati hibák | 50–90 |
| 4. Három pálya és látvány | Két további pálya, saját vizuális elemek, hangok, alapfelületek | 80–140 |
| 5. Kozmetikák és mentés | Két kis szett, előnézet, felszerelés, rekordok és tulajdon mentése | 40–70 |
| 6. Kis kereskedelmi kiadás | Vásárlás és jogosultságkezelés, analitika, eszközteszt, hibajavítás, kiadási anyagok | 60–100 |
| **Összesen** | | **300–520** |
| **25% tervezési tartalék** | Újratervezés, integráció, nem várt hibák | **75–130** |
| **Teljes tervezési keret** | | **375–650** |

Az első két munkacsomag együtt 70–120 óra, 25% tartalékkal 87,5–150 óra; ezért használjuk a kerekített **90–150 órás prototípuskeretet**.

A 25% tartalék tervezési döntés, nem statisztikai konfidenciaintervallum. A becslés nem tartalmaz nagy nyílt világot, PvP-t, battle passt, sok fegyvert, pályaszerkesztőt vagy hosszú történetet.

## 4. Naptári idő különböző munkatempókkal

| Heti tényleges munka | Egypályás prototípus | Kis kereskedelmi kiadás, kezdéstől |
|---:|---:|---:|
| 10 óra | 9–15 hét | 38–65 hét |
| 20 óra | 5–8 hét | 19–33 hét |
| 35 óra | 3–5 hét | 11–19 hét |
| 50 óra | 2–3 hét | 8–13 hét |

A hetek felfelé kerekítettek. A játékpróbákra várás, szünetek és egyéb elfoglaltságok külön naptári csúszást okozhatnak. A heti 50 órás sor azonos aktív óraszám gyorsabb elosztása, nem állítás arról, hogy ez a tempó fenntartható.

**Fontos különbség:** a „három hónap alatt játék” és a „megjelenés utáni harmadik hónap bevétele” nem ugyanaz az időpont. A lentebbi bevételi hónapok a monetizált nyilvános indulástól számítanak.

## 5. A bevétel átváltásának ellenőrzött alapjai

A modell a saját játékban eladott saját passokhoz dokumentált **70%-os alkotói részesedést** használja. Ez megfelelő kiindulópont közvetlen, tartós kozmetikai jogosultságokhoz. Más terméktípus vagy értékesítési felület esetén a tényleges részesedést külön kell ellenőrizni. [Roblox monetizáció](https://create.roblox.com/docs/monetize-experiences)

A standard DevEx-váltás **1 Earned Robux = 0,0038 USD**. Bizonyos jogosult amerikai, igazoltan 18+ játékosoktól származó bevételekre magasabb ráta létezik, de erre a fiatalabb közönséget is célzó tervben nem alapozunk. A DevEx minimális egyenlege **30 000 Earned Robux**, ami standard rátán 114 USD érték. A jogosultság és jóváhagyás külön feltétel. [Roblox DevEx](https://create.roblox.com/docs/production/monetization/developer-exchange)

| Játékos tényleges költése | 70%-os alkotói rész | Standard DevEx-érték |
|---:|---:|---:|
| 100 Robux | 70 Earned Robux | 0,266 USD |
| 200 Robux | 140 Earned Robux | 0,532 USD |
| 400 Robux | 280 Earned Robux | 1,064 USD |

Ezek eladásonkénti elméleti értékek; a kis összegek nem válthatók külön azonnal készpénzre. A függő bevétel, az elszámolás, a DevEx-feldolgozás és az esetleges utalási költség miatt a megszerzett érték és a bankszámlára érkezett pénz időben eltérhet.

## 6. Fogalmak: DAU, CCU és látogatás

- **DAU:** egy napon játszó különböző játékosok száma.
- **Átlagos DAU egy hónapban:** a napi DAU-értékek átlaga.
- **CCU:** egy adott pillanatban egyszerre online játékosok száma.
- **Átlagos CCU:** teljes napra vagy hosszabb időre vett átlag; nem a délutáni csúcs.
- **Visit / látogatás:** játékalkalom. Egy ember több látogatást is létrehozhat.
- **Napi játékidő / aktív játékos:** az adott napon minden alkalom összege, nem feltétlenül egyetlen session hossza.

Átlagokkal számolva:

```text
átlagos CCU = DAU × napi összes játékperc / 1 440
```

Napi 20 percet feltételezve:

| Átlagos CCU | Közelítő DAU | Középső modell havi kozmetikai bevétele |
|---:|---:|---:|
| 10 | 720 | 86 USD |
| 100 | 7 200 | 862 USD |
| 1 000 | 72 000 | 8 618 USD |

A 20 perc feltételezés, nem mért adat. Tízperces napi játékidő mellett ugyanakkora CCU kétszer annyi napi különböző játékost jelentene. Csúcs-CCU-ból ezzel a képlettel nem szabad DAU-t számolni.

## 7. A kozmetikai bevétel képlete

```text
D = hónap átlagos napi aktív játékosszáma
p = az aktív játékosnapok közül vásárlással járók aránya
s = egy vásárló játékos átlagos összes költése a vásárlás napján, Robuxban

játékosok havi költése = D × 30 × p × s
alkotói Earned Robux = játékosok havi költése × 0,70
havi standard DevEx-érték USD-ben = alkotói Earned Robux × 0,0038
```

Minden hónapot 30 naposra egyszerűsítünk. A költés tényleges realizált ár, így az árengedmények és eltérő árak hatását is ebben kell megjeleníteni.

A napi vásárlási arány nem azonos a havi egyedi vásárlók arányával. Egy játékos többször is vásárolhat, de a tartós kozmetikai kínálat véges: a későbbi hónapokban ugyanekkora költéshez megfelelő kínálat és/vagy új játékosok is kellenek. A modell állandó vásárlási paraméterei egyszerűsítések, nem garantáltan fenntartható értékek.

## 8. Három vásárlási feltételezés

| Paraméter | Gyenge monetizáció | Középső feltételezés | Erős monetizáció |
|---|---:|---:|---:|
| Napi vásárlási arány | 0,3% | 1,0% | 2,0% |
| Vásárlási napon átlagos költés | 100 Robux | 150 Robux | 200 Robux |
| Játékosköltés / aktív játékosnap | 0,30 Robux | 1,50 Robux | 4,00 Robux |
| Standard DevEx-érték / aktív játékosnap | 0,000798 USD | 0,003990 USD | 0,010640 USD |

**Ezek modellbemenetek, nem Robloxos iparági átlagok.** A „középső” a kiválasztott érzékenységi sor közepe, nem a legvalószínűbb eredmény.

Az erős monetizáció nem következik automatikusan a nagy közönségből. Nagy játékosszám mellett is előfordulhat a gyenge vásárlási arány.

## 9. Mekkora játékosszám mekkora bevételt jelenthet?

**Havi kozmetikai DevEx-érték, Roblox-részesedés után, saját költség és adó előtt; Creator Rewards nélkül:**

| Átlagos DAU | Gyenge monetizáció | Középső feltételezés | Erős monetizáció |
|---:|---:|---:|---:|
| 100 | 2,39 USD | 11,97 USD | 31,92 USD |
| 1 000 | 23,94 USD | 119,70 USD | 319,20 USD |
| 10 000 | 239,40 USD | 1 197,00 USD | 3 192,00 USD |

**Kidolgozott példa, 1 000 DAU-val és középső monetizációval:**

```text
1 000 × 1% = átlagosan 10 vásárló játékosnaponta
10 × 150 × 30 = 45 000 Robux havi játékosköltés
45 000 × 70% = 31 500 Earned Robux
31 500 × 0,0038 = 119,70 USD standard DevEx-érték
```

Az alacsony forgalmú sorok matematikai átlagok. A tényleges vásárlások darabosak: lehet több nap vásárlás nélkül, majd egyetlen nagyobb eladás.

## 10. Megjelenés utáni 1–6 hónap: lehetséges pályák

Az alábbi számok **szándékosan választott stressz- és növekedési forgatókönyvek**, nem a dátumból levezetett előrejelzések. Minden cella az adott hónap átlagos DAU-ját és az adott hónap bevételi értékét mutatja.

A növekedő sorok feltételezik, hogy folyamatosan érkezik új közönség és van visszatérés. Ezek megszerzésének költségét a bevétel még nem vonja le. Nincs olyan állítás, hogy a megjelenés önmagában előállítja ezt a forgalmat.

| Megjelenés óta | Gyenge elérés + gyenge monetizáció | Kisebb működő közösség + középső monetizáció | Erős növekedés + erős monetizáció |
|---|---:|---:|---:|
| 1. hónap | 20 DAU / 0,48 USD | 100 DAU / 11,97 USD | 300 DAU / 95,76 USD |
| 2. hónap | 30 DAU / 0,72 USD | 200 DAU / 23,94 USD | 800 DAU / 255,36 USD |
| 3. hónap | 30 DAU / 0,72 USD | 400 DAU / 47,88 USD | 2 000 DAU / 638,40 USD |
| 4. hónap | 20 DAU / 0,48 USD | 650 DAU / 77,81 USD | 4 000 DAU / 1 276,80 USD |
| 5. hónap | 15 DAU / 0,36 USD | 850 DAU / 101,75 USD | 6 500 DAU / 2 074,80 USD |
| 6. hónap | 10 DAU / 0,24 USD | 1 000 DAU / 119,70 USD | 10 000 DAU / 3 192,00 USD |
| **Első hat hónap összege** | **2,99 USD** | **383,04 USD** | **7 533,12 USD** |

Az összesítések a kerekítetlen számokból készültek; a kijelzett havi centértékek összege néhány centtel eltérhet.

**Külön figyelembe veendő kimenet:** a játék nem szerez tartós közönséget, vagy az induló érdeklődés után elfogy. Ekkor bármelyik hónap bevétele lehet 0. A 6. hónap sem jelent automatikus javulást.

Az erős oszlopot nem szabad a fejlesztés finanszírozásának alapjául venni. Ennél nagyobb eredmény is lehetséges, de nincs adatunk annak időpontjára vagy valószínűségére.

## 11. Mekkora közönség kell egy bevételi célhoz?

Az alábbi célok saját költség és adó előtti havi kozmetikai bevételt jelentenek. Középső monetizációval és napi 20 perc játékidővel:

| Havi bevételi cél | Szükséges átlagos DAU, felfelé kerekítve | Közelítő átlagos CCU |
|---:|---:|---:|
| 100 USD | 836 | 12 |
| 500 USD | 4 178 | 58 |
| 1 000 USD | 8 355 | 116 |
| 3 000 USD | 25 063 | 348 |
| 10 000 USD | 83 543 | 1 160 |

**Havi 1 000 USD elérésére nem tudunk megalapozott határidőt mondani.** Azt tudjuk megmondani, milyen közönség–költés kombináció kell hozzá. Ha az erős növekedési forgatókönyv és az erős monetizáció együtt teljesül, a példában a 4. megjelenés utáni hónap lépi át ezt az összeget. Ez feltételes példa, nem vállalás.

## 12. Creator Rewards: külön lehetséges bevétel

A dokumentált Daily Engagement Reward jogosult aktív költőnként napi **5 Robux**, megfelelő, legalább 10 perces játék és az első három jogosult élmény közé kerülés esetén. A jutalmakhoz 60 napos visszatartás tartozik. [Roblox Creator Rewards](https://create.roblox.com/docs/creator-rewards)

Ezt az alapbevételbe nem számítottuk bele, mert nem tudjuk, a mi játékosaink mekkora része teljesíti valamennyi feltételt.

**Érzékenységi példa:** ha 1 000 DAU mellett a játékosnapok 5%-a ténylegesen jutalmazott lenne:

```text
1 000 × 5% × 5 × 30 = 7 500 Earned Robux / hónap
7 500 × 0,0038 = 28,50 USD / hónap érték
```

Az 5% nem mért arány. A Creator Rewards már alkotói jutalom: nem vonjuk le belőle ismét a pass-eladások 30%-át. A készpénzhez jutás időpontja a jutalom keletkezésénél későbbi.

## 13. Költségek és tényleges profit

### Előfizetések

```text
Claude = felhasználó által megadott 20 USD / hónap
Codex = C USD / hónap, pontos díj még ismeretlen
projektnek tulajdonított AI-előfizetés = 20 + C USD / hónap
```

Ha ezeket a projekttől függetlenül is fizetnéd, a játék miatti **új pénzkiadás** akár 0 is lehet. A projekt teljes gazdasági eredményéhez viszont érdemes legalább a használat arányos részét hozzárendelni. A két nézőpontot külön kell vezetni.

### További költségek

- Opcionális modellek, hangok, zene vagy külsős munka.
- Hirdetési tesztek és későbbi közönségszerzés.
- Kiadás utáni hibajavítás, pályák és kozmetikák készítése.
- Esetleges fizetési, deviza- és adóterhek.

Külsős munka és hirdetés ára nincs megbecsülve piaci árként, mert a szükséges munka és a forgalomszerzés eredménye még ismeretlen.

### Egy átlátható költségpélda

**Kizárólag tervezési példa, nem jóváhagyott költés:** 300 USD egyszeri kiadás és havi 100 USD további működési/tesztkeret, valamint a teljes AI-előfizetések hozzárendelése.

```text
első 6 megjelenés utáni hónap költsége
= 300 + 6 × (100 + 20 + C)
= 1 020 + 6C USD
```

| Forgatókönyv | 6 havi kozmetikai bevétel | Eredmény a fenti pénzkiadások után |
|---|---:|---:|
| Gyenge | 2,99 USD | −1 017,01 − 6C USD |
| Kisebb működő közösség | 383,04 USD | −636,96 − 6C USD |
| Erős növekedés | 7 533,12 USD | +6 513,12 − 6C USD |

Ez még adó és saját munkadíj előtti eredmény. A fejlesztés alatti előfizetések sincsenek benne: `D` fejlesztési hónap esetén további `D × (20 + C)` USD-t kell hozzárendelni, ha teljes előfizetési költséggel számolunk. Az erős növekedési oszlophoz szükséges tényleges közönségszerzési költség magasabb is lehet a példakeretnél.

**Saját idő példája:** 500 fejlesztési óra, óránként saját döntéssel 15 USD-re értékelve 7 500 USD munkaráfordítás. Ez nem Roblox-fejlesztői piaci óradíj, hanem választható belső értékelés. A kiadás utáni munkát külön kell hozzáadni.

## 14. Miért nem lehet egyszerűen hirdetéssel megvenni a sikert?

A megengedhető játékosszerzési költséget a megszerzett játékos későbbi bevétele határozza meg.

A középső monetizáció napi aktív játékosonként 0,00399 USD kozmetikai értéket ad. Ha egy új játékos az első 30 napban összesen 4 különböző napon játszik:

```text
30 napos kozmetikai bevétel / megszerzett játékos
= 4 × 0,00399
= 0,01596 USD
```

A 4 aktív nap itt csak példa. Ebben a példában az első 30 nap kozmetikai bevétele nagyjából 1,6 centnyi közvetlen szerzési költséget fedezne, működési kiadások előtt. Ez nem hirdetési árbecslés.

Ha a tényleges szerzési költség ennél magasabb, több aktív napra, jobb monetizációra, további bevételre vagy hosszabb megtérülési időre lenne szükség. A hirdetésből esetleg következő organikus ajánlásokat nem szabad előre biztos bevételként jóváírni.

## 15. Mit kell mérni, és mikor lesz jobb becslésünk?

| Időpont | Ellenőrizendő kérdés | Következő döntés |
|---|---|---|
| Első 20–30 munkaóra | Mennyire működik az eszközlánc, a mozgás és a mobilos bevitel? | Fejlesztési órabecslés frissítése |
| Egypályás prototípus után | Végigmennek-e, megértik-e a dash-visszatöltést, újrapróbálják-e? | Folytatás vagy az alapmechanika módosítása |
| Első többalkalmas teszt | Visszajönnek-e, látnak-e értéket a közös játékban? | Hárompályás verzió terjedelmének eldöntése |
| Nyilvános teszt első hete | Hol lépnek ki, mobilon mi romlik el, mennyi új játékos érkezik? | Onboarding és technikai javítás |
| Megjelenés utáni 2–4. hét | Kezd alakulni a megtartás, a boltérdeklődés és a vásárlás? | Feltételezett arányok cseréje mért adatokra, ha elég nagy a minta |
| Megjelenés utáni 6–8. hét | Tartósabb-e a közönség, van-e ismételt költés? | Tartalomgyártás és szerzési keret újratervezése |
| 3. hónap | Javul-e a közönség és a gazdaságosság a ráfordításhoz képest? | Folytatás, szűkítés vagy új irány |

A D1/D7/D30 megtartást az új játékosok belépési csoportjai szerint kell nézni. A D30-adat az adott csoport első belépésétől számított 30. nap előtt még nem áll rendelkezésre. [Roblox Retention](https://create.roblox.com/docs/production/analytics/retention)

Kis forgalomnál az idő múlása önmagában nem teremt elég mintát. Ha 100 játékosból egy vásárol, az nem bizonyít stabil 1%-os vásárlási arányt. A bizonytalanságot és az eszközönkénti eltéréseket a frissített modellben is meg kell tartani.

## 16. Javasolt projektvállalás jelenleg

1. **Első keret:** 90–150 aktív óra az egypályás prototípusra és annak tesztjére.
2. **Heti 35 órás munkamóddal:** 3–5 hét után legyen játszható bizonyíték az alapélményről.
3. **A következő 285–500 órát** csak akkor fordítsuk a teljes kis kiadásra, ha a prototípusból érdemes továbbmenni. Ez a teljes keret és a megfelelő prototípuskeret különbségének kerekített sávja.
4. **Pénzügyi fedezet:** a fejlesztési időszakra és az első három nyilvános hónapra bevétel nélkül is vállalható kiadásokat tervezzünk.
5. **Első üzleti cél:** visszatérő közönség és tényleges kozmetikai vásárlás bizonyítása. A havi 1 000 USD ezután legyen mérhető növekedési cél.

Heti 35 órával a kis kiadás és az azt követő 2–3 hónap megfigyelése összesen nagyjából **5–7,5 hónapos döntési időtáv**. Heti 20 órával inkább **6,5–11 hónap**. Ennyi idő után már több információnk lehet arról, hogy érdemes-e tovább építeni; ez továbbra sem bevételi határidő.

## 17. Újraszámoláshoz szükséges bemenetek

- Tényleges heti munkaóra.
- Első 20–30 óra alapján mért fejlesztési tempó.
- A projektre terhelt Codex-díj és Claude-díj aránya.
- Induló és havi opcionális költségkeret.
- Napi aktív játékosok és napi összes játékidő.
- Napi vásárlási arány és vásárlási napon átlagos realizált költés.
- Tényleges Earned Robux és jogosult Creator Rewards.
- Megszerzett játékosok 7 és 30 napos bevétele, valamint szerzési költsége.
- Új pálya és új kozmetikai szett tényleges előállítási ideje.

A pénzösszegek USD-ben szerepelnek. Forintos tervnél külön, dátummal ellátott árfolyamfeltételezés kell; a vásárlási Robux-árfolyamot nem szabad DevEx-kifizetési árfolyamként használni.
