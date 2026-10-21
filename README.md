# Dig Down / 地下鼠鼠 — 2.0 Development

> **2.0 active (2026-10-21):** Start with [2.0 design](docs/design/DIG_DOWN_2_0_DESIGN.md) and [issue execution plan](docs/production/DIG_DOWN_2_0_EXECUTION.md). GitHub [#1](https://github.com/nardo-kong/popodig/issues/1) tracks P0/P1/P2 implementation. Earlier status below describes the 1.0 baseline; human gameplay gates remain separate.

## 2.0 current engineering status (2026-10-21)

Discovery rewards and frontier cues, five physical resources, autonomous workshops,
shared tools, depth progression, 18 collectibles, v7 generation, three chapters,
and persistent home milestones are implemented on `codex/dig-down-2` / [PR #16](https://github.com/nardo-kong/popodig/pull/16).

Current RC: **1388/1388 assertions**, four gameplay flows, v6 migration and rollback,
seven fresh replay hashes. This batch's authoritative v7 matrix is **288/288**.
The automated full campaign reaches a supplied five-mouse home and survives reload.
Actual player appeal/clarity gates remain open in #3/#4/#15; automatic completion
is not a playtest verdict. See [current report](docs/production/reports/2_0_BATCH_04_AND_RC.md)
and [player observation card](docs/qa/2_0_PLAYER_CHECK.md).

For small changes: `python3 tools/validate_2_0.py --suite=discovery_flow,save_roundtrip`.
For a completed batch: `python3 tools/validate_2_0.py --rc`.
Set `GODOT_BIN` to Godot 4.7 or pass `--godot /path/to/Godot`.
Only add `--worldgen-full` when another 288-seed run is warranted.

### Historical 1.0 baseline

> **Implementation status (2026-08-31):** All phases (12–17) complete plus a PM feedback round: the campaign starts with a single founding mouse (population grows +2 per chapter milestone), digging is 2× slower, unexplored ground is dark (fog of war), and the tutorial gained the missing forage-zone completion step. The campaign from Settle to the warm-chamber home is fully playable and completable, with music, settings, accessibility, save/seed soaks, and a credits audit. 1264/1264 automated assertions pass under `tools/validate.ps1` (VALIDATION_PASS); the 288-seed batch holds 100% valid worlds at 99.65%+ seed diversity. Open owner gates: an external naive-playtest round (docs/qa/19_PLAYTEST_KIT.md), a recorded full-campaign human playthrough for balance data, and export presets/non-Windows platforms when packaging is decided. Project content is proprietary to the owner (see CREDITS.md).

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
