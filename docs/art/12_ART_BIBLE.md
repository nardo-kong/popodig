# 12 — Art Bible & Asset Integration Specification

**Status: LOCKED readability goals / PROVISIONAL final art direction**

## 1. Art goal
Create a warm, clean, readable 2D underground cross-section where the colony feels cozy but terrain still communicates gameplay state instantly.

The world must look like one coherent illustration, not a collage of independently generated AI assets.

## 2. Perspective
- 2D side/cutaway view.
- Terrain tiles align to a strict grid at logic level.
- Organic edges may visually break the grid while collision/simulation remains cell-based.
- Mice and props use consistent side/3-quarter side character presentation appropriate to the cutaway.

## 3. Style direction
### Owner clarification — 2026-10-24 (current resource-art authority)

Match `assets/art/production/entities/mouse_master_idle_01.png`, the early
`art/candidates/pass_01/` terrain family, and the owner's Soft Pixel reference
in conversation `6a849506-2294-83e8-9eaf-40ef754e6d14` (field, mouse, conifer,
matte stones). The conversation's old engineering screenshot is a structural
reference only. Do not copy its placeholder graphics.

- Use visible regular pixel clusters, soft stepped shading, small material
  patches, restrained warm colours and broken coloured contours.
- New resources must belong beside the existing mouse. Avoid smooth illustrated
  inventory stickers, continuous thick dark outlines, giant polygon facets,
  glossy white spots, saturated orange minerals and blurry halos.
- `pixel-inspired` in a prompt is insufficient; compare actual output with the
  reference. Recolouring or pixelating a rejected illustration is insufficient.
- Preserve the existing 128px maximum import and mipmap scale contract. Inspect
  the actual 18-unit resource / 22-unit root and 54px guide rendering together
  with the existing mouse and terrain, including camera min/max zoom. Do not
  change the entire world's filtering to compensate for a mismatched source.
- Use genuine alpha cutouts with margin, no ground patch or fuzzy shadow. A
  transparent corner alone does not prove the absence of an internal halo.
- Revision `_01` resource images were rejected by the owner. `_02` is the
  corrected production selection; engineering checks do not imply owner approval.
  Record source and full prompts in `art/production/resource_imagegen_02.json`.

Recommended:
- fresh, soft pixel-art or pixel-inspired clean 2D;
- restrained warm earth palette;
- readable silhouettes;
- moderate texture, not noisy photorealism;
- cozy lighting accents without hiding signals;
- minimal hard outlines on terrain seams.

If true pixel art is selected, all source assets must obey a single pixel-density and scaling policy. Never mix soft high-resolution AI-painted assets with crisp pixel tiles without controlled conversion/redrawing.

## 4. Visual hierarchy
Priority order:
1. Mice and active emergency motion
2. Excavated vs solid topology
3. Water / major discovered features
4. strong signals/warnings
5. zones/jobs
6. decorative texture

Decorations must not compete with signal cues.

## 5. Terrain integration rules
Each terrain material needs:
- center tile/texture variations;
- exposed edge treatment;
- corners/transitions;
- excavated background/wall treatment;
- signal overlays compatible with it;
- damage/digging stages.

Avoid visible square “asset borders.” Use tile blending/edge masks or authored transition pieces.

## 6. Seam prevention
All AI-assisted assets must pass:
- transparent-edge check;
- unintended frame/outline check;
- palette compatibility check;
- scale/pixel density check;
- lighting direction check;
- edge/tileability check where applicable;
- in-engine screenshot review at actual zoom.

Never approve an asset only from the isolated PNG.

## 7. Lighting authority
Choose one global art lighting convention. Recommended:
- soft ambient underground base;
- gentle warm local highlights;
- no conflicting per-asset dramatic light directions.

Gameplay signals must remain visible independent of decorative lighting.

## 8. Terrain palette roles
Use distinct but harmonious families:
- Topsoil: warm medium brown
- Damp/Clay: slightly cooler/darker
- Loose Soil: lighter/crumbly
- Stone/Foundation: low-saturation gray/brown
- Root: warm organic tan/brown
- Water: muted clear blue/teal accent
- Old Burrow: aged warm neutrals

Exact colors are art-production decisions, but contrast roles are fixed.

## 9. Signal visuals
### Moisture
- darker/smoother soil;
- tiny specular droplets at strong levels;
- avoid neon blue hidden-terrain glow.

### Root
- fine threads at weak signal;
- denser thicker strands near feature.

### Instability
- crumb texture;
- cracks;
- falling dirt animation.

Signals should feel part of the terrain, not UI stickers.

## 10. Mouse character requirements
Mice must have readable small-scale animation states:
- idle
- walk/run
- dig
- carry
- eat
- sleep
- flee/panic
- simple zone setup/work

Silhouette and carried-item readability matter more than animation complexity.

## 11. Zone dressing
Automatic props must be modular and low-noise.

Sleeping:
- grass nests;
- soft scraps;
- tiny blankets only if style supports.

Storage:
- food/material piles;
- baskets/sacks appropriate to mouse scale.

Food:
- root nibble/forage visuals;
- simple preparation clutter if needed.

Do not create dense interior-decoration systems.

## 12. Feature art contracts
Each feature asset set must include:
- hidden signal art;
- partially exposed state;
- full discovered state;
- active reaction state if relevant;
- resolved/stable state;
- integration masks/anchors.

### Water Reservoir
Need wet soil halo, breach edge, water depth states, flow transition, calm pool.

### Root Cluster
Need thin signal roots, major roots, exposed/cut/preserved variants if mechanic requires.

### Unstable Soil
Need stable weak soil, crumb warning, cracks, rubble/collapse result, support integration.

## 13. AI asset workflow
AI may be used for concept generation and controlled source creation, but production integration requires:
1. locked art brief;
2. generation at consistent style/scale;
3. cleanup/crop/transparency;
4. palette/edge normalization;
5. slice into game-ready pieces;
6. import preset validation;
7. in-engine composition;
8. automated screenshot capture;
9. visual QA against neighboring assets;
10. reject/redraw if seams, frames, perspective, or lighting conflict.

Do not ask an image model to generate an entire playable level screenshot and then cut mechanics out of it.

## 14. Asset naming
Examples:
- `terrain_soil_soft_center_01.png`
- `terrain_soil_soft_edge_top_01.png`
- `signal_moisture_band_02.png`
- `feature_root_major_a.png`
- `feature_water_breach_01.png`
- `mouse_dig_strip.png`
- `zone_sleep_nest_01.png`

## 15. Import rules
If true pixel art:
- nearest-neighbor filtering;
- integer scaling preference;
- no texture smoothing;
- consistent pixels-per-cell.

If high-resolution illustrated tiles:
- define one pixels-per-cell standard;
- avoid mixed resolution;
- use correct filtering and mip policy for zoom.

## 16. Visual QA views
At minimum capture:
- close gameplay zoom;
- normal gameplay zoom;
- zoomed-out burrow overview;
- first root encounter;
- water breach before/during/after;
- unstable warning/collapse;
- each supported target aspect ratio.

## 17. Art acceptance rule
A beautiful asset that does not integrate is a failed asset. Final approval is based on the in-engine scene, not isolated generation quality.
