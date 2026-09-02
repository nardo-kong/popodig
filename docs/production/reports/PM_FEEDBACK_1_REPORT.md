# Completion Report — PM Feedback Round 1 (Tutorial + Feel)

## Status

**PASS.** Three PM-reported items fixed/implemented after the Phase 17
release-candidate verification: the tutorial dead-end after the root-found
step, the single-founding-mouse start, and the dark excavation feel
(fog of war). Digging is 2× slower. **1264/1264 automated assertions pass**
and the full `validate.ps1` prints `VALIDATION_PASS` (single founding mouse
visible in the world log).

**Follow-up (2026-09-02):** PM play at a maximized window exposed two fog
defects — draw coverage collapsed above the 1280×720 base size, and
undiscovered cavities leaked spoiler halos. Fixed; **1269/1269**,
`VALIDATION_PASS` with a new 1920×1080 fog evidence gate. See §5–6.

## 1. Tutorial dead-end after "build a forage zone" (bug)

The `root_found` step instructs the player to plan a Food/Forage zone, but
no step keyed on that completion — the tutorial silently waited for a
moisture clue instead. Fixed:
- `ContextTutorialModel.STEPS` gains a **forage** step between root_found
  and moisture, requiring the new `forage_ready` flag.
- `game_app._update_tutorial_flags` sets `forage_ready` when a **valid,
  set-up Food/Forage zone** exists.
- Texts: root_found now hands off ("…plan Food/Forage space beside it"),
  the new forage step acknowledges completion and points at the next signal
  ("watch the soil for damp traces").
- Save note: `progression.tutorial_step` stores an index; the inserted step
  shifts later indices by one for saves made before this change (cosmetic —
  the player may see one earlier sentence again; clamped and forward-safe).

## 2. Single founding mouse (design change)

- `initial_mouse_count` 3 → 1 in `config/balance/core.json`.
- Population now grows through the milestone system (+2 at Chapter 2, +2 at
  Chapter 3), so the colony earns its mice — spec 10 §14 exactly.
- **Recorded deviation:** docs/qa/18 §3 says "3 mice initially" for the
  vertical slice; overridden by PM direction. The milestone-growth arc
  supersedes it.
- Test infrastructure updated: the Phase 3 colony smoke and the QA
  colony/zone demos explicitly top up to three mice (`_ensure_qa_mice`,
  no cheat gate) because they benchmark three-mouse haul concurrency; the
  Phase 4 sleeping floor lowered to 1; the Phase 2 smoke expects exactly
  one founding mouse whose state may already be working (it claims the demo
  dig immediately). The Phase 2 drag fixture now cancels pre-existing demo
  designations so its counts are demo-independent (the fixture silently
  relied on overlap semantics before).

## 3. Slower digging (feel)

- `digging.base_dig_seconds` 0.8 → **1.6** (2× dig time per hardness point;
  `dig_work_per_second` unchanged). No smoke budget needed changing: the
  Phase 2 dig wait runs on a 200 s simulation-tick ceiling.

## 4. Fog of war — dark unexplored ground (feel)

- `src/presentation/world/fog_of_war_view.gd` (new): pure static
  `compute_visibility` — multi-source BFS from every open + surface cell;
  distance 0 fully lit, `balance.fog_radius` (default 4) and beyond fully
  dark, linear fade between. The surface band stays lit (the garden reads),
  the underground darkens away from your digging.
- Rendered as one Node2D above every world visual (mice/props included) but
  below the cursor and HUD; recomputes on terrain changes (throttled to
  4 Hz) and draws only camera-visible cells. Presentation-only — no
  simulation, save, or signal-truth changes; debug overlays sit above it.
- Evidence: `art/qa/screenshots/phase_16_fog_of_war.png` (new validate
  gate) — single mouse in the lit start burrow, world fading to darkness.
- 5 unit tests: lit excavated cells, monotonic fade, lit surface, full dark
  beyond radius, determinism.

## 5. Follow-up — fog of war regression found in PM play (fixed)

PM report during play (maximized window): "黑暗的遮罩完全失败". Two stacked
defects, both fixed; a third, minor, staleness gap closed.

**5.1 Draw coverage collapsed above the base window size (primary).**
`_visible_world_rect()` mixed coordinate spaces: it fed
`get_visible_rect().size` (base-viewport units — 1280×778 under the
`canvas_items`/`expand` stretch) into the inverse of
`CanvasItem.get_viewport_transform()` (which includes the stretch
final transform, i.e. expects window pixels). With the window larger than
the 1280×720 base (PM's ~1972×1200), the computed rect covered only the
window's top-left ~66%×65%, so fog rects were drawn nowhere else — the rest
of the frame rendered fully bright. Invisible at exactly 1280×720 (stretch
scale 1), which is how the original QA gate and this report's evidence
screenshot passed while live play failed. Fixed by deriving the visible rect
from `get_canvas_transform()` (canvas → base-viewport units, no stretch) and
converting through the node's global transform.

**5.2 Undiscovered cavities leaked spoiler halos (data).** Fog sources were
"every traversable cell", but `natural_cavity` / `old_burrow` /
`warm_chamber` cells are excavated at worldgen while still `hidden` — each
undiscovered cavity acted as a lantern. Probe on seed 137042: 188 of 242
underground open cells belonged to hidden features; 66% of lit underground
area was halos around content the player had never seen, visible through
solid rock. Hidden feature cells are now excluded from the source set
(`configure` takes the feature registry); cells light up when their feature
is discovered (`feature.hidden = false` already marks chunks dirty, which
drives the recompute). Natural BFS bleed into a cavity you tunnel beside
remains — that is the intended Signal → Reveal partial-information leak.
Side benefit: the fog now enforces "undiscovered = unseen" for open rooms
that the base renderer draws regardless of `hidden` (which only gates
dressing/cues).

**5.3 Camera pan/zoom staleness.** `queue_redraw` previously fired on
simulation events only; panning into fresh frames showed no fog until the
next dig. A changed visible rect now counts as stale (same 4 Hz throttle).

**QA process fix.** The root cause of the miss was evidence accepted without
critical review: the original `phase_16_fog_of_war.png` visibly contained
bright halo columns inside unexplored rock (defect 5.2) and should have
failed review. The validate gate now captures fog evidence at **both
1280×720 and 1920×1080** — defect 5.1 only manifests above the base size,
so the second resolution is the regression gate. Both captures passed judge
review; per-cell band luminance profiles are identical across the two
resolutions (≤0.02 difference, antialiasing noise).

## 6. Follow-up verification

- **1269/1269** automated assertions (+5: hidden-feature cells stay fully
  dark — including a pin of the old leaking behavior — player cells lit,
  discovery turns a hidden feature into a light source).
- Full `tools/validate.ps1`: **VALIDATION_PASS**, now including the
  1920×1080 fog capture + screenshot validation.

## Files changed (follow-up)

- `src/presentation/world/fog_of_war_view.gd` (visible-rect space fix,
  registry-aware sources, viewport staleness),
  `src/presentation/app/game_app.gd` (registry passed to fog),
  `tests/unit/test_fog_of_war.gd` (+2 cases / +5 assertions),
  `tools/validate.ps1` (1920×1080 fog capture gate),
  `art/qa/screenshots/phase_16_fog_of_war.png` (regenerated),
  `art/qa/screenshots/phase_16_fog_of_war_1920.png` (new)

## Commits (follow-up)

- Commit C `fix:` — fog of war: full-window coverage at any window size,
  undiscovered features no longer light halos, camera-move redraw
- Commit D `docs:` — this follow-up, changelog

## Files changed

- New: `src/presentation/world/fog_of_war_view.gd`,
  `tests/unit/test_fog_of_war.gd`, this report,
  `art/qa/screenshots/phase_16_fog_of_war.png`
- Modified: `context_tutorial_model.gd` (forage step), `game_app.gd`
  (forage flag, `_ensure_qa_mice`, fog wiring), `config/balance/core.json`
  (1 mouse, 1.6 s dig, fog_radius), `config/app.json` (worldgen unchanged),
  `assets/localization/ui.csv` (+2 tutorial keys),
  `tools/validate.ps1` (fog capture gate),
  `tests/phase2_playable_smoke.gd`, `tests/phase3_colony_smoke.gd`,
  `tests/unit/test_context_tutorial.gd`, `tools/qa/benchmark_phase4_zones.gd`

## Godot version used

Godot 4.7.stable (unchanged).

## Automated tests

- **1264/1264 PASS** (+19: fog suite 13, tutorial forage assertions,
  adjusted spawn/fixture checks).
- Full `tools/validate.ps1`: **VALIDATION_PASS** (dev+release smokes,
  benchmarks, seed batch, all screenshot gates).

## Known deviations from spec

- docs/qa/18 "3 mice initially" → 1 founding mouse + milestone growth, per
  PM direction (recorded above and in the checklist).

## Residual risks / issues

1. Fog radius (4) and darkness alpha are feel parameters — trivially
   tunable via `balance.fog_radius` after a look at real play.
2. The signal-clue visuals (root threads, moisture patches) only render on
   cells near your digs now — by design under fog, but it makes the
   Phase 6 external cue-readability gate more important.
3. Old saves restoring mid-tutorial may re-show one earlier sentence
   (index shift); harmless.

## Commits

- Commit A `feat:` — tutorial forage step, single founding mouse, slower
  dig, fog of war
- Commit B `docs:` — feedback report, changelog
