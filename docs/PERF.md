# Mobil teljesítmény mérése

A `perf` DEV-parancs szerveres pillanatképet és a helyi kliens utolsó legfeljebb600 képkockájáról jelentést készít. A `perf client 30` új,30 másodperces kliensmérést indít;1–60 másodperc választható. Új mérés felváltja a korábbit. Nincs új remote, kliensről érkező statisztikát a szerver nem fogad el és nem használ játékmeneti döntésre. A meglévő DebugService jogosultsága élesben továbbra szükséges.

A JSON a szerver Output `[Perf server]` és a kliens `[Perf client]` sorában, illetve `Player.PerfServerReport` és `PlayerGui.PerfClientReport` attribútumban olvasható. A `PlayerGui.PerfCapture` running/done állapota jelzi a mérést. Client capture esetén az összesítés mellett külön EventId/ComboId/EventPhase/quality szegmensek látszanak; egy esemény végén átnyúló mérés így felismerhető. A gyűrűkapacitás18000 frame, a `truncated` megmondja, ha a percentilis csak a megőrzött részhalmazból készült. Átlag, p95, legrosszabb képkocka és a célidőn túli frame-ek számítanak; a megakadást nem vágjuk le.

A számláló Workspace instance/part/nem-anchored/emitter/szóló hang számot, engedélyezett emission rate-et és `Rate × Lifetime.Max` élőrészecske-becslést ad. A burst-Emit pillanatnyi részecskeszáma nem olvasható pontosan, ezért a becslés nem fedi le. Az Event_* szervermappák és a LocalHorses/LocalTornado/LocalSnow kliensgyökerek külön szerepelnek. A scanMs eltelt falióra-idő, tartalmazhat együttműködő yieldet; nem CPU-profilerérték.

A Stats által elérhető DataSendKbps/DataReceiveKbps, fizikai forgalom, memória és renderadatok nyersen kerülnek a jelentésbe; hiányzó property az unavailableStats listán van. A szerver `transformTrafficModel` mezője **nem mért sávszélesség**: a figyelt esemény-partok CFrame-változásai és CityState attribútumváltozásai × konfigurált64byte × jelenlegi játékosszám. Nem modellezi a tömörítést, relevanciát, headereket vagy minden motoros replikációt; `coverageLimited` jelzi a partfigyelési plafont. A tényleges hálózati mezők/Roblox profiler az irányadók.

A budgetek a Config/Perf-ben vannak. A szerver15 másodpercenként vizsgál, fázisonként/budgetenként legfeljebb egyszer figyelmeztet. A kliens snapshot is listázza a túllépéseket. A mintavételezés és a részletes bejárás nem fut minden frame-ben; minden-frame munka néhány korlátozott frame-számláló frissítése.

## Valódi telefonos elfogadási kör (#57)

1. Középkategóriás készülék modellje/OS/Roblox-verziója, dátum/placeVersion, képernyőméret, hőállapot és minőség rögzítve. Studio Device Emulator nem telefonos teljesítménymérés.
2. Privát tesztben12 valódi kliens vagy megfelelő szerverterhelés,12 pizzéria, feltöltött törzsvendéghelyek. A DEV jogosultságot az engedélyezett UserId-lista tulajdonosa állítja; a PerfService nem kerüli meg.
3. Calm, HorseRace, Tornado, Flood, Blizzard és MEGA alatt külön legalább30s low/medium próba; mozogj a főtéren, lépj közel/távol a pizzériáktól. `perf client 30`, majd mentsd mindkét JSON-t. A teljes mérés legyen a célállapotban, vagy a megfelelő szegmenst értékeld.
4. Mobil Roblox Settings → MicroProfiler On. Ugyanazon hálózaton a gép böngészőjével nyisd a telefon kijelzett IP:port címét, ments frame dumpot az esemény és akadás idejéből. [Hivatalos útmutató](https://create.roblox.com/docs/performance-optimization/microprofiler).
5. Átlag legalább30 FPS, p95 legfeljebb33.33ms a cél; figyeld a legrosszabb frame-et, memóriaemelkedést, újra lefutó esemény utáni emitter/instance-visszaállást és a mért hálózati adatokat. Mikroprofilban a script/render/physics tüskéket nevezd meg.
6. Az issue #57 kommentjébe eszköz,12fős terhelés, esemény/minőség/átlag/p95/max/memória/hálózat táblázat és dumpok kerüljenek. Csak ez igazolja a telefonos elfogadást; a desktop Studio számai nem.

A StreamingEnabled jelenleg kikapcsolva marad: a kicsi, közös térkép és a meglévő klienskeresések még nem teljesen streaming-biztosak. Bekapcsolás előtt külön stream-out/stream-in, célpont, prompt és távoli pizzéria regressziós próba kell; a mérőmodul nem módosít játékbeállítást.

API-háttér: [Roblox Stats](https://create.roblox.com/docs/reference/engine/classes/Stats), [MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler).

## Desktop Studio sanity-mérés — 2026-11-05

Friss Rojo build,1 játékos,high minőség,1136×860 logikai viewport,3 másodperces aktív szegmensek. Több Studio-példány futott, ezért ez kizárólag a mérőműszer és a budgetek működését ellenőrzi; **nem** a #57 telefonos/12fős elfogadása. Nyers adatok: [studio-2026-11-05.json](perf/studio-2026-11-05.json). A memória az egész Studio-környezet terhét is tartalmazza.

| Esemény | Átlag FPS | p95 ms | Szerver / kliens part | Kliens budget-túllépés |
|---|---:|---:|---:|---:|
| HorseRace | 57.86 | 17.44 | 249 / 260 | 0 |
| Tornado | 60.00 | 17.38 | 174 / 194 | 0 |
| Flood | 60.01 | 17.34 | 217 / 218 | 0 |

## #57 Részecskekeret és pizzéria-LOD

A Config/Perf.visualProfiles low/medium/high kerete rendre120/480/1000 részecske/s és720/2400/5000 `Rate×Lifetime.Max` becsült élőrészecske. A saját ParticleBudgetController a már minőségskálázott kéréseket közösen, arányosan korlátozza; nem szorozza újra Claude quality multiplierét. Kikapcsolt emitter eredeti rate-je megmarad, az Enable visszakapcsolható. A burst `Emit` darabszámát nem tudja utólag korlátozni; a jelenlegi splash/MEGA burstök már a meglévő controllerben korlátosak és quality-skálázottak. A követhető helyi összesítés PlayerGui.ParticleBudget.

A saját PizzeriaLodController0.5s-onként dolgozik,20stud hiszterézissel. Low/medium/high törzsvendég-távolság80/120/180stud; árnyéktávolság80/140/220. Távolról a törzsvendég LocalTransparencyModifierrel rejtett, felirata kikapcsolt; a PizzeriaRegular **helyi** tag ideiglenes levétele a meglévő renderer publikus removal signalján állítja le az animációt. Közelről a pose/transparency/tag/felirat visszaáll. A szerver tagje, profilja, termelése és geometriája változatlan. A távoli pizzéria árnyékai kapcsolódnak le, az épület sziluettje, pultja és ütközése megmarad. Későn érkező elemek/újraépítés/destroy kezelt; PlayerGui.PizzeriaLod mutatja az állapotot.

Motoros stresszpróba:400/900 rate-es,6/10s lifetime-os két emitter low keretben82.023/s és719.280 becsült élő részecske; high-ra váltva569.605/s és4995.000. Fixture törlése után0/0. Egy110studra lévő, a meglévő120stud animatorhatáron belüli szerveres figura pózfrissítése rejtve0, közelről37/0.6s, ismét távol0 volt. Három oda-vissza váltás után0radián sodródás. A kliensen rejtett figura szervertagje/átlátszatlansága/árnyéka megmaradt, a pult CanCollide=true. A fixture-ök ideiglenesek voltak és eltávolítva.

### Mérésfókusz és megmaradt elfogadás

A háttérben futó Studio Blizzard/MEGA low capture pontosan15 FPS körüli eredményt adott, miközben a render CPU1.8–1.9ms volt. Azonos kóddal előtérbe hozva a calm60.01 FPS lett. A mérő ezért már rögzíti a WindowFocused/WindowFocusReleased jeleket, a backgroundFrames/unknownFocusFrames számát és külön fókusz-szegmenst. A foregroundVerified csak teljesen ismert, háttérképkocka nélküli mintán true; a rossz frame-eket nem távolítja el.

Új30s,low,1játékos,előtéri MEGA Tornado+HorseRace capture:59.84 FPS, p9517.43ms,0 background/unknown frame, foregroundVerified=true,0budget warning. A korábbi15 FPS-es capture-öket is megőriztem: [nyers teljes jegyzőkönyv](perf/studio-mobile-2026-11-05.json). Ezek továbbra desktop Studio-adatok.

**#57 nyitott elfogadása:** valódi középkategóriás telefon,12játékos/12pizzéria/feltöltött törzsvendégek, eseményenkénti30s mérés és MicroProfiler dump. A kódmunka és eszközök elkészültek, ezt a készülékes eredményt nem állítja elő a desktop Studio.

A közben kért gördülő snapshot nem állítja done-ra az időzített capture-t; új capture generációja kizárja a korábbi késői eredményt.
