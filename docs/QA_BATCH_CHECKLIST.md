# `qa-batch` Studio-tesztlista

A `qa-batch` ágon gyűlt, még élesben nem tesztelt rendszerek gyors ellenőrzése. A place a `pizza-claude.rbxlx`, ebből az ágból épül.

**Debug parancsok futtatása** (AGENTS.md 7.):
- a DEV panelen;
- vagy Server contextből: `ServerStorage:SetAttribute("DebugCommand", "<parancs>")`, az eredmény a `DebugResult` attribútumban.

Egy pont akkor kész, ha:
- a várt eredmény látszik;
- és az Outputban nincs hiba vagy warning a mi kódunkból.

## Indulás
- [ ] Play → az Outputban `[Server] Started N services` és `[Client] Started N controllers`, hiba nélkül.

## Második hullám (#207–#227)
| # | Parancs | Várt eredmény |
|---|---|---|
| 207 | `daily select DaredevilCourier` → esemény alatt Daredevil-kézbesítés | A heti progress +1. |
| 208 | `finale now`, kézbesíts a finálé alatt | „FINALE HERO” hint, korona a fej felett. |
| 211 | `tips` | Sorban megjelennek a tipp-kártyák, a „Got it” gomb működik. |
| 217 | `daytime night` (vagy egy fázis) | Sötétedik, a lámpák világítanak, a HUD ikon 🌙; a Blackout alatt szünetel. |
| 218 | `errand call` → `errand grab` → kézbesítés | Oszlop a boltnál, HUD sor, „Errand” ×1.4. |
| 219 | `rush`, `rush bot`, `rush end` | Városi roham HUD (y=212), a cél nő, a jutalom kifizet. |
| 223 | `golden` | Aranydoboz és szikra, ×3; ha közben elütnek: „scuffed” ×2. |
| 224 | — | ⭐ a szavazáson és a táblán a hét katasztrófájánál; a challenge tip duplázódik. |
| 227 | `titles` | A számlálók állása; küszöb elérésekor unlock-hint. |

## Harmadik hullám (#230–#256)
| # | Parancs | Várt eredmény |
|---|---|---|
| 230 | `event WindGust` | Lásd lent: Gale Force. |
| 232 | `convoy`, majd kézbesítés 12 mp-en belül | „🚚 Convoy with Test Courier! +12 tips”; az első alkalommal Convoy tipp. |
| 234 / 248 | Kézbesíts, majd `recap` | Műszak-jelentés kártya; a második `recap`-nál „📈/📉 … vs last round” sor. |
| 236 | `toss` (20 studra az ajtótól), majd F vagy a Toss gomb | Lásd lent: pizza-dobás. |
| 238 | — | Toss tipp a 2. kézbesítés után, Wind tipp a Gale Force elején. |
| 240 | `daily select Yeeter`, majd dobás | A heti progress +1. |
| 242 | `offers rate` | `daredevil x/y picked → ×2`; esemény alatt a kártyán az aktuális szorzó. |
| 244 | `event FloorIsLava` | Lásd lent: The Floor Is Lava. |
| 246 | `highfive`, majd H | „🙌 High five with Test Courier! +5 tips” és 🙌 felvillanás. |
| 251 / 256 | `titles bump loop.toss 50` | Unlock: Yeet Master (ugyanígy `loop.convoy`, `social.highFives`, `story.done`). |
| 254 | `story next`, majd a pultnál a 📖 kártya | Kézbesítéskor a sztori sora; a 3. fejezet után „Story complete” +120. A `story show` mutatja a haladást. |

**Gale Force (#230)**
- [ ] A HUD-nyíl a képernyőn arra mutat, amerre lök.
- [ ] Visszaszámlálás, majd „GUST!”.
- [ ] Ház mögött nincs lökés.
- [ ] Ugrás közben elsodor a szél.
- [ ] Tailwind tag a következő kézbesítésnél.

**Pizza-dobás (#236)**
- [ ] A doboz ívben repül.
- [ ] A kézbesítés „Yeet” taggel jár.
- [ ] Fal mögül: hint.
- [ ] Tortával (fragile): „Cakes don't fly!”.

**The Floor Is Lava (#244)**
- [ ] Narancs izzás, majd láva.
- [ ] Rálépve „Hot feet” felpattanás, de a streak megmarad.
- [ ] Ajtó, pult és spawn környéke sosem láva.
- [ ] Átugorva Lava hopper tag és challenge.

## Teljesítmény (mobil)
- [ ] `event FloorIsLava`: 62 Neon csempe hullámonként, FPS a Perf HUD-on.
- [ ] `event WindGust` Low minőségen: 10 szélcsík.

## Utána
- PR `qa-batch` → `main`, merge.
- A #209, #210, #212, #220, #221 PR-ok lezárása: a tartalmuk már a qa-batch-ben van.
