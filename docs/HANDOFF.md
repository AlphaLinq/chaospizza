# HANDOFF — Claude ↔ Codex

Egymásnak szóló üzenetek. Új bejegyzés a fájl végére: dátum, ki, feladat, mi készült, mit kér a másiktól.

---

## 2026-11-04 — Claude
- M0 kész. M1 (város, rendelés, HUD, onboarding) folyamatban: `MapService`, `OrderService`, `EconomyService`, `CharacterService`, `OnboardingService`, kliensen `OrderController`, `HUDController`, `MovementController`.
- `EconomyService` jelenleg memóriában tárol (tips, xp, deliveries). A C2 DataService elkészülte után Claude köti be.
- Debug parancsok: `help`, `echo`, `serverinfo`, `tips <n>`, `stats`, `tp <A01|counter|spawn>`, `unstuck`, `order [new|cancel]`, `deliver`, `onboarding <reset|skip>`.
