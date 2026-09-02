# Completion Report — Balance Telemetry Session Instrumentation

## Scope completed

`docs/production/21_BALANCE_TELEMETRY.md` §2 "local development metrics":
a debug-gated, local-only session recorder covering the doc's metric list,
wired into the live game. §3 decision-quality proxies and §4 worldgen
metrics are intentionally out of scope (worldgen metrics already largely
covered by the seed-batch tool reports).

## What is collected

Event-driven:
- cells excavated, split by terrain material;
- dig batch sizes per designation stroke (average reported);
- reinforcement requests accepted;
- dig-designation cancellations landing inside an actively warned cell set
  (the doc's "dig cancellations after warnings" adaptation signal);
- zone changes; saves per slot (autosave visible); loads;
- reservoir breaches + released water units;
- flooded storage cells (peak);
- collapse events + collapsed cell total;
- discoveries (root cluster via `feature_revealed`, reservoir via breach,
  old burrow / warm chamber via adjacent excavation), each stamped with
  session time and an "open feature cells at reveal" proxy for "how close
  did you dig before the signal fired" (full signal-crossing tracking is
  deferred);
- chapter advances (elapsed time per chapter) and first campaign
  completion time.

Sampled at 1 Hz:
- idle ratio and headcount (MouseAgent state samples);
- mouse travel proxy (summed cell moves per sample — agents only expose
  discrete cells);
- water units at rest, total vs outside reservoir cells (last + peak).

## Implementation

- New `src/domain/telemetry/session_telemetry.gd` — pure passive recorder
  (RefCounted), caller-owned clock, `to_summary_dict()` +
  `write_snapshot()`; unit-testable without a scene.
- `game_app.gd` instantiates it only when `AppConfig.debug_tools_enabled()`
  (development/qa profiles; release builds collect nothing — doc §7
  privacy), connects the events above, samples at 1 Hz from `_process`,
  and writes snapshots on the debug-tools **T** key (F8 is avoided — see
  the F9 editor note) and automatically on window close
  (`NOTIFICATION_WM_CLOSE_REQUEST`), to
  `user://telemetry/session_seed<seed>_<stamp>.json`.

## Files changed

- New: `src/domain/telemetry/session_telemetry.gd`,
  `tests/unit/test_session_telemetry.gd`, this report
- Modified: `src/presentation/app/game_app.gd` (recording wiring, sampler,
  snapshot key/close flush), `tests/test_runner.gd` (suite registration)

## Godot version used

Godot 4.7.stable.

## Import/parse status

PASS (test-suite compile gates + full validate.ps1 log scan).

## Automated tests

- **1299/1299 PASS** (+30 telemetry recorder assertions; +1 from the
  registration of the suite run).
- Full `tools/validate.ps1`: **VALIDATION_PASS**.

## Manual/visual QA

A temporary scene-level probe instantiated the real game, let the sampler
run ~9 s (9 mouse samples, water scan populated), forced a snapshot, and
verified the JSON file parses with all six sections — probe removed after
the check.

## Screenshots produced

None (no visual change).

## Performance observations

Sampler cost is one 96×72 water scan + N mouse reads per second — well
under 1 ms; release builds skip the recorder entirely.

## Known deviations from spec

- "Signals encountered before reveal" is recorded via the degraded
  open-feature-cells proxy (see above); exact per-cell signal crossing
  would need a new signal-system traversal record and is deferred until
  playtests show it is needed.
- "Zone relocations" is recorded as zone-change events (paint/erase),
  which is the available granularity.
- "Mouse travel distance" is a 1 Hz cell-step proxy, not a true path
  integral.

## Residual risks / issues

- Snapshot files accumulate in `user://telemetry/` across sessions; no
  retention policy (local dev data only).
- No automated validate gate for the scene-level wiring (covered by the
  one-off QA described above); if this ever regresses, the unit tests
  still protect the recorder logic.

## Commit IDs

- Commit `feat:` — session balance telemetry (21 §2)
- Commit `docs:` — this report, changelog
