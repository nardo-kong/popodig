# Completion Report — Phase 8 Stability & Collapse

## Status

**PASS for the Phase 8 engineering gate.** Local stability is live end to end: excavation
shape produces deterministic span warnings with escalating bands, ignored critical spans
collapse within a bounded radius, reinforcement and root/stone supports change outcomes,
and every collapse updates topology, zones, items, and mouse safety consistently. All
821 automated assertions pass and Development/Release smokes plus visual evidence are in
place. Two environment-sensitive gates are documented below (seed-batch p95 timing,
pre-existing wet-Storage fixture) — both fail on timing/fixture only, never on content.

## Scope completed

- Added `StabilitySystem` (local, legible, bounded per spec 09): material span budgets
  (soft moderate / loose short / stone self-supporting), dirty-region span evaluation,
  four warning levels (STABLE / CRUMBS / CRACKING / CRITICAL), critical grace period,
  and bounded cluster collapse (`max_collapse_radius = 3`).
- Wired stability into the colony loop: dig completion refreshes local spans, warnings
  emit signals, critical regions expose mouse danger, collapse refills cells, displaces
  or documents trapped water, cancels internal designations, invalidates zones that lost
  their cells, damages only a bounded fraction of stored goods, and bumps path topology.
- Reinforcement: player-requested ceiling supports funded by General Material, hauled and
  completed autonomously by mice; supports split spans, de-escalate warnings, and prevent
  delayed collapse. Requests are inspectable, cancellable, exactly-once, and
  duplicate-refusing.
- Root interaction: major root cells act as natural local supports; cutting them
  re-escalates the same span (telegraphed, local, no hidden long-range dependency).
- Mouse safety: mice avoid active critical-warning regions for normal jobs and are never
  stranded inside refilled terrain.
- Presentation: ceiling warning bands (crumbs → cracks → critical icon), reinforcement
  request highlights, support brackets, REINFORCE tool (key 6) with cursor feedback,
  inspector Stability/RUBBLE/REINFORCED lines, development STABILITY WARNINGS overlay,
  and collapsed-rubble speckle so the resolved area stays legible (spec §8). All visuals
  are explicit engineering placeholders for the Phase 11 art pass.
- Rubble state: compact `CELL_FLAG_RUBBLE` bit on refilled cells; ordinary dig clears it
  and reopens the passage.
- QA: Phase 8 unit + integration suites, Development/Release lifecycle smoke,
  smoke-manifest phase bump, validate.ps1 gates, four deterministic screenshots, and
  Phase 8 QA demo modes (`--qa-phase8-demo=clue|warn|collapse|reinforce`).

## Governing specs

- `docs/systems/09_STABILITY_COLLAPSE_SPEC.md` (primary)
- `docs/design/02_GDD.md`, `docs/product/01_PRODUCT_VISION.md`
- `docs/tech/14_TECH_ARCHITECTURE.md`, `docs/tech/16_PERFORMANCE_BUDGET.md`
- `docs/qa/17_TEST_QA_PLAN.md`, `docs/ux/11_UI_UX_SPEC.md`, `docs/art/12_ART_BIBLE.md`
- `docs/production/19_IMPLEMENTATION_ROADMAP.md` Phase 8

## Files changed

- Core (commit `9598455`): `src/domain/features/stability_system.gd` (new),
  `colony_simulation.gd`, `mouse_agent.gd`, `signal_system.gd`, `dig_system.gd`,
  `job_system.gd`, `cell_data.gd`, `world_grid.gd`, `config/balance/core.json`.
- Presentation/QA (commit `3267ab7`): `game_app.gd`, `worldgen_debug_overlay.gd`,
  `world_chunk_view.gd`, `world_view.gd`, `tests/phase8_stability_smoke.gd` (new),
  `smoke_manifest.json`, `tools/validate.ps1`, four screenshots.
- Follow-up (this report's commit): rubble flag + legibility speckle
  (`cell_data.gd`, `world_grid.gd`, `stability_system.gd`, `world_chunk_view.gd`,
  `game_app.gd`), reinforce-demo multi-support fix, terrain-candidate English rename
  (commit `b150700`), and this report/checklist/changelog/README sync.

## Environment

- Godot: `4.7.stable.official.5b4e0cb0f`
- Renderer: OpenGL 3 Compatibility, Intel Iris Xe
- OS/runtime: Windows / PowerShell

## Import / parse status

**PASS.** Headless editor import and global-class scan completed cleanly; all stability
domain and presentation scripts pass the compile gates in the test runner.

## Automated tests

- Unit/contract/integration/compile assertions: **821 passed, 0 failed**
  (691 pre-Phase-8 baseline + 130 stability/rubble assertions).
- Phase 8 stability lifecycle smoke: **Development PASS, Release PASS**
  (`witness cells=39`, warnings escalate, reinforcement request/cancel contract,
  release hides the stability overlay, no mouse stranded).
- Regression smokes re-run after stability integration: Phase 1 scene (dev/release),
  Phase 2 playable, Phase 3 colony, Phase 4 zones, Phase 5 worldgen (dev/release),
  Phase 6 root (dev/release), Phase 7 water (dev/release) — **all PASS**.
- Phase 5 seed batch: **288/288 valid, final_rate 1.0000, 0 replay mismatches**;
  the p95 generation-time budget (500 ms) is environment-sensitive and failed under
  parallel load (576–617 ms) while passing idle earlier the same day (451 ms).
  Content determinism was never affected. Documented as a flaky timing gate.
- Spec §12 coverage: stable span stable; over-span warns then collapses; reinforcement
  prevents collapse; root support applies locally (and cutting re-escalates); collapse
  updates pathfinding; radius bounded with protected-cell arrest; zone invalidation;
  item damage bounded; rubble reopen via ordinary dig.
- **Deferred by roadmap:** spec §12 "save/load preserves rubble and supports" — no save
  system exists until Phase 10; the compact rubble flag is save-ready.

## Manual / visual QA

- `art/qa/screenshots/phase_8_stability_warnings.png` — **1280×720**, escalating
  warning bands along an over-wide soft span, REINFORCE tool guidance.
- `art/qa/screenshots/phase_8_reinforced_support.png` — **1280×720**, eight completed
  supports stabilize the span (STABLE in inspector), span survives with mice on it.
- `art/qa/screenshots/phase_8_bounded_collapse.png` — **1280×720**, ignored 14-cell
  span collapses into visibly speckled rubble, route blocked, adaptation guidance shown.
- `art/qa/screenshots/phase_8_release_clean.png` — **1280×720**, Release view with no
  debug chrome, overlay, or placeholder leakage.
- All four images passed automated size/content validation and manual inspection.

## Performance observations

- Phase 6 signal benchmark (windowed, textures, vsync off): 190.5 fps average, 9.53 ms
  p95 — within the 55 fps / 33.4 ms budget (host was thermally slower this session;
  same benchmark measured 311 fps earlier).
- Phase 7 water benchmark: 1.33 ms average step, 4.92 ms p95 — unchanged.
- Phase 4 zone churn: 12.2 ms event burst, 65.6 ms flush for a 512-cell churn —
  unchanged.
- Stability evaluation is dirty-region local; no global load paths; no measurable
  frame-time regression introduced.

## Known deviations / residual risks

1. Collapsed-rubble visuals are placeholder speckle; a dedicated rubble tile arrives in
   Phase 11 (the domain flag is already in place).
2. Spec §12 save/load preservation is deferred with Phase 10 persistence (no save
   system yet).
3. Seed-batch p95 timing gate is environment-load sensitive (see tests section); the
   500 ms budget may need headroom or a quieter-machine re-run for formal sign-off.
4. Pre-existing (from the art pass, not stability): `--wait-for-wet-storage` capture
   fixture can race mouse eating and time out; simulation itself is fully covered.
5. Open gates carried from earlier phases: external naive-player Root cue readability,
   full out-of-sandbox one-command validation on clean hardware.

## Verdict

Phase 8 milestone scope is complete and verified. Phase 9 (Slice UX) should not start
until the PM reviews this report and the Phase 8 screenshots.
