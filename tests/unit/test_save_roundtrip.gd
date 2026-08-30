extends RefCounted

const GridScript = preload("res://src/domain/world/world_grid.gd")
const RegistryScript = preload("res://src/domain/worldgen/feature_registry.gd")
const FeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")
const SignalSystemScript = preload("res://src/domain/features/signal_system.gd")
const WaterSystemScript = preload("res://src/domain/features/water_system.gd")
const StabilitySystemScript = preload("res://src/domain/features/stability_system.gd")
const ColonySimulationScript = preload("res://src/domain/colony/colony_simulation.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const CellDataScript = preload("res://src/domain/world/cell_data.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_world_grid_round_trip()
	_test_feature_registry_round_trip()
	_test_signal_recognition_round_trip()
	_test_water_active_cells_round_trip()
	_test_stability_state_round_trip()
	_test_colony_round_trip()
	return results


func _make_grid(width: int = 20, height: int = 14) :
	var grid = GridScript.new(width, height, 7)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var material := CellDataScript.TerrainMaterial.SOFT_SOIL
			if x % 5 == 0:
				material = CellDataScript.TerrainMaterial.STONE
			elif x % 3 == 0:
				material = CellDataScript.TerrainMaterial.DAMP_CLAY
			grid.initialize_cell(Vector2i(x, y), material, false, x == 0, false)
	for x: int in range(2, 9):
		grid.set_excavated(Vector2i(x, 5), true, true)
	grid.set_water_units(Vector2i(12, 11), 2)
	grid.set_water_units(Vector2i(13, 11), 1)
	grid.set_rubble(Vector2i(5, 3), true)
	grid.set_reinforced(Vector2i(6, 4), true)
	grid.set_dig_state(Vector2i(7, 6), 1)
	grid.set_dig_progress(Vector2i(7, 6), 0.42)
	grid.set_stability_base(Vector2i(8, 5), 55)
	return grid


func _test_world_grid_round_trip() -> void:
	var grid = _make_grid()
	var saved: Dictionary = grid.to_save_data()
	var restored = GridScript.new(grid.width, grid.height, 7)
	for y: int in range(restored.height):
		for x: int in range(restored.width):
			restored.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.EMPTY, false, false, false)
	var apply_result: Dictionary = restored.apply_save_data(saved)
	_assert(bool(apply_result.ok), "World grid save data applies: %s" % String(apply_result.error))
	if not bool(apply_result.ok):
		return
	_assert(restored.to_save_data().hash() == saved.hash(), "World grid save data round-trips identically")
	_assert(restored.get_water_units(Vector2i(12, 11)) == 2 and restored.get_water_units(Vector2i(13, 11)) == 1, "Water units survive the round trip")
	_assert(restored.is_rubble(Vector2i(5, 3)), "Rubble flag survives the round trip")
	_assert(restored.is_reinforced(Vector2i(6, 4)), "Reinforcement flag survives the round trip")
	_assert(absf(restored.get_cell(Vector2i(7, 6)).dig_progress - 0.42) < 0.001, "Dig progress survives the round trip")
	_assert(restored.get_cell(Vector2i(2, 5)).hardness > 0.0, "Hardness is re-derived from restored terrain")


func _test_feature_registry_round_trip() -> void:
	var registry = RegistryScript.new()
	var feature = FeatureScript.new("water_reservoir", Vector2i(9, 7), [Vector2i(9, 7), Vector2i(10, 7)], true)
	feature.hidden = false
	feature.metadata = {
		"reserve_units": 13,
		"lifecycle_state": "STABLE_STATE",
		"outlet_cell": Vector2i(9, 8),
	}
	registry.add_feature(feature)
	var saved: Dictionary = registry.to_save_data()
	var restored = RegistryScript.new()
	var apply_result: Dictionary = restored.apply_save_data(saved)
	_assert(bool(apply_result.ok), "Feature registry save data applies: %s" % String(apply_result.error))
	if not bool(apply_result.ok):
		return
	_assert(restored.to_save_data().hash() == saved.hash(), "Feature registry save data round-trips identically")
	var restored_feature = restored.get_feature(feature.id)
	_assert(restored_feature != null, "Feature survives the round trip with its id")
	if restored_feature != null:
		_assert(int(restored_feature.metadata.reserve_units) == 13, "Runtime reserve survives the round trip")
		_assert(restored_feature.metadata.outlet_cell is Vector2i, "Vector2i metadata converts back from JSON arrays")
		_assert(restored_feature.metadata.outlet_cell == Vector2i(9, 8), "Outlet cell value survives the round trip")


func _test_signal_recognition_round_trip() -> void:
	var signals = SignalSystemScript.new()
	signals._recognition["root_cluster"] = 2
	signals._recognition["water_reservoir"] = 1
	var saved: Dictionary = signals.to_save_data()
	var restored = SignalSystemScript.new()
	restored.apply_save_data(saved)
	_assert(restored.get_recognition_level("root_cluster") == 2, "Root recognition level survives the round trip")
	_assert(restored.get_recognition_level("water_reservoir") == 1, "Water recognition level survives the round trip")


func _test_water_active_cells_round_trip() -> void:
	var water = WaterSystemScript.new()
	water._active_cells[Vector2i(4, 5)] = true
	water._active_cells[Vector2i(5, 5)] = true
	water._quiet_steps = 2
	water._sleeping = false
	var saved: Dictionary = water.to_save_data()
	var restored = WaterSystemScript.new()
	var apply_result: Dictionary = restored.apply_save_data(saved)
	_assert(bool(apply_result.ok), "Water save data applies: %s" % String(apply_result.error))
	_assert(restored._active_cells.size() == 2, "Active water cells survive the round trip")
	_assert(restored._active_cells.has(Vector2i(4, 5)), "Active water cell keys survive the round trip")
	_assert(restored._sleeping == false, "Pool sleep state survives the round trip")


func _test_stability_state_round_trip() -> void:
	var grid = _make_grid()
	var stability = StabilitySystemScript.new()
	stability.configure(grid, RegistryScript.new(), null, null, {}, [])
	stability.request_reinforce(Vector2i(3, 5))
	var saved: Dictionary = stability.to_save_data()
	var restored = StabilitySystemScript.new()
	restored.configure(grid, RegistryScript.new(), null, null, {}, [])
	var apply_result: Dictionary = restored.apply_save_data(saved)
	_assert(bool(apply_result.ok), "Stability save data applies: %s" % String(apply_result.error))
	var restored_requests: Array[Dictionary] = restored.get_requests()
	_assert(restored_requests.size() == 1, "Pending reinforcement request survives the round trip")
	if restored_requests.size() == 1:
		_assert(restored_requests[0].cell == Vector2i(3, 5), "Reinforcement request cell survives the round trip")
		_assert(int(restored_requests[0].request_id) == 1, "Reinforcement request id survives the round trip")


func _test_colony_round_trip() -> void:
	var grid = _make_grid()
	var path_service = PathServiceScript.new()
	var balance := {"initial_mouse_count": 1, "mouse": {}, "jobs": {}, "zones": {"setup_material_per_zone": 1, "storage_capacity_per_cell": 12, "sleeping_capacity_per_cell": 1, "dry_water_max_units": 0}, "pathfinding": {"max_walkable_water_units": 1}}
	path_service.configure(grid, balance)
	var dig_system = DigSystemScript.new()
	dig_system.configure(grid, path_service, balance)
	grid.metadata["start_cell"] = Vector2i(2, 5)
	var colony = ColonySimulationScript.new()
	colony.configure(grid, path_service, dig_system, balance, RegistryScript.new(), {})
	colony.add_mouse("mouse_2", Vector2i(3, 5))
	colony.add_item_pile("FOOD", Vector2i(4, 5), 5)
	var zone_result: Dictionary = colony.get_zone_system().paint_zone(0, [Vector2i(2, 5), Vector2i(3, 5)])
	_assert(bool(zone_result.ok), "Zone fixture paints for the colony round trip")
	var first_mouse = colony.get_mice()[0]
	first_mouse.hunger = 0.42
	first_mouse.rest = 0.77
	var saved: Dictionary = colony.to_save_data()
	var restored = ColonySimulationScript.new()
	restored.configure(grid, path_service, dig_system, balance, RegistryScript.new(), {})
	var apply_result: Dictionary = restored.apply_save_data(saved)
	_assert(bool(apply_result.ok), "Colony save data applies: %s" % String(apply_result.error))
	if not bool(apply_result.ok):
		return
	_assert(restored.get_mice().size() == 2, "Both mice survive the colony round trip")
	var restored_mouse = restored.get_mouse("mouse_1")
	_assert(restored_mouse != null and absf(restored_mouse.hunger - 0.42) < 0.001, "Mouse hunger survives the round trip")
	_assert(restored_mouse != null and absf(restored_mouse.rest - 0.77) < 0.001, "Mouse rest survives the round trip")
	_assert(restored.get_item_system().get_total_count("FOOD") == 5, "Item piles survive the colony round trip")
	_assert(restored.get_zone_system().get_zones().size() == 1, "Zones survive the colony round trip")
	if restored.get_zone_system().get_zones().size() == 1:
		_assert(restored.get_zone_system().get_zones()[0].cells.size() == 2, "Zone membership survives the round trip")


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
