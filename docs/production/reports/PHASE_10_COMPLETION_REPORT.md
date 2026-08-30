# Completion Report — Phase 10 Save/Load & Hardening

## Status

**PASS for the Phase 10 engineering gate.** Full-document persistence is
implemented per `docs/tech/15_DATA_SAVE_SPEC.md`: versioned JSON saves
(schema v2) with a sequential migration chain, atomic writes with corruption
preservation, complete domain `to_save_data`/`apply_save_data` coverage
(world grid RLE, features, colony, zones, items, signals, water, stability,
progression), Ctrl+S quick-save / F9 quick-load / rolling autosave, and six
committed save fixtures covering the documented milestones including an
active water breach. **984 automated assertions pass**, the Phase 10 save
smoke passes with performance timings, and the full `validate.ps1` gate is
green end to end.

## Scope completed

- **SaveService** (`src/infrastructure/persistence/save_service.gd`): versioned
  header (`save_schema_version`/`game_version`/`worldgen_version`/`seed`/
  timestamps), atomic write via temporary file + rename, sequential migration
  chain (v1 → v2 adds the progression section), future-version rejection,
  corruption recovery that preserves the broken file as `.corrupt` and reports
  a user-readable error (spec §12–14).
- **Domain serialization**: `world_grid` (RLE-encoded terrain/excavated/flags/
  dig state/stability, sparse floats for moisture/signal, int-RLE feature ids),
  `feature_registry` (full metadata with JSON round-trip of Vector2i values),
  `colony_simulation` (mice, items, zones), `signal_system` recognition,
  `water_system` active cells/sleep state, `stability_system` pending
  reinforcement requests. Jobs/paths are rebuilt on load per spec §8
  (reconstruction strategy: runtime reservations are never serialized).
- **App integration** (`game_app.gd`): `_build_save_document` /
  `_apply_loaded_document` with worldgen-version mismatch rejection;
  Ctrl+S quick-save, F9 quick-load (scene reload through the pending-load path, deferred out of input handling; F8 quick-save was rebound to Ctrl+S because F8 is the editor stop-project shortcut and killed editor-launched games; F9 kept after user acceptance — it also triggers the editor debugger pause, resolved by resuming via the toolbar),
  autosave slot on a 120 s accumulator; saved/notification localization keys
  (`notify.saved`, `notify.save_failed`, `notify.load_missing`).
- **Progression persistence**: tutorial step, tutorial flags, and UI language
  restore on load (resolves the Phase 9 report's deferred decision — they
  persist).
- **Fixtures** (spec §15): `tests/fixtures/saves/` — `new_game`,
  `zones_mice`, `root_reveal`, `water_breach` (active mid-breach),
  `post_collapse`, and a hand-derived `v1_schema` exercising the migration
  chain — regenerated via `tools/qa/export_phase10_fixtures.gd` and consumed
  by the unit suite.
- **Phase 10 smoke** (`tests/phase10_save_smoke.gd`): drives the runtime app
  into an active breach, saves, loads into a second app instance through the
  real pending-load path, verifies spec §16 acceptance (terrain topology,
  water conservation, feature reveal/reserve, zones, mice on traversable
  cells, item totals, no duplicates) and reports timings.
- **Regression hardening found & fixed along the way**:
  1. `world_grid._fill_rle_runs` mutated Packed-array parameters (value
     semantics in GDScript) — decode silently produced empty data; rewritten
     to return the filled buffer plus cursor. Also fixed a follow-up compile
     error (a single typed `PackedByteArray` parameter was shared by the
     byte/int decoders).
  2. `feature_registry._dejsonify_value` failed to restore `Vector2i`
     metadata after a real file round-trip because JSON parsing turns every
     number into a float (`[46, 16]` → `[46.0, 16.0]`); int-like pairs are
     now restored to `Vector2i`.
  3. `_ready` ordering bug: a pending save was applied before the tutorial
     model existed, crashing loads; the model is now materialized lazily and
     no longer recreated over restored state.
  4. Three stale phase-smoke gates from the pre-Phase-9 era (reproduced on a
     clean Phase 9 tree — full validate had not been re-run since):
     Phase 1 node count (Phase 9 UI legitimately brought the scene to 103
     nodes; threshold raised 100 → 160, still far below per-cell scale),
     Phase 1/Phase 2 inspector visibility (the dual-mode inspector stays
     visible in every profile by Phase 9 design), and the Phase 4 HUD tool
     text (localized "Food/Forage Zone"/"食物/觅食区" instead of the old
     hardcoded uppercase literal).
  5. Zone-invalidated notification crash: `_poll_notifications` read
     `zone.anchor`, a field renamed to `identity_anchor` earlier; any
     invalid zone at poll time aborted the slow poll (surfaced by the Phase 4
     wet-storage screenshot fixture).
  6. The Phase 4 wet-storage screenshot fixture expected the storage zone to
     still be WET-invalidated at capture time; the zone system now
     autonomously re-validates once dry (hazard → opportunity), so the
     fixture accepts both terminal states. The evidence screenshot was
     re-captured (761,563 bytes, 1280×720).
  7. Found during user acceptance: both tutorial-advance call sites invoked
     a nonexistent model method (`current_text()`), so every step advance
     printed a runtime error and froze the tutorial label. Fixed to resolve
     the step's translation key. The Phase 9 smoke's refresh check had been
     vacuous under the en default (it compared against a hard-coded zh
     literal) and the validate scan did not match `SCRIPT ERROR:` lines —
     the check is now language-agnostic (text must actually change) and the
     scan matches script errors too.
  8. Found during user acceptance: F9 loaded into a broken hybrid state
     (0 mice, unresponsive sim). Bulk world restore bypasses per-cell change
     signals, so the path service walkability cache still described the
     fresh generated world and colony restore rejected every mouse standing
     in a save-only dug tunnel. The path service now rebuilds after world
     restore, and an unwalkable saved mouse cell recovers at the nearest
     walkable colony cell (spec §5 safe fallback) rather than failing the
     whole load. The Phase 10 smoke now parks a mouse inside a save-only
     tunnel before saving and asserts the rebuilt cache agrees with the
     restored grid.

## Governing specs

- `docs/tech/15_DATA_SAVE_SPEC.md` (primary; LOCKED versioning)
- `docs/production/19_IMPLEMENTATION_ROADMAP.md` Phase 10
- `docs/tech/14_TECH_ARCHITECTURE.md`

## Files changed

- New: `src/infrastructure/persistence/save_service.gd`,
  `tests/unit/test_save_service.gd`, `tests/unit/test_save_roundtrip.gd`,
  `tests/phase10_save_smoke.gd`,
  `tools/qa/export_phase10_fixtures.gd`,
  `tests/fixtures/saves/{new_game,zones_mice,root_reveal,water_breach,post_collapse,v1_schema}.json`.
- Changed: `src/presentation/app/game_app.gd` (save/load wiring, Ctrl+S/F9,
  autosave, progression persistence, lazy tutorial init),
  `src/domain/world/world_grid.gd` (RLE decode fix),
  `src/domain/worldgen/feature_registry.gd` (JSON Vector2i restore),
  `src/domain/{colony,zones,features}/*` (to_save_data/apply_save_data,
  incl. colony mouse safe-fallback recovery on load),
  `src/presentation/app/game_app.gd` (zone notification crash fix),
  `tools/qa/capture_screenshot.gd` (wet-storage evidence for re-validated
  zones), `art/qa/screenshots/phase_4_wet_storage.png` (re-captured),
  `tests/phase9_ux_smoke.gd` (language-agnostic label-refresh check),
  `assets/localization/ui.csv` (+3 keys), `tests/test_runner.gd`,
  `tests/unit/test_smoke_manifest.gd`, `tests/phase1_scene_smoke.gd`,
  `tests/smoke_manifest.json` (`current_phase` 10, `save_load` PASS),
  `tools/validate.ps1` (Phase 10 gates), `MILESTONE_CHECKLIST.md`,
  `README.md`, `CHANGELOG.md`, this report.

## Environment

- Godot: `4.7.stable.official.5b4e0cb0f`, Windows / PowerShell, headless runs.

## Import / parse status

**PASS.** Headless editor rescan clean; all scripts compile; no `^ERROR:`
lines in any gate log.

## Automated tests

- Assertions: **984 passed, 0 failed** (915 pre-Phase-10 + 69 new: save
  service contract incl. atomicity/corruption/migration/committed fixtures,
  domain round-trips incl. world-grid RLE, feature registry, signal/water/
  stability/colony, and smoke-manifest updates).
- Phase 10 save smoke: **PASS** — mid-breach save of 131,362 bytes; document
  build ≈ 4.7 ms; atomic write ≈ 20 ms; load + apply ≈ 520 ms; all spec §16
  checks green.
- Full `validate.ps1`: **VALIDATION_PASS** (import, main-scene smoke, unit
  suite, both profiles of every phase smoke incl. the new Phase 10 gates,
  benchmarks, screenshot validation, log error scan).

## Manual / visual QA

- No new screenshots required (persistence is non-visual). Verified manually:
  Ctrl+S notification toast, Ctrl+L reload restores terrain/water/zones/tutorial step,
  corrupted-file `.corrupt` preservation, and fixture reload through
  `SaveService.load_game` for all six committed fixtures.

## Performance observations

- Save document build is O(cells) RLE ≈ 5 ms; write ≈ 20 ms for ~128 KiB;
  full load + apply ≈ 0.5 s dominated by path-service rebuild — acceptable
  for autosave (async-free but off the water tick, spec §11).

## Known deviations / residual risks

1. Load-time save-data equality is semantic (ints and whole floats compare
   equal) because JSON cannot distinguish `12` from `12.0`; in-memory
   round-trip tests still assert strict hash equality.
2. `feature_registry` metadata decoding treats any 2-element int-like array
   as `Vector2i`; no float `Vector2` metadata exists today, but this is a
   convention to preserve.
3. Autosave interval (120 s) is provisional; no rotating slots yet (spec §11
   marks this provisional).
4. Settings persistence (spec §10) is intentionally separate and not yet
   implemented beyond the saved UI language.
5. User decision during acceptance (pending UX scope): in-game quick-load
   should ultimately move into a settings menu behind a confirmation
   dialog; F9 stays as the development/QA path until that UX pass lands
   (no settings menu exists yet in the slice; natural fit for the
   Phase 11/12 UX follow-up).

## Verdict

Phase 10 milestone scope is complete and verified; no known blocker or
critical state loss (roadmap gate). Phase 11 (Art/Audio Integration) is next
per the roadmap; awaiting PM approval.
