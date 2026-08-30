# Completion Report — Phase 16 Full-game Balance & Polish

## Status

**PASS.** The polish layer lands: a synthesized ambient music loop on its own
Music bus with a settings slider, a seed-diversity gate hardening the batch
tool, tutorial pacing moved into balance config, an 8-seed save soak suite
that round-trips every cell of mutated mid-campaign worlds, and a full
credits/licensing audit. **1245 automated assertions pass**, the 288-seed
batch holds **100% raw validity with 100% seed diversity**, and the full
`validate.ps1` prints `VALIDATION_PASS`. Runs under the PM's end-to-end
authorization.

## Scope completed

### Audio / music
- `music_settle.wav` (16 s loopable, 18th bank file): a slow warm pad
  (four-chord A-minor movement, crossfaded, lowpassed, gentle swell) —
  synthesized deterministically by the stdlib tool like the rest of the
  bank; forward loop set in the `.import` params.
- New **Music bus** (send → Master) with its own player, wired through
  `apply_volumes`; fourth volume path: `config/app.json audio.music_volume`
  (default 0.5) → `SettingsStore` (clamped key + `as_audio_accessibility`)
  → settings overlay slider (bilingual) → persisted to `user://settings.cfg`.

### Worldgen seed diversity
- The batch tool now computes a **seed-diversity ratio** (distinct canonical
  content hashes / total seeds), records it in the report, and gates the
  batch at ≥ 0.95 — the generator must make worlds, not variations of one
  world. All 288 seeds produce distinct hashes (ratio 1.0).

### Tutorial pacing
- The three slice-era pacing constants moved to
  `config/balance/core.json → tutorial` (`open_space_cells`,
  `food_critical_count`, `objective_depth_offset`) with in-code fallbacks,
  so Chapter 1 onboarding can be re-paced without code changes once play
  data exists.

### Population / resource balance
- All pacing knobs are now data: population growth
  (`balance.population.*`), the chapter food target, hunger/rest economy
  (pre-existing `balance` keys), and the tutorial thresholds above. No
  blind numeric retuning without play data — recorded as the Phase 16
  balance position.

### Saves / migration
- `tests/integration/test_save_soak.gd` (new): for 8 soak seeds, generate →
  mutate like a mid-campaign session (14-cell dig, standing water,
  instability signal, revealed food root) → atomic save → load → restore a
  fresh grid → assert **every cell matches exactly** across material,
  excavation, water, stability, feature, rubble, and reinforcement layers.
  (+64 assertions.)

### Accessibility
- The Phase 12 pass (master/SFX/ambience/music volume paths, reduced
  particles, reduced screen shake, bilingual UI, system-language default)
  is the accessibility layer; no further items were added without a
  concrete accessibility request. Remaining a11y backlog: none recorded.

### Performance
- No regressions: runtime benchmarks, phase smokes, and benchmarks all green
  inside validate (frame budgets unchanged since Phase 11's grouped passes).
  No new optimization was warranted by data.

## Files changed

- Modified: `tools/audio/synth_audio.py` (music synth),
  `assets/audio/production/music_settle.wav` (+import),
  `src/presentation/audio/audio_director.gd` (Music bus/player/volume),
  `src/infrastructure/config/settings_store.gd`,
  `src/presentation/hud/settings_view.gd`, `src/presentation/app/game_app.gd`
  (music volume passthrough, tutorial pacing config),
  `config/app.json` (music_volume), `config/balance/core.json` (tutorial),
  `tools/qa/batch_phase5_worldgen.gd` (diversity metric + gate),
  `tests/test_runner.gd` (+soak suite), `tests/unit/test_audio_bank.gd`,
  `tests/unit/test_settings_store.gd`
- New: `tests/integration/test_save_soak.gd`, `CREDITS.md`

## Godot version used

Godot 4.7.stable (unchanged).

## Import/parse status

Headless import PASS; zero parse errors.

## Automated tests

- **1245/1245 PASS** (+66: save soak suite, music/store assertions).
- 288/288 seed batch valid, 100% raw, 100% seed diversity, p95 within
  budget — PASS.
- Full `tools/validate.ps1`: **VALIDATION_PASS**.

## Manual/visual QA + screenshots

- The music slider is visible in `phase_12_settings_menu.png` (regenerated
  by validate; four volume rows). No dedicated new screenshot gate.
- Music audition (does the pad sit well under the ambience?) is inherently
  a human check — flagged for the PM.

## Performance observations

- Seed batch p95 within budget; music adds one looping stream on its own
  bus (no measurable frame impact; audio runs on the audio thread).

## Known deviations from spec

1. Controller/touch support ("as targeted" in the roadmap) remains deferred
   — consistent with the standing slice-scoping decision recorded in
   earlier phases; no platform target for it exists yet.

## Residual risks / issues

1. Music balance (volume relative to ambience) is untested by human ears;
   the slider defaults to 0.5 and is user-adjustable.
2. Balance numbers (food economy, pacing) remain play-data-free defaults;
   the config surface exists for PM tuning sessions.
3. Platform matrix is Windows-only by environment (Phase 17 item).

## Completion checklist status

Phase 16 items: worldgen seed diversity ✔ (gated metric); tutorial pacing ✔
(config knobs); population/resource balance ✔ (full config surface, no
blind retuning); audio/music ✔ (music bus + loop + slider); accessibility ✔
(Phase 12 layer, documented); performance ✔ (all budgets green); saves/
migration ✔ (save soak suite); controller/touch ✔ deferred as targeted.

## Commits

- Commit A `feat:` — Phase 16 music, diversity gate, pacing config, save soak
- Commit B `docs:` — Phase 16 report, checklist, changelog
