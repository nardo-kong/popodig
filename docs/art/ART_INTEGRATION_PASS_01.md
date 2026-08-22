# Art Integration Pass 01 — First Production Asset Replacement

**Status: PASS (automated gates) / visual acceptance pending user review of in-game screenshots**

## 1. Scope

First production art replacement for the 96×72 finite world. Only terrain center-material
tiles were integrated. Root signal cues, exposed root modules, water, stability, and mouse
production art remain **engineering placeholders** — their candidates were not provided or
are intentionally deferred.

Simulation, worldgen, validator, signal truth, balance values, and save semantics are
untouched. This is a presentation-only pass.

## 2. Baseline (before integration)

- Commit: `ff5b120` docs: record phase 7 completion
- Automated assertions: 691/691 PASS
- Windowed runtime benchmark (240×260 flat-color world): average_fps=626.66, p95_frame_ms=2.00
- Headless runtime benchmark: average_fps=143.83, p95_frame_ms=6.95
- Visuals: engineering-placeholder flat colors

## 3. Scale contract decision

Candidates arrived as ~243–256px canvases with ~200px opaque content, no strict integer
pixel-block grid (block-size reconstruction analysis: error minimized at k=1), i.e.
soft-pixel illustrated tiles rather than crisp pixel art.

Two normalization densities were compared:

| option | close zoom 2.2 (35 px/cell) | normal zoom (~16 px/cell) |
|--------|-----------------------------|---------------------------|
| 64 px/cell | 1.8× downscale, pebble detail lost | fine |
| 128 px/cell | 3.7× downscale, pebbles readable | fine |

**Locked: 128 source pixels per logical cell (16 world units).** One density for all
terrain assets; no per-asset scaling. Atlas import enables mipmaps so far-zoom
minification (min_zoom 0.55 ≈ 14.5×) stays clean.

## 4. Normalization pipeline

Committed tool: `tools/art/build_terrain_atlas.py`

For each candidate:
1. alpha-bbox tight crop;
2. 7% inset re-crop to remove the baked-in soft rounded rim with directional edge shading
   (tiling that rim per cell produced visible horizontal seams in engine);
3. cover-resize to 128×128 (LANCZOS);
4. border alpha hardening (border band pixels with 0 < a < 250 forced to a = 255) so no
   transparent speckle survives at cell seams;
5. edge base color sampling (average opaque color of outer ring) recorded as the
   seam-hiding underlay color.

Outputs:
- `assets/art/production/terrain/terrain_soil_soft_center_01.png`
- `assets/art/production/terrain/terrain_clay_damp_center_01.png`
- `assets/art/production/terrain/terrain_soil_loose_center_01.png`
- `assets/art/production/terrain/terrain_stone_center_01.png`
- `assets/art/production/terrain/terrain_burrow_interior_center_01.png`
- atlas `terrain_atlas_pass_01.png` (640×128, one row, 0.5px bleed inset applied at draw time)
- descriptor `terrain_atlas_pass_01.json`
- manifest `art/manifests/pass_01_asset_manifest.json`

All five candidates: ACCEPTED_WITH_NORMALIZATION. Audit found true transparency, no
removebg halo (low-alpha pixels carry terrain colors, not white fringe), coherent warm-earth
palette family, 1–2px anti-aliased edge band only.

## 5. Presentation integration

- `src/presentation/world/terrain_atlas.gd` — presentation-only loader; maps
  CellData.TerrainMaterial → descriptor families. FOUNDATION reuses the stone family,
  revealed ROOT_SOIL borrows the soft-soil slot (documented temporary fallbacks until
  root assets arrive).
- `src/presentation/world/world_chunk_view.gd` — terrain drawing restructured into
  grouped passes inside each chunk view (one CanvasItem per chunk retained):
  1. flat base rects (exterior/excavated/materials),
  2. textured quads via `draw_texture_rect_region`,
  3. overlays (root cues, moisture, water, seals, protected outlines, debug grid).
- No per-cell nodes. No gameplay state written. Visual variants derive from a stable
  coordinate hash `(x*73856093) ^ (y*19349663)`; regression values locked by tests.
- Fallback: if the descriptor/atlas is missing, cells fall back to legacy flat colors.
- Determinism guard: hidden root/water features still render as stratum material;
  revealed root keeps its cue lines above textures (draw order preserved).

### Rendering performance note (important)

The first naive integration interleaved `draw_rect` and `draw_texture_rect_region` per
cell and collapsed the windowed benchmark to 27–39 fps (p95 up to 46 ms): alternating
flat/textured batches forces a state change per cell. Grouping the passes restored
312 fps / p95 4.25 ms with mipmaps enabled (240×260 stress world). The real 96×72 world
renders at vsync-capped 60 FPS.

## 6. Visual QA evidence (`art/qa/screenshots/`)

| id | file | size | notes |
|----|------|------|-------|
| baseline | pass01_baseline_1280.png / _1920.png | 1280×720 / 1920×1080 | pre-integration placeholders |
| QA01 | pass01_qa_01_gameplay_1280.png | 1280×720 | normal zoom, qa profile, no debug overlay |
| QA02 | pass01_qa_02_gameplay_1920.png | 1920×1080 | pixel scaling clean, no seams/blur |
| QA03 | pass01_qa_03_zoomed_out.png | 1280×720 | zoom 0.55, whole-world topology + strata readable, mipmap-smoothed |
| QA04 | pass01_qa_04_terrain_compare.png | 1280×720 | soft/damp/loose/stone in one scene (burrow interior covered by QA room + QA01) |
| QA05 | pass01_qa_05_root_signal_sequence.png | 1280×720 | procedural root cue ladder on production terrain |
| QA06 | pass01_qa_06_root_reveal.png | 1280×720 | revealed root (primitive line fallback) on production terrain |
| QA07 | pass01_qa_07_debug_overlay.png | 1280×720 | root_raw overlay matches simulation truth |
| QA08 | pass01_qa_08_release_clean.png | 1280×720 | release profile: no placeholder footer, no debug chrome |
| room | pass01_visual_test_room.png | 1280×720 | all five materials + root cues + mouse + water placeholders side by side |
| water | pass01_water_on_new_terrain.png | 1280×720 | procedural water on production terrain |

## 7. Water placeholder judgement

**Acceptable temporary placeholder — regeneration required before vertical slice, not
urgent.** The flat teal rectangles and flow arrows stay readable on textured terrain but
visibly clash with the soft-pixel soil family. Water art direction is not locked, so no
production water asset was promoted this pass.

## 8. Known issues / backlog

1. **Pre-existing QA fixture flake (not caused by this pass):**
   `tools/qa/capture_screenshot.gd --wait-for-wet-storage` ("Phase 4 wet-Storage"
   screenshot fixture) times out waiting for evacuation evidence on this machine. Verified
   identical failure with the art change stashed (baseline fails the same way). Root cause:
   the ready-layout condition can be satisfied while every pile is empty (mice ate the
   stored food during the wait), after which the wet-cell search finds nothing and returns
   false silently. Fixture-only issue; simulation itself is covered by 726 passing
   assertions including emergency-haul evacuation tests. Backlog: make the wet-storage
   fixture seed its own guaranteed non-empty storage pile instead of racing mouse eating.
2. Stone tile carries a faint baked-in outline that reads as brick joints on rectangular
   FOUNDATION landmark geometry — acceptable, arguably helpful there, but a dedicated
   foundation texture is recommended when foundation variants arrive.
3. Single variant per material → visible repetition (wallpaper) at normal zoom in uniform
   regions; expected to soften once user supplies 4–5 variants per material.
4. Revealed ROOT_SOIL borrows the soft-soil tile; primitive-line root presentation remains
   until modular root modules are integrated (next art pass).
5. Export presets do not exist yet; when created, add exclude filters for `scenes/qa`,
   `tools/`, `art/candidates`, `art/qa`, `tests/`, `docs/`.
6. Seed-batch p95 generation-time gate is environment-load sensitive (581 ms fail under
   parallel load, 451 ms pass on idle re-run against the same 500 ms budget); content
   results were 288/288 valid both times.

## 9. Verification summary

- Godot 4.7.stable; import/parse PASS
- Automated assertions: 726/726 PASS (691 baseline + 35 new atlas/loader tests)
- Development smoke PASS; Release smoke PASS
- Runtime benchmark (textured, mipmaps, grouped passes): 312 fps avg / p95 4.25 ms — within budget
- Phase 1–7 smokes, phase benchmarks, 288/288 seed batch (0 replay mismatches), fresh replay: PASS
- Screenshot pipeline: all captures + headless validations PASS except the pre-existing
  wet-storage fixture documented above

## 10. Commits

- Commit A `f39a3cb` — art: normalize pass-01 production candidates
  (candidates + normalized tiles + atlas + descriptor + manifest + normalization tool)
- Commit B `cc8b158` — art: integrate terrain presentation pass 01
  (atlas loader, chunk-view grouped-pass renderer, visual test room, tests, capture args, QA evidence)
- Commit C `fef3427` — docs: record art integration pass 01 (this document)
