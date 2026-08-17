# Repository Audit & Implementation Assumptions

**Date:** 2026-08-18
**Authority:** Records implementation evidence and provisional choices only. It does not amend locked product decisions.

## Baseline found

- The starting repository contained 38 Markdown files and no `project.godot`, GDScript, scenes, tests, assets, build configuration, screenshots, Git metadata, commits, or tags.
- All 111 checklist entries were initially unchecked; there was no prior milestone evidence.
- No legacy implementation existed to conflict with the current Decision Register.
- Godot `4.7.stable.official.5b4e0cb0f`, Git, Python 3.11, and ripgrep are available locally.

## Document consistency findings

No irreconcilable product-spec conflict was found. Two production-process ambiguities are resolved conservatively:

1. Roadmap Phase 9 references the complete Vertical Slice acceptance even though persistence hardening and art integration occur in Phases 10–11. Phase 9 is therefore treated as the integrated flow/usability pre-gate; the complete functional, design, and visual decision gate remains Phase 12 after Phases 10–11.
2. The QA plan's mandatory smoke list includes systems that do not exist during early phases. `tests/smoke_manifest.json` explicitly marks checks as `PASS`, `FAIL`, or `SKIPPED_NOT_IMPLEMENTED` with a target phase. Skips must become executable checks when their target phase lands; all checks are mandatory by RC.

## Product gaps to resolve at their owning milestone

These do not block Phase 0–8 engineering, but may not be silently locked:

- exact Final Home completion and seasonal failure conditions;
- General Material source/economy and Root food yield/regeneration;
- an explicit useful stable-state benefit for retained wet space;
- complete discovery contracts for Foundation/Pipes and Old Burrow;
- per-phase quantitative gates for Phases 13–17;
- seed-batch target success rate and final hardware/performance matrix.

## Provisional implementation defaults

- Desktop keyboard/mouse is the mandatory first target. Mobile remains open under O-013.
- Logical cell size `16`, chunk size `16`, Vertical Slice map `96×72`, and initial population `3` are config values, not architecture constants.
- Worldgen seed `137042`, repair passes `4`, and attempts `3` are harness defaults only.
- Development, QA, and Release are explicit profiles. Release disables debug tools, verbose logging, and cheats.
- The current renderer and launch screen are engineering placeholders. O-001/O-002 remain open until camera/readability tests; no placeholder is Production Art.
- Save schema and worldgen version start at `1`; persistent state implementation begins incrementally when Phase 1 domain data exists.

## First implementation order

Follow the repository Roadmap and gate each phase. In particular, do not expand Chapters 2–3 until the complete Vertical Slice design gate demonstrates that players can dig freely but care where they dig next.
