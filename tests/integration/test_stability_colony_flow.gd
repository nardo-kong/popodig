extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const ColonySimulationScript = preload("res://src/domain/colony/colony_simulation.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_autonomous_reinforcement_resolves_critical_span()
	_test_collapse_updates_topology_and_mice_recover()
	_test_collapse_invalidates_zones()
	return results


func _test_autonomous_reinforcement_resolves_critical_span() -> void:
	var context := _context()
	var world = context.world
	var colony = context.colony
	var stability = colony.get_stability_system()
	colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(3, 3), 2)
	var material_before: int = colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL)
	var request_cell := Vector2i(5, 3)
	var request: Dictionary = colony.request_reinforce(request_cell)
	_assert_true(request.ok, "Player can request reinforcement inside a critical span")
	for _tick: int in range(600):
		colony.fixed_tick(0.05)
		if world.is_reinforced(request_cell + Vector2i.UP):
			break
	_assert_true(world.is_reinforced(request_cell + Vector2i.UP), "A mouse autonomously hauls material and reinforces the ceiling")
	_assert_equal(
		colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL),
		material_before - 1,
		"Reinforcement consumes exactly one General Material"
	)
	_assert_true(stability.get_completed_count() == 1, "Reinforcement completion is recorded exactly once")
	for _tick: int in range(260):
		colony.fixed_tick(0.05)
	_assert_true(context.world.is_traversable(Vector2i(7, 3)), "Reinforced span never collapses afterwards")


func _test_collapse_updates_topology_and_mice_recover() -> void:
	var context := _context()
	var world = context.world
	var colony = context.colony
	var stability = colony.get_stability_system()
	var food_before: int = colony.add_item_pile(ItemSystemScript.FOOD, Vector2i(5, 3), 4)
	_assert_true(food_before > 0, "Fixture places a food pile inside the doomed span")
	var revision_before: int = context.path_service.get_topology_revision()
	var collapsed := false
	for _tick: int in range(600):
		colony.fixed_tick(0.05)
		if int(stability.get_debug_snapshot().collapsed_cells_total) > 0:
			collapsed = true
			break
	_assert_true(collapsed, "An ignored critical span collapses autonomously after its grace period")
	for _tick: int in range(160):
		colony.fixed_tick(0.05)
	_assert_true(not world.is_traversable(Vector2i(5, 3)), "Collapsed rubble refills the corridor and blocks the old route")
	_assert_true(world.is_traversable(Vector2i(10, 3)), "Collapse arrests at the stone-supported segment")
	_assert_true(context.path_service.get_topology_revision() > revision_before, "Collapse fires path topology updates")
	for mouse in colony.get_mice():
		_assert_true(
			context.path_service.is_walkable(mouse.current_cell),
			"No mouse remains trapped inside rubble (%s at %s)" % [mouse.mouse_id, str(mouse.current_cell)]
		)
	var surviving_food := 0
	var food_on_open_ground := true
	for pile in colony.get_item_system().get_piles():
		if pile.item_type != ItemSystemScript.FOOD or pile.count <= 0:
			continue
		surviving_food += pile.count
		food_on_open_ground = food_on_open_ground and world.is_traversable(pile.cell)
	_assert_true(surviving_food <= 4, "Collapse only ever destroys a bounded share of stored goods")
	_assert_true(food_on_open_ground, "Surviving goods rest on open ground, never inside solid rubble")
	var dig_result: Dictionary = context.dig_system.designate_path([Vector2i(8, 3)])
	_assert_true(dig_result.ok, "Ordinary DIG can target collapsed rubble next to surviving space")
	var reopened := false
	for _tick: int in range(600):
		colony.fixed_tick(0.05)
		if world.is_traversable(Vector2i(8, 3)):
			reopened = true
			break
	_assert_true(reopened, "Autonomous digging re-opens the rubble and restores the passage")


func _test_collapse_invalidates_zones() -> void:
	var context := _context()
	var world = context.world
	var colony = context.colony
	var zones = colony.get_zone_system()
	var zone_cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3)]
	var painted: Dictionary = zones.paint_zone(ZoneScript.Type.STORAGE, zone_cells)
	_assert_true(painted.ok, "Storage zone paints inside the span before collapse")
	var zone = zones.get_zone_at(Vector2i(4, 3))
	zones.begin_setup(zone.zone_id)
	zones.apply_setup_material(zone.zone_id, zone.setup_material_required)
	var stability = colony.get_stability_system()
	var collapsed := false
	for _tick: int in range(600):
		colony.fixed_tick(0.05)
		if int(stability.get_debug_snapshot().collapsed_cells_total) > 0:
			collapsed = true
			break
	_assert_true(collapsed, "The zoned span still collapses when warnings are ignored")
	zone = zones.get_zone_at(Vector2i(4, 3))
	_assert_true(zone == null or not zone.valid, "Collapse invalidates any zone that relied on the filled cells")


func _context() -> Dictionary:
	var balance := {
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
			"reinforce_priority": 30.0,
			"haul_priority": 20.0,
			"emergency_priority": 100.0,
			"travel_cost_weight": 0.25,
			"unreachable_retry_seconds": 0.2,
		},
		"pathfinding": {"max_walkable_water_units": 3},
		"zones": {"storage_capacity_per_cell": 12, "sleeping_capacity_per_cell": 1},
		"stability": {
			"span_short": 3,
			"span_moderate": 6,
			"span_high": 12,
			"crumbs_ratio": 0.6,
			"cracking_ratio": 0.85,
			"critical_grace_seconds": 8.0,
			"max_collapse_radius": 3,
			"reinforce_material_per_cell": 1,
			"item_damage_fraction": 0.5,
		},
	}
	var world := GridScript.new(18, 10, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false, false, false)
	world.set_material(Vector2i(9, 2), CellDataScript.TerrainMaterial.STONE)
	world.set_material(Vector2i(10, 2), CellDataScript.TerrainMaterial.STONE)
	for x: int in range(2, 11):
		world.set_excavated(Vector2i(x, 3), true, true)
	world.metadata.start_cell = Vector2i(9, 3)
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


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({"passed": passed, "description": description, "details": "" if passed else "Expected %s, got %s" % [expected, actual]})
