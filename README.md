# Dig Down / 地下鼠鼠 — Project Documentation Pack v1.0

> **Implementation status (2026-08-25):** Phase 8 Stability engineering is implemented; Phase 6's external naive-player Root cue-readability gate remains open. The finite 96×72 world now supports local span stability with four warning bands, bounded-radius collapse into legible rubble, autonomous material-funded reinforcement, root/stone local supports, mouse danger avoidance, and consistent topology/zone/item reactions. Phase 7 water, Phase 6 root, and Art Pass 01 production terrain (plus a toggleable temporary mouse-master presentation) are live. **821/821** automated assertions, all Development/Release phase smokes, and Phase 8 visual-QA captures pass. The Phase 5 seed-batch p95 timing gate is environment-sensitive (content remains 288/288 valid with 0 replay mismatches); full clean-hardware one-command validation, external naive playtests, and the Phase 10 save system (rubble/support persistence) remain open. Visuals beyond terrain/mouse-master remain engineering placeholders.

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
