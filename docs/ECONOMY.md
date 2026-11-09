# Gazdasági szimuláció

Generálás: luau tools/economy_sim.luau > docs/ECONOMY.md. Seed: 75083, 30 futás/eset, 12 órás horizont. Ez modell, nem mért játékosadat.

| Játékos | Első fejlesztés | 6. pizzériaszint | Teljes vendégkönyv | Első fejlesztés <3 perc |
|---|---:|---:|---:|---|
| Átlagos | 2.3 perc (30/30) | nem érte el | nem érte el | 30/30 |
| Lelkes | 1.3 perc (30/30) | 674.0 perc (21/30) | nem érte el | 30/30 |
| Költő | 0.0 perc (30/30) | 394.0 perc (30/30) | nem érte el | 30/30 |

## Feltételezések és korlátok

- Átlagos/lelkes:70/40 másodperc/fuvar; hibaarány20%/5%, légi stílus2%/15%. Kezdéskor az első napi jutalom, majd a valódi XP-, könyv- és szintjutalmak. Nincs ingyen pénz kódokból/barátokból.
- December15-i eseménykészlet; átlagos fázishosszak,10 percenként75s MEGA,10 fős közös szerver feltételezés. A vendégsorsolás, szorzók, lejáratok, csillagok és slotok tényleges Config/Util számolása fut.
- A költő DoubleTips passt, egyszeri StarterPackot és egyetlen PizzaScentCloudot kap; a boostok a valódi időben lejárnak. Nincs végtelen Robux-vásárlás.
- A ritka törzsvendégek legjobb termelői automatikusan leülnek és az üveg azonnal begyűlik. Nincs offline szünet, like-, napiheti- vagy óriásrendelés-farm. A pályabejárás/időjárás útvesztése nem fizikai szimuláció.
- Rendelés-választó (#185): a fuvarok 35%-a távoli (legjobb a 2 ritkaság-dobásból, ×1.3 tip, de ×1.4 idő), esemény alatt 30%-a merész (×2); az esemény-bónusz +30%.
- Kör-extrák: az esemény-kihívások 40%-a teljesül (+30); a fináléban 60% kézbesít (+100), ebből 15% a hős (+0).
- A teljes könyv eredménye csak a horizonton belüli teljes futások mediánja; a zárójel megmutatja a cenzorált futásokat, így a táblázat nem ígér garantált teljesítést.

## Hangolási javaslatok

- Az első fejlesztés <3 perc oszlopa közvetlenül ellenőrzi a brief célját; ár helyett először a tényleges onboarding fuvaridőt mérjük.
- A torony és a teljes könyv közötti eltérést zárt teszttel validáljuk; a kapott eredmény önmagában nem indok automatikus ármódosításra.
- Szezonon kívül a Blizzard-vendégek nem húzhatók: a teljes29-es könyv idejét ilyenkor nem szabad végesnek ígérni.
- A CI-futás advisory; Config-változás után ezt a dokumentumot újra kell generálni.
