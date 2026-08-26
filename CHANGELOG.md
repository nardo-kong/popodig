# Documentation Changelog

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
