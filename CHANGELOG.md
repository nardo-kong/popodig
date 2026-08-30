# Documentation Changelog

## Implementation sync — 2026-08-30
- Completed Phase 10 Save/Load & Hardening: versioned JSON saves (schema v2) with sequential v1→v2 migration, atomic writes with .corrupt preservation, full domain serialization (world-grid RLE, features, colony/zones/items, signals, water, stability), F8/F9 quick save/load plus autosave, and persisted tutorial/language progression.
- Added six committed save fixtures (new game, zones/mice, root reveal, active water breach, post-collapse, v1 migration) with a regenerating exporter, a mid-breach dual-instance save smoke with spec §16 acceptance checks and timings, and validate.ps1 Phase 10 gates. 984/984 automated assertions pass.
- Post-delivery follow-up (user decision): quick-load kept on F9 — the editor-pause side effect is understood and resumable via the toolbar; Ctrl+S quick-save unchanged.
- Post-delivery follow-up: the first Ctrl+L binding was shadowed by the bare-L language toggle (match on keycode ignores modifiers); Ctrl+L now quick-loads and bare L still toggles language.
- Post-delivery fix (user acceptance): quick-load rebound from F9 to Ctrl+L — F9 is also the Godot editor debugger pause shortcut, so an editor-launched game reloaded fine but came up paused. Acceptance also confirmed the "freeze" reports resolved once unpaused.
- Post-delivery fix (user acceptance): F9 freeze in editor-embedded sessions — quick-load (and F5/F6 seed replay) now defer reload_current_scene out of the input callback instead of tearing the scene tree down while the F9 key event is still being processed.
- Post-delivery fix (user acceptance): F9 load-order bug fixed — bulk world restore bypassed per-cell change signals so the path service walkability cache still reflected the fresh generated world, failing colony restore (0 mice, half-loaded hybrid state). The path service now rebuilds after world restore, and a mouse whose saved cell is unwalkable recovers at the nearest walkable colony cell (spec §5 safe fallback) instead of failing the whole load. Phase 10 smoke now parks a mouse inside a save-only tunnel before saving.
- Post-delivery fix (user acceptance): F9 quick-load no longer prints a viewport-null script error — during reload_current_scene the old instance still receives queued input while detached from the tree; _unhandled_input now guards get_viewport().
- Post-delivery fix (user acceptance): quick-save rebound from F8 to Ctrl+S — F8 is the Godot editor stop-project shortcut and closed editor-launched game sessions before the input arrived. F9 quick-load unchanged.
- Post-delivery fix (user acceptance): tutorial label froze and errored on every step advance (nonexistent current_text() called in two places); now resolves the step key. Hardened the phase 9 smoke refresh check (was vacuous under the en default) and made validate.ps1 scan SCRIPT ERROR lines.
- Fixed hardening bugs found by the new tests: Packed-array value-semantics bug in world-grid RLE decode, Vector2i metadata loss after JSON file round-trip, pending-load ordering crash before tutorial init, and stale Phase 1/Phase 2 scene-smoke gates (node budget 100→160; dual-mode inspector now expected visible in every profile).

## Implementation sync — 2026-08-26
- Completed Phase 9 Slice UX: compact player HUD with slice depth objective, dual-mode context inspector (qualitative player mode / numeric debug mode), ten-step contextual first-ten-minutes tutorial, deduplicated event notification queue with camera focus helpers, and Space pause control.
- Added bilingual zh/en localization: CSV translation pipeline (~100 keys), follow-system default with L-key runtime toggle and QA language override; all player-facing strings (HUD, tutorial, notifications, reasons, clues, inspector) migrated to translation keys. Debug-only chrome remains English.
- Localized all player-facing strings to both languages; added localization/notification/tutorial unit tests, Phase 9 UX smoke (Development/Release), four visual-QA captures (zh ×3, en ×1), and validate.ps1 gates. 915/915 automated assertions pass.

## Implementation sync — 2026-08-25
- Completed Phase 8 Stability engineering: material span budgets, four-level warning bands with critical grace, bounded-radius collapse with rubble refill, autonomous material-funded reinforcement, root/stone local supports, mouse danger avoidance, and zone/item/topology consistency on collapse.
- Added legible rubble state (compact cell flag + placeholder speckle), REINFORCE tool, STABILITY WARNINGS debug overlay, inspector stability lines, and Phase 8 Development/Release smokes with four visual-QA captures.
- Integrated Art Pass 01 production terrain (128 px/cell contract, atlas renderer with grouped draw passes, mipmap policy) and the toggleable golden mouse master temporary hybrid presentation.
- Standardized all candidate asset names to English conventions.
- Recorded 821/821 automated assertions passing with all Development/Release smokes; seed-batch p95 timing gate documented as environment-sensitive (content 288/288 valid, 0 replay mismatches).

## Implementation sync — 2026-08-18
- Completed Phase 7 finite Water engineering: Moisture clues, reservoir lifecycle, bounded discrete flow, stable-pool sleep, breach/escape recovery, wet-zone emergency hauling, material-funded seals, topology updates, and conservation tests.
- Added Phase 7 Development/Release smokes, isolated performance benchmark, five deterministic visual-QA captures, technical architecture notes, and completion report.
- Recorded worldgen v3 Signal Fields and the Phase 6 Root lifecycle implementation.
- Added the Phase 6 engineering report, QA evidence, performance results, and explicit open naive-player/full-validation gates.

## v1.0 — 2026-08-17
- Consolidated original Dig Down concept into implementation-ready project documentation.
- Locked free-digging systemic sandbox positioning.
- Replaced route-choice interpretation with Decision Frontier / Decision Knot model.
- Defined structured finite-world PCG pipeline.
- Defined Signal Field discovery grammar.
- Defined tile-level finite water and local stability abstractions.
- Defined autonomous minimal mouse colony and zone model.
- Added Godot 4.7 architecture, save, QA, performance, art integration, production, Codex execution, and risk specifications.
