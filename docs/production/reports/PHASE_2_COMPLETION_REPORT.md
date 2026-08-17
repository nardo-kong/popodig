# Completion Report — Phase 2 Digging & Dynamic Topology

## Scope completed

- Added player-facing left-click/drag dig designation over any legal, colony-connected frontier in the continuous grid world.
- Added right-click cancellation, including deterministic pruning of downstream designations that no longer connect to the colony.
- Added structured legality results for protected, excavated, out-of-bounds, disconnected, duplicate, and valid cells.
- Added persistent dig jobs with priorities, reservations, hardness-scaled work, continuous progress, and atomic excavation completion.
- Added one autonomous mouse that claims reachable frontier work, follows updated paths, digs, and recovers from cancelled or stale work.
- Added synchronous walkability-cache, topology-revision, distance-field, reachability, and path updates after terrain or shallow-water changes.
- Added separate chunk-level dig overlays so progress redraws do not invalidate terrain or create one presentation node per cell.
- Added player HUD feedback, legal/invalid/cancel cursors, an engineering-placeholder mouse view, and focus-safe input handling that coexists with camera drag.
- Gated QA automation and all engineering debug UI behind Development configuration; the Release scene starts clean and remains directly playable.
- Extended unit, deterministic integration, scene, Release-profile, screenshot, and VSync-independent performance validation.

## Governing specs

- `docs/systems/06_TERRAIN_DIGGING_SPEC.md`
- `docs/systems/10_COLONY_ROOMS_AI_SPEC.md` (Phase 2 job/path foundations only)
- `docs/tech/14_TECH_ARCHITECTURE.md`
- `docs/tech/16_PERFORMANCE_BUDGET.md`
- `docs/qa/17_TEST_QA_PLAN.md`
- `docs/production/19_IMPLEMENTATION_ROADMAP.md` Phase 2
- `skills/soft-pixel-game-art-pipeline/SKILL.md` placeholder and integration rules

## Files changed

- Domain: `src/domain/jobs/dig_job.gd`, `dig_system.gd`, `src/domain/colony/mouse_agent.gd`, and the world-grid/chunk dig-state extensions.
- Application: dig/cancel commands and `src/application/services/grid_path_service.gd`.
- Presentation: `src/presentation/app/game_app.gd`, mouse/cursor/dig-overlay views, world-view integration, and `scenes/app/game_app.tscn`.
- Configuration: provisional digging, mouse-work, simulation-step, and walkable-water values in `config/balance/core.json`, plus validation in `app_config.gd`.
- Tests/QA: Phase 2 unit and integration tests, playable Development/Release smoke, actual-gameplay benchmark, validation pipeline extensions, smoke manifest, and screenshot tooling.
- Evidence/tracking: three Phase 2 screenshots, `MILESTONE_CHECKLIST.md`, `README.md`, and this report.

## Environment

- Godot: `4.7.stable.official.5b4e0cb0f`
- Renderer: OpenGL 3 Compatibility, Intel Iris Xe
- OS/runtime: Windows / PowerShell

## Import / parse status

**PASS.** Clean editor import and GDScript class scanning completed with exit code 0. The final full-validation logs contain no `ERROR:` records.

## Automated tests

- Unit/contract/integration assertions: **176 passed, 0 failed**.
- Build-profile process smokes: **2 passed, 0 failed**.
- Phase 1 scene regression smokes, Development and Release: **2 passed, 0 failed**.
- Phase 2 playable smokes, Development and Release: **2 passed, 0 failed**.
- Full-size render/local-redraw smoke: **1 passed, 0 failed**.
- Raw large-world and actual-gameplay performance gates: **2 passed, 0 failed**.
- Screenshot capture/content validation: **3 passed, 0 failed**.
- Full one-command validation: **PASS** (`VALIDATION_PASS`, 79.2 seconds).

Covered cases include click and cardinal drag interpolation; duplicate and mixed designations; protected, non-excavatable, out-of-bounds, unreachable, and isolated-natural-cave rejection; planned-chain connectivity; cancellation and downstream pruning; reservation ownership; hardness-scaled continuous progress; atomic completion; same-tick topology/path updates; water walkability threshold; mouse pathing, work completion, and cancellation recovery; focus-loss paint reset; camera-pan coexistence; Release cheat exclusion; and bounded overlay redraw.

The Release playable smoke deliberately supplies `--qa-phase2-demo`, proves that it creates zero designations, and then completes a path through the same synthetic player-input route used by the real application.

## Manual / visual QA

- `art/qa/screenshots/phase_2_digging.png` — **1280×720**, Development.
- `art/qa/screenshots/phase_2_digging_1920x1080.png` — **1920×1080**, Development.
- `art/qa/screenshots/phase_2_release_clean.png` — **1280×720**, Release.
- Automated dimension and rendered-content validation passed for all three screenshots.
- Manual inspection confirmed readable queued/active/progress states, visible mouse work, responsive HUD placement, and explicit engineering-placeholder labelling in Development.
- Manual inspection confirmed that Release starts with an idle mouse and zero queued jobs, while the QA path, debug top bar, inspector, grid help, FPS counter, and engineering footer are absent.

## Performance observations

- `240×260` / 62,400-cell deterministic generation: **218.88 ms** in the final test run.
- Full-size rendered world: **255 chunk views**, **512 total nodes** (terrain plus job-overlay node per chunk), and **one target redraw** for an edit.
- VSync-independent large-world benchmark: **758.29 average FPS**, **1.70 ms p95 frame time**, **5.87 ms** for the edit burst, across **2,276 frames**.
- VSync-independent actual Phase 2 gameplay benchmark: **425.40 average FPS**, **3.51 ms p95 frame time**, **1,277 frames**, **89 nodes**, ten active designations, and the mouse actively digging.
- Capacity benchmarks explicitly disable VSync so host refresh divisors do not masquerade as simulation/rendering cost.

## Known deviations from spec

None for the Roadmap Phase 2 gate. This does not claim completion of the full terrain/digging specification: hazard/discovery interruption belongs to Phases 6–8, debris and hauling to Phase 3/content integration, and material-specific audio/VFX and production digging animation to Phase 11.

## Residual risks / issues

- Phase 2 intentionally presents one mouse. The configured initial colony of three, needs, work arbitration across residents, hauling, and long-run deadlock handling are Phase 3 acceptance work.
- The current unweighted cardinal BFS is deterministic and well within the one-mouse budget. Phase 3 must re-profile it under multi-mouse job churn before treating that result as a colony-scale performance guarantee.
- Shallow-water walkability is already a topology input, but weighted route preferences await the water and colony phases.
- Terrain, mouse, cursors, and job effects are clearly labelled programmatic engineering placeholders and are not Production Art. No final art, particles, or audio are claimed.
- Low-level world mutation exists for tests and future systems; runtime excavation must continue to use the atomic DigSystem completion path.
- Persistence of jobs, reservations, and mouse state remains deferred to the versioned Phase 10 save schema.

## Independent review

**PASS.** A separate QA/architecture review found no blocking bug or false-positive gate after the Release-cheat and focus-loss fixes. It independently confirmed player input, legality/frontier rules, progress and atomic completion, topology refresh, autonomous recovery, Release isolation, chunk-local overlays, final logs, performance evidence, and screenshot content.

## Git

- Implementation commit: `7b639a95981f756ff1fb191684d42e2acfae7177`
- Tag: not required for Phase 2.

## Recommendation

**PASS — begin Phase 3 Colony Simulation.**
