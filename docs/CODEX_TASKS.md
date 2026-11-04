# Codex feladatcsomag — párhuzamos munka

Ezen a projekten két AI dolgozik egyszerre: **Claude** (játékmenet, Studio-tesztelés) és **Codex** (adat-, bevételi és logikai rendszerek). Ez a fájl mondja meg, ki melyik fájlokhoz nyúlhat, hogy ne írjuk felül egymás munkáját.

Először olvasd el: `AGENTS.md`, `docs/PIZZA_CHAOS_2_GAME_BRIEF.md`.

## 1. Fájltulajdonlás (kötelező)

| Terület | Tulajdonos | Codex nyúlhat hozzá? |
|---|---|---|
| `src/server/Services/{Map,Order,Character,Economy,Onboarding,Event*,Debug}Service.luau` | Claude | **Nem** |
| `src/client/Controllers/*` | Claude | **Nem** |
| `src/shared/Config/{MapLayout,Events,Tuning,Customers}.luau`, `src/shared/Net.luau` | Claude | **Nem** (ha kell bele valami, írd a `docs/HANDOFF.md`-be) |
| `src/shared/Util/{Bootstrap,MapGeometry,OrderLogic,RateLimiter,Validate}.luau` | Claude | **Nem** |
| Az alábbi feladatok **új** fájljai | Codex | Igen |
| `tests/run.luau` | közös | Csak **új teszteket fűzz hozzá** a fájl végére, a `print(... passed ...)` sor elé |
| `.github/workflows/ci.yml` | Codex | Igen (C6) |
| `docs/HANDOFF.md` | közös | Igen, ide írd, mit csináltál, és mit kérsz Claude-tól |

Szabályok:
- A `Services/` mappába tett új modult a Bootstrap **automatikusan elindítja** a Studióban. Ezért a modulod indulása soha ne dobjon hibát. Ha valami hiányzik (pl. Studióban nincs DataStore-hozzáférés), írj egyetlen `warn`-t, és működj mock módban.
- A tiszta logika a `src/shared/Util/` alá kerül, Roblox API nélkül, tesztekkel a `tests/run.luau`-ban (`luau tests/run.luau`).
- Commit előtt: `stylua src tests && selene src && luau tests/run.luau && rojo build -o build.rbxlx`.
- Ha egy Claude-fájlba bele kellene nyúlnod, ne tedd. Írd le a `docs/HANDOFF.md`-be, hogy mit és miért, és Claude beköti.

## 2. Feladatok (sorrendben)

### C1 — Profil-séma és migrációk (tiszta logika)
**Fájlok:** `src/shared/Util/ProfileSchema.luau`, tesztek.
- `ProfileSchema.VERSION`, `ProfileSchema.default(): Profile`, `ProfileSchema.migrate(raw: any): Profile` (régebbi vagy hiányos adatból mindig érvényes, aktuális profil lesz).
- Mezők (v1): `tips`, `xp`, `deliveries`, `customerBook: {[customerId]: {served: number, stars: number}}`, `pizzeriaLevel` (1–6), `regulars: {customerId}`, `movementTier` (0–4), `cosmetics: {owned: {[id]: true}, equipped: {[slot]: id}}`, `purchases: {[purchaseId]: number}` (feldolgozott vásárlások), `lastSeen` (unix idő), `dailyLogin: {day: number, lastClaim: number}`.
- Típus az exporttal: `export type Profile`.
- **Elfogadás:** ismeretlen és hibás mezők (NaN, negatív, rossz típus) javítva vagy eldobva; v0 (üres tábla) → v1; 15+ teszt.

### C2 — DataService (perzisztencia)
**Fájl:** `src/server/Services/DataService.luau` (+ ha kell: `wally.toml` ProfileStore, `Packages/` a `default.project.json`-ban; ezt a HANDOFF-ba írd, mert a project.json Claude-é).
- Session lock, autosave (60 mp), `BindToClose`, újrapróbálkozás visszalépéssel.
- API: `DataService.getProfile(player): Profile?`, `DataService.onLoaded(callback)`, `DataService.update(player, fn)`, `DataService.isLoaded(player)`.
- Studióban, ha nincs API-hozzáférés: memória-mock és egy `warn`.
- Debug parancsok a `DebugService.register`-rel: `profile` (kiírja), `wipe` (alapértékre állít).
- **Elfogadás:** gyors újracsatlakozás nem duplikál és nem veszít adatot; a migráció a C1-et használja.
- Az EconomyService-be **Claude** köti be (HANDOFF).

### C3 — Vendégsorsolás esélyei (tiszta logika)
**Fájl:** `src/shared/Util/CustomerOdds.luau`, tesztek.
- `CustomerOdds.rollRarity(table: "normal"|"event"|"mega", rarities, modifiers, rng): RarityId`, ahol a `modifiers` mezői: `rarePlusMultiplier` (pizzaillat ×2), `pizzeriaLevelBonus`.
- `CustomerOdds.pickCustomer(customers, rarity, eventId?, rng): customerId`. Ha az adott ritkaságban nincs vendég, essen vissza a legközelebbi alacsonyabb ritkaságra.
- `CustomerOdds.describe(...)`: az esélyek százalékban, a bolt kijelzéséhez (a brief 9.2 szerint kötelező).
- **Elfogadás:** 10 000 szimulált húzás eloszlása ±1%-on belül egyezik a Configgal; a módosítók összege mindig 100%.

### C4 — Haladás és passzív borravaló (tiszta logika)
**Fájlok:** `src/shared/Config/Progression.luau` (új), `src/shared/Util/Progression.luau`, tesztek.
- Futárszint-görbe (az első órában 5–8 szint), `levelFromXp`, `xpForLevel`.
- Passzív borravaló percenként: `alap × ritkasági szorzó × (1 + 0,2 × csillag)` (brief 10. fejezet).
- Offline termelés: legfeljebb 2 óra, 50% (gamepass-szal 8 óra, 100%), visszaadja az összeget és a figyelembe vett időt; óraállítás elleni védelem (negatív vagy túl nagy időköz → 0, illetve a korlát).
- `Progression.canUpgradePizzeria(level, tips)`, `Progression.regularSlots(level, hasPass)`.
- **Elfogadás:** határesetek tesztelve (0 perc, 1 év, negatív idő, 5 csillag).

### C5 — MonetizationService
**Fájlok:** `src/server/Services/MonetizationService.luau`, `src/shared/Util/ReceiptLedger.luau` (tiszta), tesztek.
- Gamepass-tulajdon gyorsítótárazva, a `Config/Products` alapján; az `id = 0` „még nem elérhető”.
- `ProcessReceipt` idempotens: a `PurchaseId` a profilba kerül (C2), mentés után `PurchaseGranted`; ismeretlen termék → `NotProcessedYet` és `warn`.
- API: `MonetizationService.registerProduct(key, handler(player) -> boolean)`, `MonetizationService.ownsPass(player, key)`, `MonetizationService.onPassChanged(callback)`.
- A termékek hatásait (boost, katasztrófarendelés) **Claude** köti be.
- **Elfogadás:** ugyanaz a receipt kétszer nem ad kétszer; szerverösszeomlás utáni újrafeldolgozás egyszer teljesít (ledger-teszttel).

### C6 — Típusellenőrzés a CI-ban
**Fájl:** `.github/workflows/ci.yml`.
- `luau-lsp analyze` Roblox-definíciókkal és `rojo sourcemap`-pel (a GitHub runnernek van internete a definíciók letöltéséhez).
- Először csak figyelmeztessen (`continue-on-error`); a valódi hibákat írd a HANDOFF-ba.

### C7 — AnalyticsService burkoló
**Fájl:** `src/server/Services/AnalyticsService.luau`.
- `funnel(player, step)`, `economy(player, flow, amount, item, reason)`, `custom(player, name, value?)`; Roblox AnalyticsService, `pcall`-lal; Studióban konzolra is naplóz.
- Funnel-lépések a brief 22.2 szerint. A meghívásokat a játékmenetbe **Claude** teszi be.

## 3. Átadás

Minden feladat végén:
1. Írd a `docs/HANDOFF.md` végére: feladat-azonosító, új fájlok, publikus API, mit kell Claude-nak bekötnie, mit nem teszteltél.
2. Futtasd az ellenőrzéseket (1. fejezet).

Amíg nincs GitHub-repó, a közös mappán dolgozunk (`~/Desktop/another_roblox_idea/pizza-chaos`). A te fájljaidat Claude onnan veszi át a saját git-történetébe. Ezért **csak a saját fájljaidat** módosítsd.

---

# 2. kör (C8–C13) — 2026-11-04

A C1–C7 kész, köszi! A tulajdonlási szabályok változatlanok. Új Codex-fájlok: a lenti feladatok fájljai, valamint **két új kliens-controller** (C9, C10). A `Net.luau`-ba Claude már felvette a szükséges remote-okat:
`GetCustomerBook` (RemoteFunction), `GetShop` (RemoteFunction), `CustomerBookUpdated` (S→C), `RequestPurchase` (C→S), `PurchaseResult` (S→C).

### C8 — ProfileSchema v2 (migráció v1 → v2)
**Fájl:** `src/shared/Util/ProfileSchema.luau` (+ tesztek).
Új mezők:
- `boosts: {[key]: expiresAtUnix}`
- `pendingEffects: { {id: string, kind: string, key: string, createdAt: number} }` (outbox a vásárolt világhatásokhoz, max 20)
- `sessions: {count: number, lastDay: number}`
- `onboardingDone: boolean`
- `settings: {music: number, sfx: number, effects: "low"|"normal"}`

**Elfogadás:** a v1-ből veszteség nélkül v2 lesz; a hibás adat javítva; az eddigi tesztek is zöldek.

### C9 — Vendégkönyv UI (kliens)
**Fájl:** `src/client/Controllers/CustomerBookController.luau` (új, Codexé).
- **Megnyitó gomb:** saját ScreenGui, bal felső sarok, `Position = UDim2.fromOffset(12, 64)`, mérete legalább 110×44, felirat „📖 Book”.
- **Adat:** `Net.func("GetCustomerBook"):InvokeServer()` → `{ total: number, discovered: number, customers: { {id, name, rarity, event: string?, served: number, stars: number, known: boolean, hint: string} } }`. Ha `known = false`, a neve `"???"`, és sziluettet/tippet mutass. A `CustomerBookUpdated` eseményre (payload: `{id, isNew}`) frissíts. Új vendégnél villanjon meg a gomb.
- **Megjelenés:** rács, ritkaság szerint színezve (`Config/Rarities.colorHex`), haladás „x / total”, a csillagok kijelezve. Mobilon görgethető és olvasható.
- A szerveroldalt (`GetCustomerBook`, `CustomerBookUpdated`) **Claude** írja.

### C10 — Bolt UI + vásárlás-kezelés
**Fájlok:** `src/client/Controllers/ShopController.luau` (új), valamint bővítés a `MonetizationService.luau`-ban (Codexé).
- **Szerver:** `GetShop` → `{ gamepasses: {...{key, name, price, owned, available}}, products: {...{key, name, price, available, odds: {[rarity]: percent}?}} }`. Az `odds` csak a `changesOdds` termékeknél jelenjen meg, a `CustomerOdds.describe` alapján.
- **Szerver:** `RequestPurchase(key)` → validálás (string, ismert key, `id ~= 0`). Tiltott, ha a játékos `OnboardingStep` attribútuma nem `"done"`, vagy ha a `ReplicatedStorage.CityState` `EventPhase` értéke `"warning"|"buildUp"|"active"` (AGENTS 4.7). Ha szabad: `MarketplaceService:PromptProductPurchase`/`PromptGamePassPurchase`. Elutasításnál `PurchaseResult(false, reason)`.
- **Kliens:** megnyitó gomb a bal felső sarokban, a Book alatt (`(12, 116)`), fülekkel: Passes, Boosts, Tips. Az esélyeket is mutasd. Tiltott állapotban a gomb ne kínáljon vásárlást (szürke), és írja ki az okát.

### C11 — Stílus-kézbesítés és káosz-mérő logika (tiszta)
**Fájlok:** `src/shared/Util/StyleLogic.luau`, `src/shared/Util/ChaosMeterLogic.luau`, `src/shared/Config/Style.luau` (+ tesztek).
- **StyleLogic:** `evaluate(facts) -> { tags: {string}, bonus: number }`. A `facts` mezői: `airborne`, `secondsSinceSharkZone`, `secondsSinceHorseLane`, `hadAccident`, `seconds`, `targetSeconds`, `giantOrderClean`. A címkéket és az értékeket a brief 14. fejezete adja; a bónusz összeg felső korlátja `Tuning.Style.maxTotalBonus` (paraméterként add át).
- **ChaosMeterLogic:** `new(config)`, `addDelivery(state, duringEvent)`, `isFull`, `reset`, és a cél-töltési arány a játékosszám alapján (8–12 perc egy 8–12 fős szerveren). Tisztán, időt injektálva.

### C12 — Napi bejelentkezés és heti kihívások (tiszta)
**Fájlok:** `src/shared/Config/DailyRewards.luau`, `src/shared/Util/DailyLogin.luau`, `src/shared/Util/WeeklyChallenges.luau` (+ tesztek).
- **Napi naptár:** 7 nap, a kihagyás nem nullázza; UTC napváltás; óraállítás elleni védelem; `claim(profilePart, nowUnix) -> (reward?, newState)`.
- **Heti kihívások:** 3 választható feladat a Configból, haladás-számlálás eseményekből (`delivery`, `eventDelivery`, `newCustomer`), hétváltás.

### C13 — Sessionszámlálás és `second_session` funnel
**Fájl:** a `DataService.luau`-ban vagy egy új kis modulban.
- A profil `sessions` mezője (C8) alapján: belépéskor `count += 1`. Ha a mentett adatból ez a második session, `AnalyticsService.funnel(player, "second_session")`. Az `onLoaded`-ba kösd, és tedd idempotenssé.

Átadás ugyanúgy: a `docs/HANDOFF.md` végére.
