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
