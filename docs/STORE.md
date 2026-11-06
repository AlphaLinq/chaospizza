# Pizza Chaos — store-szövegek és képi terv

Állapot: szerkesztett anyag a Creator Hubhoz; nincs publikálva. Az alapváltozat egész évben használható. Az ünnepi bekezdést csak az engedélyezett december1–január6 UTC szezonban illeszd be. A nyitott/PR-ban lévő áramszünet, sajtkerék, ágyúk és más jövőbeli funkciók nem szerepelnek kész funkcióként.

## Cím és rövid pitch

| Nyelv | Cím | Rövid pitch |
|---|---|---|
| EN | Pizza Chaos | Deliver pizza through tornadoes, horse races and shark floods. Grow your own pizzeria! |
| HU | Pizza Chaos | Kézbesíts pizzát tornádón, lóversenyen és cápás áradáson át! Fejleszd a saját pizzériád! |

## Hosszú leírás — EN

Pick up a pizza. Follow the arrow. Try to keep your feet on the ground.

A surprise horse race can cut across your route. A tornado can send your delivery airborne. And when the streets flood, watch for shark fins!

Deliver to unusual customers, fill your Customer Book and invite regulars to your own pizzeria. Collect their tips, improve your courier gear and grow from a food cart to a neon tower.

Carry giant pizzas with friends. Brave two disasters at once during MEGA CHAOS. Come back for daily rewards and weekly challenges, or change your look with courier cosmetics.

The next customer is waiting. The city has other plans.

## Hosszú leírás — HU

Vedd fel a pizzát. Kövesd a nyilat. Próbálj talpon maradni.

Egy váratlan lóverseny keresztezheti az utadat. A tornádó a levegőbe repítheti a futárt. Ha pedig elönti az utcákat az áradás, figyeld a cápauszonyokat!

Kézbesíts különös vendégeknek, töltsd meg a Vendégkönyvet, és hívd a törzsvendégeket a saját pizzériádba. Gyűjtsd be a borravalót, fejleszd a futárfelszerelést, és nőj ételkocsiból neontoronnyá.

Szállíts óriáspizzát a barátaiddal. Nézz szembe két katasztrófával egyszerre a MEGA KÁOSZ alatt. Térj vissza napi jutalmakért és heti kihívásokért, vagy válogass a futárkinézetek között.

A következő vendég már vár. A városnak más terve van.

## Opcionális ünnepi bekezdés

EN: Winter deliveries are here! Meet seasonal customers in the blizzard, including Santa himself. Preview the Santa Courier collection and spend earned tips on its gift box, bag, apron with hat and festive pizzeria sign. Seasonal purchases end January6 UTC; looks you own stay yours.

HU: Megérkeztek a téli fuvarok! A hóviharban szezonális vendégekkel, köztük a Mikulással is találkozhatsz. Nézd meg a Mikulás-futár kollekciót: ajándékdoboz, táska, sapkás kötény és ünnepi pizzériacégér vár a megkeresett borravalódért. A szezonális vásárlás január6-án, UTC szerint véget ér; a megszerzett kinézetek megmaradnak.

A visszaszámlálás és a vásárlási ablak a játék Configjával együtt változzon. A Mikulás ritka vendég, ezért nincs garantált találkozás ígérete.

## Kulcsszó-irány

EN: pizza delivery, courier, disasters, tornado, horse race, shark flood, co-op, pizzeria, customer collection.

HU: pizzafutár, pizzakiszállítás, katasztrófák, tornádó, lóverseny, cápás áradás, közös játék, pizzéria, vendéggyűjtés.

Ezek a leírás természetes témái; nem ismétlődő kulcsszóhalmaz a játékosnak szánt szövegben. Nincs „Steal a…” elnevezés, ingyen Robux, biztos ritka vendég vagy még nem bekapcsolt badge/csoportjutalom ígérete.

## Három bélyegkép-koncepció

| Változat | Kép és olvasási sorrend | Opcionális felirat | Ellenőrzés |
|---|---|---|---|
| A — Levegőposta | Előtérben a levegőben repülő futár, jól látható pizzás dobozzal. Mögötte a tornádó, lent az áradó utca egy cápauszonnyal. A doboz és az arc marad a fókusz, a veszélyek másodlagosak. | EN: PIZZA INCOMING! / HU: PIZZA ÉRKEZIK! | A két veszély MEGA-kombóként valóban együtt előfordul. Nincs hamis játékmeneti UI vagy jutalom. |
| B — Ketten a káoszban | Két futár közösen visz egy óriáspizzát. A háttérben lóverseny választja el őket a célajtótól; a híd/szabad átkelés is felismerhető. | EN: DELIVER TOGETHER / HU: SZÁLLÍTSATOK EGYÜTT | A hordozókat és a nagy dobozt elkülöníti a sziluett; nem állít versengő játékostámadást vagy fizetett védelmet. |
| C — A saját pizzériád | Egy kompozícióban az ételkocsi és a neontorony, azonos futárral. Az előtérben egy törzsvendég és a borravalós üveg. A fejlesztési út a fő történet. | EN: BUILD YOUR PIZZERIA / HU: ÉPÍTSD A PIZZÉRIÁD | A tényleges1-es és6-os modellekből induljon ki; ne mutasson kitalált jutalomértéket vagy még nem létező berendezést. |

Az első változat követi a brief fő képirányát. Mindháromhoz először valódi Studio-jelenetet rögzíts, a felirat külön réteg legyen. Ugyanazon jelenetekből készülhet EN/HU és felirat nélküli változat. Az összehasonlításhoz a kép fő témáját változtasd, ne egyszerre a címet, logót és teljes palettát. A konkrét exportméretet/feltöltési követelményt a Creator Hub aktuális felülete szerint ellenőrizd; ez a dokumentum nem állít platformkorlátot.

## Ikon-koncepció

Egy ferdén álló piros-krém pizzás doboz, mögötte egyetlen kis sötét viharfelhő és sajt-sárga villám. A doboz sziluettje maradjon felismerhető kis méretben is. Vastag, egyszerű formák; nincs apró szöveg, pénzszám vagy ritkaságjelvény. A játék Fredoka/Gotham, krém/piros/sárga világához illeszkedjen, és a valódi dobozmodell arányait kövesse.

## Állítások ellenőrzése

| Állítás | Meglévő alap |
|---|---|
| Lóverseny, tornádó, cápás áradás | Config/Events és server/Events |
| Két katasztrófa egyszerre | EventService MEGA-pár és meglévő kliens-FX/hang |
| Vendégkönyv és törzsvendégek | Customers/CustomerBook/PizzeriaService |
| Ételkocsitól neontoronyig | A meglévő hat pizzériaszint |
| Közös óriáspizza | GiantOrderService; induláshoz a játék feltételei teljesítendők |
| Napi/heti visszatérés | DailyService, WeeklyChallenges |
| Ünnepi kollekció | #68 szezonkapu és megtartott tulajdon; csak az ünnepi bekezdésben |

Hátravan: emberi szöveg-/képkiválasztás, végleges jelenetrögzítés, ikon/bélyegképek előállítása, feltöltés és a publikus store frissítése (#58/#60). A #69 ezekhez a kész szövegeket és képi briefet adja, semmit nem publikál.
