# PIZZA CHAOS — részletes játékterv és fejlesztési brief

**Verzió:** 1.0 — 2026. november 4.

**Munkacím:** PIZZA CHAOS. A végleges nevet később választjuk ki; ez a dokumentum nem állítja a név elérhetőségét vagy egyediségét.

**Fejlesztési helyzet:** egyszemélyes Roblox-fejlesztés, AI-segítséggel.

**Projektirány:** gyalogos pizzakiszállítás egy abszurd, katasztrófák által rendszeresen átalakított városban. Az autó egyelőre nincs a tervben. A korábbi [Neon Rush-koncepció](NEON_RUSH_GAME_BRIEF.md) tartalékötlet; ez önálló játékterv. A hozzá készült [idő- és bevételbecslés](NEON_RUSH_ESTIMATION.md) nem alkalmazható automatikusan erre a projektre.

> **A játék ígérete: Vidd ki a pizzát. Bármi történik.**
>
> A játékos egy teljesen hétköznapi feladatot próbál elvégezni, miközben a városban tornádó vonul át, áradás után cápa úszik az utcákon, vagy váratlanul lóverseny indul a kézbesítési útvonalon.

## 1. Mi eldöntött, és mi tervezési javaslat?

### Közösen elfogadott irány

- Roblox-játék, amelyet egy ember AI segítségével készít.
- A népszerűség és a pénzügyi megtérülés fontos cél.
- Az első változatban gyalog közlekedünk, autó nélkül.
- A fő feladat a pizzakiszállítás.
- A káosz nagy léptékű és abszurd: a várost és az útvonalat érdemben alakítja át.
- Az első három fő esemény: tornádó, áradás cápával, váratlan lóverseny.
- A játékban legyen helye mások előtt látható skineknek és effekteknek.

### A briefben javasolt, tesztelendő döntések

A játékoslétszám, a fuvarok hossza, az események időzítése, a jutalmazás, a kezelőszervek, a pálya pontos felépítése és a termékkínálat kiinduló javaslat. Ezeket a prototípus tapasztalatai alapján módosítani kell.

A dokumentum nem bizonyított piaci rést vagy előre igazolt bevételi modellt ír le. Egy konkrét, tesztelhető játékirányt határoz meg.

## 2. Rövid koncepció

A játékos egy kis pizzéria futárja. Felvesz egy rendelést, elindul a megjelölt címre, átadja a pizzát, és jutalmat kap. A város közben folyamatosan új helyzeteket teremt: egy járható utca elárad, egy csapat ló elsodorja az útvonalat, vagy egy tornádó új helyre dobja a játékost.

Az alapfeladat mindig könnyen megérthető. A változatosságot az adja, hogy milyen útvonalon, milyen esemény közben és milyen váratlan helyzetből sikerül teljesíteni.

**Javasolt angol rövid leírás:**

> Deliver pizza through tornadoes, shark floods, and surprise horse races. Finish the delivery. Look good doing it.

**A játékosnak megmaradó történet:**

> „Már majdnem odaértem, amikor megindult a lóverseny. Felugrottam egy napellenzőre, aztán eláradt az utca, és végül egy úszó autón keresztül jutottam a címzetthez.”

## 3. Az élmény öt alapelve

### 3.1. Egyszerű cél, nagy felfordulás

A kézbesítés legyen világos: melyik csomag a tiéd, hová kell menned, hol tudod átadni. A környezet változhat drasztikusan, a cél megértéséhez ne kelljen új szabályrendszert megtanulni.

### 3.2. Az esemény valóban változtassa meg a játékot

A tornádó elmozdít, az árvíz új közlekedési felületeket hoz létre, a lóverseny átmenetileg veszélyes sávokra osztja az utcát. A képernyőn megjelenő felirat és részecske önmagában nem elég.

### 3.3. A játékosnak legyen befolyása

Az esemény érkezése lehet meglepetés. A már megjelent veszélynek azonban legyen felismerhető működése, előjele és legalább egy értelmes válaszlehetősége.

### 3.4. A balesetből gyorsan lehessen továbbmenni

A felborulás, elsodródás és repülés a humor része. A hosszú kiesés és az ismételt teljes újrakezdés megtörné az élményt. A futár rendszerint visszakapja az irányítást, és folytathatja a szállítást.

### 3.5. Az újabb fuvarnak legyen értelme

Az új helyzetek mellett személyes fejlődés, megszerezhető megjelenések, ismert útvonalakon javuló ügyesség és barátokkal kialakuló történetek adjanak okot a folytatásra.

## 4. Milyen játékot építünk?

**Műfaji irány:** harmadik személyű, társas akció- és ügyességi játék, rövid kézbesítési feladatokkal és közös környezeti eseményekkel.

**Hangulat:** színes, abszurd, játékos és mozgalmas. A város túlzóan reagál mindenre, a futár pedig feltűnően komolyan veszi a pizzakiszállítást.

**Komikus kontraszt:** a teljes város éppen víz alatt áll, de a címzett csak azt kérdezi, megérkezett-e a sajtos pizza.

**Fő játékforma:** minden játékosnak saját kézbesítése van ugyanabban a közös városban. A társas élmény már akkor is működik, ha a játékosok nem kommunikálnak és nem alkotnak előre csapatot.

A játék tartalommal, eseményekkel és térbeli kihívásokkal legyen mozgalmas. A vizuális olvashatóság, a kezelhetőség és a tisztességes vásárlási élmény végig fontos marad.

## 5. A fő játékmeneti ciklus

```text
Pizzéria / depó
    ↓
Saját rendelés felvétele
    ↓
Cím és útvonal felismerése
    ↓
Kiszállítás a közös városban
    ↓
Esemény: kitérés, kerülő, menedék vagy látványos mentés
    ↓
Pizza átadása
    ↓
Jutalom + személyes fejlődés
    ↓
Következő rendelés vagy visszatérés a depóba
```

Az első változatban egy játékos egyszerre egy rendelést visz. A pizzát nem kell elkészíteni, hozzávalókat kezelni vagy hosszasan csomagolni. A felvétel egy rövid interakció.

Kiinduló cél egy átlagos fuvarra: **60–120 másodperc**, az útvonaltól és az eseménytől függően. Ez tesztelendő pályatervezési cél, nem előre igazolt játékidő.

## 6. Az első belépés és első kiszállítás

1. A játékos a pizzéria előtti védett járdarészen jelenik meg.
2. Látja a többi futárt, a pizzásdobozokat és a közeli utcát.
3. Egy rövid jelzés a pulthoz vezeti: „Vedd fel az első rendelést.”
4. A felvétel után egy közeli, jól látható cím jelenik meg.
5. Az első szakaszon megtanulja a mozgást, ugrást és kézbesítést.
6. Az első fuvar során vagy közvetlenül utána találkozik egy látványos, reagálható eseménnyel.
7. Átadáskor egyértelmű jutalmat és következő célt kap.

A kezdéskor a bolt és a hosszú fejlődési menü ne szakítsa meg a játékot. A meglévő szerver eseményét nem indítjuk újra egy új belépő miatt. Aktív katasztrófa idején a belépő védett területen induljon, és kapjon érthető tájékoztatást a helyzetről.

**Első sikerélmény:** a játékos akkor is úgy érezze, hogy teljesített valamit, ha közben elesett vagy kerülőt választott.

## 7. A város első változata

### 7.1. Kis, jól megjegyezhető városrész

Egy kompakt térkép készüljön, amelynek fő pontjai rövid játék után felismerhetők:

- Pizzéria és közös indulóterület.
- Főutca, amelyen a lóverseny áthaladhat.
- Kis tér, ahol a tornádó látványosan megjelenhet.
- Alacsonyabb utcaszakasz az áradáshoz.
- Oldalutcák és kapualjak.
- Néhány erkély, lépcső, napellenző és felüljáró.
- Három kezdeti kézbesítési pont.

Az első pálya ne legyen nagy nyílt világ. Rövid távolságon is legyen több lehetséges út és néhány ismételten használható menedék.

### 7.2. Két használható út a fontos címekhez

Ahol lehetséges, legyen egy rövidebb, nyitottabb út és egy hosszabb, védettebb útvonal. Az események ezek relatív előnyét változtassák meg.

Áradáskor az emeleti útvonalak felértékelődnek. Lóverseny idején a felüljáró válik hasznossá. Tornádónál a kapualjak és az útvonaltól távoli utcák adnak menedéket.

### 7.3. Minden cím maradjon elérhető

Az események ne hozzanak létre véglegesen teljesíthetetlen rendelést. Áradáskor a kézbesítési interakció áttehető ugyanannak a háznak egy kijelölt magasabb pontjára. Az új pontot világosan jelezni kell.

A játék ne várja el, hogy a játékos kitaláljon egy nem jelzett, esetleges fizikai hibán alapuló megoldást.

## 8. Mozgás és kezelés

### 8.1. Alapmozgás

- Harmadik személyű kamera, jól látható avatarral és pizzásdobozzal.
- Kényelmes alap futósebesség; kezdetben ne kelljen külön sprintgomb.
- Megbocsátó ugrás és érthető érkezés.
- Széles platformok, lépcsők és kapaszkodás nélkül is használható városi elemek.
- A fizikai kilökések után rövid, kiszámítható visszaállás.
- A karakter ne akadjon be a város apró díszítőelemeibe.

Falra futás, grappling hook és összetett parkour nem szükséges az első verzióhoz. A kihívást a változó környezet adja.

### 8.2. Kiinduló vezérlés

| Művelet | PC | Mobil |
|---|---|---|
| Mozgás | WASD | Virtuális joystick |
| Kamera | Egér / megszokott kameravezérlés | Képernyőhúzás |
| Ugrás | Space | Nagy ugrásgomb |
| Felvétel / kézbesítés | Egy kontextusfüggő interakció | Egy kontextusfüggő gomb |
| Elakadásból mentés | Menüből elérhető művelet | Menüből elérhető művelet |

A mozgás lehetőleg azonnal ismerős legyen a Roblox-játékosnak. A pontos kiosztást és kameraműködést eszközteszt alapján kell véglegesíteni.

## 9. A pizza és a rendelés szabályai

### 9.1. Első verzió

- Egy normál pizzásdoboz.
- Egy aktív rendelés játékosonként.
- A doboz a játékoshoz rendelt tárgy; más nem veheti el.
- A kézbesítési cél egyértelmű térbeli jelölést kap.
- Baleset után a doboz megmarad, vagy automatikusan visszakerül a futárhoz.
- Egy rendelésért egyszer jár jutalom.
- Kilépett játékos rendelése megszűnhet; a korábban megszerzett tartós jutalmak megmaradnak.

### 9.2. Jutalmazás

A teljesítésért járjon biztos alapjutalom. Később kiegészíthető ügyességi bónusszal, például gyorsaságért vagy egy különleges szállítási feltétel teljesítéséért.

Az első változatban ne legyen kötelező lejárati idő vagy pizza-hőmérséklet, amely egy rosszul időzített esemény miatt lenullázza a futást. A gyorsasági kihívás külön, választható rendeléstípus lehet.

### 9.3. Későbbi különleges rendelések

- Óriási doboz, amely más útvonalválasztást kér.
- Mozgolódó rakomány, amely időnként kibillenti a futárt.
- Lebegő szállítmány, amely megváltoztatja az ugrást.
- Törékeny torta, opcionális sérülésmentes bónusszal.

Ezek bővítési ötletek. Előbb a normál pizzával és a három eseménnyel kell bizonyítani az alapélményt.

## 10. Eseményrendszer: hogyan épül fel a nagy káosz?

Minden eseménynek legyen öt állapota:

1. **Előjel:** hang, térbeli jelzés és rövid üzenet.
2. **Felépülés:** a játékos látja, hol és hogyan változik a város.
3. **Aktív veszély:** a fő játékmeneti hatás működik.
4. **Lecsengés:** a veszély megszűnik, a környezet rendeződik.
5. **Visszaállítás:** a következő eseményhez tiszta, ellenőrzött állapot jön létre.

Az előjel elég rövid legyen a meglepetéshez, de adjon tényleges reakcióidőt. Kiinduló próbaértékként néhány másodperces jelzés, körülbelül 20–45 másodperces aktív esemény és köztes nyugodtabb szakasz tesztelhető.

A végleges ritmust játékpróbából kell kialakítani. Nem cél, hogy minden pillanatban minden esemény működjön.

### Mi legyen közös?

Ugyanabban a szerverben ugyanaz a városi esemény történjen. A játékosok így ugyanarról a tornádóról és lóversenyről tudnak történeteket megélni. A saját rendelésük és jutalmuk ettől független.

### Mitől lesz változatos?

Később változhat az esemény útvonala, iránya, érintett utcája és néhány hangolható paramétere. A véletlenszerűséget ellenőrzött, járható lehetőségekből kell választani.

## 11. Esemény A — tornádó

### A jelenet

A szél felerősödik, papírok és kisebb díszítőelemek kezdenek sodródni. Egy utca végén megjelenik a tornádó, majd végigvonul egy kijelölt útvonalon.

### Játékmeneti hatás

- Egy jól látható veszélyzóna közelében sodró hatás éri a karaktert.
- A belső zónába kerülő futár rövid időre felemelkedik.
- A forgószél néhány másodperc után egy előre ellenőrzött, használható területre dobja ki.
- A játékos rövid időn belül visszakapja az irányítást és folytathatja a rendelést.

### Játékosdöntések

- Behúzódik egy kijelölt kapualjba.
- Védettebb kerülőt választ.
- Megvárja, amíg a tornádó elhalad.
- Későbbi, megtanulható lehetőségként kihasználja a kilökést egy magasabb útvonalhoz.

### Humor

A futár a levegőben is próbálja vízszintesen tartani a pizzát. Néhány könnyű városi kellék együtt kering vele. A túlzás a mozgásból és a jelenetből jöjjön, erős kameraforgatás nélkül.

### Megvalósítási korlát

Az első változatban egy mozgó veszélyzóna és szabályozott karakterhatás elég. A teljes város épületeit nem kell fizikailag szétszedni. A látványos törmelék külön, korlátozott számú díszelem lehet.

### Elfogadási feltételek

- A játékos megérti, hol van a veszély és hol a menedék.
- A tornádó nem ejti ki a karaktert a térképről végtelen esésbe.
- Nem lehet folyamatos, irányíthatatlan elkapási ciklusba kerülni.
- A rendelés folytatható marad.

## 12. Esemény B — áradás és cápa

### A jelenet

Egy óriási cső eltörik vagy víz tör fel az utcából. A vízszint láthatóan emelkedik. A parkoló autók és néhány nagy tárgy felúszik, majd egy túlzóan nagy cápauszony jelenik meg.

### Játékmeneti hatás

- Az alacsonyabb utcák átmenetileg vízi veszélyzónává válnak.
- Előre megtervezett autótetők, bútorok és platformok új útvonalat alkotnak.
- Az erkélyek és felüljárók biztonságos közlekedési pontok.
- A cápa egyértelműen jelzett szakaszon közelít, majd rövid támadást végez.
- A vízbe esett játékost biztonságos pontra lehet visszahelyezni rövid, komikus mentéssel.

### Játékosdöntések

- Magasabb útvonalra vált.
- Átugrál az úszó felületeken.
- Kivárja a cápa elhaladását.
- Rövidebb, kockázatosabb átkelést választ a hosszabb kerülő helyett.

### Humor

A cápa a városi útkereszteződésben úszik, a lakók közben az erkélyről várják a pizzát. A veszély komikus, stilizált legyen, grafikus sérülések nélkül.

### Megvalósítási korlát

A kezdeti változat használhat emelkedő vízfelületet, állapotot váltó platformokat és előre kijelölt cápamozgást. Nem szükséges általános vízszimuláció vagy teljes, fizikai felhajtóerő-rendszer.

Az úszó autók környezeti platformok; ez nem jelent vezethető járműrendszert.

### Elfogadási feltételek

- Legalább egy teljesíthető út vezet minden aktív célhoz.
- A cápa közeledése felismerhető.
- A víz megszűnésekor senki nem kerül beszorult vagy elérhetetlen helyre.
- A céljelölés követi az esetleges erkélyre áthelyezett átadási pontot.

## 13. Esemény C — váratlan lóverseny

### A jelenet

Megszólal egy lelkes sportbemondó. Zászlók és ideiglenes pályakorlátok jelennek meg, és a főutca lóversenypályává alakul. A lovak több hullámban haladnak át rajta.

### Játékmeneti hatás

- Egy vagy több útsávban mozgó veszély keletkezik.
- A hullámok között át lehet jutni.
- Egy kijelölt felüljáró vagy kerülő végig használható.
- A lóval ütköző futár rövid, túlzó kilökést kap, majd visszaáll.

### Játékosdöntések

- Megfigyeli a lovak ritmusát és a hullámok közötti rést.
- Átmegy a felüljárón.
- Rövid időre egy védett járdaszigetre ugrik.
- Másik utcán közelíti meg a címet.

### Humor

A város úgy viselkedik, mintha teljesen normális lenne, hogy most itt lóverseny van. A bemondó röviden kommentálhatja a futárok ügyetlenkedését vagy egy különösen látványos átkelést.

### Megvalósítási korlát

A lovak előre megtervezett útvonalon, hullámokban mozogjanak. Nem szükséges teljes verseny-AI, lovaglás vagy egyenként összetett fizikai járműmodell.

### Elfogadási feltételek

- Az áthaladási irány és a következő hullám felismerhető.
- A találat következménye rövid és kiszámítható.
- A korlátok nem zárják el az összes utat.
- Az esemény végén minden ideiglenes tárgy megfelelően eltűnik.

## 14. Események kombinálása

Az első prototípusban egyszerre egy fő esemény működjön. A kombinációk külön fejlesztési szakaszba tartoznak.

Később csak tudatosan engedélyezett párosításokat használjunk:

| Párosítás | Lehetséges működés | Szükséges feltétel |
|---|---|---|
| Áradás + lóverseny | A lovak egy magasabban fekvő útvonalon haladnak | Külön száraz versenysáv és másik járható átkelés |
| Tornádó + lóverseny | A két esemény eltérő utcákat érint | Ne zárják el egyszerre az összes menedéket |
| Áradás + tornádó | A tornádó egyes vízi platformokat kerülendővé tesz | Maradjon stabil, ellenőrzött alternatív út |

Egy kombináció attól jó, hogy új döntést kér. Ha csak mindenhol egyszerre veszély van, kevesebb értelmes játékosi választás marad.

A kombinálás előtt minden alap-eseménynek külön is működnie kell mobilon és több játékossal.

## 15. Baleset, visszaállás és elakadás

A játékos többféleképpen hibázhat: fellökik, vízbe esik, rossz utcát választ vagy elkapja a tornádó. A következmények jellemzően rövid időveszteséget és helyváltoztatást jelentsenek.

**Javasolt alapkezelés:**

- Rövid ragdoll vagy célzott animáció.
- Automatikus felállás.
- A pizzarendelés megmarad.
- Szükség esetén visszahelyezés a legközelebbi ellenőrzött biztonságos pontra.
- Rövid védelem az azonnali ismételt eltalálás ellen.

Az elakadásból mentés legyen ingyenes. Ne váljon normál útvonal-rövidítéssé: olyan biztonságos pontra vigyen, amely nem juttatja indokolatlanul közelebb a játékost a célhoz.

Az első változatban ne legyen fizetős kötelező újraélesztés, megvásárolható eseményimmunitás vagy pénzért helyreállítható elveszett rendelés.

## 16. Többjátékos felépítés

### 16.1. Kiinduló létszám

Tesztelési alapnak legfeljebb **6 játékos egy szerveren**. A végleges kapacitás teljesítmény- és játékmeneti próba alapján módosítható.

Egyedül is elindítható és teljesíthető legyen minden alapfeladat. Ne kelljen csapatra várni a kézbesítéshez.

### 16.2. Személyes feladat, közös világ

- Minden játékos saját rendelést kap.
- A városi esemény közös és szinkronizált.
- A többiek pizzáját nem lehet ellopni vagy megsemmisíteni.
- Egy másik játékos ne tudja testével tartósan elzárni a szűk útvonalat.
- A depó és a célpontok közelében legyen elég hely a találkozásokhoz.

### 16.3. Segítség és közös történetek

Később lehet segítő interakció: felhúzás, rövid mentés vagy közös nagy rendelés. Az MVP ezek nélkül is adjon társas élményt a közös katasztrófák és a látható reakciók révén.

A közös fuvar és a pizza átadása másik játékosnak csak később kerüljön be, amikor a tulajdon- és jutalmazási szabályok már tiszták.

## 17. Fejlődés és hosszabb távú célok

### Első játszható verzió

- Kézbesítések száma és alap pénzjutalom.
- Futárszint vagy egyszerű, világosan jelzett mérföldkövek.
- Néhány megszerezhető doboz- és táskamegjelenés.
- Eseményekhez kapcsolódó teljesítések.
- Saját korábbi eredmények vagy egyszerű személyes statisztikák.

### Későbbi bővítés

- Új körzetek és kézbesítési helyzetek.
- Különleges rendelések.
- Saját depósarok, dekorációkkal és trófeákkal.
- Tematikus futárszettek.
- Heti, választható kihívások.

A fejlődés ne igényeljen végtelen sebességnövelést. Az események és ugrások kezelhetősége korlátozott, ezért az egyre nagyobb számok helyett új megjelenés, útvonal, rendeléstípus vagy kihívás lehet a jutalom.

A visszatérést érdemes érdekes célokra építeni. Egy kihagyott nap ne törölje a már megszerzett fejlődést.

## 18. Kozmetikai monetizáció

### 18.1. Miért illik ide?

A játékos harmadik személyből látja magát, a depóban mások mellett áll, az utcán pedig feltűnő mozdulatokat végez. A megjelenés ezért természetesen része lehet a játékélménynek.

Ez monetizációs hipotézis. A tényleges vásárlási érdeklődést csak játékosadatok igazolhatják.

### 18.2. Termékjelöltek

| Termék | Hol látszik? | Mire kell figyelni? |
|---|---|---|
| Pizzásdoboz-skin | Kézben, felvételnél és átadásnál | Maradjon felismerhető a rendelés |
| Futártáska | Mozgás és társas találkozás közben | Ne takarja ki a kamerát |
| Munkaruha / céges szett | Folyamatosan az avatáron | A Roblox-avatar identitása is megmaradhat |
| Átadási animáció | Minden sikeres kiszállításnál | Rövid legyen, ne lassítsa a következő fuvar indulását |
| Esés- vagy felállásanimáció | Komikus balesetek után | Ne adjon játékmeneti előnyt |
| Emote | Depóban és nyugodtabb helyzetekben | Legyen megszakítható |
| Saját depódekoráció | A közös indulóterület mellett | Későbbi bővítés, külön rendszerigénnyel |

### 18.3. Első szettötletek

**Classic Courier:** piros-fehér doboz, egyszerű futártáska, hagyományos kézbesítési animáció.

**Storm Express:** sötétkék és sárga esőruhás megjelenés, stilizált viharfelhős doboz, rövid elektromos díszjelzés. A látvány nem ad villám- vagy tornádóvédelmet.

**Extra Cheese:** sajtmintás doboz, túlzó sajtos táska és komikus, rövid átadási mozdulat.

Az első kozmetikai teszthez két jól elkülönülő megjelenés elég.

### 18.4. Értékesítési alapelvek

- Átlátható, közvetlen vásárlás.
- Ár és tartalom egyértelmű feltüntetése.
- Előnézet, animációknál mozgó bemutató.
- Néhány jól kinéző, játék közben megszerezhető tárgy.
- A fizetős effekt nem zavarhatja mások tájékozódását.
- Az események kiváltását ne lehessen pénzért másokra kényszeríteni.
- Az első prototípusban teszt-tulajdon legyen, valós fizetés nélkül.

A pontos árak, csomagok és későbbi bevételi rendszerek külön döntést igényelnek. A játék korai változatába nem szükséges lootbox, kereskedés, előfizetés vagy szezonbérlet.

## 19. Látványvilág és művészeti irány

### 19.1. A város

Stilizált, színes kisváros, nagy és olvasható formákkal. A pizzéria könnyen felismerhető, barátságos kiindulópont. A házak, ajtók és utcák eltérő színei segítik a tájékozódást.

A távoli háttér egyszerű maradhat. A fő figyelmet az útvonalak, a kézbesítési célok és az események kapják.

### 19.2. Kiinduló színvilág

| Szerep | Javasolt irány |
|---|---|
| Pizzéria és fő márka | Paradicsompiros, krémszín és meleg sárga |
| Város normál állapotban | Világos ég, színes homlokzatok, jól elkülönülő járdák |
| Tornádó | Kékesszürke ég és erős, olvasható forgószél-sziluett |
| Áradás | Tiszta kék víz, kontrasztos úszó platformok |
| Lóverseny | Színes zászlók, nagy irányjelzések és felismerhető futó sziluettek |

A szín mellett alak, mozgás és ikon is jelezze a fontos információkat. A veszélyzóna ne csak piros színből legyen felismerhető.

### 19.3. Animáció és humor

A futár pizzát óvó mozdulatai, a túlzó felállások és a címzettek reakciói adják a karaktert. Az animáció legyen rövid, jól olvasható és közvetlenül kapcsolódjon a történéshez.

Erős villogás, folyamatos kamerarázás és mindenütt megjelenő részecskék nélkül is lehet nagy léptékű a káosz.

## 20. Hang és kamera

- Alapállapotban könnyed, ismételhető zene.
- Eseményenként felismerhető hangjelzés.
- Lóversenynél rövid bemondó és patadobogás.
- Tornádónál fokozódó szélhang és tárgyak sodródásának hangjai.
- Áradásnál vízhang, cápaelőjel és rövid veszélyjelzés.
- Kézbesítésnél kellemes, egyértelmű sikerhang.

A fontos jelzések hang nélkül is láthatók legyenek. A zene és az effektek hangereje külön állítható.

A kamera kövesse az eseményt, de ne vegye el szükségtelenül a tájékozódást. Tornádóban sem kell a teljes képet folyamatosan forgatni. Legyen csökkentett kameramozgás és mérsékelt effektbeállítás.

## 21. Felület és játékoskommunikáció

### Futás közben

- Aktív cím és egyszerű irányjelzés.
- A pizza birtoklásának egyértelmű jelzése.
- Rövid, helyzethez illő eseményfigyelmeztetés.
- Minimális személyes jutalom- és fejlődésinformáció.

Egy veszélyhelyzet közepén ne jelenjen meg kötelező menü vagy vásárlási ajánlat. A célhoz vezető jelzés ne takarja ki a közelgő veszélyt.

### Átadáskor

Rövid sikerjelzés, jutalom és választható folytatás. A kézbesítési animáció ne blokkolja hosszasan a mozgást.

### Depóban

Rendelésfelvétel, felszerelés és később személyre szabás. A bolt jól megtalálható legyen, de a következő fuvar elindítása maradjon a legegyszerűbb fő művelet.

## 22. Mi kerül az első prototípusba?

### Kötelező alap

- Egy kompakt városrész.
- Egy pizzéria / indulópont.
- Három kézbesítési cím.
- Egy normál pizza és egy aktív rendelés játékosonként.
- Egyszerű felvétel, útvonaljelzés és átadás.
- Futás, ugrás, harmadik személyű kamera és mobilos bevitel.
- Alap pénzjutalom.
- Tornádó, áradás cápával és lóverseny, kezdetben külön tesztelhetően.
- Gyors baleseti visszaállás.
- Több játékos ugyanabban a világban, saját rendelésekkel.
- Egyszerű mérés: rendelésindítás, kézbesítés, baleset, újabb rendelés.

### A mechanikai próba után

- Két teszt-kozmetikai megjelenés.
- Alap felszerelési felület.
- Személyes fejlődés és mentés.
- Később külön kereskedelmi vásárlási integráció.

### Tudatosan későbbre hagyott elemek

- Autók és vezetés.
- Nagy nyílt világ.
- Pizzakészítési minijáték és részletes étteremgazdaság.
- Teljes épületrombolás és általános fizikai szimuláció.
- Sok különleges rendelés.
- Eseménykombinációk.
- Csapatfüggő kötelező feladatok.
- Kereskedés, nagy gyűjteményrendszer, szezonbérlet és rangsorolt verseny.

## 23. Fejlesztési sorrend

### A. Egy teljes kézbesítés

Egyszerű térkép, rendelésfelvétel, céljelzés, kézbesítés és jutalom. Egy teljes kör működjön PC-n és mobilon.

**Döntési kérdés:** érthető-e külön magyarázat nélkül, mit kell csinálni?

### B. Egy esemény: lóverseny

A lóverseny elsőként könnyen megfigyelhető átkelési helyzetet adhat: egy utca, mozgó hullámok, előjel és biztonságos kerülő. Legyen kézi tesztindítás, hogy gyorsan ismételhető legyen.

**Döntési kérdés:** a játékos a veszély miatt érdekesebb döntést hoz-e, és a találat után kedve van-e folytatni?

### C. Tornádó és áradás

Ugyanarra a kis pályára kerüljenek fel a további események. Először külön működjenek, aztán jöhet a váltogatásuk és a megbízható visszaállítás.

**Döntési kérdés:** ugyanaz a városrész tényleg másképp játszható-e az egyes eseményekben?

### D. Közös játék és ismétlés

Több klienssel ellenőrzött közös események, személyes rendelések és legalább több egymást követő fuvar.

**Döntési kérdés:** a társak jelenléte hozzáad-e, és az ötödik szállítás is élvezetes-e?

### E. Fejlődés és kozmetikai próba

Kis személyes célok, két tesztmegjelenés, mentés és felszerelés. Valós fizetés még nem szükséges.

**Döntési kérdés:** a játékosnak van-e saját következő célja, és észreveszi-e mások megjelenését?

### F. Kiadási és bevételi tervezés

Csak a játékpróbák eredménye után kell pontosítani a kereskedelmi kínálatot, a szükséges tartalommennyiséget és a projekt idő- és pénzügyi becslését.

Az első 20–40 aktív óra egy szűk tanulási keret lehet az A–B lépéshez. Ez nem határidőígéret a háromeseményes, kész játékra. A tényleges tempó alapján újra kell tervezni.

## 24. Technikai felelősségek

A megvalósítás Roblox Studio / Luau környezetben készüljön. A részrendszerek legyenek elkülöníthetők:

- Rendelések létrehozása és állapota.
- Kézbesítési pontok és eseményfüggő elérhetőségük.
- Jutalmak és személyes fejlődés.
- Események állapotgépe és időzítése.
- Veszélyek, balesetek és biztonságos visszaállítás.
- Kamera és eszközfüggő bemenet.
- Kozmetikai megjelenítés és felszerelés.
- Mentés és mérési események.

### Szerveroldali hitelesség

- A szerver tartsa nyilván az aktív rendelést és a jogosult címzettet.
- A kézbesítés helyét és állapotát ellenőrizni kell.
- Ismételt üzenet ne adjon ismételt jutalmat.
- A pénzt, tulajdont és későbbi vásárlási jutalmakat ne hozhassa létre szabadon a kliens.
- A városi események állapota közös szerverállapot legyen.
- A kliens megjelenítheti a látványt, de a jutalmat érintő eredményt ellenőrizni kell.

### Események robusztussága

Minden eseményhez tartozzon teljes takarítás: ideiglenes tárgyak eltávolítása, útvonalak visszaállítása és a félbeszakadt karakterhatások lezárása.

Az esemény közben belépő játékos a jelenlegi állapotot kapja meg. Egy kliens késése vagy kilépése ne állítsa meg a szerver eseményrendszerét.

Ha egy esemény hibázik, legyen visszaállítható biztonságos városi állapot. A kézbesítések ne maradjanak végleg elzárva.

## 25. Teljesítmény és hozzáférhetőség

- Korlátozott számú aktív ló, törmelék és részecske.
- Az események látványának egyszerűsített beállítása mobilon.
- A veszélyek formája és előjele alacsony grafikai szinten is látható.
- A nagy fizikai jelenetek lehetőség szerint szabályozott mozgásokból épüljenek.
- A játékos által valóban használt platformok legyenek megbízhatóbbak a puszta díszleteknél.
- A gombok ne fedjék el a szükséges ugrási felületeket.
- A fontos hangjelzéseknek legyen vizuális megfelelője.
- Erős kameramozgás és villogás csökkenthető vagy elhagyható.

A teljesítményt valódi mobilos próbával is vizsgálni kell. Az asztali Studio-próba önmagában nem bizonyítja a célközönség eszközein való használhatóságot.

## 26. Játékpróba és mérés

### A fő kérdések

1. A játékos segítség nélkül felveszi és kézbesíti az első rendelést?
2. Az esemény előjeléből megérti, mi történik?
3. Tud legalább egy értelmes módon reagálni?
4. A baleset vicces vagy inkább bosszantó számára?
5. A visszaállás után folytatja a fuvarját?
6. Önként kér újabb rendelést?
7. Több fuvar után is változatosnak érzi a játékot?
8. Egy későbbi alkalommal is visszatér?
9. Mások jelenléte javít vagy ront az élményen?
10. Észreveszi-e a másik játékos táskáját, dobozát és animációját?

### Események, amelyeket érdemes mérni

- Első játszható állapot elérése.
- Rendelés felvétele.
- Rendelés teljesítése.
- Esemény megélése és baleset típusa.
- Elakadásból mentés használata.
- Következő rendelés indítása.
- Kilépés egy aktív rendelés vagy baleset után.
- Kozmetika előnézete és felszerelése.
- Később igazolt vásárlás.

Az adatokat eszköz és első/visszatérő játékos szerint is külön kell nézni. A közös eseménynek kitett összes játékoshoz viszonyítva értékeljük a kilépéseket; egyetlen látványos balesetből nem következik, hogy az esemény rossz.

Az első kisebb teszt a használhatóságot és az élményt vizsgálja. Nem bizonyít piacméretet, bevételt vagy stabil vásárlási arányt.

## 27. Legfontosabb kockázatok és válaszok

| Kockázat | Jel | Tervezési válasz |
|---|---|---|
| A kiszállítás unalmas | Esemény nélkül csak céltalan gyaloglásnak érződik | Rövid távolságok, útvonalválasztás, gyors átadás |
| A káosz igazságtalan | A játékos nem érti, miért esett el | Olvasható előjelek és következetes veszélyszabályok |
| Túl sok a megszakítás | Több idő megy el felállásra, mint játékra | Rövid hatások, ismételt találat elleni védelem |
| Három esemény hamar kiismerhető | Néhány fuvar után nincs újdonság | Előbb útvonal- és eseményváltozatok, majd új tartalom |
| A társak akadályozzák egymást | Ajtóblokkolás, rendelések elvétele | Személyes rendelésállapot, védett interakciók |
| A látvány túl drága | Mobilon esik a képkockaszám | Szabályozott jelenetek, kevés fizikai tárgy |
| A kozmetika érdektelen | Nem veszik észre vagy nem használják | Nagyobb, olvasható táska- és dobozmegjelenések |
| A fejlesztés túl nagyra nő | Már a prototípushoz teljes város és gazdaság készül | Egy kis pálya és az első esemény előresorolása |

## 28. Elfogadási lista az első háromeseményes verzióhoz

- [ ] Egyedül is felvehető és teljesíthető a rendelés.
- [ ] Mobilon a mozgás, ugrás, felvétel és átadás működik.
- [ ] A három esemény külön is kipróbálható.
- [ ] Az események ténylegesen megváltoztatják az útvonalválasztást.
- [ ] A veszélyek előjele felismerhető.
- [ ] A baleset után gyorsan folytatható a játék.
- [ ] Nincs végleg teljesíthetetlen cím.
- [ ] Nincs ismétlődő, megszakíthatatlan elkapási ciklus.
- [ ] Több játékos ugyanazt az eseményállapotot látja.
- [ ] A játékosok rendelése és jutalma nem keveredik.
- [ ] Ugyanazért a rendelésért nem jár kétszer jutalom.
- [ ] Az esemény végén helyesen visszaáll a térkép.
- [ ] Az esemény közben belépő játékos használható állapotba kerül.
- [ ] A normál folytatáshoz nem szükséges vásárlás.
- [ ] Több egymást követő fuvar során is stabil a játék.
- [ ] A kipróbált és még nem ellenőrzött részek dokumentáltak.

## 29. Másolható fejlesztési prompt

Az alábbi promptot ezzel a teljes dokumentummal együtt kell átadni a fejlesztőnek vagy AI-nak. A prompt a legelső működő próbát kéri; nem utasít a teljes későbbi játékrendszer egyszerre történő felépítésére.

```text
Egy Roblox Studio / Luau játékot készítünk, egyedüli fejlesztőként AI-segítséggel.
Olvasd végig a mellékelt PIZZA_CHAOS_GAME_BRIEF.md dokumentumot.
Ez a projekt aktuális játékterve. A korábbi Neon Rush-terv külön, tartalékötlet.

A játék munkacíme PIZZA CHAOS.
Alapígérete: Vidd ki a pizzát. Bármi történik.

A játékos gyalogos pizzafutár egy kis, közös városrészben. Felvesz egy rendelést,
elviszi a megjelölt házhoz, és jutalmat kap. Közben nagy, abszurd események
alakítják át az útvonalat: tornádó, áradás cápával és váratlan lóverseny.

Az autó nem része a jelenlegi feladatnak. Nem készítünk részletes pizzafőzést,
nagy nyílt világot, teljes rombolásszimulációt vagy komplex parkourrendszert.

ELSŐ FELADAT:
1. Vizsgáld meg a meglévő projektet és a helyi instrukciókat.
2. Állapítsd meg az elérhető Roblox-eszközöket és tesztelési lehetőségeket.
3. Készíts egy kis, egyszerű geometriájú városrészt, pizzériával és három címmel.
4. Valósíts meg egy teljes rendelési ciklust: felvétel, céljelzés, átadás, jutalom.
5. Készítsd el az alap PC-s és mobilos kezelést harmadik személyű kamerával.
6. Első eseményként valósítsd meg a lóversenyt: előjel, mozgó lóhullámok,
   használható átkelési rés, biztonságos kerülő és rövid baleseti visszaállás.
7. Adj könnyen használható fejlesztői tesztindítást az eseményhez.
8. Ellenőrizd az esemény teljes lezárását és az ismételt elindíthatóságát.

JÁTÉKMENETI ELVEK:
- A cél mindig érthető: a játékos tudja, melyik pizzát hová viszi.
- Az esemény változtassa meg a játékhelyzetet, ne csak díszítő effekt legyen.
- A már megjelent veszély működése legyen felismerhető és reagálható.
- Baleset után a játékos gyorsan visszakapja az irányítást.
- A rendelés a normál balesetek után is folytatható.
- Minden aktív címhez maradjon teljesíthető út.
- A többiek jelenléte ne akadályozza tartósan a teljesítést.
- Egyedül is működjön az alapjáték.

TECHNIKAI ELVEK:
- A rendelés, jutalom és eseményállapot legyen szerver által ellenőrzött.
- Egy rendelés egyszer adhat jutalmat, ismételt kérés esetén is.
- A játékosok személyes rendelései ne keveredjenek.
- A kamera, felület és látvány lehet helyi, a hiteles állapot közös rendszerből jöjjön.
- Az esemény előjel, aktív szakasz, lecsengés és visszaállítás állapotokra tagolódjon.
- A lovak előre megtervezett útvonalon mozoghatnak; teljes verseny-AI nem szükséges.
- A fontos értékek és útvonalak legyenek könnyen hangolhatók.
- Az eseményhez tartozó ideiglenes elemeket mindig takarítsd el.

TERJEDELEM:
Ebben a feladatban az alap kézbesítés és a lóversenyes próba készüljön el.
A tornádó, a cápaáradás, a kozmetikai rendszer és a tartós fejlődés a következő
szakaszok része. A szerkezet tegye lehetővé a későbbi eseményeket, de ne építs
előre teljes boltot vagy nagy gazdasági rendszert.

Az első változat nem kezdeményezhet valós vásárlást. A publikálás és a fizetett
szolgáltatások használata külön feladat.

MUNKAMÓD ÉS ÁTADÁS:
- A meglévő projekt használható részeit őrizd meg.
- Ha nincs projekt, készíts minimális, világosan importálható vagy szinkronizálható
  Roblox-projektstruktúrát az elérhető eszközökkel.
- A szokásos megvalósítási döntéseket hozd meg a brief alapján.
- Csak akkor kérdezz, ha hiányzó információ ténylegesen blokkolja a munkát.
- Adj rövid indítási és tesztelési útmutatót.
- Írd le a kezelőszerveket és a fő hangolható paramétereket.
- Jelöld, mit teszteltél, és mi maradt ellenőrizetlen.
- Ha nincs Studio- vagy mobilos tesztelési lehetőség, ezt pontosan közöld.

A cél egy rövid, ismételhető kézbesítési helyzet, amelyben a váratlan lóverseny
érthető, vicces és valóban befolyásolja az útvonalat. Erre épül majd a két további
katasztrófa és a teljesebb játék.
```
