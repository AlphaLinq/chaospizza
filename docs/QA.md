# Automatikus Studio-füstteszt

Friss, egyszemélyes Studio Play tesztben, nyugodt várossal, üres káoszmérővel és rendelés nélkül nyisd a DEV panelt, majd futtasd: `smoke`. A teszt legfeljebb110 másodperc; futás közben ne játssz manuálisan.

MCP Client környezetből: `game.ReplicatedStorage.Remotes.DebugRun:FireServer("smoke")`. A hívás indít, a részletes, folyamatosan frissülő eredmény a játékos `SmokeReport` attribútuma. A `smoke status` debug parancs is kiírja. Minden lépés PASS/FAIL és részletes hibaüzenetet ad a konzolban/JSON-ban.

Rendelésfelvétel, valódi szerveres kézbesítési API, shop-preview, dupla napi claim és teljes MEGA warning→active→calm ciklus fut. Végül a profil, a mock rangsor, a könyvjelzés és a pozíció/káoszmérő/onboarding visszaáll; az aktív tesztrendelés törlődik. Ha a játék eseményciklusa hibásan nem ér véget, az event/cleanup sor FAIL marad, a teszt nem állít sikeres takarítást.

Csak Studio + engedélyezett debug játékos + memória-mock profil mellett fut. Éles szerveren a debug parancs sincs regisztrálva, a public API is elutasít. Pozitív badge ID mellett elutasít, hogy ne adjon visszavonhatatlan valódi achievementet. Nincs Robux prompt, meghívó küldés, publikálás vagy éles DataStore-írás.

Korlát: ez nem helyettesíti a fizikai mobil/gamepad és kétklienses barát/like/óriáspizza próbákat. A saját UI-khoz360px és nagy szöveg, egér/touch/gamepad fókusz és magyar/angol szöveg külön ellenőrzendő.

## Kontroller és keskeny felület

A Select/View gomb beléptet a saját menük fókuszába. D-pad/bal kar választ, A aktivál, B bezárja az aktuális PizzaOverlay panelt és visszaadja az előző fókuszt. A jobb kar görgeti a kijelölt görgethető régiót; a Book olvasható soraihoz maga a görgető is kijelölhető. A Roblox rendszermenüje nyitott állapotban elsőbbséget kap. A kódbeírásnál a platform natív TextBox/virtuális billentyűzetét kell használni.

Kézi kör fizikai kontrolleren: Book, Shop mindhárom fül és termékgomb, Daily kihívások, Settings és minden alnézete, Looks/Rides kiválasztás, Codes beírás, közösségi profil/látogatás és emote. Ellenőrizd a sárga fókuszkeretet, a görgetést, a B-visszatérést, majd egérrel és érintéssel is nyisd újra. Válts magyar/angol nyelvre és normál/nagy szövegre; 360px szélességen a hosszú fülek oldalra görgethetők.

2026-11-05 gépi/motoros ellenőrzés: a fókuszgráf/SelectionGroup létrejött, szintetikus B bezárta a Settings és Shop panelt; natív egérkattintással a bolt fülei és a szerverről érkező terméksorok működtek. Magyar/nagy szöveg/360px mellett a saját panelek TextBounds ellenőrzése nem talált levágott szöveget; két Settings-képernyőkép vizuálisan ellenőrizve. A Studio MCP szintetikus A/D-pad bemenete billentyűzetként jelentkezett, ezért ez **nem** igazol fizikai gamepadot, analóg kart vagy konzolos virtuális billentyűzetet. Fizikai telefon/kontroller és többklienses próba továbbra is kézi ellenőrzés.
