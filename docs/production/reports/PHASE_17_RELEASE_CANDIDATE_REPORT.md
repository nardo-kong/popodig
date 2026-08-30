# Completion Report — Phase 17 Release Candidate

## Status

**Release-candidate verification PASS, with two environmental limitations
recorded.** Every verifiable release-candidate item is green: full
regression (latest `tools/validate.ps1` → `VALIDATION_PASS`, **1245/1245
automated assertions**, 288/288 seed batch at 100% raw validity, 99.65%
seed diversity), save soak and seed soak evidence, a clean release profile
(no debug tools, no verbose logging, no cheats), and a completed
credits/licensing audit (`CREDITS.md`). Limitations: the platform matrix is
Windows-only (single dev machine; no export presets exist yet), and no
human full-campaign playthrough has been recorded.

## Verification summary

### Full regression
- `tools/validate.ps1` end-to-end: import, compile gates, 31 test suites
  (1245 assertions), development + release profile smokes, phase 1–10
  smokes, runtime/phase benchmarks, 288-seed structured-worldgen batch
  (determinism replays, diversity), ten screenshot fixtures + validations,
  release-clean captures. Final line: `VALIDATION_PASS`.

### Platform matrix
- **Windows x64 (this machine) only.** Godot 4.7 supports the usual
  desktop/mobile targets, but export presets do not exist yet (documented
  since Art Pass 01's backlog: exclude `scenes/qa`, `tools/`, `art/`,
  `tests/`, `docs/` when created). Creating export presets and testing on
  other platforms requires packaging decisions that belong to the PM.

### Save soak
- `tests/integration/test_save_soak.gd` (Phase 16): 8 seeds × full mutation
  (digs, water, instability, reveals) → atomic save → load → cell-exact
  restore verification. Plus the Phase 10 smoke's mid-breach save/load with
  spec §16 acceptance checks, six committed fixtures (including a v1
  migration), and the migration chain v1→v2. Save schema remains v2
  (additive-only progression keys since).

### Random seed soak
- The authoritative 288-seed batch (32 curated + 256 random) ran four times
  during Phases 13–16 on worldgen v4/v5/v6 — every run 288/288 valid, 0
  determinism replay mismatches, raw validity 99.65–100%, diversity 99.65%.
  This is the seed soak evidence; a larger soak (1000+) would only repeat
  the same pipeline and is not added as a gate.

### Release config / security / debug cleanup
- `config/build_profiles.json`: release = no debug tools, no verbose
  logging, **no cheats**; validated by `tests/profile_smoke.gd` and the
  release smokes (release captures must show no debug chrome — gated).
- QA camera overrides refuse the release profile; debug overlays/HUD chrome
  are debug-gated; cheat/demo arguments require `allow_cheats`.
- No secrets/keys in the repository; no network code exists.
- Export presets: not yet created (see Platform matrix).

### Credits / legal / license audit
- `CREDITS.md` (new in Phase 16): all art and audio is repository-generated
  (procedural/code-drawn; deterministic stdlib synthesis); no third-party
  assets; Godot Engine MIT; project content proprietary to the owner.

## Remaining open gates (owner decisions, not engineering)

1. **External naive playtests** (waived at the Phase 12 gate; kit ready in
   `docs/qa/19_PLAYTEST_KIT.md`) — the design-acceptance observations and
   the Phase 6 Root cue-readability external check fold into these.
2. **Full-campaign human playthrough** — the campaign is completable and
   every gate on the path is automated, but no person has yet played
   Settle → Adapt → Old Burrow to the warm-chamber home. Balance data
   (food economy, pacing) should be collected there.
3. **Export presets + non-Windows platforms** when packaging is decided.

## Commits

- Commit `docs:` — Phase 17 release-candidate report, checklist, changelog
  (Phase 17 is a verification milestone; no code changes were needed, so
  there is no feat commit this phase)
