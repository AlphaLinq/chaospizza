# Pizza Chaos — a fő játékmeneti kör elemzése és fejlesztési terv

> 2026-11-06 · Claude. A brief (v2.0) 4. és 12. fejezetére épül, és a ma elkészült rendszerekből indul ki. Döntési javaslat: a brief tervezési döntéseit nem írja felül, csak bővíti őket.

## 1. Hogyan néz ki most a kör

**Rövid kör (60–120 mp):**
1. Rendelés a pultnál. Ezt a játékos nem választja: automatikusan kapja (normál / dupla / sürgős / törékeny / party).
2. Futás a címre: utcák, felüljáró, ágyúk, fejesugrás, buborék.
3. Átadás: tip + XP + vendég a könyvbe, rá a szorzók (stílus, hóbort, streak, Sal-verseny).

**Közepes kör (5–15 perc):**
- esemény 2–3 percenként: lóverseny, tornádó, áradás, sajtkerék, áramszünet, buborékvihar (a hóvihar szezonális);
- káosz-mérő → MEGA;
- óriásrendelés, városi cél, arany pepperoni, kívánságkút.

**Hosszú kör:** Vendégkönyv, pizzéria-szintek, törzsvendégek, időfutam-ranglista, kozmetikák.

## 2. Mi működik jól

- Sok **szorzó-forrás** (stílus, hóbort, streak, Sal, party), ezért egy-egy kézbesítés kis jutalom-robbanás.
- Az események **olvashatók**: előjel, sáv vagy kör a földön, eseménysáv a HUD-on; és veszélytelen is van köztük (áramszünet).
- A közös célok (városi cél, káosz-mérő, óriásrendelés) együtt tartják a szervert.

## 3. Hol gyenge a kör

| # | Probléma | Miért baj |
|---|---|---|
| G1 | **Nincs választás a rendelésnél.** A játékos azt viszi, amit kap. | A kör „A-ból B-be sétálás”, kevés a döntés és a kockázatvállalás. |
| G2 | **Az esemény akadály, nem lehetőség.** Inkább kikerüljük, mint belemegyünk. | A káosz a játék lényege, de nem éri meg keresni. Az esemény alatti +50% minden kézbesítésre jár, akkor is, ha távol maradsz a veszélytől. |
| G3 | **A nyugodt szakasz 90–150 mp-ig üres.** | Az idő 70%-ában semmi meglepő nem történik a városban. |
| G4 | **Kevés az eseményfajta, és mind „kerüld el” típusú.** | Gyorsan kiismerhető. Hiányzik a jutalmazó esemény (gyűjtés), a mozgást átalakító (gravitáció) és a „boss” jellegű. |
| G5 | **A szerver nem dönt együtt.** | A közösség csak elszenvedi az eseményeket; nincs várakozás és nincs „mi jön most?” izgalom. |
| G6 | **Nincs csúcspont a sessionben.** | A MEGA véletlenszerűen jön; nincs „maradj még 3 percet, jön a finálé” horog. |

## 4. Javaslatok

### 4.1. Rendelés-választó (G1) — **a legnagyobb hatású**
A pultnál 3 ajánlat közül lehet választani, kártyákon:
- **Közeli:** biztos, kisebb tip.
- **Távoli vagy ritka vendég:** nagyobb tip és jobb esély ritka vendégre.
- **Különleges:** rush, party, hóbortos vendég vagy esemény alatt „merész” rendelés.

A kártyán ott van a vendég ritkaság-kerete, a hóbort és a becsült tip. 15 mp-en belül választani kell, különben az első ajánlat érvényes. Mobilon 3 nagy gomb.

### 4.2. Merész rendelések az eseményekben (G2)
Esemény alatt a választó egyik ajánlata **a veszélyzónába** szól (tornádó útja, áradás, lópálya, meteor-zóna): ×2 tip és új stílus-címke, a **„Daredevil”**. Az esemény alatti általános bónusz megmarad, de kisebb lesz (+50% → +30%), hogy a jutalom a merészeké legyen. Ez a brief 12.2 „átcímzés” ötletének választhatós változata.

### 4.3. Új eseményfajták (G4) — 5 új esemény, mind más „szerepű”
| Esemény | Szerep | Lényeg |
|---|---|---|
| **Meteoreső** | kerüld el / olvasd | Piros célkörök jelzik előre a becsapódást. A kráterekben csillagpor-gyűjthető marad. (A briefben „később” szerepel.) |
| **Holdséta** (alacsony gravitáció) | mozgás-átalakító | A gravitáció 1/3-ára esik, óriási ugrások, a tetőkön át lehet vágni. Új címke: „Moonwalk”. |
| **Pizzaeső** | jutalmazó | Égő pizzák hullanak, árnyékuk jelzi, hova. Ha elkapod, tip; a szerver közös számlálója egy kis bónuszért megy. |
| **UFO-elrablás** | kaotikus / vicces | Az UFO-k vonósugara felkap és a város másik pontján tesz le. Ha rendelés van nálad, ez előny is lehet. Új címke: „Abducted”, új vendégek: ufók. (A briefben „később” szerepel.) |
| **Óriás macska** | boss | Egy hatalmas macska ül a Plazán, mancsával csap a futárok felé, és lézerpöttyöt üldöz. Az „etesd meg” közös cél (a szerver összes kézbesítése) elküldi. (A briefben „később” szerepel.) |

Mindegyik a meglévő mintát követi: a szerver csak adatot küld, a kliens animál; MEGA-kombók; 4 eseményvendég; HU szöveg; debug parancs.

### 4.4. Mikro-káosz a nyugalomban (G3)
Nyugodt szakaszban 20–40 mp-enként egy **apró, helyi** meglepetés történik egy véletlen utcán. Példák:
- elszabadult bevásárlókocsi;
- locsoló-szökőkút, ami felrepít (Air delivery-esély);
- autóriasztó, ami libacsapatot ijeszt fel;
- leeső pizzásdoboz-halom, belőle +tip.

Ezek nem szerver-szintű események, nincs bannerük, és nem állítják le a következő eseményt.

### 4.5. Szavazás és káosz-finálé (G5, G6)
- **Szavazás:** a nyugodt szakasz második felében a Plaza táblán 3 esemény közül lehet szavazni (egy érintés, HUD-gomb is). A győztes jön következőnek. A fizetős „Rendelj katasztrófát” továbbra is elsőbbséget kap.
- **Káosz-finálé** 20 percenként: 30 mp-es visszaszámlálás, aztán MEGA két eseménnyel és dupla káosz-mérővel. Előtte HUD-jelzés: „Finálé 3 perc múlva!”, ami maradásra ösztönöz.

## 5. Sorrend (ebben a körben)
1. ✅ **Új események:** Holdséta (#180) → Meteoreső (#181) → Pizzaeső (#182) → UFO-elrablás (#183) → Óriás macska (#184). A macskát etetőtállal lehet jóllakatni: a kézbesítés-alapú cél 30–45 mp alatt teljesíthetetlen volt.
2. ✅ **Rendelés-választó + merész rendelések** (#185): Gyors kör / Hosszú út (×1.3, legjobb a 2 ritkaság-dobásból) / Különleges, esemény alatt VAKMERŐ (×2). Az esemény-bónusz +30%.
3. ✅ **Szavazás + káosz-finálé** (#186): a finálé 20 percenként jön, és a kézbesítőknek +100 tipet ad (a „dupla káosz-mérő” helyett).
4. ✅ **Mikro-káosz** (#187): bevásárlókocsi, libák, locsoló-gejzír, dobozhalom.

5. ✅ **Vakmerő-zóna minden veszélyes eseményhez** (#199): sajtkerék és UFO a pályák mentén; tornádó, meteor és buborék az élő pozíciók körül.
6. ✅ **Esemény-kihívások** (#200): minden eseményhez egy opcionális mini-feladat (+30 tip, HUD-pipa).
7. ✅ **Analitika** (#202): melyik kártyát választják, szavazási részvétel, finálé, mikro-káosz, kihívások.

**Következő ötletek:**
- A kihívás-számláló (`claims["challenges.done"]`) jelenjen meg a futárprofilban, és legyen belőle achievement.
- A finálé végén legyen „a finálé hőse” kiemelés (a legtöbb kézbesítés).
- Hangoljuk a vakmerő-arányt az analitika alapján: ha senki nem választja, ×2.5; ha mindenki, ×1.75.

A hangok és a bolti effektek a Codexé: #188.

## 6. Kockázatok
- **Túl sok szorzó:** a tip-infláció gyorsíthatja a pizzéria-fejlődést. A merész rendelés ×2-je a stílus-cap után jön, ezért a gazdasági szimulátorban (`Util/EconomySimulator`) érdemes újramérni.
- **Mobil teljesítmény:** az új események kliensoldali partokat használnak, Low minőségen limitekkel; a mérés a #172-ben.
- **Olvashatóság:** egyszerre legfeljebb 1 esemény fusson (MEGA-ban 2), és a mikro-káosznak nincs bannere.
