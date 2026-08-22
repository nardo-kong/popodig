class_name TerrainAtlasView
extends RefCounted

# Presentation-only loader for normalized production terrain tiles.
# Reads the pass manifest descriptor; never mutates simulation state.
# Deterministic visual variants derive from a stable coordinate hash so the
# same seed/cell/material always renders the same texture across sessions.

const DESCRIPTOR_PATH := "res://assets/art/production/terrain/terrain_atlas_pass_01.json"

# CellData.TerrainMaterial -> descriptor material key.
const MATERIAL_KEYS: Dictionary = {
	1: "soft_soil",
	2: "damp_clay",
	3: "loose_soil",
	4: "stone",
}

# Pass 01 visual fallbacks until dedicated assets arrive (documented in
# docs/art/ART_INTEGRATION_PASS_01.md): FOUNDATION shares the stone family and
# revealed ROOT_SOIL borrows the soft-soil center texture.
const FALLBACK_KEYS: Dictionary = {
	5: "stone",
	6: "soft_soil",
}

const BURROW_INTERIOR_KEY := "burrow_interior"
const ATLAS_BLEED_INSET_PX := 0.5

static var _shared: TerrainAtlasView

var _texture: Texture2D
var _entries: Dictionary = {}
var _tile_px := 128


static func get_shared() -> TerrainAtlasView:
	if _shared == null:
		_shared = TerrainAtlasView.new()
		_shared._load()
	return _shared


static func cell_variant_hash(cell_coord: Vector2i) -> int:
	return absi((cell_coord.x * 73856093) ^ (cell_coord.y * 19349663))


func _load() -> void:
	if not FileAccess.file_exists(DESCRIPTOR_PATH):
		return
	var file := FileAccess.open(DESCRIPTOR_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return
	var descriptor: Dictionary = parsed
	_tile_px = maxi(1, int(descriptor.get("atlas_tile_px", 128)))
	var atlas_path := String(descriptor.get("atlas", ""))
	if atlas_path.is_empty():
		return
	var resource_path := atlas_path if atlas_path.begins_with("res://") else "res://" + atlas_path
	_texture = load(resource_path) as Texture2D
	if _texture == null:
		return
	var raw_entries: Variant = descriptor.get("entries", {})
	if raw_entries is not Dictionary:
		return
	for key: String in raw_entries:
		var variants: Array = []
		for entry: Variant in raw_entries[key]:
			if entry is not Dictionary or bool(entry.get("empty", false)):
				continue
			if not entry.has("atlas_column"):
				continue
			variants.append({
				"column": int(entry.atlas_column),
				"base_color": Color(String(entry.get("edge_base_color", "#808080"))),
			})
		if not variants.is_empty():
			_entries[key] = variants


func is_available() -> bool:
	return _texture != null and not _entries.is_empty()


## Returns {texture, source_rect, base_color} or an empty dictionary when the
## material has no production tile yet.
func get_tile_for_key(material_key: String, variant_hash: int) -> Dictionary:
	if not is_available() or not _entries.has(material_key):
		return {}
	var variants: Array = _entries[material_key]
	var variant: Dictionary = variants[variant_hash % variants.size()]
	var column := int(variant.column)
	var source_rect := Rect2(
		column * _tile_px + ATLAS_BLEED_INSET_PX,
		ATLAS_BLEED_INSET_PX,
		_tile_px - ATLAS_BLEED_INSET_PX * 2.0,
		_tile_px - ATLAS_BLEED_INSET_PX * 2.0
	)
	return {
		"texture": _texture,
		"source_rect": source_rect,
		"base_color": variant.base_color,
	}


func get_tile_for_material(material: int, variant_hash: int) -> Dictionary:
	var key := String(MATERIAL_KEYS.get(material, FALLBACK_KEYS.get(material, "")))
	if key.is_empty():
		return {}
	return get_tile_for_key(key, variant_hash)


func get_burrow_interior_tile(variant_hash: int) -> Dictionary:
	return get_tile_for_key(BURROW_INTERIOR_KEY, variant_hash)
