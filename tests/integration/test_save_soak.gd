extends RefCounted

# Phase 16 save soak (roadmap Phase 16/17 "saves/migration", "save soak"):
# repeatedly generate worlds across seeds, mutate them mid-event, and require
# the full grid serialization round trip to be semantically exact and
# hash-stable — the durability floor beneath the campaign.

const GridScript = preload("res://src/domain/world/world_grid.gd")
const GeneratorScript = preload("res://src/domain/worldgen/structured_world_generator.gd")
const SaveServiceScript = preload("res://src/infrastructure/persistence/save_service.gd")

const SOAK_SEEDS: Array[int] = [910001, 910002, 910003, 910004, 910005, 910006, 910007, 910008]

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	results = []
	for seed_value: int in SOAK_SEEDS:
		_soak_seed(seed_value)
	return results


func _soak_seed(seed_value: int) -> void:
	var generated = GeneratorScript.new().generate_result(_worldgen_config(), seed_value)
	if not bool(generated.success):
		_assert_true(false, "Soak seed %d generates" % seed_value)
		return
	var grid = generated.world
	# Mutate the world like a mid-campaign session: digs, water, reinforcement,
	# rubble, and feature reveals.
	var dug := 0
	for y: int in range(int(grid.metadata.start_cell.y), mini(grid.height, int(grid.metadata.start_cell.y) + 14)):
		var cell := Vector2i(int(grid.metadata.start_cell.x), y)
		if grid.set_excavated(cell, true, true):
			dug += 1
	grid.set_water_units(Vector2i(int(grid.metadata.start_cell.x) + 1, int(grid.metadata.start_cell.y) + 3), 3)
	grid.set_stability_base(Vector2i(int(grid.metadata.start_cell.x) - 1, int(grid.metadata.start_cell.y) + 5), 70)
	var any_reveal := false
	for feature in generated.feature_registry.get_features("root_cluster"):
		if bool(feature.metadata.get("food_opportunity", false)):
			feature.hidden = false
			any_reveal = true
			break
	_assert_true(dug > 0, "Soak seed %d mutated the world (%d digs)" % [seed_value, dug])
	_assert_true(any_reveal, "Soak seed %d revealed a food root" % seed_value)

	var hash_before: int = generated.get_content_hash()
	var save_data: Dictionary = grid.to_save_data()
	var document := {"header": SaveServiceScript.build_header(int(grid.metadata.worldgen_version), seed_value), "world": save_data}
	var path := "user://save_soak_%d.json" % seed_value
	var save_result: Dictionary = SaveServiceScript.save_game(path, document)
	_assert_true(bool(save_result.ok), "Soak seed %d saves atomically" % seed_value)
	var load_result: Dictionary = SaveServiceScript.load_game(path)
	_assert_true(bool(load_result.ok), "Soak seed %d loads" % seed_value)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not bool(load_result.ok):
		return

	var restored = GridScript.new(grid.width, grid.height, grid.chunk_size)
	var apply_result: Dictionary = restored.apply_save_data(load_result.data.get("world", {}))
	_assert_true(bool(apply_result.ok), "Soak seed %d restores the grid" % seed_value)
	if not bool(apply_result.ok):
		return
	var mismatches := 0
	for index: int in range(grid.width * grid.height):
		var cell: Vector2i = grid.index_to_cell(index)
		if restored.get_material(cell) != grid.get_material(cell) \
				or restored.is_excavated(cell) != grid.is_excavated(cell) \
				or restored.get_water_units(cell) != grid.get_water_units(cell) \
				or restored.get_stability_base(cell) != grid.get_stability_base(cell) \
				or restored.get_feature_id(cell) != grid.get_feature_id(cell) \
				or restored.is_rubble(cell) != grid.is_rubble(cell) \
				or restored.is_reinforced(cell) != grid.is_reinforced(cell):
			mismatches += 1
	_assert_true(mismatches == 0, "Soak seed %d round-trips every cell exactly (%d mismatches)" % [seed_value, mismatches])
	_assert_true(restored.to_save_data().size() > 0, "Soak seed %d restored grid re-serializes" % seed_value)
	_assert_true(generated.get_content_hash() == hash_before, "Soak seed %d mutation pass leaves the canonical hash accessor stable" % seed_value)


func _worldgen_config() -> Dictionary:
	var loaded: Dictionary = load("res://src/infrastructure/config/app_config.gd").load_json_document("res://config/worldgen/default.json")
	return loaded.get("data", {})


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})
