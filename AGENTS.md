# AGENTS.md — Pizza Chaos

Instructions for AI coding agents (Codex, Claude Code, others) working in this repository.
Read this file fully before starting any task. Project docs and issues are in **Hungarian**; code, identifiers and code comments are in **English**.

## 1. What this project is

**Pizza Chaos** is a Roblox game (Luau, managed with Rojo). The player is a pizza courier in a small shared city where absurd disasters (horse race, tornado, shark flood, later blizzard) hit the server every few minutes. Orders go to weird **customers** with rarities; rare ones become **regulars** in the player's own **pizzeria** on the shared plaza and produce passive tips. The pizzeria grows from a food cart to a neon tower.

- **Source of truth for design:** `docs/PIZZA_CHAOS_2_GAME_BRIEF.md` (v2.0). Background/event details: `docs/PIZZA_CHAOS_GAME_BRIEF.md` (v1.0). If they conflict, v2.0 wins.
- **Work tracking:** GitHub issues, grouped in milestones M0–M9. Overview: `docs/BACKLOG.md`, source: `tools/backlog.py`.
- Solo developer + AI. Primary target platform: **mobile**. Secondary: PC, console, tablet.

## 2. How to pick up work

1. Work on **one issue at a time**. Read the issue, its acceptance criteria (`Elfogadási feltételek`) and the brief chapter it references.
2. Branch: `m<milestone>/<issue-number>-<short-slug>` (e.g. `m1/7-order-service`).
3. Implement only what the issue asks. Do not pre-build systems from later milestones; leave a clear extension point instead.
4. Verify (section 8). Tick the acceptance criteria you actually verified.
5. Commit with a short imperative message and open a PR using `.github/pull_request_template.md`, with `Closes #<n>`. List what you tested and **what remains unverified**.
6. If something blocks you (missing asset, missing decision), say so in the PR/issue instead of guessing silently. Make ordinary implementation decisions yourself, following the brief.

## 3. Repository layout

```text
default.project.json      Rojo project (maps src/ into the DataModel)
rokit.toml                Pinned tool versions (rojo, stylua, selene)
src/
  server/                 → ServerScriptService.Server (the only Script)
    init.server.luau      Net.setupServer(), then Bootstrap.run(Services)
    Services/             One ModuleScript per server system (DebugService, OrderService, …)
  client/                 → StarterPlayer.StarterPlayerScripts.Client (the only LocalScript)
    init.client.luau      Bootstrap.run(Controllers)
    Controllers/          One ModuleScript per client system (DebugController, HUDController, …)
  shared/                 → ReplicatedStorage.Shared (readable by clients: nothing secret)
    Config/               ALL tunable numbers and content tables (pure data)
    Types.luau            Shared type definitions
    Net.luau              Remote registry (the only place remotes are created)
    Util/                 Bootstrap + pure helpers (RateLimiter, Validate, …)
tests/run.luau            Pure-logic and config tests (Luau CLI)
docs/                     Design docs (Hungarian)
tools/                    Backlog tooling (Python)
```

Map, models and other non-script assets live in the Studio place (`.rbxl`, not committed) until a ticket says otherwise. Anything code depends on must be found by **CollectionService tags or named folders**, never by fragile paths like `workspace.Model.Part3`.

## 4. Architecture rules (non-negotiable)

### 4.1 Server authority
- Anything that touches **money (tips), XP, customers, Customer Book, regulars, pizzeria level, movement level, cosmetics ownership, purchases, event state, chaos meter**: decided and stored **only on the server**.
- The client sends **intent** ("I want to pick up", "I want to deliver"), never results ("give me 50 tips").
- Every remote handler: rate-limited (`Util/RateLimiter`), arguments type-checked (`Util/Validate`), never trusts client positions blindly (check distance server-side).
- Rewards are **idempotent**: one order = one reward, even if the request is repeated.

### 4.2 Services and controllers
- Each service/controller is a ModuleScript returning a table with optional plain functions `init()` and `start()` (no `self`). The loader is `src/shared/Util/Bootstrap.luau`: it requires all modules sorted by name, runs every `init()`, then every `start()` in its own thread.
  - `init()`: synchronous wiring, register debug commands, no yielding, no calls into other services' runtime behaviour.
  - `start()`: connect remotes/events, start loops. Other services may be used here.
- Services get each other with `require(script.Parent.OtherService)`. Never use `_G` or `shared`.
- Cross-service notifications: expose a signal/callback on the module instead of reaching into another service's internals. Avoid require cycles.
- Keep services small and single-purpose. If a file passes ~400 lines, split it.
- Pure logic (formulas, odds, economy math, validation) goes in `src/shared/Util/` with **no Roblox APIs and no `script` requires**, randomness injected as a function, so `tests/run.luau` can test it outside Roblox.
- Every new gameplay system also registers its **debug commands** via `DebugService.register(...)` (QA must be able to reach its states in seconds), and those handlers call the same service APIs as real gameplay.

### 4.3 Configuration
- Every tunable number (speeds, timings, prices, odds, rewards, costs) goes in `src/shared/Config/*`. No magic numbers in services.
- Content (customers, events, pizzeria levels, products) is data in Config; code reads it.
- Robux prices and gamepass/product IDs live in `Config/Products.luau`. Never hardcode IDs elsewhere.

### 4.4 Networking
- Remotes are created only through `Shared/Net.luau` (`Net.event(name)`, `Net.func(name)`). Names are declared in `Net.Remotes`.
- Prefer `RemoteEvent`. Use `RemoteFunction` only for client→server requests that need an answer; **never** invoke the client from the server.
- Replicate shared state (current event, chaos meter) with attributes or a single state remote, not with many small remotes.

### 4.5 Data
- Persistent player data only via `DataService` (session-locked, versioned schema with migrations). Never call `DataStoreService` directly from other services.
- Purchases: `ProcessReceipt` must be idempotent (record `PurchaseId` in the profile, save, then return `PurchaseGranted`).

### 4.6 Events (disasters)
- Every event follows: **warning → build-up → active → wind-down → reset**.
- Every event must fully clean up (temporary parts, tweens, character effects) and leave every delivery address reachable.
- A player joining mid-event receives the current state and spawns in a safe spot.

### 4.7 Monetization rules (from brief ch. 18)
- No paid immunity, no paid advantage against other players, nothing that targets another player.
- Any product that changes odds must show the odds in the UI.
- No purchase prompts during active events or in the first 3 minutes of a new player's first session.

### 4.8 Mobile first
- Big touch targets, no UI covering jump surfaces, effect-quality setting, limited particles/parts during events.
- Important sounds always have a visual equivalent.

## 5. Code style

- Luau, files end in `.luau`. Use `--!strict` in every new module unless there is a concrete reason not to (then use `--!nonstrict` and say why in a comment).
- Formatting: **StyLua** (`stylua.toml`). Linting: **Selene** (`selene.toml`, Roblox std). CI fails on either.
- Naming: `PascalCase` for modules, services, types; `camelCase` for locals and functions; `UPPER_SNAKE` for true constants.
- Get services with `game:GetService(...)` at the top of the file.
- Types: put shared types in `src/shared/Types.luau`; local types at the top of the module.
- Avoid `wait`, `spawn`, `delay` — use `task.wait`, `task.spawn`, `task.delay`.
- Clean up connections (`:Disconnect()`), instances (`:Destroy()`) and threads you create.
- Comments explain *why*, not *what*. Player-facing text: English for now (localization later), short and funny.

## 6. Commands

Tools are pinned in `rokit.toml`. Install once: `rokit install`.

```bash
rojo serve                     # live-sync into Studio (Rojo plugin → Connect)
rojo build -o build.rbxlx      # build a place file (CI uses this as a compile check)
stylua src tests               # format
stylua --check src tests       # format check (CI)
selene src                     # lint (CI, Roblox std)
luau tests/run.luau            # pure-logic + config tests (CI); needs the Luau CLI
python3 tools/create_backlog.py --markdown docs/BACKLOG.md   # regenerate backlog overview
```

Before every commit: `stylua src tests && selene src && luau tests/run.luau && rojo build -o build.rbxlx`.

When you add a config table or pure util, add its checks to `tests/run.luau`.

Type checking: Studio's Script Analysis (or luau-lsp with Roblox definitions) is the type checker; it is not in CI yet. When the Studio MCP is connected, check Script Analysis / the Output for type warnings in files you changed.

Packages: no Wally packages yet. `wally.toml` exists for the planned ProfileStore (M5); add a package only when an issue asks for it.

## 7. Roblox Studio MCP (live testing)

Roblox Studio exposes a built-in MCP server (Assistant → … → Manage MCP Servers → *Enable Studio as MCP server*; Codex/Claude via Quick connect). When it is connected, **use it to verify your work in the real engine** instead of claiming it works.

Typical loop:
1. Make sure `rojo serve` is running and the Rojo plugin in Studio is connected, so Studio has your latest code. If Rojo is not running and you cannot start it, load the code with `python3 tools/gen_studio_sync.py > /tmp/sync.luau` and run that snippet through the MCP `execute_luau` tool in **Edit** mode (it mirrors `default.project.json`; Rojo overwrites the same instances later). Say in the PR which way you synced.
2. Check Studio state; stop any running playtest.
3. Start a playtest.
4. Read the **console output**: the bootstrap prints `[Server] Started N services` / `[Client] Started N controllers`. Any error or warning from our code is a failure.
5. Use player-input simulation (movement, keys) to exercise the feature. To reach a game state, use the **debug commands** (the DEV panel, or fire `ReplicatedStorage.Remotes.DebugRun` with a command name from the Client context; if the MCP thread may not fire remotes, set the Studio-only `ServerStorage` attribute `DebugCommand` to a command line from the Server context and read `DebugResult`) — not `require()` from the command bar/Edit context, which may create a separate module instance and not touch the running game. Running Luau in the Server/Client context to inspect **instances and attributes** is fine; to read a service's internal state, add a debug command that prints it.
6. Take a screenshot when UI or visuals are part of the acceptance criteria.
7. Stop the playtest. Summarize what you verified in the PR.

Rules for the Studio MCP:
- Do **not** edit scripts inside Studio that are managed by Rojo — change the files in `src/`; Rojo syncs them. Editing in Studio gets overwritten.
- You may create or edit **non-script** instances in Studio (map parts, folders, tags) when a ticket requires it. Describe exactly what you changed, because the `.rbxl` place is not in Git. Prefer creating map content from code or saving it as a model file under `assets/` if the ticket allows.
- Never publish the place, change game settings, or create/modify products or gamepasses from the MCP unless the issue explicitly asks.
- Multi-client tests (2+ players) may not be possible through the MCP; if not, state it and describe a manual test (Studio → Test → Clients and Servers).

## 8. Definition of done

- [ ] Acceptance criteria of the issue met and ticked (only those actually verified).
- [ ] `stylua --check src tests`, `selene src`, `luau tests/run.luau` and `rojo build` pass.
- [ ] Verified in Studio via MCP (or a clear note why not and what a human should check).
- [ ] No new errors/warnings in the console.
- [ ] New tunables are in `Config/`.
- [ ] Server-authority rules respected for anything gameplay- or money-related.
- [ ] Mobile considered (touch controls, UI size, performance).
- [ ] PR describes what was tested and what remains unverified.

## 9. Do not

- Do not add stealing, pet eggs, or "Steal a …" style mechanics/naming — this game is intentionally different (brief ch. 1).
- Do not add pay-to-win, paid immunity, or purchases that hurt other players.
- Do not introduce new frameworks (Knit, Fusion, React-lua, Wally packages) without an issue that asks for it. Plain Luau modules first.
- Do not commit `.rbxl/.rbxlx` files, secrets, API keys, or Open Cloud credentials.
- Do not change `docs/PIZZA_CHAOS_2_GAME_BRIEF.md` design decisions on your own; propose changes in the PR/issue.
