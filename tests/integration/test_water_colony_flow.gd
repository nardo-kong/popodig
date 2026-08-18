extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const ColonySimulationScript = preload("res://src/domain/colony/colony_simulation.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const ColonyJobScript = preload("res://src/domain/jobs/colony_job.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")
const RegistryScript = preload("res://src/domain/worldgen/feature_registry.gd")
const FeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_dig_breach_reaction_and_conservation()
	_test_flow_driven_emergency_haul()
	return results


func _test_dig_breach_reaction_and_conservation() -> void:
	var balance := _balance()
	var world := GridScript.new(12, 10, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var open := x >= 1 and x <= 10 and y >= 2 and y <= 4
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, open)
	world.metadata.start_cell = Vector2i(2, 3)
	world.metadata.signal_emitters = []
	var reservoir_cell := Vector2i(7, 5)
	var registry := RegistryScript.new()
	var reservoir := FeatureScript.new("water_reservoir", reservoir_cell, [reservoir_cell], true)
	reservoir.metadata = {"reserve_units": 8}
	registry.add_feature(reservoir)
	world.set_feature_id(reservoir_cell, reservoir.id)
	world.set_material(reservoir_cell, CellDataScript.TerrainMaterial.DAMP_CLAY)
	var path_service := PathServiceScript.new()
	path_service.configure(world, balance)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, balance)
	var colony := ColonySimulationScript.new()
	colony.configure(world, path_service, dig_system, balance, registry, {"signal_fields": {}})
	var dangerous_path: Array[Vector2i] = [reservoir_cell, Vector2i(7, 6), Vector2i(7, 7)]
	var designation: Dictionary = dig_system.designate_path(dangerous_path)
	_assert_true(designation.ok, "Player can freely plan a continuous dig through a hidden reservoir frontier")
	var breach_count: Array[int] = [0]
	colony.get_water_system().reservoir_breached.connect(func(_id: int, _cell: Vector2i, _danger: Array, _released: int) -> void:
		breach_count[0] += 1
	)
	var inventory_before: int = colony.get_water_system().get_conserved_inventory()
	for _tick: int in range(500):
		colony.fixed_tick(0.05)
		if not reservoir.hidden:
			break
	_assert_true(not reservoir.hidden, "Authoritative mouse digging breaches and persistently reveals the reservoir Feature")
	_assert_equal(breach_count[0], 1, "Reservoir breach reaction fires exactly once")
	_assert_true(bool(reservoir.metadata.reaction_fired), "Reservoir records its one-shot Reaction lifecycle state")
	_assert_equal(dig_system.get_designated_count(), 0, "Breach cancels queued follow-on digging inside the immediate danger region")
	var endangered := 0
	for mouse: MouseAgent in colony.get_mice():
		if mouse.danger_state:
			endangered += 1
	_assert_equal(endangered, colony.get_mice().size(), "Breach interrupts autonomous mice into the existing escape behavior")
	for _tick: int in range(30):
		colony.fixed_tick(0.2)
	var still_endangered := 0
	for mouse: MouseAgent in colony.get_mice():
		if mouse.danger_state:
			still_endangered += 1
	_assert_equal(still_endangered, 0, "Mice resume autonomy after reaching safe cells outside the short-term breach reaction")
	_assert_equal(colony.get_water_system().get_conserved_inventory(), inventory_before, "Breach, source discharge, and blocked pooling conserve finite water inventory")
	_assert_true(world.get_water_units(reservoir_cell) > 0, "Breach changes the continuous map with standing water instead of resolving as an event card")
	_assert_true(int(reservoir.metadata.reserve_units) < 8, "Finite source reserve moves into world cells over time")


func _test_flow_driven_emergency_haul() -> void:
	var balance := _balance()
	var world := GridScript.new(12, 9, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var open := x >= 1 and x <= 10 and y >= 2 and y <= 7
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, open)
	world.metadata.start_cell = Vector2i(2, 3)
	world.metadata.signal_emitters = []
	var path_service := PathServiceScript.new()
	path_service.configure(world, balance)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, balance)
	var colony := ColonySimulationScript.new()
	colony.configure(world, path_service, dig_system, balance, RegistryScript.new(), {"signal_fields": {}})
	var zones = colony.get_zone_system()
	var fallback_cell := Vector2i(3, 3)
	var threatened_cell := Vector2i(8, 4)
	for cell: Vector2i in [fallback_cell, threatened_cell]:
		var painted: Dictionary = zones.paint_zone(ZoneScript.Type.STORAGE, [cell])
		var zone: Zone = zones.get_zone_at(cell)
		_assert_true(painted.ok and zone != null, "Flow emergency fixture creates Storage space")
		zones.begin_setup(zone.zone_id)
		zones.apply_setup_material(zone.zone_id, zone.setup_material_required)
	var pile_id: int = colony.add_item_pile(ItemSystemScript.FOOD, threatened_cell, 5)
	colony.fixed_tick(0.05)
	world.set_water_units(threatened_cell + Vector2i.UP, 1)
	colony.fixed_tick(0.2)
	var emergency_found := false
	for job: ColonyJob in colony.get_job_system().get_jobs():
		if job.job_type == ColonyJobScript.Type.EMERGENCY_HAUL and job.source_pile_id == pile_id:
			emergency_found = true
			break
	_assert_equal(world.get_water_units(threatened_cell), 1, "Tile flow enters Storage at a still-walkable early warning depth")
	_assert_true(emergency_found, "Flow-driven wetness creates the existing high-priority Emergency Haul job")
	for _tick: int in range(400):
		colony.fixed_tick(0.05)
		if colony.get_item_system().get_count_at(fallback_cell) == 5:
			break
	_assert_equal(colony.get_item_system().get_count_at(threatened_cell), 0, "Autonomous mice remove stores from the water path")
	_assert_equal(colony.get_item_system().get_count_at(fallback_cell), 5, "Emergency Haul settles threatened Food in dry Storage")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.FOOD), 5, "Flow-driven emergency response conserves stored Food")


func _balance() -> Dictionary:
	return {
		"initial_mouse_count": 3,
		"digging": {"base_dig_seconds": 0.25, "simulation_step_seconds": 0.05},
		"mouse": {
			"move_cells_per_second": 8.0,
			"dig_work_per_second": 2.0,
			"initial_hunger": 0.0,
			"hunger_per_second": 0.0,
			"initial_rest": 1.0,
			"rest_drain_per_second": 0.0,
		},
		"jobs": {
			"dig_priority": 10.0,
			"seal_priority": 35.0,
			"haul_priority": 20.0,
			"emergency_priority": 100.0,
			"travel_cost_weight": 0.25,
			"unreachable_retry_seconds": 0.2,
		},
		"pathfinding": {"max_walkable_water_units": 1},
		"zones": {"storage_capacity_per_cell": 12, "sleeping_capacity_per_cell": 1},
		"water": {
			"cell_capacity_units": 4,
			"simulation_step_seconds": 0.2,
			"max_transfers_per_step": 64,
			"source_release_per_step": 2,
			"breach_initial_units": 1,
			"stable_quiet_steps": 3,
			"danger_radius": 3,
			"danger_water_units": 2,
		},
	}


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({"passed": passed, "description": description, "details": "" if passed else "Expected %s, got %s" % [expected, actual]})
