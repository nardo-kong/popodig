# Completion Report — Phase 13 Chapter 1 Production

## Status

**PASS.** Chapter milestone progression is live (Settle → Adapt with
milestone population growth per spec 10 §14), world generation gained
authored root silhouettes and topsoil stone scatter with density tuning
(worldgen v4), the HUD carries the current chapter, and everything is
validated: **1154 automated assertions pass**, the 288-seed batch is
288/288 valid at **99.65% raw rate** (self-healing generation, only 1 seed
repaired), and the full `validate.ps1` prints `VALIDATION_PASS`.

This phase ran under the PM's end-to-end authorization ("完成 phase12 所有
测试通过之后就继续下去，13 14 以此类推"): the Phase 12 gate is recorded as
**GO by PM decision** (their own acceptance play; external naive playtests
via `docs/qa/19_PLAYTEST_KIT.md` remain recommended during Chapter 1).

## Scope completed

### Chapter milestone progression
- `src/domain/progression/chapter_model.gd` (new, pure logic): Chapter 1
  "Settle" completes on **dry Sleeping zone + Storage zone set up, secured
  food (config target, default 10), both signals learned (root + moisture
  recognised), and the colony dug into the transition band**
  (`depth_targets.chapter_2`). Chapter 2 "Adapt" completes on reaching the
  old-burrow depth band with settled water and at least one completed
  reinforcement (PROVISIONAL — Phase 14 may tighten). Advancement is
  monotonic; Chapter 3 completion lands with Phase 15's endgame content.
- Population growth at milestones (spec 10 §14): each chapter grants +2
  mice (config `population.chapter_*_growth`) spawned near the start
  burrow through the new public `colony_simulation.find_spawn_cells_near`.
- Persistence: additive `progression.chapter_model` key — old v2 saves
  restore to Chapter 1 via the default, no schema bump (documented in the
  save-data comment).
- Presentation: the HUD objective line is now prefixed with the localized
  chapter name ("第 2 章 · 适应 · 目标：…"), and each milestone fires a
  long-lived notification plus a Chapter 3 hint pointing at the old burrow.

### Authored content variations + density tuning (worldgen v4)
- Optional root clusters now pick from three authored silhouettes —
  **runner / forked / taproot** — recorded in `metadata.shape_id`; required
  roots keep the authored inward tap so the early-food witness geometry
  stays predictable.
- Topsoil stone scatter (`topsoil_stone_ratio`, default 0.6%): sparse small
  stones knit the soft topsoil band so uniform regions read less tiled.
  Stabilising-only (stone raises allowed spans), so stability content
  validation stays authoritative.
- Density tuning: optional root clusters 2→3, natural cavities 5→6.
- `worldgen_version` 3→4 (app.json + worldgen.json). Saves generated on v3
  are rejected by design (version contract); six committed fixtures were
  regenerated during validation.

### Stability demo fixtures made ceiling-aware
The new content shifted the fixed-seed RNG stream and exposed a latent
fixture bug: the Phase 8 demos picked tunnel spans by tunnel material only,
while the stability system rates the **ceiling** run. Seed 137042's v4
ceiling under the demo seam generated a clay band (allowed span 6), so the
9-cell reinforce demo span was instantly critical and collapsed before any
mouse could land a support (0/8, requests cancelled as COLLAPSED —
diagnosed with an instrumented run). Fix: `_find_qa_teaching_ceiling`
selects ceiling runs (stone splits them, mirroring the system's support
members) nearest the start, and each mode sizes the span from the weakest
ceiling material — warn/reinforce at 90% of allowed (visible warnings,
never critical), collapse at 2× (guaranteed critical). The Phase 8 smoke
was ported to the same finder.

### New generation constraint discovered by the gate
The longer authored shapes exposed a real lifecycle hole: an optional food
root could spawn **pre-exposed** against a natural cavity, letting the
colony walk to food with zero digging — skipping Signal → Reveal
(docs/systems/07). Fixed at the correct layers:
- `world_validator.gd`: new `EARLY_FOOD_PREEXPOSED` failure for optional
  food roots touching generated open cells.
- `structured_world_generator.gd`: deterministic **generation-time self-trim**
  of exposed fringe cells at the end of the terrain stage (keeps the repair
  budget for genuine anomalies). First seed-batch run without this showed
  raw rate 63.2% / p95 911ms; with it, 99.65% / 449ms.
- `world_repairer.gd`: `trim_preexposed_food_cells` action (falls back to
  removing the optional feature if the trim cannot keep a coherent body).

## Files changed

- New: `src/domain/progression/chapter_model.gd`,
  `tests/unit/test_chapter_model.gd`
- Modified: `structured_world_generator.gd` (shapes, stone scatter,
  self-trim), `world_validator.gd` (preexposure guard),
  `game_app.gd` stability demos + `tests/phase8_stability_smoke.gd`
  (ceiling-aware span selection, see above),
  `world_repairer.gd` (trim action), `colony_simulation.gd` (public spawn
  query), `game_app.gd` (milestone wiring, HUD, growth, save/restore),
  `config/worldgen/default.json` (v4, density, stone ratio),
  `config/app.json` (v4), `config/balance/core.json` (population),
  `assets/localization/ui.csv` (+5 chapter/notify keys),
  `tests/test_runner.gd` (+1 suite, +1 compile gate),
  `tests/unit/test_structured_worldgen.gd` (shape assertions, dynamic
  version assert)

## Godot version used

Godot 4.7.stable (unchanged).

## Import/parse status

Headless import PASS; zero parse errors.

## Automated tests

- **1154/1154 PASS** (+50: chapter model suite, authored-shape assertions).
- 288/288 seed batch valid, raw 99.65%, 1 repair seed, 0 replay mismatches,
  p95 449.50 ms — PASS.
- Full `tools/validate.ps1`: **VALIDATION_PASS**.

## Manual/visual QA + screenshots

- Chapter name is visible in the regenerated HUD captures
  (`phase_9_hud_tutorial.png` and all gameplay captures show the localized
  chapter prefix on the objective line).
- Root silhouettes visible in `phase_6_root_clues.png` /
  `phase_6_root_stable.png` regenerations.
- No dedicated new screenshot gate: chapter progression is evidenced by the
  unit suite + HUD captures; a milestone-moment capture would require a
  scripted long play session (deferred to PM play).

## Performance observations

- Seed batch p95 449.50 ms (budget 600 ms), max 1595 ms — within budget.
- Runtime benchmarks unchanged (validate gates all green).

## Known deviations from spec

1. Chapter 2 completion thresholds (settled water + supports + depth) are
   PROVISIONAL and marked as such in the model — Phase 14 owns the real
   Chapter 2 content and may tighten them.
2. Save schema stays v2 (additive optional `progression.chapter_model`
   key); the version contract protects structural changes only. Recorded
   in code and here.
3. Worldgen version bump invalidates pre-Phase-13 saves by design.

## Residual risks / issues

1. Chapter 1's completion conditions are now testable but un-tuned by real
   play: the food target (10) and depth gate (stratum B top) may need
   pacing adjustments from the PM's Chapter 1 sessions.
2. Optional-root trims can (rarely) delete a feature outright (1 of 288
   seeds repaired in the batch); food redundancy comes from the required
   root + remaining optionals.
3. Topsoil stones shorten soft-soil seams for the Phase 8 demo search;
   current 0.6% ratio keeps seams findable (validate green), but raising
   the ratio needs re-checking that demo.

## Completion checklist status

Phase 13 items: content density tuning ✔ (config knobs + tuned counts);
final onboarding ✔ (chapter framing + milestone notifications; deep
tutorial pacing stays in Phase 16 as roadmapped); authored root/topsoil
variations ✔; population/progression pacing ✔ (milestone growth per spec
10 §14); chapter milestone ✔.

## Commits

- Commit A `feat:` — Phase 13 chapter progression and authored worldgen
- Commit B `docs:` — Phase 13 report + gate GO record, checklist, changelog
