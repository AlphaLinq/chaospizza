# Városi futárútlevél (#280)

Minden teljes kézbesítés végpontja egyszeri pecsétet ad. A meglévő Courier profile aktivitásblokkjában a bejárt címek száma látszik; ugyanazon cím ismétlése nem növeli. A jelenlegi térképen14cím van. A cél a város felfedezése: nincs új pénz/XP, vásárlás vagy szerveres előny. A teljes album a City Explorer kozmetikai címet adja (#284). A korábbi, cím nélkül tárolt összes kézbesítésből nem találunk ki visszamenőleges pecséteket.

A RoutePassportService a valódi OrderService.onDelivered callbackhez kapcsolódik, új remote nélkül. Csak a MapLayout.buildings aktuális address.id értékeit fogadja el. A registry tiszta helper, rendezett, egyedi, max64cím; a limit és claims-prefix a Config/RoutePassportban állítható. Kétmegállós rendelésnél a teljesítés callbackje a végső címre fut, az első részmegállót nem tekinti külön teljesítésnek. Ismeretlen/óriásrendeléshez nem tartozó cím nem készít mesterséges pecsétet.

Mentés a meglévő DataService transaction és profile.claims["route.stamp.<addressId>"] = unix-idő mezőn át történik. A jelenlegi v7 migráció megőrzi. Foglalt session esetén legfeljebb az ismert címekből álló helyi várakozó halmaz marad; a tranzakció után érkező onUpdated újrapróbálja, PlayerRemoving törli. Nincs külön DataStore, kliens által küldött eredmény vagy azonnali vásárlási mentés. Normál autosave/reconnect szerződés érvényes. A hirtelen leállás előtti még nem mentett játékállapotnak ugyanaz a korlátja, mint más szokásos profilfrissítésnek.

Publikus attribútum csak RouteStampCount és RouteStampTotal, többi játékos profilnézetéhez is; a teljes claims ledger/timestamp nem kerül át. Hiányzó vagy hibás számláló esetén a saját profilmező rejtett. Az EN/HU szöveget a Config/ProfileActivity adja, a nézet a kiválasztott futár attribútumait figyeli.

QA: `passport` kiírja az összesítést és következő hiányzó címet. `passport next` a valódi assignOrder API-val normál rendelést készít oda; meglévő rendelést nem töröl és nem ír felül. `deliver` a meglévő debug kézbesítési API, utána újabb `passport`. A `next` nem ad pecsétet: törlés/elmulasztás esetén ugyanaz a cím marad hátra. Teljes albumra nincs új rendelés. Ezek fejlesztői parancsok, nem új játékos-UI/intents.

## City Explorer cím (#284)

Az utolsó hiányzó pecséttel azonos DataService-tranzakció adja a CityExplorerTitle tulajdont. Nem vásárolható meg, nem szerelődik fel automatikusan, nem változtat statisztikát. A Cosmetics title kategóriában az unlock-hint magyarul/angolul elmondja a feltételt; utána a meglévő felszerelési API használható. A szerver csak sikeres első jóváírás után frissíti a katalógust és küldi a meglévő title Hint-et/fanfárt. Új remote vagy LoopTitleService-módosítás nincs.

A funkció előtti teljes útlevelet betöltéskor egyezteti: a meglévő pecsétekből a címet egyszer megkapja. Ismételt onLoaded/onUpdated/kézbesítés nem küld új jóváírást vagy fanfárt; a már kiérdemelt cím későbbi térképbővítéskor is megmarad. A busy-session pendinghalmaz és a kozmetikai tulajdon ugyanazon tranzakcióhoz tartozik, nem külön egymás utáni mentéshez. A tulajdon mentése a szokásos profil-autosave szerződését követi.
