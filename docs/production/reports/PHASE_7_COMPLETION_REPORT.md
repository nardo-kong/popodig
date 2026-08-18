# Completion Report — Phase 7 Water System

## Status

**PASS for the Phase 7 engineering gate.** Multiple player-created topologies produce deterministic, observably different water outcomes, and conservation coverage passes. Repository-wide out-of-sandbox one-command validation remains pending because the Codex execution approval quota rejected the access needed by Godot's normal `user://` logging path.

## Scope completed

- Added finite Water Reservoir metadata and the full Signal → Reveal → Reaction → Adaptation → Stable State lifecycle.
- Added qualitative Moisture clues and recognition progression without exposing cell-perfect hidden reservoir geometry in normal play.
- Added deterministic 0–4-unit tile water with bounded fixed steps, downward priority, horizontal lower-fill equalization, topology wake-up, and stable-pool sleep.
- Connected authoritative DIG completion to exactly-once reservoir breach, finite initial/continued discharge, local dig cancellation, mouse danger interruption, and automatic recovery after escape.
- Added the Seal tool and autonomous SEAL jobs. A mouse selects reachable material, carries exactly one General Material, works from an adjacent cell, displaces shallow water when possible, and commits a topology-blocking seal.
- Preserved DIG as the dominant verb: a completed seal is removed by an ordinary dig designation and does not refund or duplicate material.
- Reused wet-zone suitability and added a flow-driven integration fixture proving that shallow incoming water creates a high-priority Emergency Haul and that autonomous mice relocate Food to dry Storage.
- Added water depth, flow, moisture, source, seal request/completion, HUD/inspector, and development overlay presentation. All current visuals are explicitly engineering placeholders.

## Governing specs

- `docs/product/00_DECISION_REGISTER.md`
- `docs/design/02_GDD.md`
- `docs/systems/07_DISCOVERY_SIGNAL_SPEC.md`
- `docs/systems/08_WATER_ENVIRONMENT_SPEC.md`
- `docs/systems/10_COLONY_ROOMS_AI_SPEC.md`
- `docs/tech/14_TECH_ARCHITECTURE.md`
- `docs/tech/16_PERFORMANCE_BUDGET.md`
- `docs/qa/17_TEST_QA_PLAN.md`
- `docs/production/19_IMPLEMENTATION_ROADMAP.md` Phase 7

## Files changed

- Water and adaptation domain: `src/domain/features/water_system.gd`, `seal_system.gd`, and `signal_system.gd`.
- Compact world state: `src/domain/world/cell_data.gd` and `world_grid.gd`.
- Colony/jobs: `src/domain/colony/colony_simulation.gd`, `mouse_agent.gd`, `src/domain/jobs/colony_job.gd`, `job_system.gd`, and `dig_system.gd`.
- Presentation: `src/presentation/app/game_app.gd`, `world/world_view.gd`, `world_chunk_view.gd`, `dig_cursor_view.gd`, `debug/worldgen_debug_overlay.gd`, and `scenes/app/game_app.tscn`.
- Configuration: `config/balance/core.json` and `src/infrastructure/config/app_config.gd`.
- Tests/QA: Water unit tests, seal/water colony integration tests, Phase 7 scene smoke, water benchmark, smoke manifest, five screenshots, and `tools/validate.ps1` gates.
- Documentation/tracking: checklist, README, changelog, architecture notes, and this report.

## Environment

- Godot: `4.7.stable.official.5b4e0cb0f`
- Renderer: OpenGL 3 Compatibility, Intel Iris Xe
- OS/runtime: Windows / PowerShell

## Import / parse status

**PASS in sandbox.** Godot editor import/global-class scanning completed with exit code 0. All Phase 7 domain and presentation scripts pass explicit compile gates. The sandbox emits a non-gameplay Windows root-certificate-store warning; the log-clean external validation gate remains pending.

## Automated tests

- Unit/contract/integration/compile assertions: **691 passed, 0 failed**.
- Phase 7 Water runtime smoke: **Development PASS, Release PASS**.
- Development evidence: `moisture_cells=170`, `water_units=4`, `reserve_units=197`, `seals=1`.
- Release evidence: the same authoritative simulation result, with requested debug overlay rejected and hidden.
- Water topology/conservation coverage includes vertical gravity, basin equalization, sealed barriers, newly opened drainage redirection, finite source exhaustion, stable sleep, authentic DIG breach, exactly-once reaction, emergency designation cancellation, mouse escape/recovery, flow-driven Emergency Haul, wet seal displacement, seal removal, and inventory conservation.
- Full `tools/validate.ps1`: not completed after Phase 7 because sandbox-external approval was rejected by the Codex usage limit. The directly runnable Phase 7 gates above passed with project-local log files.

## Manual / visual QA

- `art/qa/screenshots/phase_7_moisture_clues.png` — **1280×720**, normal qualitative dampness gradient; hidden reservoir geometry remains undisclosed.
- `art/qa/screenshots/phase_7_reservoir_breach.png` — **1280×720**, revealed source and standing depth response.
- `art/qa/screenshots/phase_7_water_flow_debug_1920x1080.png` — **1920×1080**, Development water active/flow overlay.
- `art/qa/screenshots/phase_7_seal_recovery.png` — **1280×720**, completed material-funded seal and DIG-removal guidance.
- `art/qa/screenshots/phase_7_release_clean.png` — **1280×720**, Release view with no inspector, debug overlay, seed/hash, or placeholder/debug labels.
- All five images passed automated size/content validation and were manually inspected for clue readability, source/depth distinction, flow diagnostics, seal visibility, UI clipping, and Release isolation.

## Performance observations

- Isolated `96×72` active-water benchmark with 376 conserved units over 240 fixed steps: **0.960 ms average**, **3.251 ms p95**, **4.656 ms maximum**, and **94 maximum transfers per step**.
- The active set ended at 284 cells and never exceeded the configured 256 transfer attempts per step. Stable pools leave the active simulation after three quiet steps and wake on source, water, terrain, or seal changes.
- A deliberately invalid concurrent benchmark run contended with three other Godot processes and exceeded the gate; it was discarded as a polluted measurement. The required isolated measurement above passes.

## Known deviations from spec

- Optional limited upward pressure/equalization is not implemented. The locked behavior requires downward preference and horizontal lower-fill movement; current fixtures satisfy predictable drainage and basin outcomes without the extra complexity.
- Save/load preservation of water units, source reserves, lifecycle state, recognition, and seals is deferred to the scheduled Phase 10 persistence milestone.
- Final water edge art, breach VFX, audio, and ambience remain later art/audio integration work. Current terrain, water, source, seal, mice, and UI marks are engineering placeholders and are not represented as Production Art.

## Residual risks / issues

- The exact water rates, danger radius, shallow/deep thresholds, and clue density require whole-slice playtesting and balance telemetry.
- Water behavior is intentionally discrete. More varied topology fixtures should be retained as Stability and later Features begin changing cells dynamically.
- Phase 6's independent naive-player Root cue-readability gate and the repository-wide external log-clean validation/fresh-process replay remain open.
- Stability, full onboarding, save/load, formal art/audio, campaign progression, export, and final acceptance remain future roadmap work; Phase 7 completion does not imply game completion.

## Git

- Commit ID: **pending** — Git index writes require sandbox-external access, currently unavailable due the Codex usage limit.
- Tag: not required for Phase 7.

## Next engineering target

Proceed with Phase 8 local Stability: Weak Soil signals, local span warnings, player-built reinforcement, bounded collapse, and immediate path/zone topology repair. Preserve the same predictable spatial-reaction contract and prove at least two intentionally avoidable/solvable instability situations.
