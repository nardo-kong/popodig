extends "res://tests/test_case.gd"

const World = preload("res://src/domain/world/world_grid.gd")
const Cell = preload("res://src/domain/world/cell_data.gd")
const Registry = preload("res://src/domain/worldgen/feature_registry.gd")
const Feature = preload("res://src/domain/worldgen/generated_feature.gd")
const Items = preload("res://src/domain/colony/item_system.gd")
const Discovery = preload("res://src/domain/features/discovery_system.gd")
const Generator = preload("res://src/domain/worldgen/structured_world_generator.gd")


func run() -> Array[Dictionary]:
	var world := World.new(12, 8, 4)
	for y: int in range(8):
		for x: int in range(12):
			world.initialize_cell(Vector2i(x, y), Cell.TerrainMaterial.SOFT_SOIL, false, false, false)
	world.set_excavated(Vector2i(4, 4), true, true)
	var registry := Registry.new()
	var feature := Feature.new("discovery", Vector2i(5, 4), [Vector2i(5, 4)])
	feature.metadata = {"definition_id": "fiber_cache", "claimed": false}
	registry.add_feature(feature)
	var items := Items.new()
	items.configure(world, null)
	var discoveries := Discovery.new()
	discoveries.configure(world, registry, items, null)
	assert_true(not discoveries.claim(feature.id, Vector2i(0, 0)).ok, "Discovery cannot be claimed remotely")
	items.replace_cell_capacities({Vector2i(4, 4): 1})
	assert_equal(discoveries.claim(feature.id, Vector2i(4, 4)).reason, "OUTPUT_BLOCKED", "Blocked output does not consume discovery")
	assert_true(not bool(feature.metadata.claimed), "Full destination preserves reward entitlement")
	# Real JSON round-trip while output is blocked must retain retry exposure.
	var restored := Registry.new()
	assert_true(restored.apply_save_data(JSON.parse_string(JSON.stringify(registry.to_save_data()))).ok, "Pending discovery metadata survives real JSON load")
	var resumed := Discovery.new()
	resumed.configure(world, restored, items, null)
	items.replace_cell_capacities({})
	resumed.fixed_tick(0.6)
	assert_equal(items.get_total_count("GENERAL_MATERIAL"), 6, "Pending reward delivers after capacity recovers")
	resumed.fixed_tick(1.0)
	assert_true(not resumed.claim(feature.id, Vector2i(4, 4)).ok, "Retry and repeated claim cannot duplicate reward")
	assert_equal(items.get_total_count("GENERAL_MATERIAL"), 6, "Reward is delivered exactly once")
	assert_true(items.add_pile("ORE", Vector2i(4, 4), 3) > 0, "Ore is a usable physical resource")
	assert_true(items.add_pile("UNRECOGNISED", Vector2i(4, 4), 3) < 0, "Unknown resource is rejected on add")
	assert_true(not items.apply_save_data({"piles": [{"id": 1, "item_type": "UNKNOWN", "count": 4, "cell": [4, 4]}]}).ok, "Unknown saved resource is explicitly rejected")
	assert_equal(items.get_total_count("ORE"), 3, "Rejected inventory load preserves live resources")
	var config: Dictionary = AppConfig.get_document("worldgen")
	var first = Generator.new().generate_result(config, 137042)
	var replay = Generator.new().generate_result(config, 137042)
	assert_true(first.success and replay.success, "Discovery-enabled world remains valid")
	assert_equal(first.get_content_hash(), replay.get_content_hash(), "Discovery placement is deterministic")
	var available: Dictionary = {}
	for found in first.feature_registry.get_features("discovery"):
		available[str(found.metadata.definition_id)] = true
	assert_true(available.has("seed_cache") and available.has("fiber_cache") and available.has("stone_seam") and available.has("ore_seam"), "Generated world supplies food, building material, stone and ore")
	return results
