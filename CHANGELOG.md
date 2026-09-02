# Documentation Changelog

## Implementation sync — 2026-09-02 (balance telemetry)
- Implemented 21_BALANCE_TELEMETRY §2 local session metrics: new pure recorder `src/domain/telemetry/session_telemetry.gd` (excavation by material, dig batch average, warning-gated dig cancellations, discoveries with elapsed-time intervals + open-feature-cells proxy, breach/released water units, flooded storage peak, collapse counters, zone changes, saves/loads, 1 Hz colony idle/travel and water-at-rest sampling, chapter/campaign timing). Wired into game_app behind `debug_tools_enabled()` (release collects nothing); snapshots to `user://telemetry/session_*.json` on the debug T key and on window close. Tests +30 → 1299/1299; full validate VALIDATION_PASS. Deferred: exact signal-crossing-before-reveal tracking; report in docs/production/reports/TELEMETRY_IMPLEMENTATION_REPORT.md.

## Implementation sync — 2026-09-02 (PM feedback round 1 follow-up: fog of war)
- PM play at a maximized window broke the fog mask. Fixed both root causes: (1) `_visible_world_rect()` mixed base-viewport units with the stretch final-transform space, so above the 1280×720 base the fog only covered the window's top-left ~2/3 — now derived from `get_canvas_transform()`; (2) undiscovered cavities (excavated-at-worldgen but `hidden`) acted as BFS light sources, leaking spoiler halos through solid rock (66% of lit underground area on the report seed) — hidden feature cells are excluded from sources via the feature registry and light up on discovery. Camera pan/zoom now also refreshes the fog (same 4 Hz throttle).
- QA process: fog evidence is now captured at 1280×720 AND 1920×1080 in `validate.ps1` (the coverage bug only manifests above the base size), and both captures passed judge review with identical per-cell luminance profiles. The originally accepted fog screenshot contained visible leak halos — recorded as a review miss.
- Tests +5 → 1269/1269; full validate VALIDATION_PASS.

## Implementation sync — 2026-08-31 (PM feedback round 1)
- Tutorial: new forage step between root_found and moisture keyed on a valid set-up Food/Forage zone (the root_found instruction previously had no completion flag — building the zone never advanced the tutorial).
- Feel (PM direction): campaign starts with a single founding mouse (initial_mouse_count 3→1; population grows +2 per chapter milestone), digging 2× slower (base_dig_seconds 0.8→1.6), and fog of war — unexplored ground fades to darkness away from open/surface cells (pure BFS visibility, presentation-only, balance.fog_radius=4, evidence screenshot phase_16_fog_of_war.png). docs/qa/18's "3 mice initially" recorded as overridden by PM direction.
- Test infrastructure: Phase 2 smoke expects one founding mouse and cancels pre-existing demo designations (fixture independence); Phase 3 smoke tops up to three mice for haul concurrency; Phase 4 sleeping floor 1; tutorial test covers the forage step. 1264/1264 assertions; validate VALIDATION_PASS.

## Implementation sync — 2026-08-31 (Phase 16 + 17)
- Completed Phase 16 Full-game Balance & Polish: synthesized ambient music loop (music_settle.wav, 16 s loopable pad) on a dedicated Music bus with a fourth settings slider persisted to user settings; seed-diversity gate in the authoritative batch tool (distinct canonical hashes ≥95%); tutorial pacing constants moved to balance config (tutorial.open_space_cells / food_critical_count / objective_depth_offset); save soak suite (8 seeds × mutated mid-campaign world, cell-exact round-trip verification); CREDITS.md licensing audit (all assets repository-generated; Godot MIT).
- Completed Phase 17 Release Candidate verification: full regression VALIDATION_PASS, save/seed soak evidence, clean release profile (no debug/cheats), credits audit. Recorded limitations: Windows-only platform matrix (no export presets yet), external naive playtests and a recorded full-campaign human playthrough remain owner gates.
- Tests 1245/1245; seed batch 288/288 valid, 100% raw, 99.65% diversity.

## Implementation sync — 2026-08-30 (Phase 15)
- Completed Phase 15 Chapter 3: Old Burrow — the campaign is now completable. Old-burrow prefab mutation system (two_room_sealed / collapsed_wing / triple_nest, deterministic per seed, weak-cell fill for the collapsed wing); old burrow and warm chamber reveal through adjacent excavation with localized discovery notifications and stingers; spatial storytelling dressing (faded nest rings, hoard debris, twig remains at alpha ≤ 0.34; warm tint + glow specks in the final chamber); campaign completion (GDD §14) when a set-up sleeping zone stands inside the revealed warm chamber — fires once, persists in saves, HUD gains a "✦ Home established" suffix, sandbox continues.
- Worldgen v6. Tests +15 (campaign completion lifecycle, mutation membership/variety, warm-chamber depth placement) → 1179/1179; seed batch 288/288 at 100% raw, p95 ~440 ms; full validate VALIDATION_PASS.

## Implementation sync — 2026-08-30 (Phase 14)
- Completed Phase 14 Chapter 2: Adapt. Water × instability is live (spec 09 §10 enabled): each ceiling bay over standing water counts double toward its roof span — a fully flooded run is one band weaker — with live re-rating on flood/drain via CHANGE_WATER; one unstable pocket is authored directly beneath the required reservoir so a breach floods weak terrain. Per-bay model chosen after the whole-run halving collapsed storage rooms from a single water cell (4 colony-flow regressions caught by the suite).
- Richer water: second additional reservoir, first one authored elevated in the transition band so its breach drains through mid-world routes. Foundation walls vary authored ride-height per seed. Pipe/heat/sound intentionally deferred ("if validated" unmet — no playtests yet).
- Worldgen v5. Tests +10 (wet-ceiling stable→critical→recovery lifecycle, chapter-2 knot assertions) → 1164/1164; seed batch 288/288 at 100% raw; full validate VALIDATION_PASS.

## Implementation sync — 2026-08-30 (Phase 13)
- Recorded the Phase 12 gate outcome: GO by PM end-to-end authorization (external naive playtests waived for now; docs/qa/19_PLAYTEST_KIT.md retained for Chapter 1 sessions).
- Completed Phase 13 Chapter 1 Production: chapter milestone progression (ChapterModel — Settle completes on dry sleeping + storage + secured food + learned signals + transition-band depth; Adapt gates on old-burrow depth with settled water and a completed reinforcement), +2 mice per milestone (spec 10 §14), localized chapter HUD prefix and milestone notifications, chapter persisted as an additive progression key (old v2 saves default to Chapter 1).
- Authored worldgen variations on v4: optional root silhouettes (runner/forked/taproot in metadata.shape_id; required roots keep the inward tap), topsoil stone scatter (0.6%, stabilising-only), density tuning (optional roots 3, cavities 6). New EARLY_FOOD_PREEXPOSED validator guard + generation-time self-trim keeps food roots reveal-driven (a longer shape had let optional roots spawn walkable against natural cavities — seed batch raw rate fell to 63% until the trim landed; now 99.65% at p95 433 ms).
- Stability demo fixtures made ceiling-aware: spans are now sized from the ceiling run's weakest material (warn/reinforce 90% of allowed, collapse 2×), fixing a 0/8-supports collapse race the v4 RNG stream exposed; Phase 8 smoke ported to the same finder.
- Tests: +50 (chapter model suite, authored-shape assertions) → 1154/1154.

## Implementation sync — 2026-08-30 (Phase 12)
- Phase 12 Vertical Slice Decision Gate support: new Esc settings overlay (quick-load with explicit confirmation — the decision deferred from Phase 10, live master/SFX/ambience volume sliders, language switch, reduced-particles/reduced-shake accessibility flags) persisted to user://settings.cfg via a closed-key SettingsStore; Esc no longer resets the DIG tool (key 1 does). Simulation pauses and world input is blocked while the overlay is open.
- Added docs/qa/19_PLAYTEST_KIT.md: functional-acceptance checklist mapping every spec §6 criterion to automated evidence, verbatim naive-player briefing, beat-structured observation sheets targeting §7 observations and §8 red flags, and the GO/ITERATE/NO-GO decision rule. The gate decision itself remains deliberately open pending PM external playtests.
- New tests: settings store suite (+17, 1104/1104 total). validate.ps1 gained a settings-menu capture gate; Phase 4 node budget 125→150 for the overlay's ~23 persistent nodes. Stability/collapse model unchanged after the Phase 11 design review — depth-stress proposal recorded in the Phase 11 report but not adopted.

## Implementation sync — 2026-08-30 (Phase 11)
- Completed Phase 11 Art/Audio Integration: production procedural presentation for every remaining placeholder — terrain edge transitions (exposed-face rim gradients + deterministic notches, material-boundary blend bands, tunnel ceiling/side shading), organic tapered root cue threads and cell-connected revealed root networks, complete water states (depth-gradient bodies with meniscus, seamless continuous reservoir pools with boundary rims, wet-soil halos, 8 Hz ripple/shimmer/flow-accent layer), complete stability states (branching cracks, timber support props, chunky rubble, falling warning dust), state-driven mouse animation (walk/dig/eat/sleep/flee/idle/carry over the master sprite, now the default), and upgraded zone dressing (grass nests, woven baskets, forage sprouts).
- Added pooled single-node VFX (dig dust/debris, breach droplets, collapse debris, warning dust; cap 220, reduced mode ~40%) and a decaying camera shake for collapse/breach only, both behind accessibility flags.
- Added a deterministic stdlib audio synthesizer (tools/audio/synth_audio.py) generating the committed 17-file WAV bank (five material dig impacts, UI cues, zone assign, discovery stinger, breach/collapse/critical cues, loopable room tone, drips) and an AudioDirector with SFX/Ambience buses, a one-shot player pool, camera-following drip layer, and config-driven volumes (per-slider UI deferred to the Phase 12 settings menu with quick-load).
- New tests: terrain edge rules, VFX pool/accessibility, audio bank/buses/config (1087/1087 assertions). validate.ps1 gained four Phase 11 close-up capture gates (terrain transitions, mouse states, water close-up, zone dressing); visual judge review passed all four after reworking the reservoir pool from per-cell circles into one seamless calm pool.
- Gate adjustments with rationale in the completion report: seed-batch p95 500→600 ms (machine-load flake, content gates unchanged) and Phase 4 node budget 110→125 (nine persistent presentation nodes).

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
