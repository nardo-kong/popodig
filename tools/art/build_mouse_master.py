"""Normalize the golden mouse master candidate into a production entity asset.

Pass 01 addendum (user-approved deviation from the static-master-only rule):
the master idle sprite is adopted as a TEMPORARY HYBRID presentation — the
static art replaces the procedural placeholder body while all existing
procedural state badges (dig tool, carry box, sleep arc, panic triangle,
movement bob) remain on top until a real animation set arrives.

Scale contract: 8 source pixels per world unit (same family as the 128 px/cell
terrain contract). Locked display height: 18 world units -> 144 px source
height, width proportional.

Usage:
    python tools/art/build_mouse_master.py
"""

from __future__ import annotations

import json
import os

from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CANDIDATE_PATH = os.path.join(REPO_ROOT, "art", "candidates", "pass_01", "mouse_master_idle_candidate_01.png")
OUTPUT_DIR = os.path.join(REPO_ROOT, "assets", "art", "production", "entities")
OUTPUT_NAME = "mouse_master_idle_01.png"
SOURCE_HEIGHT_PX = 144
DISPLAY_HEIGHT_UNITS = 18.0
MANIFEST_PATH = os.path.join(REPO_ROOT, "art", "manifests", "pass_01_asset_manifest.json")


def main() -> int:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    im = Image.open(CANDIDATE_PATH).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit("no opaque content in mouse candidate")
    content = im.crop(bbox)

    cw, ch = content.size
    scale = SOURCE_HEIGHT_PX / ch
    out = content.resize((max(1, round(cw * scale)), SOURCE_HEIGHT_PX), Image.LANCZOS)
    out_path = os.path.join(OUTPUT_DIR, OUTPUT_NAME)
    out.save(out_path)

    with open(MANIFEST_PATH, encoding="utf-8") as handle:
        manifest = json.load(handle)
    entry = {
        "source_candidate": "art/candidates/pass_01/mouse_master_idle_candidate_01.png",
        "class": "entity_mouse_master_idle",
        "family": "pass_01_soft_pixel",
        "style_version": "pass_01",
        "status": "ACCEPTED_TEMPORARY_HYBRID",
        "asset": f"assets/art/production/entities/{OUTPUT_NAME}",
        "source_px_per_world_unit": 8,
        "display_height_units": DISPLAY_HEIGHT_UNITS,
        "normalized_size": list(out.size),
        "decision": "User-approved temporary hybrid: static master replaces the placeholder body while procedural state badges stay on top until key animation states arrive.",
        "audit": {
            "candidate_canvas": [1254, 1254],
            "opaque_bbox": list(bbox),
            "halo_check": "low-alpha pixels are warm outline tones, no removebg fringe",
        },
    }
    assets = [a for a in manifest.get("assets", []) if a.get("asset") != entry["asset"]]
    assets.append(entry)
    deferred = manifest.setdefault("deferred", [])
    manifest["deferred"] = [
        d for d in deferred
        if not (d.get("type") == "mouse_master" or d.get("type") == "mouse_animation_states")
    ] + [{"type": "mouse_animation_states", "reason": "idle/walk/dig/carry/eat/sleep/panic set still required before final mouse integration replaces the temporary hybrid"}]
    manifest["assets"] = assets
    with open(MANIFEST_PATH, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    print(f"OK {OUTPUT_NAME} {out.size[0]}x{out.size[1]} display={DISPLAY_HEIGHT_UNITS}u")
    print("OK manifest updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
