# Dig Down / 地下鼠鼠 — Project Documentation Pack v1.0

> **Implementation status (2026-08-30):** The full campaign arc (Phases 12–15) is implemented and the campaign is completable: Phase 12 settings/playtest support (GO recorded), Phase 13 chapter progression + authored worldgen, Phase 14 water × instability + chapter 2 content, Phase 15 old-burrow prefab mutations (two_room_sealed / collapsed_wing / triple_nest), buried-landmark discovery reveals, spatial-storytelling relic dressing, and campaign completion via a warm-chamber sleeping home (GDD §14) with post-completion sandbox. 1179/1179 automated assertions pass under `tools/validate.ps1`; the 288-seed batch holds 100% raw validity at p95 ~440 ms. Remaining: Phase 16 full-game balance & polish and a PM playthrough of the complete campaign.

This repository is the implementation authority for a 2D underground mouse-colony systemic sandbox built around one dominant verb: **DIG**.

## Product statement
The player can excavate any legal underground tile. The game does not present artificial route choices; instead, terrain signals, value, risk, excavation cost, and topology make different directions meaningfully unequal. Each important discovery changes how the colony can use space, so the resulting burrow becomes a record of the player's decisions and accidents.

## Recommended reading order for Codex
1. `AGENTS.md`
2. `docs/product/00_DECISION_REGISTER.md`
3. `docs/product/01_PRODUCT_VISION.md`
4. `docs/design/02_GDD.md`
5. `docs/design/03_CORE_LOOP_PROGRESSION.md`
6. `docs/world/04_WORLD_STRUCTURE_AND_CHAPTERS.md`
7. `docs/world/05_WORLD_GENERATION_SPEC.md`
8. `docs/systems/06_TERRAIN_DIGGING_SPEC.md`
9. `docs/systems/07_DISCOVERY_SIGNAL_SPEC.md`
10. `docs/systems/08_WATER_ENVIRONMENT_SPEC.md`
11. `docs/systems/09_STABILITY_COLLAPSE_SPEC.md`
12. `docs/systems/10_COLONY_ROOMS_AI_SPEC.md`
13. `docs/ux/11_UI_UX_SPEC.md`
14. `docs/art/12_ART_BIBLE.md`
15. `docs/art/13_AUDIO_VFX_SPEC.md`
16. `docs/tech/14_TECH_ARCHITECTURE.md`
17. `docs/tech/15_DATA_SAVE_SPEC.md`
18. `docs/tech/16_PERFORMANCE_BUDGET.md`
19. `docs/qa/17_TEST_QA_PLAN.md`
20. `docs/qa/18_VERTICAL_SLICE_ACCEPTANCE.md`
21. `docs/production/19_IMPLEMENTATION_ROADMAP.md`
22. `docs/production/20_CONTENT_AUTHORING_GUIDE.md`
23. `docs/production/21_BALANCE_TELEMETRY.md`
24. `docs/production/22_RISK_REGISTER.md`

## Status vocabulary
Each spec uses one of these statuses:
- **LOCKED** — must not be changed implicitly.
- **PROVISIONAL** — implementation default; may be tuned without changing the concept.
- **DEFERRED** — intentionally outside the current release.
- **OPEN** — a decision remains for playtesting.

## Build strategy
The project is deliberately developed in layers:
1. **Simulation foundation** — grid, terrain, digging, pathing, mouse jobs.
2. **Vertical Slice** — root, water, unstable soil; 30–45 minute playable chapter.
3. **Chapter 1: Settle** — complete onboarding and basic colony loop.
4. **Chapter 2: Adapt** — stronger environmental interactions and foundation structures.
5. **Chapter 3: Old Burrow** — existing spaces, historical traces, endgame goal.
6. **Polish and content expansion** — only after the core decision loop proves fun.

## Definition of success
The project succeeds when players repeatedly experience:
> “I can dig anywhere, but I care where I dig next.”

The world should make players pause, infer, commit, react, and then incorporate the consequence into the home they are building.
