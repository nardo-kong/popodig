# Completion Report — Phase 12 Vertical Slice Decision Gate (Support)

## Status

**Support work complete; the gate decision itself is intentionally open.**
Phase 12 (docs/production/19 roadmap) is the Vertical Slice Decision Gate:
GO / ITERATE / NO-GO, decided by the PM from functional acceptance plus
external naive playtests (docs/qa/18 §7–§10). The agent's deliverables for
this phase are the two missing pieces of player-facing infrastructure the
slice needed before being handed to outsiders — the **settings overlay**
(the quick-load-with-confirmation decision deferred from Phase 10, plus the
audio spec §10 accessibility controls) and the **playtest kit** — and the
gate stays open until the PM's sessions produce a verdict.

## Scope completed

### Settings overlay (Esc)
- `src/infrastructure/config/settings_store.gd` (new): pure ConfigFile-backed
  store over `user://settings.cfg` with a closed key set (three volumes +
  two accessibility flags), range clamping, and stale-entry tolerance.
  Defaults come from the store; the player file only ever overrides the
  player-facing subset — balance/config documents stay authoritative.
- `src/presentation/hud/settings_view.gd` (new): code-built overlay (the
  scene file is untouched): Resume, **Quick load with explicit confirmation**
  ("everything since the save will be lost"), language switch (mirrors the L
  key), Master/SFX/Ambience sliders (live-applied), reduced-particles and
  reduced-screen-shake checkboxes (live-applied to VfxView/camera), fully
  bilingual via new `settings.*` keys.
- Wiring: **Esc now opens/closes settings** (previously Esc reset the DIG
  tool; key 1 still does). While the overlay is open the simulation pauses
  (independent of the Space pause flag) and all world input is blocked so
  sliders cannot paint designations underneath. Saved options override the
  config defaults at startup and changes persist immediately.

### Playtest kit
- `docs/qa/19_PLAYTEST_KIT.md` (new): functional-acceptance checklist mapping
  every spec §6 criterion to its automated evidence, a verbatim briefing
  script for naive players (no mechanics spoilers), the beat-by-beat session
  structure (spec §5), a per-player observation sheet targeting every §7
  observation and §8 red flag, an explicit GO/ITERATE/NO-GO decision rule,
  and session logistics.

### Gate bookkeeping
- `tests/smoke_manifest.json` → current_phase 12 with the new
  `player_settings` check; `tools/validate.ps1` gained a settings-menu
  screenshot gate (`--qa-open-settings` capture + size validation);
  `tools/qa/benchmark_phase4_zones.gd` node budget 125 → 150 (the overlay
  adds ~23 persistent nodes; same documented-follows-scene-graph pattern).

## Files changed

- New: `src/infrastructure/config/settings_store.gd`,
  `src/presentation/hud/settings_view.gd`,
  `tests/unit/test_settings_store.gd`,
  `docs/qa/19_PLAYTEST_KIT.md`,
  `art/qa/screenshots/phase_12_settings_menu.png`
- Modified: `game_app.gd` (Esc handling, settings wiring, accessibility
  application), `settings_view.gd`/`settings_store.gd` (this phase's new
  files), `assets/localization/ui.csv` (+12 `settings.*` keys, regenerated
  translations), `tools/qa/capture_screenshot.gd` (`--qa-open-settings`),
  `tools/validate.ps1`, `tools/qa/benchmark_phase4_zones.gd`,
  `tests/test_runner.gd`, `tests/smoke_manifest.json`,
  `tests/unit/test_smoke_manifest.gd`

## Godot version used

Godot 4.7.stable (unchanged).

## Import/parse status

Headless import PASS; zero parse errors; compile gates load.

## Automated tests

- **1104/1104 PASS** (was 1087; +17 from the settings store suite and
  compile gates).
- Phase 1 scene smoke PASS (137 nodes vs 160 budget), Phase 9 UX smoke PASS.
- Full `tools/validate.ps1`: **VALIDATION_PASS** (including the new Phase 12
  capture gate).

## Manual/visual QA + screenshots

- `art/qa/screenshots/phase_12_settings_menu.png` (1280×720): overlay
  centered, dimmed world behind, all controls rendered bilingually
  (English system locale in the capture).
- PM in-game smoke of the menu is the remaining check (open/close, slider
  feedback, quick-load confirmation flow) — listed in the residual section
  because it requires a human.

## Performance observations

- Node count 137 (was 113) — within every budget. No frame-budget change:
  the overlay is hidden unless opened.

## Known deviations from spec

1. **Esc no longer resets the DIG tool** — it opens settings; key 1 keeps
   that role. Recorded as a deliberate keybinding change (docs/ux/11 does
   not assign Esc).
2. The Phase 4 node budget rose 125 → 150 for the overlay's node tree
   (same pattern as the two earlier raises, rationale in code).

## Residual risks / issues

1. Checkbox glyphs use the default dark theme and read faintly on the dark
   panel; cosmetic polish is deferred unless playtests flag it.
2. The gate decision (GO / ITERATE / NO-GO) is pending PM playtests using
   `docs/qa/19_PLAYTEST_KIT.md`; the checklist's manual rows (#2 feel, #11)
   need the PM.
3. Volume changes apply live but have no test feedback cue (no test tone);
   sliders verify by ear during play.

## Gate status

- Functional acceptance: automated rows all backed by green gates; PM manual
  rows outstanding.
- Design acceptance: pending external naive playtests (kit provided).
- **No GO/ITERATE/NO-GO verdict is claimed by this report.**

## Commits

- Commit A `feat:` — Phase 12 settings overlay, playtest kit support changes
- Commit B `docs:` — playtest kit, completion report, checklist, changelog
