# 🍕 PIZZA CHAOS

> **Vidd ki a pizzát. Bármi történik. És gyűjtsd össze a város legfurább vendégeit.**

Roblox-játék (Luau + Rojo), egyszemélyes fejlesztés AI-segítséggel (Codex / Claude).

A játékos pizzafutár egy városban, ahol pár percenként tornádó, cápás áradás vagy váratlan lóverseny forgatja fel az utcákat. A rendelések fura vendégekhez szólnak. A ritkák beülnek a saját pizzériádba, borravalót termelnek, a pizzéria pedig büfékocsiból neon toronnyá nő.

## Dokumentumok

| Dokumentum | Mi ez |
|---|---|
| [AGENTS.md](AGENTS.md) | **Szabályok az AI-fejlesztőnek** (Codex, Claude). A [CLAUDE.md](CLAUDE.md) erre hivatkozik |
| [docs/PIZZA_CHAOS_2_GAME_BRIEF.md](docs/PIZZA_CHAOS_2_GAME_BRIEF.md) | **Az aktuális, irányadó játékterv (2.0)** |
| [docs/BACKLOG.md](docs/BACKLOG.md) | Ticketek áttekintése mérföldkövenként |
| [docs/PIZZA_CHAOS_GAME_BRIEF.md](docs/PIZZA_CHAOS_GAME_BRIEF.md) | 1.0 terv: események részletes leírása, alapelvek |
| [docs/NEON_RUSH_GAME_BRIEF.md](docs/NEON_RUSH_GAME_BRIEF.md) | Tartalék ötlet (archív) |
| [docs/NEON_RUSH_ESTIMATION.md](docs/NEON_RUSH_ESTIMATION.md) | A bevételi modell logikája (archív) |

## Fejlesztés indítása (Mac)

1. **Rokit** (eszközkezelő) telepítése, egyszer:
   ```bash
   curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
   ```
   Nyiss új terminált, majd a projekt mappájában:
   ```bash
   rokit install          # rojo, stylua, selene a rokit.toml szerint
   rojo plugin install    # Rojo plugin a Roblox Studióba
   ```
2. Hozz létre Studióban egy üres place-t (*Baseplate*), és mentsd el a projekt mappájába `PizzaChaos.rbxl` néven (nem kerül Gitbe).
3. Indítsd el a szinkront:
   ```bash
   rojo serve
   ```
4. Studióban: **Plugins → Rojo → Connect**. A `src/` tartalma megjelenik a ReplicatedStorage / ServerScriptService / StarterPlayerScripts alatt.
5. **Play** → az Outputban ezt kell látnod:
   ```text
   [Server] Started 1 services
   [Client] Started 1 controllers
   ```
   Bal oldalt megjelenik egy piros **DEV** gomb (csak Studióban, illetve az engedélyezett fiókoknak). Próbáld ki: `help`, `echo szia`, `serverinfo`.

### Roblox Studio MCP + Codex

Studio: **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**, majd *Quick connect → Codex*. Így a Codex el tudja indítani a playtestet, olvassa a konzolt és képernyőképet készít. A részleteket az [AGENTS.md](AGENTS.md) 7. fejezete írja le.

### Ellenőrzések (a CI is ezeket futtatja)

```bash
stylua src tests && selene src && rojo build -o build.rbxlx
luau tests/run.luau     # Luau CLI kell hozzá: github.com/luau-lang/luau/releases
```

## Munkamód

- Minden munka egy GitHub issue-hoz tartozik, mérföldkövekre bontva (M0–M9).
- Egy issue = egy branch = egy PR (`Closes #<szám>`).
- A saját fiókod UserId-jét a `src/server/Services/DebugService.luau` `DEV_USER_IDS` listájába írd, ha élő szerveren is kell a DEV panel.

## Backlog

```bash
python3 tools/create_backlog.py --markdown docs/BACKLOG.md          # áttekintő újragenerálása
python3 tools/create_backlog.py --repo OWNER/pizza-chaos --dry-run  # előnézet
python3 tools/create_backlog.py --repo OWNER/pizza-chaos            # issue-k létrehozása (gh CLI)
```
