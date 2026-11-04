# 🍕 PIZZA CHAOS

> **Vidd ki a pizzát. Bármi történik. És gyűjtsd össze a város legfurább vendégeit.**

Roblox-játék (Luau + Rojo), egyszemélyes fejlesztés AI-segítséggel.

A játékos pizzafutár egy városban, ahol pár percenként tornádó, cápás áradás vagy váratlan lóverseny forgatja fel az utcákat. A rendelések fura vendégekhez szólnak. A ritkák beülnek a saját pizzériádba, borravalót termelnek, a pizzéria pedig büfékocsiból neon toronnyá nő.

## Dokumentumok

| Dokumentum | Mi ez |
|---|---|
| [docs/PIZZA_CHAOS_2_GAME_BRIEF.md](docs/PIZZA_CHAOS_2_GAME_BRIEF.md) | **Az aktuális, irányadó játékterv (2.0)** |
| [docs/BACKLOG.md](docs/BACKLOG.md) | Ticketek áttekintése mérföldkövenként |
| [docs/PIZZA_CHAOS_GAME_BRIEF.md](docs/PIZZA_CHAOS_GAME_BRIEF.md) | 1.0 terv: az események részletes leírása, alapelvek |
| [docs/NEON_RUSH_GAME_BRIEF.md](docs/NEON_RUSH_GAME_BRIEF.md) | Tartalék ötlet (archív) |
| [docs/NEON_RUSH_ESTIMATION.md](docs/NEON_RUSH_ESTIMATION.md) | A bevételi modell logikája (archív) |

## Munkamód

- Minden munka egy GitHub issue-hoz tartozik, mérföldkövekre (M0–M9) bontva.
- Egy issue = egy branch = egy PR (`Closes #<szám>`).
- Az AI-fejlesztőnek szóló prompt a 2.0 brief 26. fejezetében található.

## Backlog újragenerálása

```bash
python3 tools/create_backlog.py --markdown docs/BACKLOG.md          # áttekintő
python3 tools/create_backlog.py --repo OWNER/pizza-chaos --dry-run  # előnézet
python3 tools/create_backlog.py --repo OWNER/pizza-chaos            # issue-k létrehozása (gh CLI kell)
```

## Fejlesztés indítása

A Rojo projektstruktúrát az **M0** mérföldkő első ticketje hozza létre. Utána itt lesz a `rojo serve` útmutató.
