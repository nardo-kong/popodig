extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const ColonySimulationScript = preload("res://src/domain/colony/colony_simulation.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_autonomous_seal_and_dig_removal()
	_test_wet_seal_displacement_conserves_water()
	return results


func _test_autonomous_seal_and_dig_removal() -> void:
	var context := _context()
	var world = context.world
	var colony = context.colony
	var seal_cell := Vector2i(7, 3)
	colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(3, 3), 3)
	var request: Dictionary = colony.request_seal(seal_cell)
	_assert_true(request.ok, "Player can request a seal in connected excavated space")
	for _tick: int in range(300):
		colony.fixed_tick(0.05)
		if world.is_sealed(seal_cell):
			break
	_assert_true(world.is_sealed(seal_cell), "Mouse autonomously hauls material and constructs the requested seal")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL), 2, "Seal construction consumes exactly one General Material")
	_assert_equal(colony.get_seal_system().get_completed_count(), 1, "Seal completion is recorded exactly once")
	_assert_true(not context.path_service.is_walkable(seal_cell), "Completed seal immediately updates path topology")
	for mouse: MouseAgent in colony.get_mice():
		_assert_true(mouse.current_cell != seal_cell, "Seal construction leaves its worker on an adjacent safe work cell")
	var dig_result: Dictionary = context.dig_system.designate_path([seal_cell])
	_assert_true(dig_result.ok, "Ordinary DIG designation can target a constructed seal")
	for _tick: int in range(300):
		colony.fixed_tick(0.05)
		if not world.is_sealed(seal_cell):
			break
	_assert_true(not world.is_sealed(seal_cell) and world.is_traversable(seal_cell), "Autonomous digging removes the seal and restores the original passage")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL), 2, "Removing a seal does not duplicate refunded material")


func _test_wet_seal_displacement_conserves_water() -> void:
	var context := _context()
	var world = context.world
	var colony = context.colony
	var seal_cell := Vector2i(7, 3)
	world.set_water_units(seal_cell, 3)
	colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(3, 3), 1)
	var request: Dictionary = colony.request_seal(seal_cell)
	_assert_true(request.ok, "Wet open cell remains a legal containment request")
	for _tick: int in range(300):
		colony.fixed_tick(0.05)
		if world.is_sealed(seal_cell):
			break
	var total_water := 0
	for index: int in range(world.width * world.height):
		total_water += world.get_water_units(world.index_to_cell(index))
	_assert_true(world.is_sealed(seal_cell), "Seal completion can displace a shallow local pool into available adjacent capacity")
	_assert_equal(world.get_water_units(seal_cell), 0, "No inaccessible water remains inside the solid seal cell")
	_assert_equal(total_water, 3, "Wet seal displacement conserves all water units")


func _context() -> Dictionary:
	var balance := _balance()
	var world := GridScript.new(10, 8, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var open := x >= 1 and x <= 8 and y >= 2 and y <= 5
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, open)
	world.metadata.start_cell = Vector2i(2, 3)
	var path_service := PathServiceScript.new()
	path_service.configure(world, balance)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, balance)
	var colony := ColonySimulationScript.new()
	colony.configure(world, path_service, dig_system, balance)
	return {
		"world": world,
		"path_service": path_service,
		"dig_system": dig_system,
		"colony": colony,
	}


func _balance() -> Dictionary:
	return {
		"initial_mouse_count": 2,
		"digging": {"base_dig_seconds": 0.8, "simulation_step_seconds": 0.05},
		"mouse": {
			"move_cells_per_second": 6.0,
			"dig_work_per_second": 1.0,
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
		"pathfinding": {"max_walkable_water_units": 3},
		"zones": {"storage_capacity_per_cell": 12, "sleeping_capacity_per_cell": 1},
	}


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({"passed": passed, "description": description, "details": "" if passed else "Expected %s, got %s" % [expected, actual]})
