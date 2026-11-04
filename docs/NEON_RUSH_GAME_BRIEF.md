# NEON RUSH — Roblox játékkoncepció és fejlesztési prompt

**Kapcsolódó becslés:** [Fejlesztési idő, játékosszám és bevételi forgatókönyvek](NEON_RUSH_ESTIMATION.md) — 2026. november 4.

> **Munkacím:** NEON RUSH. A végleges név kiválasztása és elérhetőségének ellenőrzése későbbi feladat.
>
> **A dokumentum célja:** egy önálló arculatú, Neon White- és Ghostrunner-inspirációjú Roblox-játék részletes meghatározása. Használható tervezési briefként és AI-fejlesztőnek átadható specifikációként. A dokumentum végén szereplő prompt az első prototípus elkészítését írja elő.
>
> **Döntési státusz:** a parkour, lövöldözés, kikapcsolódás, közös játék és kozmetikai bevétel a felhasználó által megadott irány. Az alábbi konkrét pályák, számértékek, rendszerek és vizuális megoldások javasolt kiindulópontok; játékpróbával kell őket ellenőrizni.

## 1. A játék egy mondatban

Egy látványos, könnyen tanulható parkour shooter, amelyben a játékosok rövid, színes pályákon futnak, falakon száguldanak, drónokat lőnek szét, és a találatokból kapott újabb dash segítségével folyamatos mozgáskombókat építenek — egyedül vagy a barátaik mellett.

**A játékosnak szóló ígéret:** „Már az első percben menő mozdulatokat csinálsz. Később megtanulod őket igazán jól összekötni.”

**Javasolt angol rövid leírás:**

> Run rooftops. Break drones. Chain your dash. Find your flow with friends.

Az élmény három fő összetevője:

- **Flow:** a futás, ugrás, falon futás és lövés egyetlen folyamatos cselekvéssorrá áll össze.
- **Saját fejlődés:** a játékos jobban ismeri az útvonalat, tisztábban mozog és új rövidítéseket talál.
- **Saját stílus:** fegyverek, kesztyűk, dash-effektek és befutóanimációk teszik felismerhetővé.

## 2. Üzleti cél és a siker feltételei

A cél egy hosszabb távon bevételt termelő Roblox-játék. A fő tervezett bevételi forrás a közvetlenül megvásárolható kozmetikai tartalom.

A bevételi elképzelés négy feltételtől függ:

1. A látvány és az alapötlet rövid videóból is érthető.
2. Az első pálya gyorsan sikerélményt ad, mobilon is.
3. A játékosnak később is van oka visszatérni és barátot hívni.
4. A kozmetikák használata közben a tulajdonos és a társai is észreveszik őket.

A terv nem garantál sikert vagy bevételt. A megtartást, a vásárlást és a tartalomgyártás költségét külön kell mérni. Egy szép prototípus még nem bizonyít fenntartható üzletet.

**Fejlesztési prioritás:** mozgásélmény → első pálya érthetősége → társas élmény → visszatérés → vásárlás → tartalombővítés.

## 3. Célközönség és nehézség

Olyan Roblox-játékosoknak készül, akik szeretik az obbykat, a gyors mozgást, a látványos lövöldözést és a barátokkal összehasonlítható eredményeket. A főútvonal kezdők számára is teljesíthető legyen; a rövidítések adjanak teret a gyakorlott játékosoknak.

A „relaxing” itt folyamatos, kis büntetéssel járó játékot jelent:

- A játékos gyors lehet anélkül, hogy minden pillanatban a kieséstől tartana.
- A pályákon világos, merre kell továbbmenni.
- A checkpointok rövidek és a visszatérés gyors.
- A rekordhajszolás választható cél.
- A kezdő is kapjon elismerést a teljesítésért és a saját javulásáért.

A prototípus elsődleges mozgásnézete belső nézet. A közös térben legyen kényelmes külső nézet, hogy a játékos láthassa az avatarját és mások megjelenését. A kameraváltás legyen kiszámítható.

## 4. Inspiráció és saját karakter

| Inspiráció | Átvehető tervezési tanulság | Saját megoldás |
|---|---|---|
| Neon White | Rövid pályák, lövés és mozgás kapcsolata, új útvonalak felfedezése | Egyszerűbb kezdőirányítás, dróntalálatra visszatöltődő dash, közös futások |
| Ghostrunner | Falon futás, lendület, jól összekötött mozdulatok | Világosabb világ, ritkább büntetés, barátságosabb főútvonal |
| Klasszikus Roblox speedrun pályák | Azonnal érthető cél, eltérő pályahangulatok | Lövésből származó mozgáslehetőség és felismerhető kozmetikák |

Az inspiráció a mechanikák és az élmény szintjén értendő. Saját pályák, karakterek, fegyverformák, zene, felület és márka készüljön.

**A fő megkülönböztető állítás:** könnyen elérhető, látványos mozgásélmény, amelyet a barátok együtt is élvezhetnek, és amelyben a harc a továbbhaladást segíti.

## 5. A játék alapritmusa

### 5.1. Pillanatról pillanatra

Futás → ugrás → falon futás → drón lelövése → légi dash visszatöltése → újabb átrepülés → érkezés → következő mozgássor.

Egy jó szakaszon a játékosnak nem kell megállnia a célzáshoz. A célpontok elhelyezése a következő mozdulatra irányítja a figyelmet.

### 5.2. Egy pálya

- A játékos választ egy rövid útvonalat.
- Átlépi a startvonalat, az időmérés elindul.
- Teljesíti a checkpointokkal tagolt szakaszokat.
- A befutónál megjelenik az ideje és saját korábbi eredményéhez viszonyított javulása.
- Egyetlen művelettel újrapróbálhatja, folytathatja a következő pályával vagy visszatérhet a közös térbe.

### 5.3. Egy játékalkalom

Tervezési célként egy rövid alkalom is legyen kerek: néhány pálya, egy új rövidítés, egy baráttal közös futás vagy egy személyes rekord. A 5–15 perces alkalom kiinduló felhasználási helyzet, nem előre igazolt játékidő-becslés.

## 6. Az első két perc

| Időszak | Játékosélmény | Tervezési feladat |
|---|---|---|
| 0–15 másodperc | Megérkezik egy szép tetőteraszra, látja a következő útvonalat | Rövid betöltés, egyértelmű indulási pont |
| 15–35 másodperc | Fut és átugrik néhány széles rést | Irányítás tanítása mozgás közben |
| 35–55 másodperc | Egy rövid falon futással áthalad az első látványos szakaszon | Megbocsátó aktiválás és biztonságos érkezés |
| 55–80 másodperc | Lelövi az első drónt, visszakapja a dasht, átrepül a következő platformra | Az egyedi mechanika bemutatása |
| 80–120 másodperc | Befut, lát egy animációt és saját eredményt, újraindulhat | Azonnali, érthető sikerélmény |

Ezek megfigyelési célok. A játékos sebességéhez igazodjanak, ne kötelező időzített jelenetek legyenek.

Az első pálya előtt ne legyen hosszú menüsor, bolt vagy kötelező jutalomátvétel. A szükséges magyarázat ott jelenjen meg, ahol először használni kell a mozdulatot.

## 7. Mozgásrendszer

### 7.1. Futás

- A normál előrehaladás legyen kellően gyors; külön sprintgomb ne legyen szükséges.
- A gyorsulás adjon lendületérzetet, de rövid korrigálásra is legyen lehetőség.
- A levegőbeli irányítás legyen megbocsátó.
- A karakter ne akadjon el apró díszítőelemekben.
- A játék szándékosan szerkesztett pályáihoz tartozzon kezelhető maximális mozgássebesség.

### 7.2. Ugrás

- Legyen rövid bemeneti puffer: a landolás előtt kicsivel megnyomott ugrás működjön.
- Legyen rövid türelmi idő a perem elhagyása után.
- Kiinduló hangolási tartományként 0,10–0,15 másodperc tesztelhető mindkettőre.
- A kamera és a hang jelezze az érkezést, erős rázkódás nélkül.
- A magas platformperemekhez szükséges segítség csak akkor kerüljön be, ha a pályapróba indokolja.

### 7.3. Dash

- Egy rövid, jól kiszámítható előrelendülés.
- Alapesetben egy légi dash áll rendelkezésre.
- Érkezéskor visszatöltődik.
- Egy új, érvényes drón megsemmisítése visszaadja a már elhasznált légi dasht.
- A játékos mindig lássa, hogy a dash készen áll-e.
- Egyazon célpont ugyanabban a próbálkozásban egyszer adhat visszatöltést.
- A dash ne engedjen falakon vagy pályaellenőrző kapukon keresztülugrani.

### 7.4. Falon futás

- Csak egyértelműen jelölt, erre tervezett felületeken működjön.
- Megfelelő oldalirányú megközelítés és nyomva tartott ugrás indítsa el; az automatikus változat külön tesztelhető.
- Ne követeljen pixelpontos belépést.
- A falról elrugaszkodás természetesen vezessen a következő platformra.
- A kamera enyhe dőlése kikapcsolható legyen.

### 7.5. Későbbi mozdulatok

A csúszás, grappling hook és összetett fegyverváltás csak a fő mozgássor igazolása után következzen. A csúszás elsőként vizsgálható bővítés; új gomb helyett kontextusfüggő megoldás is kipróbálható.

## 8. Lövöldözés és célpontok

### 8.1. Kezdő fegyver

Egyetlen futurisztikus impulzuspisztoly készüljön. Legyen jól felismerhető sziluettje, olvasható működése és kellemes találati hangja.

- Korlátlan lőszer, újratöltési megszakítás nélkül.
- A tüzelési ütem hangolható legyen; a nyomva tartott lövés legyen használható.
- Egy alapdrónt egy találat semmisítsen meg.
- A találat azonnal kapjon visszajelzést.
- Ne legyen kritikus találati rendszer vagy fegyverstatisztika-fejlesztés az első változatban.

### 8.2. A drónok szerepe

Az első pályákon a drónok mozgást segítő célpontok. Nem kell visszalőniük. A harci élményt az időzítés, a hang, a szétesés és a dash-visszatöltés adja.

Minden kötelező szakasznak legyen biztonságos főútvonala. Egy célpont eltalálása gyorsabb vagy látványosabb útvonalat nyithat. Elvétett lövés után legyen lehetőség normál platformra érkezni vagy közeli checkpointból újrapróbálni.

Az MVP teljesítésének feltétele a kötelező útvonalkapuk érintése és a célba érés. Ne kelljen az egész pályán visszamenni egy kihagyott drónért.

### 8.3. Későbbi ellenféltípusok

- Lassan oldalazó drón a célzás gyakorlására.
- Egyértelműen jelzett veszélyzónát létrehozó drón.
- Opcionális rövidítésben elhelyezett, nehezebb célpont.

A valódi visszalövő ellenfelek csak akkor indokoltak, ha nem teszik szaggatottá és fárasztóvá a futást. PvP nem része az első kiadás tervezett alapjátékának.

## 9. Mobilos és kontrolleres használat

A mobilos irányítás az alapmechanikával együtt készüljön, ne egy kész PC-s vezérlés utólagos átalakítása legyen.

| Művelet | PC kiindulópont | Mobil kiindulópont |
|---|---|---|
| Mozgás | WASD | Bal oldali virtuális joystick |
| Kamera | Egér | Jobb oldali húzás |
| Ugrás / falon futás | Space / nyomva tartott Space | Nagy ugrásgomb / nyomva tartás |
| Dash | Shift | Ugrás közelében elhelyezett dashgomb |
| Lövés | Bal egérgomb, nyomva tartható | Nyomva tartható lövésgomb, célzássegítéssel |
| Checkpoint újrapróbálása | R | Elkülönített újrapróbálás gomb |
| Teljes pálya újraindítása | T | Szünetmenüből elérhető művelet |

A végleges gombkiosztást kézben tartott eszközön kell kipróbálni. Kontrolleren minden alapfunkció, pályaválasztás és menühasználat legyen elérhető egér nélkül is.

A célzássegítés javasolt működése:

- Csak a látótérben és közvetlenül elérhető célpontok között segítsen.
- Közel a célkereszthez, kiszámítható módon válasszon célt.
- Ne fordítsa hirtelen el a kamerát.
- Vizuálisan jelezze, melyik célpontot segít eltalálni.
- Az automatikus tüzelés külön kísérlet; ne legyen ellenőrizetlen alapértelmezés.

A segített és kézi célzás összehasonlíthatóságát a ranglisták bevezetése előtt rendezni kell. Eltérő szabályrendszerrel futott rekordokat ne kezeljünk automatikusan azonos kategóriaként.

## 10. Pályatervezési szabályok

- Egy pálya tervezett hossza kezdetben 45–90 másodperc; kezdőknek ennél több is lehet.
- Egy szakasz lehetőleg egy fő készséget tanítson vagy kombináljon.
- Az útvonalat a tér, a fény, a jelzések és a célpontok együtt mutassák.
- A leglátványosabb mozdulat után legyen biztonságos érkezési hely.
- A főútvonal szélesebb és megbocsátóbb; a rövidítés pontosabb mozdulatot kér.
- A rövidítés jellemzően újra csatlakozzon a főútvonalhoz, hogy a társak ne tűnjenek el végleg egymás elől.
- Esés után rövid szakaszt kelljen újrapróbálni.
- A kötelező kapuk helye engedje a tervezett rövidítéseket, de zárja ki a teljes pálya átugrását.
- A díszítés ne fedje el a fontos platformszéleket és a drónokat.

A checkpoint visszaállítja a karaktert, a dash állapotát és az adott próbához szükséges saját célpontokat. A teljes pályaideje közben tovább futhat. A tiszta rekordhoz a játékos teljes újraindítást választhat.

## 11. Az első három pálya

### 11.1. First Flight — az első siker

**Hangulat:** fehér tetők, tiszta kék ég, türkiz jelzések, nyugodt elektronikus alapzene.

**Útvonal:** széles indulóterasz → egyszerű ugrások → rövid falon futás → első drón → opcionális dash-rövidítés → nyitott befutótér.

**Feladat:** a játékos megértse az ugrást, a falon futást és a találat utáni dash lehetőségét. Az első pályát a drón elvétése mellett is végig lehessen vinni a biztonságos útvonalon.

**Javasolt hossz:** gyakorlott játékosnak 45–60 másodperc.

### 11.2. Rooftop Relay — a mozdulatok összekötése

**Hangulat:** tetőkertek, narancssárga napfény, fehér épületek és néhány mélyebb kék árnyék.

**Útvonal:** induló rámpa → két egymást követő falon futó felület → két drónnal összekötött légi szakasz → választható alsó vagy felső útvonal → közös befutó.

**Feladat:** a játékos tapasztalja meg, hogy egy jól időzített találat következő mozdulatot tesz lehetővé. Az alsó útvonal legyen hosszabb, de biztonságos.

**Javasolt hossz:** 60–75 másodperc.

### 11.3. Sunset Circuit — az első visszatérős pálya

**Hangulat:** korall és arany égbolt, sötétkék részletek, hosszú panorámák.

**Útvonal:** széles közös kezdés → egymásra épülő dash-szakaszok → felfedezhető magas rövidítés → visszatérés a főútvonalra → látványos végső ugrás és befutó.

**Feladat:** elsőre teljesíthető legyen, de másodszorra már látszódjon, hol lehet időt nyerni.

**Javasolt hossz:** 75–90 másodperc.

## 12. Többjátékos működés

### 12.1. Közös tér, önálló haladás

Kiinduló prototípus-beállításként egy szerveren legfeljebb 8 játékos legyen. Ez tesztelési döntés, nem végleges kapacitásígéret.

- A játékosok látják egymást a közös gyakorlótéren és az azonos pályán.
- Nem lökik le egymást, és nem állják el a másik útját.
- Mindenki önállóan indíthat pályát.
- Egy üres szerveren is azonnal működik a teljes játék.
- Barátok számára később legyen választható közös visszaszámlálás.
- A befutó játékos azonnal újrapróbálhat; ne legyen kötelező kivárnia mindenkit.

### 12.2. Célpontok és állapot

A drónok és a célpontok állapota játékosonként külön kezelendő. Ha valaki lelő egy dash-visszatöltő drónt, az ne vegye el a következő játékostól ugyanazt a mozgáslehetőséget.

A közös világgeometria megosztható. A lövés hatása, a checkpoint, az időmérés és a visszatöltés viszont a megfelelő játékos futásához tartozik.

A személyes dróneffektet a tulajdonos teljesen lássa. Mások számára egyszerűsített lövés- és mozgáseffektek jelenhetnek meg, hogy a tér olvasható maradjon.

### 12.3. Társas célok

Későbbi jelöltek: baráti rekordlista, közös teljesítési kihívás, meghívással indítható futás. Ezek ne legyenek feltételei a normál haladásnak.

Globális lassítás vagy mindenkit megállító befutó-jelenet ne kerüljön a közös pályába.

## 13. A közös gyakorlótér

A lobby egy kis, játszható tetőterasz legyen. A pályabejáratok a fő vizuális célpontok, a kozmetikai bemutató pedig természetesen illeszkedjen a térbe.

Tartalma:

- Rövid falon futó felület és néhány ugróplatform.
- Újra használható gyakorlódrónok, rekord- vagy jutalomfarmolás nélkül.
- Jól látható pályabejáratok.
- Öltözőpont, teljes karakteres előnézettel.
- Kis közös terasz, ahol az emote-ok és a felszerelések láthatók.
- A barátokhoz és a következő pályához vezető egyszerű felület.

A játékos ne azért töltsön itt időt, mert visszatartjuk, hanem mert a mozgás és a társas jelenlét önmagában is kellemes.

## 14. Látványvilág

### 14.1. Alapirány

Világos, stilizált, futurisztikus tetőváros az égben. Letisztult tömegek, nagy felületek, erős sziluettek, növényekkel és néhány technikai részlettel.

**Vizuális benyomás:** tiszta levegő, nagy magasság, könnyedség, sebesség és játékosság.

A mozgási útvonal legyen részletesebb és kontrasztosabb a távoli háttérnél. A távolban elég néhány épülettömeg, felhő és mozgó díszelem.

### 14.2. Kiinduló paletta

| Szerep | Javasolt szín |
|---|---|
| Alap épületfelület | Törtfehér — `#F2F5F0` |
| Felületi és fémes árnyék | Mély kékesszürke — `#24364B` |
| Ég és távoli háttér | Égkék — `#79C7EA` |
| Használható mozgásfelület | Türkiz — `#26CFBF` |
| Drónmag és dash-visszatöltés | Meleg sárga — `#FFD56A` |
| Veszély | Korall — `#F16D67` |

Ezek arculati kiindulópontok. A fontos jelzéseket forma, ikon és animáció is különböztesse meg; a szín önmagában ne hordozzon kötelező információt. A felületi szövegek kontrasztját külön ellenőrizni kell.

### 14.3. Avatar és felszerelés

A játékos Roblox-avatarja maradjon felismerhető. A mozgási ütközést és játékmenetet ne a különböző avatarméretek határozzák meg. A futóanimációk egyértelműek, energikusak és távolról is olvashatók legyenek.

Javasolt saját kiegészítők: könnyű futóhátizsák, kesztyű, cipődísz, energiamodul és rövid dash-csík. Ezek később kapcsolhatók egységes kozmetikai szettekhez.

## 15. Effektek, kamera és hang

### 15.1. Effektek

- Dash: rövid irányjelző csík és gyorsan eltűnő utókép.
- Falon futás: finom, a felületet követő energianyom.
- Találat: jól látható drónmag-villanás, rövid szétesés.
- Dash visszatöltése: kis jelzés a célkereszt közelében és felismerhető hang.
- Befutó: rövid, helyhez kötött effekt, amely nem takarja el a még futókat.

A megvásárolható effekt ugyanakkora játékmeneti olvashatóságot biztosítson, mint az alapváltozat. A látványosságot ne az egész képernyőt elfedő részecskemennyiség adja.

### 15.2. Kamera

- Stabil belső nézet.
- Sebességtől függő látószögváltozás csak kis mértékben és kikapcsolhatóan.
- Kamerarázás, fejbólogatás és falon futási dőlés külön csökkenthető.
- Erős mozgáselmosás és kényszerített kameraforgatás ne legyen szükséges a sebességérzethez.
- A játékos szabadon állíthassa a kamerája érzékenységét.

### 15.3. Hang

Melodikus, kellemes elektronikus zene, jól elkülönülő mozgás- és találati hangokkal. A zenének legyen energiája, de hosszabb ismétlés mellett se váljon fárasztóvá.

A lövés, találat, dash-kész állapot és checkpoint hangja eltérő funkciót töltsön be. A zene, effektek és más játékosok hangjai külön állíthatók legyenek.

Saját vagy megfelelően felhasználható hanganyag kell. A prototípus ideiglenes hangjai legyenek könnyen lecserélhetők.

## 16. Játékfelület

### 16.1. Futás közbeni HUD

- Kis időmérő felül, másodlagos vizuális súllyal.
- Egyszerű célkereszt.
- Jól olvasható dash-kész jelzés a célkereszt közelében.
- Rövid checkpoint-visszajelzés.
- Helyzethez kötött, rövid tanítóüzenet, amely az elsajátítás után eltűnik.

A futást ne takarja bolt, jutalomeső, hosszú küldetéslista vagy több pénznem egyidejű kijelzése.

### 16.2. Befutóképernyő

Első helyen a teljesítés és az idő szerepeljen. Utána a saját rekordhoz viszonyított változás és legfeljebb néhány érthető eredmény, például „első teljesítés” vagy „új személyes rekord”.

Három fő művelet: **újra**, **következő pálya**, **közös tér**. Az újraindítás legyen azonnali. A befutóanimáció ne akadályozza a következő futást.

### 16.3. Kozmetikai felület

- Teljes karakteres és fegyveres előnézet.
- A dash és a befutóeffekt mozgásban is kipróbálható.
- Az ár és a tartalom legyen közvetlenül látható.
- Egyértelmű különbség: megvan, felszerelve, megszerezhető, megvásárolható.
- A vásárlási ablak csak a megfelelő vásárlási művelet után jelenjen meg.

## 17. Haladás és visszatérés

### 17.1. Első játszható változat

- Pályánkénti teljesítés.
- Személyes legjobb idő.
- Alap érmek vagy teljesítési jelvények, tesztelt határidőkkel.
- Kevés megszerezhető kozmetika.
- Az elsajátított mozgások fokozatos kombinálása.

A kezdő mozgáskészlet és a normál fegyver mindenki számára azonos. A fejlődés fő értéke az ügyesebb játék és a személyre szabás.

### 17.2. Bővítési jelöltek

- Saját legjobb futás szellemképe.
- Barátok eredményeinek összehasonlítása.
- Heti kiemelt pálya vagy útvonal.
- Új vizuális témához tartozó pályacsomag.
- Opcionális kihívások és teljesíthető kozmetikai gyűjtemények.

Ne kerüljön egyszerre minden rendszer az induló játékba. Előbb ki kell deríteni, hogy a játékosok a pályák, a rekordok, a barátok vagy a megjelenés miatt térnek vissza.

## 18. Kozmetikai bevételi modell

### 18.1. Tervezett termékek

| Termék | Tulajdonos számára látható érték | Társas láthatóság |
|---|---|---|
| Fegyverskin | Belső nézetben folyamatosan látszik | Közös térben és karakterelőnézetben |
| Kesztyűskin | Ugrásnál, fegyverhasználatnál látszik | Közös térben közelről |
| Dash-effekt | Minden dash külön visszajelzést kap | Futás közben a többiek látják |
| Futócsík | Saját stílusérzet | A közeli futók számára felismerhető |
| Befutóanimáció | Minden teljesítés jutalmazó lezárása | A befutótérben látható |
| Emote | Személyes karakterkifejezés | Gyakorlótéren, barátokkal |
| Profilkártya | Saját megjelenés | Baráti és eredményfelületeken |

Az első kereskedelmi változat néhány teljes, egymással kombinálható szettre épüljön. A szett elemei külön is értelmesek legyenek.

### 18.2. Három szettötlet

**Solar:** törtfehér fegyver, borostyán energiamag, rövid arany dash, napfényszerű befutóív.

**Circuit:** sötétkék fegyver, türkiz vonalak, rövid geometrikus utókép, elektromos befutójelzés.

**Bloom:** világos fegyver, korall és zöld részletek, stilizált levélforma, színes sziromív a célban.

Az MVP-ben két szett tesztváltozata elég. A harmadik csak későbbi vizuális irány.

### 18.3. Vásárlási szabályok

- Közvetlen, átlátható vásárlás.
- Az alapmozgás és a versenyképesség ne függjön költéstől.
- A termék legyen előnézetben megtekinthető.
- A kezdő és az átlagos játékos is rendszeresen használhassa a megvett effektet.
- Legyen néhány játék közben megszerezhető, jól kinéző tárgy is.
- Az első prototípusban ne legyen valós fizetés; a tulajdon és felszerelés tesztadatokkal működjön.
- A kereskedelmi kiadás árait külön döntésként, vásárlási és megtartási adatok alapján kell kialakítani.

A szezonbérlet, előfizetés és nagy mennyiségű rendszeres termékgyártás csak akkor indokolt, ha már van visszatérő közönség és fenntartható frissítési kapacitás.

## 19. Hogyan válik láthatóvá a játékos stílusa?

A társas láthatóság tervezett pontjai:

1. **Megérkezés:** a közös térben látszik az avatar és a felszerelés.
2. **Gyakorlás:** a játékos rögtön kipróbálhatja a dash-effektjét.
3. **Közös indulás:** a barátok rövid ideig egymás mellett vannak.
4. **Útvonalak találkozása:** a futók újra látják egymást.
5. **Befutó:** minden teljesítőnek saját rövid animációja van.
6. **Profilmegtekintés:** opcionálisan megnézhető, milyen felszerelést használ valaki.

A közös indulás és a befutó ne váljon kötelező várakozássá. A kozmetikai értéknek a természetes játékmenet közben kell megjelennie.

## 20. Az MVP pontos terjedelme

### Kötelező

- Egy kis közös gyakorlótér.
- Három rövid pálya, először egyszerű geometriai változatban.
- Futás, ugrás, dash és falon futás.
- Egy fegyver és egy alapdrón-típus.
- Találat utáni dash-visszatöltés.
- Checkpoint, gyors újrapróbálás és teljes pályaújraindítás.
- Személyes időmérés és legjobb idő.
- Látható társak, játékosok közti ütközés nélkül.
- Játékosonként elkülönített célpont- és futásállapot.
- PC-s és mobilos alapirányítás.
- Két teszt-kozmetikai szett, előnézettel és felszereléssel.
- Egyszerű eseménymérés a fő játékoslépésekhez.

### Nem része az MVP-nek

- PvP, rangsorolt matchmaking és nagy nyílt világ.
- Sok fegyver, fegyverfejlesztés és képességfa.
- Grappling hook, összetett közelharc és bossok.
- Globális ranglista és szellemfutás-visszajátszás.
- Saját pályaszerkesztő és közösségi pályafeltöltés.
- Kereskedés, lootboxok, több pénznemes gazdaság.
- Battle pass, előfizetés és valós Robux-vásárlás.

Ezek hiánya az első verzió tudatos terjedelmi korlátja. A fő élmény vizsgálata után külön dönthető el a bővítés.

## 21. Fejlesztési sorrend és döntési kapuk

### A. Egyetlen működő mozgássor

Készüljön egy egyszerű tesztpálya, amelyen egymás után elvégezhető: futás → ugrás → falon futás → lövés → dash-visszatöltés → befutó.

**Továbblépés feltétele:** a mozdulatok ismételhetők, kiszámíthatók, és mobilon is végrehajthatók. Ebben a szakaszban a mozgást kell javítani, ha az élmény nem működik.

### B. Első teljes pálya

First Flight, checkpointokkal, egyszerű HUD-dal és újraindítással. Legyen összehasonlítható célpontos és célpontok nélküli változat.

**Továbblépés feltétele:** a tesztelők megértik a haladást, és a lövöldözős változatban nem törik meg rendszeresen a mozgásuk.

### C. Közös játék és kozmetikai próba

Közös gyakorlótér, több látható játékos, elkülönített célpontállapot, két tesztszett és rövid befutóeffekt.

**Továbblépés feltétele:** a társak nem akadályozzák egymást; észreveszik az eltérő kozmetikákat; a közös játék nem jár túl sok várakozással.

### D. Hárompályás, menthető tesztverzió

Három pálya, személyes rekordmentés, felszerelésmentés, alap mérés és stabil mobilos működés.

**Továbblépés feltétele:** több alkalmas tesztből is látszik visszatérési szándék vagy tényleges visszatérés. Enélkül a tartalommennyiség növelése helyett az alapélményt kell módosítani.

### E. Külön kereskedelmi kiadás

Csak a fenti tanulságok után: vásárlási integráció, szerveroldali jogosultságkezelés, valós árak, bevételmérés és indokolt tartalombővítés.

## 22. Technikai felelősségek

Roblox Studio és Luau környezetben, egymástól elkülönített rendszerekkel készüljön a megvalósítás.

Javasolt felelősségi körök:

- Mozgás és helyi visszajelzés.
- Kamera és eszközfüggő bemenet.
- Fegyverhasználat és célpontkezelés.
- Futásindítás, útvonalkapuk, checkpointok és időmérés.
- Kozmetikai definíciók, felszerelés és megjelenítés.
- Személyes rekordok, tulajdon és beállítások mentése.
- Játékesemények mérése.

A pályák, a mozgásparaméterek és a kozmetikák adatból legyenek konfigurálhatók. Új skin vagy pálya felvételéhez ne kelljen átírni a teljes alapjátékot.

### Kliens és szerver

A kliens az azonnali mozgásérzetért és megjelenítésért felel. A szerver ellenőrizze a jutalmat, tulajdont, vásárlást és rekordot érintő állapotváltozásokat.

- Ne a kliens szabadon megadott időeredménye kerüljön a mentésbe.
- Ellenőrizhető legyen a futás kezdete, a kapuk sorrendje és a befutás.
- Egy kliensüzenet önmagában ne hozzon létre kozmetikai tulajdont.
- A dróntalálat és dash-visszatöltés ellenőrzése vegye figyelembe a késést és az ismételt üzeneteket.
- A későbbi vásárlási jutalmazás legyen ismételt feldolgozás mellett is helyes.
- A mentési hibákat és újracsatlakozást kezelni kell.

A gyors mozgás miatt külön figyelmet igényel a csalások és a hálózati késés megkülönböztetése. A kezdeti ellenőrzések ne ígérjenek teljes csalásvédelmet.

## 23. Teljesítmény és hozzáférhetőség

- A fontos útvonal és a célpontok gyengébb grafikai beállítás mellett is olvashatók legyenek.
- A távoli játékosok effektjei egyszerűsíthetők.
- A részecskék élettartama és darabszáma legyen korlátozott.
- A kötelező információ ne kizárólag hangból vagy színből derüljön ki.
- Legyen csökkentett mozgású kameraopció.
- A mobilos gombok ne fedjék el a következő platformot.
- A felület vegye figyelembe a különböző kijelzőarányokat és biztonságos képernyőterületeket.

Első teljesítménycélként a kijelölt középkategóriás teszteszközön stabil 60 FPS-re kell törekedni. Ha ez nem tartható, a mérés mutassa meg a szűk keresztmetszetet. Az elfogadott minimumot a tényleges eszköztesztek alapján kell meghatározni; nem elég az asztali Studio-teljesítmény.

## 24. Mérési terv

| Esemény | Mit segít megérteni? |
|---|---|
| Első megérkezés | Hányan jutnak el ténylegesen a játszható állapotig? |
| Első pályaindítás | Elég egyértelmű-e, hogyan kell elkezdeni? |
| Első sikeres falon futás | Megtanulható-e az első különleges mozdulat? |
| Első találat és dash-visszatöltés | Megértik-e az egyedi mechanikát? |
| Checkpoint-újrapróbálás | Hol akadnak el? |
| Első befutás | Eljutnak-e a sikerélményig? |
| Önkéntes pályaújraindítás | Van-e kedvük javítani? |
| Következő pálya indítása | Akarnak-e tovább játszani? |
| Kozmetikai előnézet és felszerelés | Érdekes-e a személyre szabás? |
| Közös pályaindítás | Használják-e a társas lehetőséget? |

A kereskedelmi változatban további események: boltnyitás, termékelőnézet, vásárlási folyamat indítása, szerver által igazolt vásárlás.

Vizsgálandó mutatók:

- Első pálya befejezési aránya és a sikerig eltelt idő.
- Kilépési és elakadási helyek.
- Önkéntes újrapróbálások.
- Következő napokon visszatérők aránya.
- Baráttal játszó alkalmak.
- Fizető játékosok aránya és egy aktív játékosra jutó bevétel.
- Egy pálya és egy kozmetikai szett elkészítésének tényleges munkaigénye.

Az adatokat eszköz és belépési forrás szerint is érdemes külön nézni. Kis tesztcsoportból nem szabad stabil bevételi előrejelzést készíteni. Univerzális „jó retention” küszöböt ez a brief nem állít.

## 25. Játékpróba és értékelés

Az első körben 8–12 tesztelő már segíthet gyakori érthetőségi és irányítási hibák megtalálásában. Ez kvalitatív teszt, nem piacméret- vagy bevételbecslés.

**Megfigyelési kérdések:**

1. Elindulnak-e külön magyarázat nélkül?
2. Melyik mozdulatnál állnak meg vagy veszítik el az irányt?
3. Észreveszik-e, hogy a találat visszaadja a dasht?
4. Elvétett lövés után folytatják-e, vagy feladják?
5. Maguktól indítanak-e még egy futást?
6. A lövés hozzáad-e az élményhez a célpont nélküli pályához képest?
7. Észreveszik-e a másik játékos dash-effektjét és befutóját?
8. Mobilon a kamerát vagy a gombokat hibáztatják-e egy elrontott mozdulatért?
9. Egy második alkalommal is szeretnének-e játszani?

A szóbeli vásárlási szándék külön kezelendő a tényleges vásárlástól. A bolt iránti érdeklődés hasznos korai jel, de nem bevételi bizonyíték.

## 26. Fontos hibás irányok és javításuk

| Tünet | Valószínű kérdés | Következő lépés |
|---|---|---|
| A játékos minden drónnál megáll | Túl nehéz-e célozni, rossz helyen van-e a célpont? | Célpontelhelyezés és célzássegítés tesztje |
| Csak a fejlesztő tudja élvezni a pályát | Túl szűkek-e a mozgási ablakok? | Főútvonal szélesítése, belépési tolerancia javítása |
| Jó a PC-s változat, nehézkes a mobilos | Túl sok-e az egyidejű bemenet? | Kevesebb aktív művelet, nagyobb gombok, célzási próba |
| Végigmennek egyszer, de nem térnek vissza | Van-e érdekes rövidítés vagy társas cél? | Újrafutási ok tesztje, új tartalom előtt |
| A skineket nem veszik észre | Van-e természetes alkalom egymásra nézni? | Közös tér és befutó javítása |
| Az effektek rontják a teljesítményt | Túl sok-e az egyszerre megjelenő elem? | Egyszerűsített távoli effektek és szigorú keretek |
| Túl lassú az új pályák készítése | Hiányoznak-e az újrahasználható elemek? | Moduláris pályaelemek, egyszerűbb tematika |

## 27. Elfogadási ellenőrzőlista az MVP-hez

- [ ] Egyetlen játékos is teljesen használhatja a játékot.
- [ ] Első belépés után egyértelmű a következő teendő.
- [ ] A dash és a visszatöltés állapota érthető.
- [ ] A teljes alapmozgássor PC-n és mobilon is végrehajtható.
- [ ] Minden pályának van megbocsátó főútvonala.
- [ ] Az elvétett célpont nem okoz megoldhatatlan állapotot.
- [ ] A checkpoint következetesen visszaállítja a szükséges állapotot.
- [ ] Két játékos nem fogyasztja el egymás célpontjait.
- [ ] A társak nem lökik le egymást.
- [ ] Nincs kötelező várakozás egy teljes pályányi időre.
- [ ] Az eredmények és felszerelések mentése ellenőrzött.
- [ ] Az első prototípus nem kezdeményez valós vásárlást.
- [ ] A kozmetikák a tulajdonos és legalább egy másik játékos számára láthatók.
- [ ] Az újraindítás gyors és megbízható.
- [ ] A fő mérési események nem többszöröződnek hibásan.
- [ ] A teljesítményt tényleges mobilos próbával is ellenőriztük.
- [ ] A kipróbált és még nem ellenőrzött részek külön dokumentálva vannak.

## 28. Kutatási háttér és bizonytalanságok

Az előzetes webes kutatásban kapcsolódó játékokként felmerült a Speed Run 4, PARKOUR Reborn, REDLINER és Runshot. A Runshot nyilvános leírása különösen közeli kombinációt mutat: parkour, célpontlövés, mozgást segítő nyilak, időeredmények és skinek. Emiatt a koncepciót nem szabad „még soha nem létezett ötletként” kezelni.

A kutatás nem igazolta, hogy ez a konkrét változat mekkora közönséget vagy bevételt érhet el. A kiinduló üzleti hipotézis a könnyű belépés, a társas jelenlét és a kozmetikai önkifejezés együttese.

Források, amelyek az előző beszélgetésben áttekintett háttérhez tartoznak:

- [Neon White — hivatalos Steam-oldal](https://store.steampowered.com/app/1533420/Neon_White/)
- [Speed Run 4 — Roblox](https://www.roblox.com/games/183364845/Speed-Run-4)
- [PARKOUR Reborn — Roblox](https://www.roblox.com/games/11639495622/PARKOUR-Reborn)
- [Runshot — nyilvános játékleírás a Medalön](https://medal.tv/games/roblox/experiences/1bcVHw-xFzhtOj/beta-runshot)
- [Roblox Discovery — ajánlási és megtartási háttér](https://create.roblox.com/docs/discovery)
- [Roblox Monetization Analytics — bevételi mutatók](https://create.roblox.com/docs/production/analytics/monetization)

Ezek referenciaforrások. A fenti mechanikai és vizuális döntések saját tervezési javaslatok; a források nem igazolják előre a játék sikerét.

## 29. Másolható fejlesztési prompt

Az alábbi promptot **ezzel a teljes dokumentummal együtt** add át a fejlesztőnek vagy AI-nak. A prompt először a kis prototípus megvalósítását kéri, és döntési kapukhoz köti a bővítést.

```text
Egy Roblox Studio / Luau játék fejlesztésében dolgozol velem. A mellékelt
NEON_RUSH_GAME_BRIEF.md az aktuális játékterv. Olvasd végig, és használd
a feladat meghatározásához.

A játék munkacíme NEON RUSH. Egy világos, stilizált, futurisztikus tetővárosban
játszódó parkour shooter. A fő élmény: rövid pályákon látványosan, folyamatosan
mozogni, drónokat eltalálni, és a találatokból újabb légi dasht kapni.
A játék legyen könnyen elkezdhető, kis büntetéssel járó és barátokkal is élvezhető.
A kezdő főútvonal legyen megbocsátó, a rövidítések adjanak mélységet.

Hosszabb távon kozmetikai bevételt szeretnénk. Ezért fontos, hogy a játékosok
lássák egymás megjelenését, dash-effektjét és befutóanimációját. Az első
prototípusban azonban csak teszt-kozmetikák és teszt-tulajdon legyen; valós
vásárlást ne integrálj ebben a feladatban.

ELŐSZÖR VÉGZENDŐ FELADAT:
1. Vizsgáld meg a projektet és a meglévő helyi instrukciókat.
2. Állapítsd meg, milyen Roblox-eszközök és futtatási lehetőségek állnak rendelkezésre.
3. Röviden írd le az első működő prototípus terjedelmét és a fő függőségeket.
4. Valósíts meg egyetlen egyszerű tesztpályát, a következő teljes sorral:
   futás -> ugrás -> falon futás -> drón lelövése -> dash visszatöltése -> befutás.
5. Legyen működő checkpoint, újrapróbálás, teljes újraindítás és alap időmérő.
6. Az első mozgáspróbával együtt készítsd el a mobilos bemenetet is.
7. A pálya legyen egyszerű geometriából szerkesztett, de a fontos felületeket
   már a brief vizuális nyelve jelölje: világos épületek, türkiz mozgásfelületek,
   sárga drónmag, jól megkülönböztetett veszélyek.

KÖTELEZŐ TERVEZÉSI ELVEK:
- A mozgás legyen azonnali, megbocsátó és kiszámítható.
- A lövés támogassa a futást; ne kényszerítsen rendszeres megállásra.
- Egy alapfegyver és egy dróntípus elég.
- Egy drón egy futási állapotban egyszer adhat dash-visszatöltést.
- Az elvétett lövés ne tegye megoldhatatlanná a pályát.
- A célpontok állapotát úgy szervezd, hogy később játékosonként elkülöníthető legyen.
- A kameramozgás és a vizuális effektek ne akadályozzák a tájékozódást.
- A fontos paraméterek legyenek könnyen hangolhatók.
- A rekordot, jutalmat és tulajdont érintő állapotot ne bízd ellenőrizetlen kliensadatokra.
- A briefben szereplő számokat kiinduló hangolási értékként kezeld.

TERJEDELMI KORLÁT:
Az első feladat a brief A–B szakaszának alapja. Ne építs hozzá egyszerre teljes
boltot, battle passt, PvP-t, nyílt világot, sok fegyvert vagy összetett progressiont.
A közös gyakorlótér, három pálya, mentés és kozmetikai próba a következő
fejlesztési szakaszok része. A kód szerkezete készítse elő ezeket, de csak a most
szükséges rendszereket valósítsd meg.

MUNKAMÓD:
- A meglévő projekt működő részeit használd fel.
- Ha nincs projekt, a rendelkezésre álló eszközökkel hozz létre egy minimális,
  világosan importálható vagy szinkronizálható Roblox-projektstruktúrát.
- A routine implementációs döntéseket hozd meg a brief alapján.
- Csak akkor kérdezz, ha a hiányzó információ érdemben blokkolja a munkát.
- A mozgási alapélményt ellenőrizd a pálya és a tartalom kibővítése előtt.
- Ne publikálj és ne indíts fizetett szolgáltatást pusztán e prompt alapján.
- Ha nem tudsz Studio-ban vagy tényleges eszközön tesztelni, ezt pontosan jelezd;
  ne állítsd, hogy a játékmenet ellenőrzött.

ÁTADÁS:
- Működő prototípus vagy világosan importálható projektfájlok.
- Rövid indítási és tesztelési útmutató.
- PC-s és mobilos irányítás leírása.
- A legfontosabb hangolható paraméterek helye és szerepe.
- Mi készült el, hogyan lett ellenőrizve, mi nem lett még kipróbálva.
- A következő játékpróbán ellenőrizendő legfontosabb kérdések.

A cél az, hogy egy kis pályán valóban jó érzés legyen újra meg újra végrehajtani
a teljes mozgássort. Ez legyen a további fejlesztés alapja.
```
