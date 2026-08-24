"""Build Pass 01 production terrain tiles + atlas + manifest from user candidates.

Pipeline (Art Integration Pass 01):
    candidate PNG -> alpha-bbox tight crop -> cover-resize to SOURCE_PX (LANCZOS)
    -> center-crop to square -> production tile PNG (+ atlas + JSON descriptor).

Scale contract: SOURCE_PX source pixels per logical cell (16 world units).
Locked at 128 for pass 01 after comparing 64 vs 128 against gameplay zoom range
(see docs/art/ART_INTEGRATION_PASS_01.md).

Usage:
    python tools/art/build_terrain_atlas.py
"""

from __future__ import annotations

import json
import os
import sys

from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CANDIDATE_DIR = os.path.join(REPO_ROOT, "art", "candidates", "pass_01")
PRODUCTION_DIR = os.path.join(REPO_ROOT, "assets", "art", "production", "terrain")
MANIFEST_DIR = os.path.join(REPO_ROOT, "art", "manifests")

SOURCE_PX = 128

# Candidates carry a baked-in soft rounded rim with directional (bottom-heavy)
# edge shading. Tiling that rim per cell produced visible horizontal seams in
# engine, so pass 01 crops this border away before scaling.
EDGE_INSET_RATIO = 0.07

# candidate filename stem -> (material key, art-bible asset name, variant index)
CANDIDATE_MAP = {
    "terrain_soil_soft_candidate_01": ("soft_soil", "terrain_soil_soft_center", 1),
    "terrain_clay_damp_candidate_01": ("damp_clay", "terrain_clay_damp_center", 1),
    "terrain_soil_loose_candidate_01": ("loose_soil", "terrain_soil_loose_center", 1),
    "terrain_stone_candidate_01": ("stone", "terrain_stone_center", 1),
    "terrain_burrow_interior_candidate_01": ("burrow_interior", "terrain_burrow_interior_center", 1),
}

# Presentation slot order; FOUNDATION intentionally reuses the stone family for pass 01.
ATLAS_ORDER = ["soft_soil", "damp_clay", "loose_soil", "stone", "burrow_interior"]
FOUNDATION_REUSES = "stone"


def normalize(candidate_path: str) -> tuple[Image.Image, dict]:
    im = Image.open(candidate_path).convert("RGBA")
    audit = {
        "candidate_canvas": list(im.size),
        "corner_alpha_transparent": all(im.getpixel(p)[3] == 0 for p in [(0, 0), (im.size[0] - 1, 0), (0, im.size[1] - 1), (im.size[0] - 1, im.size[1] - 1)]),
    }
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit(f"no opaque content in {candidate_path}")
    audit["opaque_bbox"] = list(bbox)
    content = im.crop(bbox)
    inset_w = round(content.size[0] * EDGE_INSET_RATIO)
    inset_h = round(content.size[1] * EDGE_INSET_RATIO)
    content = content.crop((inset_w, inset_h, content.size[0] - inset_w, content.size[1] - inset_h))
    if content.getchannel("A").getbbox() is None:
        raise SystemExit(f"inset removed all content from {candidate_path}")
    content = content.crop(content.getchannel("A").getbbox())

    # Cover-resize preserving aspect ratio, then center-crop to SOURCE_PX square.
    cw, ch = content.size
    scale = max(SOURCE_PX / cw, SOURCE_PX / ch)
    resized = content.resize((max(1, round(cw * scale)), max(1, round(ch * scale))), Image.LANCZOS)
    rw, rh = resized.size
    left = (rw - SOURCE_PX) // 2
    top = (rh - SOURCE_PX) // 2
    tile = resized.crop((left, top, left + SOURCE_PX, top + SOURCE_PX))
    audit["normalized_size"] = [SOURCE_PX, SOURCE_PX]
    return tile, audit


def alpha_harden_border(tile: Image.Image, band: int = 3) -> None:
    """Remove residual sub-opaque anti-aliasing near tile borders so tiling
    never leaves faint transparent speckle at cell seams."""
    w, h = tile.size
    px = tile.load()
    for y in range(h):
        for x in range(w):
            if x > band and x < w - band and y > band and y < h - band:
                continue
            r, g, b, a = px[x, y]
            if 0 < a < 250:
                px[x, y] = (r, g, b, 255)


def edge_base_color(tile: Image.Image) -> tuple[int, int, int]:
    """Average opaque color near the tile edge; used as seam-hiding underlay color."""
    w, h = tile.size
    px = tile.load()
    ring = max(2, w // 16)
    totals = [0, 0, 0]
    count = 0
    for y in range(h):
        for x in range(w):
            if x > ring and x < w - ring and y > ring and y < h - ring:
                continue
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            totals[0] += r
            totals[1] += g
            totals[2] += b
            count += 1
    if count == 0:
        raise SystemExit("tile has no opaque border pixels for base-color sampling")
    return (totals[0] // count, totals[1] // count, totals[2] // count)


def main() -> int:
    os.makedirs(PRODUCTION_DIR, exist_ok=True)
    os.makedirs(MANIFEST_DIR, exist_ok=True)

    entries: dict[str, list[dict]] = {key: [] for key in ATLAS_ORDER}
    manifest_assets: list[dict] = []

    for stem, (material_key, asset_name, variant_index) in CANDIDATE_MAP.items():
        candidate_path = os.path.join(CANDIDATE_DIR, stem + ".png")
        if not os.path.isfile(candidate_path):
            print(f"SKIP missing candidate: {stem}.png", file=sys.stderr)
            continue
        tile, audit = normalize(candidate_path)
        alpha_harden_border(tile)
        out_name = f"{asset_name}_{variant_index:02d}.png"
        out_path = os.path.join(PRODUCTION_DIR, out_name)
        tile.save(out_path)
        base = edge_base_color(tile)
        entry = {
            "material": material_key,
            "variant": variant_index,
            "asset": f"assets/art/production/terrain/{out_name}",
            "source_px_per_cell": SOURCE_PX,
            "edge_base_color": "#%02x%02x%02x" % base,
        }
        entries[material_key].append(entry)
        manifest_assets.append({
            "source_candidate": f"art/candidates/pass_01/{stem}.png",
            "class": "terrain_center",
            "family": "pass_01_soft_pixel",
            "style_version": "pass_01",
            "status": "ACCEPTED_WITH_NORMALIZATION",
            **entry,
            "audit": audit,
        })
        print(f"OK {out_name} base={entry['edge_base_color']}")

    # Atlas: single row, fixed slot order, one 128px cell per variant.
    columns = sum(max(len(entries[key]), 1) for key in ATLAS_ORDER)
    atlas = Image.new("RGBA", (columns * SOURCE_PX, SOURCE_PX), (0, 0, 0, 0))
    descriptor_entries: dict[str, list[dict]] = {}
    column = 0
    for key in ATLAS_ORDER:
        descriptor_entries[key] = []
        variants = entries[key] or []
        if not variants:
            # Reserve an empty slot so material indices stay stable across passes.
            descriptor_entries[key].append({
                "variant": 1,
                "atlas_column": column,
                "empty": True,
            })
            column += 1
            continue
        for entry in variants:
            tile = Image.open(os.path.join(REPO_ROOT, entry["asset"]))
            atlas.paste(tile, (column * SOURCE_PX, 0))
            descriptor_entries[key].append({
                "variant": entry["variant"],
                "atlas_column": column,
                "edge_base_color": entry["edge_base_color"],
            })
            column += 1
    atlas_rel = "assets/art/production/terrain/terrain_atlas_pass_01.png"
    atlas.save(os.path.join(REPO_ROOT, atlas_rel))

    descriptor = {
        "schema_version": 1,
        "style_version": "pass_01",
        "source_px_per_cell": SOURCE_PX,
        "logical_cell_world_units": 16,
        "atlas": atlas_rel,
        "atlas_tile_px": SOURCE_PX,
        "foundation_reuses": FOUNDATION_REUSES,
        "entries": descriptor_entries,
    }
    descriptor_rel = "assets/art/production/terrain/terrain_atlas_pass_01.json"
    with open(os.path.join(REPO_ROOT, descriptor_rel), "w", encoding="utf-8") as handle:
        json.dump(descriptor, handle, indent=2)
        handle.write("\n")

    manifest = {
        "schema_version": 1,
        "pass": "pass_01",
        "scale_contract": {
            "source_pixels_per_logical_cell": SOURCE_PX,
            "alternatives_considered": [64, 128],
            "decision": "128 keeps pebble detail readable at max gameplay zoom 2.2 while linear-filtered minification stays clean; 64 lost close-zoom material detail.",
        },
        "assets": manifest_assets,
        "rejected": [],
        "deferred": [
            {"type": "root_signal", "reason": "candidates not yet provided by user"},
            {"type": "root_modules", "reason": "candidates not yet provided by user"},
            {"type": "water", "reason": "water art direction not locked; placeholder retained by decision"},
            {"type": "stability", "reason": "phase 8 domain not implemented; candidates not provided"},
            {"type": "mouse_master", "reason": "static master only useful once animation states exist"},
            {"type": "terrain_variants", "reason": "user will supply 4-5 more variants per material"},
        ],
    }
    manifest_path = os.path.join(MANIFEST_DIR, "pass_01_asset_manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    print(f"OK atlas {atlas_rel} ({atlas.size[0]}x{atlas.size[1]})")
    print(f"OK manifest {os.path.relpath(manifest_path, REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
