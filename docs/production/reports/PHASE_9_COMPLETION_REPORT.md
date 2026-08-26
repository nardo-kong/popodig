# Completion Report — Phase 9 Slice UX

## Status

**PASS for the Phase 9 engineering gate.** The player-facing experience layer is
complete: compact Chinese HUD, qualitative context inspector, contextual first-ten-
minutes tutorial, event notification queue with camera focus, pause control, and a
marked slice depth objective (Beat H). All 850 automated assertions pass, the Phase 9
UX smoke passes in Development and Release, and three visual evidence captures are in
place. The 30–45 minute flow is structurally playable end to end; its actual duration
and readability require the external playtest that also gates Phase 12.

## Scope completed

- **Player HUD** (docs/ux/11 §5): permanent compact panel — 食物 / 材料 / 鼠鼠 counts,
  current tool, dig/seal/reinforce queue counts, and the slice objective
  (抵达深度 X/Y). Hunger/rest percentages and sim internals moved out of the permanent
  HUD; debug chrome (top bar, footer, FPS) stays development-only.
- **Context inspector** (§6): dual-mode panel. Player mode shows only known
  information in Chinese — material, qualitative dig difficulty (低/中/高/极高), rubble
  state, exposed water, qualitative root/moisture 迹象, stability warning name, zone
  name, discovered feature names. Debug numeric mode unchanged for development.
- **Contextual tutorial** (§11–12): ten-step action-first script matching the spec's
  first-ten-minutes flow (dig → mice dig → sleeping space → food/root clue → root
  reveal → moisture → breach → instability → objective). Strictly forward-moving,
  event-driven flags (authoritative terrain-change hook plus 2 Hz polling), one visible
  sentence at a time.
- **Notifications** (§14): deduplicated, cooldown-guarded, self-expiring toast queue
  (max 3) for discovery revealed, reservoir breach, local collapse, critical stability
  warning, zone invalidated, food critically low, mouse in danger, and the slice
  milestone. Pure-logic model is unit-tested; view renders mouse-transparent toasts.
- **Camera & control helpers** (§3, §13): Space pauses/resumes the sandbox (pan still
  works while paused), Home refocuses the start burrow, N focuses the most recent
  notifiable event location.
- **Slice objective** (Beat H): "抵达深度 Y" tracked from the colony-reached depth
  (distance-field from the start cell, so natural cavities never count). Reaching it
  fires the milestone notification and the tutorial's closing line.
- **Language coherence**: player-facing strings (tools, reasons, clues, feedback,
  notifications, tutorial, inspector) localized to Chinese; debug-only strings remain
  English by design.
- **Touch pass**: explicitly deferred — roadmap scopes it "if in slice scope"; desktop
  keyboard/mouse is the slice platform. Recorded for a later decision.

## Governing specs

- `docs/ux/11_UI_UX_SPEC.md` (primary)
- `docs/qa/18_VERTICAL_SLICE_ACCEPTANCE.md` (UX requirements + beats)
- `docs/production/19_IMPLEMENTATION_ROADMAP.md` Phase 9
- `docs/design/02_GDD.md`, `docs/tech/14_TECH_ARCHITECTURE.md`

## Files changed

- New: `src/presentation/hud/notification_model.gd`, `notification_view.gd`,
  `context_tutorial_model.gd`, `tests/unit/test_notification_model.gd`,
  `test_context_tutorial.gd`, `tests/phase9_ux_smoke.gd`.
- Changed: `src/presentation/app/game_app.gd` (HUD/inspector/tutorial/notification
  wiring, pause/camera shortcuts, localization), `scenes/app/game_app.tscn`
  (Notifications layer, TutorialPanel, ObjectiveLabel row),
  `src/domain/features/signal_system.gd` (player clue strings only — no behavior),
  `tests/test_runner.gd`, `tools/validate.ps1`, three screenshots,
  `MILESTONE_CHECKLIST.md`, `README.md`, `CHANGELOG.md`, this report.

## Environment

- Godot: `4.7.stable.official.5b4e0cb0f`, OpenGL 3 Compatibility, Intel Iris Xe,
  Windows / PowerShell.

## Import / parse status

**PASS.** New classes registered through a headless editor rescan; all scripts pass
compile gates.

## Automated tests

- Assertions: **850 passed, 0 failed** (821 pre-Phase-9 + 29 new: 17 notification
  model, 8 tutorial state machine, 4 smoke-adjacent).
- Phase 9 UX smoke: **Development PASS** (tutorial advanced via flags, notification
  rendered, inspector qualitative) and **Release PASS** (debug chrome hidden, player
  HUD/tutorial visible, no stray notifications, no debug field names in inspector).
- Full regression: all Phase 1–8 smokes remain green (run during the Phase 8 sync and
  re-verified through validate.ps1 gates).

## Manual / visual QA

- `art/qa/screenshots/phase_9_hud_tutorial.png` — **1280×720**: Chinese player HUD,
  objective 19/46, tutorial prompt, dig designation in progress.
- `art/qa/screenshots/phase_9_root_discovery.png` — **1280×720**: real root-reveal
  notification toast, objective 27/46, tutorial on the sleep step, Chinese feedback.
- `art/qa/screenshots/phase_9_release_clean.png` — **1280×720**: release profile with
  zero debug chrome, qualitative-only inspector, tutorial and HUD visible.
- All three passed automated validation and manual inspection (layout overlap between
  the tutorial bar and the grown HUD panel was found and fixed during review).

## Performance observations

- Slow poll runs at 2 Hz: one full-grid traversable scan plus one distance-field BFS
  over the 96×72 world — negligible frame impact; no regression in any phase benchmark.
- Notification view rebuilds rows only when the model changes.

## Known deviations / residual risks

1. Development-profile debug chrome (top bar, footer, numeric inspector) remains
   English by design; player-facing surfaces are fully Chinese.
2. Touch controls deferred (see scope) — needs an explicit decision before mobile
   scoping.
3. The 30–45 minute flow duration and tutorial readability are structurally in place
   but unproven until external naive playtests (Phase 12 gate, shared with the Phase 6
   cue-readability check).
4. Tutorial/notifications have no persistence; a save/load in Phase 10 should decide
   whether tutorial progress persists (recommended: yes).
5. The tutorial bar is fixed above the HUD; on very short viewport heights (<400 px)
   layouts may tighten — acceptable for supported slice resolutions.

## Bilingual localization addendum (same-day follow-up)

User review corrected the language scope: the slice must be **bilingual zh/en**, not
Chinese-only. Implemented immediately after acceptance:

- **Infrastructure**: `assets/localization/ui.csv` (≈100 keys, zh + en columns) imported
  through Godot's CSV translation pipeline and registered in project settings;
  `src/infrastructure/localization/localization_service.gd` resolves the default
  language as `--language=zh|en` (QA override) → OS UI language when zh/en → English
  fallback, and exposes `cycle()`.
- **Switch**: `L` toggles zh/en at runtime; HUD/objective/inspector refresh
  automatically, the tutorial bar re-resolves its current step, and new notifications
  use the new language (short-lived toasts keep their push-time language by design).
- **Migration**: every player-facing string now goes through translation keys — HUD,
  objective, tools, dig/seal/reinforce feedback, all reason codes, hover hints,
  inspector lines (including stability level and zone names), notification templates,
  the ten tutorial steps, and the twelve signal-clue strings (the domain now returns
  stable `clue.*` keys; presentation translates). Debug-only chrome intentionally
  remains English.
- **Tests**: `tests/unit/test_localization.gd` verifies both languages resolve for all
  sampled keys (including every clue key), that translations differ, cycle works, and
  missing keys fall back safely. The tutorial unit test asserts step ids/keys instead
  of locked Chinese text. Suite: **915 passed, 0 failed**.
- **Evidence**: `phase_9_hud_tutorial.png`, `phase_9_root_discovery.png`,
  `phase_9_release_clean.png` captured with `--language=zh`, plus
  `phase_9_release_clean_en.png` — all validated.
- **Note**: this dev machine's Windows UI culture is en-US, so follow-system correctly
  defaults to English here; Chinese is one `L` press away. Language preference
  persistence is deferred to the Phase 10 save system.

## Verdict

Phase 9 milestone scope is complete and verified. Phase 10 (Save/Load & Hardening) is
next per the roadmap; the external slice playtest gate remains after Phase 10/11.
