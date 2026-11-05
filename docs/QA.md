# Automatikus Studio-füstteszt

Friss, egyszemélyes Studio Play tesztben, nyugodt várossal, üres káoszmérővel és rendelés nélkül nyisd a DEV panelt, majd futtasd: `smoke`. A teszt legfeljebb110 másodperc; futás közben ne játssz manuálisan.

MCP Client környezetből: `game.ReplicatedStorage.Remotes.DebugRun:FireServer("smoke")`. A hívás indít, a részletes, folyamatosan frissülő eredmény a játékos `SmokeReport` attribútuma. A `smoke status` debug parancs is kiírja. Minden lépés PASS/FAIL és részletes hibaüzenetet ad a konzolban/JSON-ban.

Rendelésfelvétel, valódi szerveres kézbesítési API, shop-preview, dupla napi claim és teljes MEGA warning→active→calm ciklus fut. Végül a profil, a mock rangsor, a könyvjelzés és a pozíció/káoszmérő/onboarding visszaáll; az aktív tesztrendelés törlődik. Ha a játék eseményciklusa hibásan nem ér véget, az event/cleanup sor FAIL marad, a teszt nem állít sikeres takarítást.

Csak Studio + engedélyezett debug játékos + memória-mock profil mellett fut. Éles szerveren a debug parancs sincs regisztrálva, a public API is elutasít. Pozitív badge ID mellett elutasít, hogy ne adjon visszavonhatatlan valódi achievementet. Nincs Robux prompt, meghívó küldés, publikálás vagy éles DataStore-írás.

Korlát: ez nem helyettesíti a fizikai mobil/gamepad és kétklienses barát/like/óriáspizza próbákat. A saját UI-khoz360px és nagy szöveg, egér/touch/gamepad fókusz és magyar/angol szöveg külön ellenőrzendő.
