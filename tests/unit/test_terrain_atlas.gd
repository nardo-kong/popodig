extends RefCounted

const TerrainAtlasViewScript = preload("res://src/presentation/world/terrain_atlas.gd")
const CellDataScript = preload("res://src/domain/world/cell_data.gd")

const DESCRIPTOR_PATH := "res://assets/art/production/terrain/terrain_atlas_pass_01.json"

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_descriptor_contract()
	_test_shared_atlas_available()
	_test_all_terrain_materials_resolve()
	_test_foundation_and_root_fallbacks()
	_test_variant_selection_is_deterministic()
	_test_coordinate_hash_is_stable()
	_test_missing_material_returns_empty_tile()
	return results


func _test_descriptor_contract() -> void:
	assert_true(FileAccess.file_exists(DESCRIPTOR_PATH), "Terrain atlas descriptor exists")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTOR_PATH))
	assert_true(parsed is Dictionary, "Terrain atlas descriptor parses as an object")
	if parsed is not Dictionary:
		return
	var descriptor: Dictionary = parsed
	assert_equal(int(descriptor.get("schema_version", 0)), 1, "Terrain atlas descriptor schema is v1")
	assert_equal(int(descriptor.get("source_px_per_cell", 0)), 128, "Pass 01 scale contract is 128 source px per cell")
	assert_true(FileAccess.file_exists("res://" + String(descriptor.get("atlas", ""))), "Terrain atlas texture exists")
	for key: String in ["soft_soil", "damp_clay", "loose_soil", "stone", "burrow_interior"]:
		assert_true(descriptor.get("entries", {}).has(key), "Atlas descriptor covers material family: %s" % key)


func _test_shared_atlas_available() -> void:
	var atlas := TerrainAtlasViewScript.get_shared()
	assert_true(atlas != null, "Shared terrain atlas instantiates")
	assert_true(atlas.is_available(), "Shared terrain atlas loads texture and entries")


func _test_all_terrain_materials_resolve() -> void:
	var atlas := TerrainAtlasViewScript.get_shared()
	for material_value: int in [
		CellDataScript.TerrainMaterial.SOFT_SOIL,
		CellDataScript.TerrainMaterial.DAMP_CLAY,
		CellDataScript.TerrainMaterial.LOOSE_SOIL,
		CellDataScript.TerrainMaterial.STONE,
	]:
		var tile := atlas.get_tile_for_material(material_value, 0)
		assert_true(not tile.is_empty(), "Material %d resolves a production tile" % material_value)
		if tile.is_empty():
			continue
		var source_rect: Rect2 = tile.source_rect
		assert_equal(int(source_rect.size.x), 127, "Material %d tile region is inset once around 128px cell" % material_value)
		assert_true(tile.texture != null, "Material %d tile binds the atlas texture" % material_value)
	var burrow := atlas.get_burrow_interior_tile(0)
	assert_true(not burrow.is_empty(), "Burrow interior resolves a production tile")


func _test_foundation_and_root_fallbacks() -> void:
	var atlas := TerrainAtlasViewScript.get_shared()
	var foundation := atlas.get_tile_for_material(CellDataScript.TerrainMaterial.FOUNDATION, 7)
	var stone := atlas.get_tile_for_material(CellDataScript.TerrainMaterial.STONE, 7)
	assert_true(not foundation.is_empty(), "FOUNDATION reuses the stone family for pass 01")
	if not foundation.is_empty() and not stone.is_empty():
		assert_equal(foundation.source_rect, stone.source_rect, "FOUNDATION shares the stone atlas slot")
	var root_soil := atlas.get_tile_for_material(CellDataScript.TerrainMaterial.ROOT_SOIL, 3)
	var soft_soil := atlas.get_tile_for_material(CellDataScript.TerrainMaterial.SOFT_SOIL, 3)
	assert_true(not root_soil.is_empty(), "ROOT_SOIL has a documented pass 01 fallback")
	if not root_soil.is_empty() and not soft_soil.is_empty():
		assert_equal(root_soil.source_rect, soft_soil.source_rect, "ROOT_SOIL borrows the soft-soil slot until root assets arrive")


func _test_variant_selection_is_deterministic() -> void:
	var atlas := TerrainAtlasViewScript.get_shared()
	var first := atlas.get_tile_for_material(CellDataScript.TerrainMaterial.SOFT_SOIL, TerrainAtlasViewScript.cell_variant_hash(Vector2i(31, 17)))
	var second := atlas.get_tile_for_material(CellDataScript.TerrainMaterial.SOFT_SOIL, TerrainAtlasViewScript.cell_variant_hash(Vector2i(31, 17)))
	assert_equal(first.source_rect, second.source_rect, "Same coordinate hash selects the same variant")
	assert_equal(
		TerrainAtlasViewScript.cell_variant_hash(Vector2i(31, 17)),
		TerrainAtlasViewScript.cell_variant_hash(Vector2i(31, 17)),
		"Coordinate hash is stable across calls"
	)


func _test_coordinate_hash_is_stable() -> void:
	# Locked regression value: guards against accidental re-hashing that would
	# reshuffle visible variants between sessions.
	assert_equal(TerrainAtlasViewScript.cell_variant_hash(Vector2i(0, 0)), 0, "Origin coordinate hashes to zero")
	assert_equal(TerrainAtlasViewScript.cell_variant_hash(Vector2i(1, 0)), 73856093, "Unit X coordinate hash matches contract")
	assert_equal(TerrainAtlasViewScript.cell_variant_hash(Vector2i(0, 1)), 19349663, "Unit Y coordinate hash matches contract")


func _test_missing_material_returns_empty_tile() -> void:
	var atlas := TerrainAtlasViewScript.get_shared()
	assert_true(atlas.get_tile_for_key("nonexistent_family", 5).is_empty(), "Unknown material family yields an empty tile")


func assert_true(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})


func assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
