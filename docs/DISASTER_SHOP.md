# Eseményválasztó a boltban

A Chaos fülön külön gomb választja a lóversenyt, tornádót vagy cápás áradást; a hóvihar csak a Config/Events szerinti UTC-szezonban látszik. A MEGA is ide került. A gomb alatti sor a szerver canOrder ellenőrzésének elutasítását mutatja, teli sornál és készülő/futó MEGA-nál is. A nyitott panel másodpercenként frissíti a kapukat; változatlan tartalomnál megőrzi a gombokat és a gamepad fókuszt.

A választás négy külön developer-product kulcshoz tartozik: DisasterHorseRace, DisasterTornado, DisasterFlood, DisasterBlizzard. Mindegyik productId-ja továbbra0. A Creator Hubban külön, egyedi ID szükséges mindegyikhez. Egyetlen közös productId melletti módosítható „utolsó választás” nem kötné biztonságosan a késleltetett receiptet a megvásárolt eseményhez.

A receipt alapján választott Config-definíció eventId-ja a tartós pendingEffectbe kerül, migráció/reconnect után is megmarad. A publikus peekPending kompatibilis OrderDisaster key-t és a konkrét eventId-t adja a meglévő DisasterOrderService-nek; a tárolt productKey megkülönbözteti az eseményeket. A régi OrderDisaster definíció a régi Tornado-nyugtákhoz megmarad, a katalógusban rejtett. Már kifizetett effektet nem törlünk a pillanatnyi sor/szezon alapján: a meglévő pump később próbálja, és csak az esemény indulásakor nyugtázza.

Élesítés előtt a pozitív ID-k jogosultsági/nyugta/reconnect tesztje és a szezonhatár után beérkező fizetett hóvihar teljesítési szabálya külön ellenőrzendő. A jelenlegi EventService.canOrder szezonon kívül a kifizetett hóvihart is várakoztatja; ezt a #50 éles fizetési elfogadásánál rendezni kell. Ebben a körben nincs éles vásárlás vagy ID-engedélyezés.
