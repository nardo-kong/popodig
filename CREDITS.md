# Credits & Asset License Audit

Roadmap Phase 16/17 "credits/legal/license audit for all assets".

## Art
- Terrain and character art (`assets/art/production/terrain/`, `entities/`) is **procedurally generated or
  code-drawn** by this repository:
  - terrain atlas normalized by `tools/art/build_terrain_atlas.py` from the
    pass-01 candidate set in `art/candidates/pass_01/`;
  - mouse master sprite by `tools/art/build_mouse_master.py`;
  - terrain edges, root networks, water, stability props, zone dressing,
    mouse state animation, and landmark relics are code-drawn presentation
    (Phase 11/15 procedural-production decision).
- Resource pictures (`assets/art/production/resources/`, six selected `_02` transparent PNGs)
  were generated with the built-in imagegen tool on 2026-10-24 for this project,
  using the original mouse and owner-provided early Soft Pixel reference for style.
  Full prompts and generated source filenames: `art/production/resource_imagegen_02.json`.
  The rejected 2026-10-23 `_01` revision and its prompt record remain for history;
  it is no longer selected in `ResourceVisuals`.
  Original PNGs are preserved; Godot imports at max 128px with mipmaps and shared
  texture regions for world piles, carrying and tutorial pictures.
- No scraped or externally licensed stock image assets are used.

- The local desktop icon (`assets/app_icon.svg`) is an original code-drawn vector in this repository.

## Audio
- All audio (`assets/audio/production/*.wav`, 18 files) is synthesized
  deterministically by `tools/audio/synth_audio.py` (Python stdlib only, seed
  1101). Re-running the tool reproduces the bank byte-for-byte.
- No recorded, sampled, or licensed audio exists in the repository.

## Fonts & engine
- UI text uses the Godot 4 default font (Godot's bundled open-source font).
- Engine: Godot 4.7 stable (MIT licensed, © Juan Linietsky, Ariel Manzur,
  and Godot Engine contributors).

## Tooling
- Validation/audio/art tooling is Python 3 standard library only; no
  third-party Python packages are required.

## License
- Project content is proprietary to the Dig Down / 地下鼠鼠 project owner.
  Third-party obligations are limited to the Godot Engine MIT license.
