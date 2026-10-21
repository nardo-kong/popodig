# Credits & Asset License Audit

Roadmap Phase 16/17 "credits/legal/license audit for all assets".

## Art
- All production art (`assets/art/production/`) is **procedurally generated or
  code-drawn** by this repository:
  - terrain atlas normalized by `tools/art/build_terrain_atlas.py` from the
    pass-01 candidate set in `art/candidates/pass_01/`;
  - mouse master sprite by `tools/art/build_mouse_master.py`;
  - terrain edges, root networks, water, stability props, zone dressing,
    mouse state animation, and landmark relics are code-drawn presentation
    (Phase 11/15 procedural-production decision).
- No third-party, scraped, or licensed image assets exist in the repository.

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
