# Engineering Report — Phase 6 Signal & Root Feature

## Status

**Engineering implementation PASS; milestone acceptance remains OPEN.** The external naive-player test required by the Roadmap gate has not been performed. The repository-wide one-command validation and fresh-process replay also remain pending because sandbox-external execution was rejected by the Codex usage/approval limit on 2026-08-18.

## Scope completed

- Replaced the Phase 5 signal hook stage with real deterministic Signal Fields and advanced structured generation to worldgen v3.
- Added compact Root Density and Moisture fields derived from final Feature geometry with Manhattan falloff, overlap-by-maximum, configurable qualitative thresholds, EXTERIOR exclusion, and bounded runtime dirty-region updates.
- Added category recognition states `UNKNOWN`, `ENCOUNTERED`, and `UNDERSTOOD`; physics remains unchanged by recognition.
- Added normal-view Root clues that vary by qualitative density without exposing hidden cell-perfect Root geometry. Hidden Root cells render as their ordinary stratum until reveal.
- Added development overlays for qualitative Root bands, raw values, emitters, dirty regions, Feature IDs, and recognition state. Release ignores overlay arguments and hides debug UI.
- Added the Root Cluster lifecycle: signal, boundary/cell reveal, exactly-once reaction, initial Food release, player adaptation through nearby set-up Food/Forage space, finite sustained forage, depletion, and persistent Stable State.
- Integrated Signal/Root systems into `ColonySimulation`, items, zones, authoritative Dig events, UI feedback, inspector diagnostics, structured validation/repair, seed hashes, QA fixtures, and one-command validation.
- Added low-frequency progress output to the authoritative batch tool so CI timeouts identify the last completed seed.

## Files changed

- Signal and Feature domain: `src/domain/features/signal_system.gd`, `root_feature_system.gd`.
- World/state/generation: `src/domain/world/world_grid.gd`, `src/domain/worldgen/structured_world_generator.gd`, `world_validator.gd`, `world_repairer.gd`.
- Colony/application presentation: `src/domain/colony/colony_simulation.gd`, `src/presentation/app/game_app.gd`, `src/presentation/world/world_view.gd`, `world_chunk_view.gd`, `src/presentation/debug/worldgen_debug_overlay.gd`.
- Configuration: `config/app.json`, `config/worldgen/default.json`, `src/infrastructure/config/app_config.gd`.
- Tests/QA: Signal unit tests, Root lifecycle integration test, Phase 6 Development/Release smoke, signal benchmark, screenshot evidence, batch progress logging, smoke manifest, and validation script.
- Tracking/docs: checklist, README, technical architecture, authoritative seed report, and this report.

## Environment

- Godot: `4.7.stable.official.5b4e0cb0f`
- Renderer: OpenGL 3 Compatibility, Intel Iris Xe
- OS/runtime: Windows / PowerShell

## Import / parse status

**PASS in sandbox.** Godot editor import/global-class scan completed with exit code 0 after the final implementation. The external log-clean import gate remains pending because Godot cannot read the Windows certificate store or write `user://logs` inside the restricted sandbox.

## Automated tests

- Unit/contract/integration/compile assertions: **622 passed, 0 failed**.
- Phase 6 Root scene smoke: **Development PASS, Release PASS**.
- Authoritative worldgen v3 batch: **288/288 final valid**, **286/288 raw valid**, **0 repairs**, **2 deterministic retries**, **0 required-path softlocks**, and **0/16 same-process replay mismatches**.
- Batch performance: **496.77 ms p95**, **983.68 ms maximum**; the required p95 is at most 500 ms.
- Independent fresh-process replay: not rerun successfully after v3 because its child Godot processes require sandbox-external `user://` access. Same-process replay and deterministic unit coverage pass.
- Full `tools/validate.ps1`: not completed after v3 because sandbox-external approval was rejected by the Codex usage limit. Individual in-sandbox gates above were run directly.

## Manual / visual QA

- `art/qa/screenshots/phase_6_root_clues.png` — **1280×720**, normal qualitative clue view with raw inspector hidden.
- `art/qa/screenshots/phase_6_root_signal_raw_1920x1080.png` — **1920×1080**, Development raw Root field overlay.
- `art/qa/screenshots/phase_6_root_stable.png` — **1280×720**, revealed persistent Root and set-up Food/Forage Stable State.
- `art/qa/screenshots/phase_6_release_clean.png` — **1280×720**, Release presentation with debug overlay request rejected.
- All four images passed automated dimension/content checks and were manually inspected. Weak/noticeable clues are deterministically sparse; strong clues are continuous enough to read while hidden Root geometry retains normal stratum color.
- All terrain, Root, mice, items, and zone visuals remain engineering placeholders. None are accepted as Production Art.

## Performance observations

- Runtime signal benchmark at 1280×720: **280.66 average FPS**, **4.84 ms p95 frame**, **107.69 ms** for a burst of 64 terrain-triggered bounded updates; dirty history remained capped at 32.
- Generation initially measured **518.72 ms p95**, failing the 500 ms gate. Replacing generation-time per-cell field mutation with an equal-size compact field assignment reduced p95 to **496.77 ms** without changing runtime local updates or content hashes for a seed/config version.
- The maximum case is a deterministic retry and remains below the 2,000 ms hard batch limit.

## Known deviations from spec

- The Roadmap gate specifically requires a naive tester to learn that Root cues predict a Root/Food opportunity. Automated tests and visual inspection cannot substitute for that usability evidence, so `Playtest cue readability` remains unchecked.
- Root cutting/removal remains the open product decision O-010. This implementation supports route-around and nearby forage adaptation; it does not silently decide that major roots are removable.
- Final Root art, animation, audio, and VFX remain Phase 11 work. The current procedural marks are explicitly engineering placeholders.

## Residual risks / issues

- Worldgen p95 has only 3.23 ms headroom; Phase 7/8 validators must be profiled and may require planner optimization or a revised staged performance budget without weakening validation.
- Root clues are structurally differentiated and avoid exact geometry leakage, but their real learnability and false-positive tolerance require an external first-time-player session.
- Recognition is runtime state but persistence is not implemented until Phase 10 Save/Load.
- The full log-clean validation and v3 fresh-process replay must be rerun once sandbox-external Godot execution is available.

## Git

- Commit ID: **pending** — Git index writes require sandbox-external approval, which was unavailable due the Codex usage limit.
- Tag: not required for Phase 6.

## Next engineering target

Proceed with Phase 7 finite Water while keeping Phase 6's external cue-readability and full-validation gates open. Water must reuse the same Signal → Reveal → Reaction → Adaptation → Stable State contract and prove conservation across multiple player-created topologies.
