---
name: soft-pixel-game-art-pipeline
description: Generate, normalize, QA, and integrate 2D soft-pixel / painterly-pixel game art for this project. Use whenever creating or modifying terrain, tilesets, characters, props, buildings, UI art, animation frames, visual variants, or when integrating generated image assets into Godot. Enforces Golden Style References, asset contracts, terrain engineering, transparent-background checks, visual QA, and in-game compatibility. Do not use for gameplay code changes that do not touch visual assets.
---

# Soft Pixel Game Art Production Pipeline

## Mission

Follow this skill whenever the game needs new visual assets or an existing visual asset must be changed, regenerated, standardized, animated, tiled, packed, or integrated.

The goal is **not** to produce individually attractive PNG files.

The goal is to produce assets that:

1. look as if they were created by one art team for one game;
2. share the same camera, scale, pixel density, palette, lighting, grounding, and edge language;
3. can be placed in Godot without obvious seams, halos, floating objects, inconsistent scale, or "sticker" appearance;
4. remain coherent when dozens or hundreds of assets are added later;
5. survive actual in-game screenshots, not only isolated-image inspection.

Treat image generation as the first stage of a production pipeline, never as the final stage.

---

# 1. Core visual direction

Unless `docs/ART_STYLE_BIBLE.md` explicitly overrides these values, use the following visual direction.

## Style

- soft pixel art / painterly pixel art;
- fresh, soft, warm, restrained;
- clear pixel character, but not coarse 8-bit art;
- medium-to-high visual pixel density;
- simple silhouettes with controlled internal detail;
- game asset readability takes priority over illustration detail;
- ordinary gameplay composition takes priority over cinematic composition.

## Palette

Primary environment family:

- yellow-green;
- sage green;
- muted spring green;
- warm cream;
- soft brown;
- warm gray;
- slightly cool gray only where needed.

Avoid:

- fluorescent or highly saturated green;
- pure-black outlines;
- high-contrast cel shading;
- cold blue shadows unless a biome specifically requires them;
- independently chosen palettes per asset.

## Lighting

Default global lighting:

- soft light from upper-left;
- light and restrained contact shadow toward lower-right;
- no dramatic rim light;
- no bloom or glow around ordinary assets;
- no different light direction between neighboring assets.

## Camera

Default world presentation:

- light top-down 3/4 game view;
- not front-facing;
- not strict isometric;
- not perspective-heavy 3D;
- all assets in the same gameplay layer must share the same camera language.

## Edge language

Do not accept:

- white sticker borders;
- bright halos;
- transparent fringes;
- thick pure-black outlines;
- unrelated anti-aliasing styles;
- soft airbrushed edges that conflict with the pixel language;
- rectangular background remnants.

---

# 2. Reference hierarchy

Every generated production asset must be grounded in an approved reference hierarchy.

Use this priority order:

1. `art/references/golden_style_reference.*`
2. approved Golden Assets from `art/references/golden_assets/`
3. approved same-family asset, when generating a variant or animation
4. external inspiration references only as secondary context

Never allow an external inspiration screenshot to remain the sole long-term reference once the project has an approved original Golden Style Reference.

External references are for **visual language only**. Do not copy their characters, map layout, UI, exact trees, exact buildings, logos, text, or distinctive asset designs.

If `golden_style_reference` is missing, stop bulk asset production and create/approve a compatibility scene first.

---

# 3. Golden Assets

Maintain a small set of canonical visual anchors.

Recommended initial Golden Set:

- `golden_ground`
- `golden_character`
- `golden_tree`
- `golden_rock`
- `golden_structure`
- `golden_ui_panel`

Do not create dozens of production assets before these anchors are visually compatible in one real game screenshot.

When a Golden Asset is approved:

- copy it into `art/references/golden_assets/`;
- version it;
- do not silently overwrite it;
- record its production metadata;
- use it as a reference for future family members.

If the art direction changes materially, create a new style version. Do not mix style versions in the same release scene.

Example:

```text
style_v001/
style_v002/
```

---

# 4. Asset classes and allowed AI freedom

Classify every asset before generation.

## Class A — WORLD SYSTEM

Examples:

- grass;
- dirt;
- cave floor;
- cave wall;
- water;
- roads;
- cliffs;
- terrain borders;
- terrain transitions.

AI freedom: **very low**.

These are system assets. They must be engineered as tile/terrain systems. A beautiful generated background is not a production terrain asset.

## Class B — STRUCTURAL

Examples:

- buildings;
- rooms;
- walls;
- doors;
- furniture with collision;
- deployment modules;
- machines;
- bridges.

AI freedom: **low**.

They require strict footprint, anchor, camera, interface, and scale contracts.

## Class C — ENTITY

Examples:

- hamster;
- NPC;
- creature;
- enemy;
- animated interactive object.

AI freedom: **medium** for the master design, low for animation consistency.

Do not generate an entire final sprite sheet in one uncontrolled prompt.

## Class D — DECORATION

Examples:

- flowers;
- pebbles;
- loose branches;
- tiny mushrooms;
- leaves;
- non-interactive clutter.

AI freedom: **highest**, while still obeying the style and palette.

---

# 5. Mandatory pre-generation brief

Before generating an image, create or update:

`art/requests/<asset_id>.md`

The request must state at minimum:

```text
Asset ID:
Asset class:
Purpose:
Style version:
Primary reference:
Same-family reference:
World footprint:
Visual canvas target:
Ground/contact anchor:
Camera:
Light direction:
Palette family:
Shadow policy:
Required variants:
Animation state, if any:
Forbidden content:
Acceptance tests:
```

Do not generate first and invent the specifications afterward.

---

# 6. Default scale contract

If the project already defines scale in `docs/ART_STYLE_BIBLE.md` or `docs/ASSET_CONTRACT.md`, obey it exactly.

Otherwise bootstrap with the following provisional contract and then lock it after the first vertical slice:

```text
Logical world cell: 32 Godot world units
Art density: one project-wide fixed ratio, initially target 4×
Nominal visual density: ~128 source pixels per logical cell
Ground anchor: bottom-center unless the asset family defines another anchor
World sprite scaling: fixed by asset metadata, never guessed by eye
```

Important:

- logical grid size and source-art resolution are different concepts;
- do not force high-quality soft pixel art into 24×24 or 32×32 source images simply because the game logic uses a 32-unit cell;
- do not place arbitrary 1536 px generations in Godot at random scale factors;
- normalize all production assets to a defined family resolution before integration.

Do not use different pixel densities for nearby assets.

---

# 7. Grounding and anchors

Every object that touches the world must have a defined contact anchor.

Default:

```text
anchor = bottom_center
```

Examples:

- tree: trunk contact point;
- rock: bottom-center contact point;
- character: midpoint between feet;
- building: center of ground footprint or explicitly defined entrance/footprint anchor.

Store anchors in asset metadata. Do not rely on manual visual placement in individual scenes.

A sprite is not accepted if it appears to float, sink, or stand on a different ground plane than its neighbors.

---

# 8. Transparent background rules

Prompt text saying "transparent background" is not sufficient evidence of transparency.

Whenever the image-generation tool exposes an explicit transparent-background option, use it.

After generation, inspect the actual file:

- confirm an alpha channel exists;
- inspect corner pixels;
- inspect semi-transparent edge pixels;
- verify no black or colored rectangle remains.

If the generated file is RGB with a black background:

- do **not** automatically treat pure black as transparency;
- do **not** blindly chroma-key the black background when shadows or dark outlines blend into it;
- prefer regeneration with real transparency;
- if regeneration is impossible, perform controlled segmentation/cleanup and inspect the result on both light and dark test backgrounds.

Production assets must not contain unintended background pixels.

---

# 9. Shadow policy

Generated concept images may include baked contact shadows, but production assets should normally separate:

```text
asset_sprite
asset_shadow
```

Reasons:

- character animation remains stable;
- terrain tint changes do not expose mismatched baked shadows;
- shadows can be hidden or adjusted by environment;
- asset extraction is cleaner.

If a baked shadow is kept, the asset contract must explicitly state that decision.

Never let three nearby asset families use three unrelated shadow styles.

---

# 10. Standard image-generation prompt structure

Construct generation prompts using the following order.

## A. Reference declaration

```text
The uploaded Golden Style Reference is the primary visual reference.
Use its overall visual language only.
Do not copy any existing character, layout, UI, text, logo, or exact asset design.
```

## B. Production intent

Explicitly state:

```text
This is a 2D game production asset, not concept art, not a scene illustration, not a poster.
```

## C. Asset identity

State exactly one asset family and its purpose.

Example:

```text
Generate one original small conifer tree asset for a 2D game.
```

## D. Shared style

Always include the project style:

```text
fresh, soft, warm soft pixel art / painterly pixel art;
medium-high pixel density;
controlled low-saturation palette;
no pure-black outline;
no white sticker edge;
no glow;
no AI-style sharp halo;
soft upper-left light;
subtle lower-right grounding;
restrained detail;
clear gameplay silhouette.
```

## E. Geometry and scale

Specify:

- footprint;
- relative scale to Golden Character;
- camera;
- contact point;
- whether the visible form may extend outside its footprint.

## F. Isolation

For discrete assets:

```text
one isolated asset only;
transparent background;
no grass;
no sky;
no UI;
no text;
no frame;
no extra props unless explicitly requested.
```

## G. Priority

End with:

```text
If additional detail conflicts with visual consistency or game usability, prefer consistency, restraint, readability, and production usability.
```

---

# 11. Prompt template — single prop / tree

Use a same-family Golden reference whenever available.

```text
The uploaded Golden Style Reference and approved same-family reference are the primary references.

Generate ONE original <ASSET_NAME> for this 2D game.

This is a production asset, not an illustration or scene.

Requirements:
- isolated asset;
- real transparent background;
- soft pixel art / painterly pixel art;
- same palette, pixel density, camera, edge language, and lighting as the Golden references;
- low saturation;
- no pure-black outline;
- no white border or halo;
- upper-left soft light;
- restrained detail;
- clear silhouette;
- footprint: <FOOTPRINT>;
- ground anchor: <ANCHOR>;
- relative height vs Golden Character: <RATIO>;
- no extra props, grass, sky, UI, text, or decorative frame.

If detail conflicts with consistency or game readability, prefer consistency and game usability.
```

---

# 12. Prompt template — character master

```text
Use the uploaded Golden Style Reference as the primary visual reference.

Generate ONE original character master for <CHARACTER_ID>.

This is a 2D game character production design reference, not a scene or poster.

Keep:
- soft pixel / painterly pixel visual language;
- controlled warm palette;
- same pixel density as the game world;
- same upper-left lighting;
- clear silhouette at gameplay scale;
- bottom-center ground contact;
- no clothing or props unless specified;
- no exaggerated giant eyes unless explicitly required;
- no sticker border, halo, or pure-black outline;
- transparent background.

Pose:
- simple neutral idle pose suitable as the canonical master;
- stable feet/contact point;
- anatomy designed for later walk, sleep, eat, dig, and carry animations.

Priority:
character identity and repeatability are more important than micro-detail.
```

---

# 13. Character animation workflow

Do not ask the image model for a large final sprite sheet as the first step.

Use this order:

1. approve Character Master;
2. lock body proportions, face pattern, ears, paws, palette, and anchor;
3. define each animation state;
4. create key poses;
5. normalize canvas and anchor;
6. generate/inbetween additional frames only after key poses pass;
7. inspect the animated result in Godot.

For every frame:

- same canvas size;
- same ground anchor;
- same body volume;
- same palette;
- same markings;
- same camera;
- same light direction.

Minimum initial walk test:

```text
idle
walk_contact_A
walk_pass
walk_contact_B
```

Prefer 4 coherent frames over 8 inconsistent frames.

Reject animation if:

- face changes between frames;
- ear size changes;
- body width drifts;
- feet anchor jumps;
- markings move;
- lighting flips;
- line/edge density changes.

---

# 14. Terrain production is a special pipeline

Never directly convert a generated full grass field, dirt field, cave wall image, or scenic background into repeated game tiles.

A generated terrain image is a **Ground Style Reference**, not a TileSet.

Use three layers.

## Layer 1 — Base terrain

Create seamless low-information base variants:

```text
grass_base_01
grass_base_02
grass_base_03
grass_base_04
```

Characteristics:

- restrained;
- low-frequency detail;
- no prominent flowers or recognizable repeated tuft pattern;
- tileable;
- compatible palette.

## Layer 2 — Macro variation

Add large-scale variation separately using one or more:

- low-frequency noise;
- large tint overlay;
- biome tint;
- large seamless overlays.

Do not bake all macro variation into a tiny repeated tile.

## Layer 3 — Detail decals

Create independent decorations:

```text
grass_tuft_01
grass_tuft_02
grass_tuft_03
flower_white_01
clover_01
tiny_pebble_01
```

Scatter them through controlled rules.

This allows:

- natural variation;
- gameplay removal;
- grass being eaten;
- biome control;
- reduced wallpaper repetition.

---

# 15. Terrain transitions

When two terrain types meet, create explicit transition assets.

Example:

```text
GRASS
DIRT
GRASS_DIRT_EDGE_N
GRASS_DIRT_EDGE_S
GRASS_DIRT_EDGE_E
GRASS_DIRT_EDGE_W
GRASS_DIRT_CORNER_NE
GRASS_DIRT_CORNER_NW
GRASS_DIRT_CORNER_SE
GRASS_DIRT_CORNER_SW
GRASS_DIRT_INNER_CORNER_*
```

Use Godot terrain/TileSet rules for final connectivity.

Do not cover bad seams with random decorations.

---

# 16. Mandatory terrain QA

Before any terrain set becomes production-ready, generate test maps.

## Seam test

Repeat each base variant in at least a 4×4 block.

Reject if visible grid seams appear.

## Wallpaper test

Repeat and randomize variants over a larger field.

Reject if recognizable motifs repeat on a regular cadence.

## Transition test

Test:

```text
grass grass dirt
grass dirt  dirt
dirt  dirt  dirt
```

and all edge/corner combinations.

## Decoration density test

Inspect at:

- sparse;
- normal;
- dense.

Gameplay readability must remain intact.

## Zoom test

Inspect at the actual intended game zoom. Do not approve terrain solely from the source PNG.

---

# 17. Structural asset workflow

For buildings, rooms, machines, and modules, define geometry before prompting.

Required values:

```text
footprint_cells
canvas_family
anchor
door_position
walkable_area
collision_area
front_occlusion_area
connection_points
relative_height_to_character
```

Generate the art against that contract.

Do not modify gameplay geometry to accommodate a pretty but incompatible generated building unless the design decision is explicitly approved.

A production structural asset must visually and logically agree with the grid.

---

# 18. Variant generation

When creating variants, use:

1. Golden Style Reference;
2. approved family master;
3. the same written asset contract.

Do not rely on the text phrase "same style" alone.

For a family test, generate a small batch first:

```text
3–5 variants
```

Place all variants together in the test room.

Approve the family before expanding to large batches.

Reject a variant that is individually attractive but visually belongs to a different game.

---

# 19. AI output is always a Candidate

All generated images start in:

```text
art/candidates/
```

Never place raw generated output directly in:

```text
art/production/
```

Promotion requires:

1. file inspection;
2. normalization;
3. asset metadata;
4. visual QA;
5. in-game integration screenshot;
6. acceptance.

---

# 20. Recommended repository structure

Use or adapt:

```text
art/
  references/
    golden_style_reference.png
    golden_assets/
  requests/
  candidates/
  rejected/
  source/
  production/
    terrain/
    props/
    entities/
    structures/
    ui/
  tilesets/
  atlases/
  qa/
    screenshots/
    contact_sheets/

docs/
  ART_STYLE_BIBLE.md
  ASSET_CONTRACT.md
  CAMERA_AND_SCALE.md
  VISUAL_QA.md

tools/
  art_qa/

scenes/
  qa/
    visual_test_room.tscn
```

---

# 21. Asset metadata

Each accepted production asset should have metadata, for example:

```json
{
  "id": "tree_pine_01",
  "class": "B",
  "family": "tree_pine",
  "style_version": "style_v001",
  "source_reference": "golden_tree_v001",
  "footprint_cells": [1, 1],
  "anchor": "bottom_center",
  "anchor_px": [64, 240],
  "camera": "topdown_3q_v001",
  "light_direction": "upper_left",
  "shadow_policy": "separate",
  "palette_family": "spring_v001",
  "production_scale": 4,
  "status": "approved"
}
```

Use project-specific values rather than copying example coordinates blindly.

---

# 22. Normalization step

Before integration, normalize candidate assets.

Check and correct:

- crop;
- canvas;
- alpha;
- edge fringe;
- pixel density;
- palette;
- contact anchor;
- family scale;
- shadow;
- file naming;
- metadata.

Do not "improve" a pixel asset with arbitrary smoothing or resampling.

Use one approved downsampling/resampling method across the project.

Do not scale neighboring sprites by arbitrary values such as `0.83`, `1.17`, or whatever visually fits in the editor.

---

# 23. Visual Test Room

Maintain:

`scenes/qa/visual_test_room.tscn`

It should include at minimum:

- approved ground;
- one Golden Character;
- Golden Tree;
- Golden Rock;
- one structural asset;
- representative UI;
- current camera and game zoom.

Every new important asset must be tested beside the Golden Set.

A PNG that looks good alone can still fail in the game.

---

# 24. Mandatory visual QA checklist

Before promotion to `art/production/`, check:

## Technical

- correct file format;
- expected alpha channel;
- no unwanted background rectangle;
- no halo;
- no clipping;
- correct crop;
- correct canvas family;
- correct anchor;
- expected footprint;
- consistent pixel density;
- consistent palette range;
- correct light direction;
- correct shadow style.

## In-game

- does not float;
- does not sink;
- scale is believable next to Golden Character;
- does not visually overpower unrelated gameplay elements;
- does not look like a sticker;
- no obvious interpolation blur;
- no abnormal edge fringe against light or dark terrain;
- no transition seam;
- no obvious repeated pattern;
- visually belongs to the same game.

## Family consistency

- neighboring variants share the same shape language;
- no accidental art-direction drift;
- no sudden increase/decrease in detail density.

---

# 25. Integration gate

Use the following states:

```text
GENERATED
  ↓
CANDIDATE
  ↓
NORMALIZED
  ↓
INTEGRATION_TEST
  ↓
APPROVED
  ↓
PRODUCTION
```

If the asset fails:

```text
REJECTED
```

Do not keep failed art in production "temporarily".

For high-impact assets, require a human visual gate before mass production:

- Golden Style Reference;
- player/primary resident master;
- base terrain family;
- first structural family;
- UI theme;
- new biome style.

Once the family is approved, routine variants may proceed through automated/self QA.

---

# 26. Godot integration rules

When integrating:

- use metadata-driven scale and anchor;
- use consistent texture filtering configured for the chosen soft-pixel pipeline;
- avoid arbitrary per-scene scale adjustments;
- keep shadow separate where the art contract requires it;
- use TileSet/Terrain systems for world-system assets;
- keep decorations as separate sprites/tiles when they need to appear/disappear dynamically;
- capture an actual gameplay screenshot after integration.

Do not judge integration quality from the Godot inspector thumbnail.

---

# 27. Never do these

Never:

- generate 30+ assets before the Golden Set is approved;
- use a full AI grass background as a repeated terrain tile;
- assume "transparent background" means the file has alpha;
- black-key backgrounds without checking shadow/fringe damage;
- use a different prompt style for every asset;
- change camera angle between families;
- change lighting direction between families;
- resize every asset by eye;
- hide bad transitions under extra grass or particles;
- accept a beautiful asset that breaks scale or gameplay readability;
- ask for a huge animation sprite sheet before locking the character master;
- treat AI output as final production art without QA;
- let Code or scene geometry drift merely to accommodate one incompatible image;
- silently mix different style versions.

---

# 28. Failure recovery

When an asset fails, identify the failure category before regenerating.

Use one of:

```text
STYLE_DRIFT
SCALE_MISMATCH
PIXEL_DENSITY_MISMATCH
CAMERA_MISMATCH
LIGHTING_MISMATCH
HALO_OR_BACKGROUND
BAD_GROUNDING
BAD_FOOTPRINT
TERRAIN_SEAM
WALLPAPER_REPEAT
ANIMATION_IDENTITY_DRIFT
OVERDETAILED
UNDERDETAILED
PALETTE_DRIFT
```

Modify only the relevant constraints if possible.

Do not rewrite the entire art direction on every retry.

---

# 29. Batch-production policy

Only batch-produce after a family passes a small consistency test.

Sequence:

```text
1 Golden asset
→ 3–5 variants
→ contact sheet
→ in-game test
→ approve family
→ larger batch
```

For terrain:

```text
visual mother
→ base tile prototypes
→ 4×4 seam tests
→ transition set
→ decoration set
→ test map
→ approve
```

For characters:

```text
character master
→ idle + 4-frame walk
→ in-game animation test
→ one interaction animation
→ approve animation language
→ expand states
```

---

# 30. Completion report for every art task

When finishing an art-related task, report:

```text
Asset(s) created:
Asset class:
Style version:
Reference(s) used:
Candidate path:
Production path, if approved:
QA performed:
Known issues:
Pass / Conditional Pass / Fail:
Next required action:
```

Do not claim an asset is production-ready when only generation has completed.

---

# 31. Fallback when no image-generation capability is available

If the current Codex environment cannot directly generate or edit images:

1. do not fabricate final PNGs from simplistic placeholder drawing and call them production art;
2. create the complete generation request under `art/requests/`;
3. include the exact Golden references that must be supplied;
4. mark the asset status as `BLOCKED_IMAGE_GENERATION`;
5. continue only with tasks that do not require pretending the missing asset exists;
6. once the generated candidate is provided, resume from the Candidate QA stage.

Placeholders are allowed only when explicitly marked as placeholders and must never be promoted into `art/production/`.

---

# 32. Quality principle

The governing rule is:

> A coherent game made from restrained, compatible assets is better than a collection of individually impressive images.

Whenever "more detail" conflicts with:

- visual unity;
- scale consistency;
- gameplay readability;
- tileability;
- animation repeatability;
- integration quality;

choose the coherent production system.

