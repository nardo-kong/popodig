# Completion Report — Phase 15 Chapter 3: Old Burrow

## Status

**PASS.** The campaign arc is complete end to end: the old burrow assembles
from authored prefab mutations, buried Chapter 3 landmarks reveal through
adjacent excavation with their own discovery stingers, the warm chamber
reads as the final home (warm dressing + a set-up sleeping zone inside it
completes the campaign), and old-burrow cells carry spatial-storytelling
relic dressing. **1179 automated assertions pass**, the 288-seed batch is
**288/288 valid at 100% raw rate** (p95 463.31 ms), and the full
`validate.ps1` prints `VALIDATION_PASS`. Runs under the PM's end-to-end
authorization.

## Scope completed

### Prefab mutation system
- `structured_world_generator.gd`: `OLD_BURROW_MUTATIONS` — three authored
  prefab mutations chosen deterministically per seed and recorded in
  `metadata.mutation`:
  - **two_room_sealed** (the original two-hall layout with a connecting
    corridor);
  - **collapsed_wing** — a second wing partially choked with authored weak
    cells (loose soil at terrain fill), so the old shortcut exists but must
    be re-dug through weak terrain;
  - **triple_nest** — three chamber hints around the main hall, reading as
    the old family nest.
  All mutations keep the required-landmark contract (anchor + approach
  cells), so the validator and witness constraints hold unchanged.

### Old-burrow landmarks & discovery
- Old burrow and warm chamber were previously never-revealing metadata;
  they now reveal through the standard Signal → Reveal courtesy: digging a
  cell cardinally adjacent to either hidden landmark reveals it, fires a
  long-lived localized discovery notification and the discovery stinger,
  and dirties the region so the dressing appears. Reveal state persists
  through the existing feature-registry save path.

### Final warm chamber & campaign completion
- GDD §14: the campaign completes when the final home is stable in the deep
  warm area. `ChapterModel` now gates Chapter 3 on **a set-up Sleeping zone
  intersecting the warm chamber's cells** (`warm_home_ready`), flipping
  `campaign_complete` exactly once (persisted; the celebration notification
  does not replay on reload).
- Completion surfaces as a warm-chamber-anchored campaign notification +
  stinger, and the HUD objective line gains a "✦ 家园落成" suffix.
  Post-completion sandbox continues by design (GDD §14).

### Spatial storytelling dressing
- Revealed old-burrow cells draw one of three faint relic marks per
  deterministic cell hash — a faded nest ring, scattered hoard debris, or
  twig remains (alpha ≤ 0.34, well under signal cues per art bible §4).
- Warm-chamber cells carry a soft warm tint plus occasional glow specks, so
  the final home reads warm before any UI says so.

## Files changed

- Modified: `structured_world_generator.gd` (mutation prefabs + weak-cell
  fill), `chapter_model.gd` (chapter 3 gate + campaign completion),
  `game_app.gd` (buried-landmark discovery, warm-home context, celebration
  persistence, HUD suffix), `world_chunk_view.gd` (landmark dressing),
  `config/worldgen/default.json` (v6), `config/app.json` (v6),
  `assets/localization/ui.csv` (+4 keys),
  `tests/unit/test_chapter_model.gd` (campaign completion suite),
  `tests/unit/test_structured_worldgen.gd` (mutation + warm chamber
  assertions)

## Godot version used

Godot 4.7.stable (unchanged).

## Import/parse status

Headless import PASS; zero parse errors.

## Automated tests

- **1179/1179 PASS** (+15: campaign completion lifecycle, mutation
  membership + cross-seed variety, warm chamber placement in the deep band).
- 288/288 seed batch valid, 100% raw rate, 0 repairs, 0 replay mismatches,
  p95 463.31 ms — PASS.
- Full `tools/validate.ps1`: **VALIDATION_PASS**.

## Manual/visual QA + screenshots

- Regenerated phase captures under worldgen v6 (validate gates green).
  The old burrow's dressed interior is visible whenever a capture passes
  near the deep band; relic marks are intentionally subtle (alpha ≤ 0.34).
- A campaign-completion screenshot would require playing ~60+ minutes to
  the warm chamber; the completion path is covered by the chapter-model
  suite and left for the PM's Chapter run.

## Performance observations

- Seed batch p95 463.31 ms (budget 600 ms) — within budget.
- Landmark dressing is two to four draw calls per revealed landmark cell,
  dirty-driven like all static overlays; runtime benchmarks unchanged.

## Known deviations from spec

1. Worldgen version bump (v6) invalidates pre-v6 saves by design.
2. "Spatial storytelling dressing" is procedural (hash marks), not authored
   art pieces — consistent with the Phase 11 procedural-production decision;
   authored relic sprites remain a candidate when art candidates arrive.

## Residual risks / issues

1. Campaign completion conditions (sleeping zone inside the warm chamber)
   are testable but untuned by a real playthrough; the warm chamber is deep
   (~86% band), so the endgame trek length may need pacing in Phase 16.
2. Discovery notifications share the notification queue's cooldown; digging
   into both landmarks in quick succession stacks two rows (acceptable).
3. The `collapsed_wing` weak fill uses loose soil — under the Phase 14 wet
   rule, a flooded collapsed wing becomes genuinely dangerous (intended, but
   unvalidated by playtests).

## Completion checklist status

Phase 15 items: prefab mutation system ✔; old-burrow landmarks ✔ (discovery
reveal + dressing); spatial storytelling dressing ✔; final warm chamber ✔
(warm dressing + completion condition); campaign completion ✔
(`campaign_complete` + HUD + notification; post-completion sandbox
continues).

## Commits

- Commit A `feat:` — Phase 15 old burrow mutations, discovery, campaign
  completion
- Commit B `docs:` — Phase 15 report, checklist, changelog
