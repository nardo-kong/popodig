extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const ColonySimulationScript = preload("res://src/domain/colony/colony_simulation.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")
const ZoneSystemScript = preload("res://src/domain/zones/zone_system.gd")
const ColonyJobScript = preload("res://src/domain/jobs/colony_job.gd")

const BALANCE := {
	"initial_mouse_count": 3,
	"digging": {"base_dig_seconds": 0.8},
	"mouse": {
		"move_cells_per_second": 8.0,
		"dig_work_per_second": 1.0,
		"initial_hunger": 0.0,
		"hunger_per_second": 0.0001,
		"food_restore": 0.75,
		"hunger_seek_threshold": 0.65,
		"hunger_critical_threshold": 0.9,
		"initial_rest": 0.9,
		"rest_drain_per_second": 0.0001,
		"rest_seek_threshold": 0.25,
		"rest_critical_threshold": 0.08,
		"rest_recover_per_second": 0.2,
		"rest_resume_threshold": 0.9,
		"need_interrupt_priority_ceiling": 25.0,
	},
	"jobs": {
		"dig_priority": 10.0,
		"zone_setup_priority": 15.0,
		"haul_priority": 20.0,
		"emergency_priority": 100.0,
		"travel_cost_weight": 0.25,
		"unreachable_retry_seconds": 1.0,
	},
	"pathfinding": {"max_walkable_water_units": 1},
	"zones": {
		"setup_material_per_zone": 1,
		"storage_capacity_per_cell": 12,
		"sleeping_capacity_per_cell": 1,
		"dry_water_max_units": 0,
	},
}

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_space_commands_support_normal_colony_life()
	_test_inaccessible_pile_waits_for_topology_without_capacity_leak()
	_test_existing_overcapacity_is_rebalanced()
	_test_threatened_storage_evacuates_while_walkable()
	_test_carrier_finds_distant_safe_stash_beyond_full_storage()
	return results


func _test_space_commands_support_normal_colony_life() -> void:
	var context := _context()
	var colony = context.colony
	var zones = colony.get_zone_system()
	var items = colony.get_item_system()
	var jobs = colony.get_job_system()
	var sleeping_cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
	var storage_cells: Array[Vector2i] = [Vector2i(6, 2), Vector2i(7, 2), Vector2i(6, 3), Vector2i(7, 3)]
	var food_cells: Array[Vector2i] = [Vector2i(9, 4), Vector2i(10, 4)]
	_assert_true(zones.paint_zone(ZoneScript.Type.SLEEPING, sleeping_cells).ok, "Player space command creates a Sleeping zone")
	_assert_true(zones.paint_zone(ZoneScript.Type.STORAGE, storage_cells).ok, "Player space command creates a Storage zone")
	_assert_true(zones.paint_zone(ZoneScript.Type.FOOD_FORAGE, food_cells).ok, "Player space command creates a Food/Forage zone")
	var setup_zones: int = zones.get_zones().size()
	var material_before: int = items.get_total_count(ItemSystemScript.GENERAL_MATERIAL)
	var food_before: int = items.get_total_count(ItemSystemScript.FOOD)
	var setup_completed := false
	for _tick: int in range(1600):
		colony.fixed_tick(0.05)
		setup_completed = _all_zones_set_up(zones)
		if setup_completed and _all_items_in_usable_storage(colony) and jobs.get_pending_count() == 0 and jobs.get_active_count() == 0:
			break
	_assert_true(setup_completed, "Three autonomous mice complete every Zone Setup job")
	_assert_equal(
		items.get_total_count(ItemSystemScript.GENERAL_MATERIAL),
		material_before - setup_zones,
		"Zone Setup consumes exactly the configured General Material"
	)
	_assert_equal(items.get_total_count(ItemSystemScript.FOOD), food_before, "Automatic setup and storage preserve Food")
	_assert_true(_all_items_in_usable_storage(colony), "Loose Food and Material are autonomously hauled into usable Storage")
	_assert_true(_storage_respects_capacity(colony), "Automatic storage respects every logical cell capacity")
	_assert_equal(items.get_debug_reservations().size(), 0, "Completed zone work leaves no source reservation")
	_assert_equal(items.get_debug_dropoff_reservations().size(), 0, "Completed zone work leaves no destination-capacity reservation")
	for zone: Zone in zones.get_zones():
		var dressing: Dictionary = zones.get_dressing_contract(zone.zone_id)
		_assert_true(dressing.ready and dressing.engineering_placeholder, "Set-up zone exposes deterministic placeholder dressing")
	var sleeper = colony.get_mice()[0]
	sleeper.rest = 0.05
	var saw_zone_rest := false
	for _tick: int in range(240):
		colony.fixed_tick(0.05)
		if sleeper.get_state_name() == "RESTING":
			var rest_zone: Zone = zones.get_zone_at(sleeper.current_cell)
			if rest_zone != null and rest_zone.zone_type == ZoneScript.Type.SLEEPING:
				saw_zone_rest = true
				break
	_assert_true(saw_zone_rest, "Low Rest autonomously selects a set-up Sleeping cell")
	var resize_pile = _first_stored_pile(colony)
	_assert_true(resize_pile != null, "Storage resize fixture finds a stored pile")
	var old_storage_cell: Vector2i = resize_pile.cell
	var food_owned_before_resize: int = _owned_total(colony, ItemSystemScript.FOOD)
	var material_owned_before_resize: int = _owned_total(colony, ItemSystemScript.GENERAL_MATERIAL)
	_assert_true(zones.erase_cells([old_storage_cell]).ok, "Player can resize Storage beneath an existing pile")
	var relocated := false
	for _tick: int in range(800):
		colony.fixed_tick(0.05)
		if items.get_count_at(old_storage_cell) == 0 and jobs.get_pending_count() == 0 and jobs.get_active_count() == 0:
			relocated = true
			break
	_assert_true(relocated, "Storage resize creates autonomous relocation instead of deleting the pile")
	_assert_equal(_owned_total(colony, ItemSystemScript.FOOD), food_owned_before_resize, "Storage resize conserves Food")
	_assert_equal(_owned_total(colony, ItemSystemScript.GENERAL_MATERIAL), material_owned_before_resize, "Storage resize conserves General Material")
	_assert_true(_all_items_in_usable_storage(colony), "Colony returns to a stable storage layout after resize")
	_run_stability_soak(colony, food_owned_before_resize, material_owned_before_resize)


func _run_stability_soak(colony, expected_food: int, expected_material: int) -> void:
	var jobs = colony.get_job_system()
	var items = colony.get_item_system()
	var reservations_remained_bounded := true
	var storage_remained_valid := true
	for _tick: int in range(2000):
		colony.fixed_tick(0.05)
		reservations_remained_bounded = reservations_remained_bounded \
			and items.get_debug_reservations().size() <= colony.get_mice().size() \
			and items.get_debug_dropoff_reservations().size() <= colony.get_mice().size()
		if _tick % 100 == 0:
			storage_remained_valid = storage_remained_valid and _all_items_in_usable_storage(colony)
	_assert_true(reservations_remained_bounded, "100-second zone soak keeps source and destination reservations bounded")
	_assert_true(storage_remained_valid, "100-second zone soak keeps stored piles in valid set-up Storage")
	_assert_equal(_owned_total(colony, ItemSystemScript.FOOD), expected_food, "100-second zone soak conserves Food")
	_assert_equal(_owned_total(colony, ItemSystemScript.GENERAL_MATERIAL), expected_material, "100-second zone soak conserves General Material")
	_assert_equal(jobs.get_pending_count(), 0, "100-second zone soak leaves no pending work")
	_assert_equal(jobs.get_active_count(), 0, "100-second zone soak leaves no active work")
	_assert_equal(items.get_debug_reservations().size(), 0, "100-second zone soak releases source reservations")
	_assert_equal(items.get_debug_dropoff_reservations().size(), 0, "100-second zone soak releases destination reservations")


func _test_inaccessible_pile_waits_for_topology_without_capacity_leak() -> void:
	var world := GridScript.new(9, 5, 3)
	for y: int in range(world.height):
		for x: int in range(world.width):
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false)
	for x: int in range(1, 4):
		world.initialize_cell(Vector2i(x, 2), CellDataScript.TerrainMaterial.SOFT_SOIL, true)
	world.initialize_cell(Vector2i(5, 2), CellDataScript.TerrainMaterial.SOFT_SOIL, true)
	world.metadata = {"start_cell": Vector2i(1, 2), "seed": 741}
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, BALANCE)
	var colony := ColonySimulationScript.new()
	colony.configure(world, path_service, dig_system, BALANCE)
	var zones = colony.get_zone_system()
	var items = colony.get_item_system()
	var jobs = colony.get_job_system()
	_assert_true(zones.paint_zone(ZoneScript.Type.STORAGE, [Vector2i(2, 2)]).ok, "Reachable Storage can be prepared for inaccessible-pile recovery")
	colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(1, 2), 2)
	var isolated_food_id := colony.add_item_pile(ItemSystemScript.FOOD, Vector2i(5, 2), 3)
	for _tick: int in range(300):
		colony.fixed_tick(0.05)
		var storage: Zone = zones.get_zone_at(Vector2i(2, 2))
		if storage != null and storage.setup_state == ZoneScript.SetupState.SET_UP:
			break
	for _tick: int in range(20):
		colony.fixed_tick(0.05)
	_assert_true(items.get_pile(isolated_food_id) != null, "Disconnected loose pile remains intact while unreachable")
	_assert_equal(jobs.get_pending_count(), 0, "Disconnected loose pile does not create an unreachable pending haul")
	_assert_equal(items.get_debug_dropoff_reservations().size(), 0, "Disconnected loose pile does not leak Storage capacity reservation")
	world.set_excavated(Vector2i(4, 2), true, true)
	var recovered := false
	for _tick: int in range(400):
		colony.fixed_tick(0.05)
		if items.get_count_at(Vector2i(5, 2)) == 0 and jobs.get_pending_count() == 0 and jobs.get_active_count() == 0:
			recovered = true
			break
	_assert_true(recovered, "Topology reconnection automatically retries and stores the waiting pile")
	_assert_equal(items.get_total_count(ItemSystemScript.FOOD), 3, "Topology recovery conserves the waiting Food")
	_assert_equal(items.get_debug_dropoff_reservations().size(), 0, "Recovered haul releases Storage capacity reservation")


func _test_existing_overcapacity_is_rebalanced() -> void:
	var context := _context(false)
	var colony = context.colony
	var zones = colony.get_zone_system()
	var items = colony.get_item_system()
	var jobs = colony.get_job_system()
	colony.add_item_pile(ItemSystemScript.FOOD, Vector2i(2, 2), 20)
	colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(1, 2), 2)
	_assert_true(zones.paint_zone(ZoneScript.Type.STORAGE, [Vector2i(2, 2), Vector2i(3, 2)]).ok, "Storage may be painted under a pre-existing oversized loose pile")
	var settled := false
	for _tick: int in range(800):
		colony.fixed_tick(0.05)
		if jobs.get_pending_count() == 0 and jobs.get_active_count() == 0 and _all_items_in_usable_storage(colony) and _storage_respects_capacity(colony):
			settled = true
			break
	_assert_true(settled, "Pre-existing overcapacity is split and rebalanced across Storage cells")
	_assert_equal(items.get_total_count(ItemSystemScript.FOOD), 20, "Capacity rebalancing conserves oversized Food")
	_assert_equal(items.get_total_count(ItemSystemScript.GENERAL_MATERIAL), 1, "Capacity rebalancing consumes only the one configured setup material")


func _test_threatened_storage_evacuates_while_walkable() -> void:
	var context := _context(false)
	var world = context.world
	var colony = context.colony
	var zones = colony.get_zone_system()
	var items = colony.get_item_system()
	var jobs = colony.get_job_system()
	var threatened_cell := Vector2i(2, 2)
	var safe_cell := Vector2i(5, 2)
	_assert_true(zones.paint_zone(ZoneScript.Type.STORAGE, [threatened_cell]).ok, "Threatened-storage fixture creates the source Storage")
	_assert_true(zones.paint_zone(ZoneScript.Type.STORAGE, [safe_cell]).ok, "Threatened-storage fixture creates separate dry fallback Storage")
	colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(1, 2), 5)
	for _tick: int in range(800):
		colony.fixed_tick(0.05)
		if _all_zones_ready(zones, 2) and jobs.get_pending_count() == 0 and jobs.get_active_count() == 0:
			break
	_assert_true(colony.add_item_pile(ItemSystemScript.FOOD, threatened_cell, 4) > 0, "New stores may arrive immediately before an environmental change")
	var food_before: int = _owned_total(colony, ItemSystemScript.FOOD)
	var material_before: int = _owned_total(colony, ItemSystemScript.GENERAL_MATERIAL)
	world.set_water_units(threatened_cell, 1)
	colony.fixed_tick(0.05)
	var threatened: Zone = zones.get_zone_at(threatened_cell)
	_assert_true(threatened != null and not threatened.valid and threatened.invalid_reasons.has(ZoneSystemScript.REASON_WET), "Shallow water invalidates Storage before its source cell becomes unwalkable")
	var saw_emergency := false
	for job in jobs.get_jobs():
		if job.job_type == ColonyJobScript.Type.EMERGENCY_HAUL:
			saw_emergency = true
	_assert_true(saw_emergency, "Walkable wet Storage creates executable emergency hauling")
	var evacuated := false
	for _tick: int in range(800):
		colony.fixed_tick(0.05)
		if items.get_count_at(threatened_cell) == 0 and jobs.get_pending_count() == 0 and jobs.get_active_count() == 0:
			evacuated = true
			break
	_assert_true(evacuated, "Mice evacuate threatened stores before water reaches the blocking threshold")
	_assert_true(_all_items_in_usable_storage(colony), "Emergency haul settles threatened resources in dry valid Storage")
	_assert_true(_storage_respects_capacity(colony), "Emergency haul preserves dry Storage capacity")
	_assert_equal(_owned_total(colony, ItemSystemScript.FOOD), food_before, "Wet-Storage evacuation conserves Food")
	_assert_equal(_owned_total(colony, ItemSystemScript.GENERAL_MATERIAL), material_before, "Wet-Storage evacuation conserves General Material")


func _test_carrier_finds_distant_safe_stash_beyond_full_storage() -> void:
	var balance: Dictionary = BALANCE.duplicate(true)
	balance.initial_mouse_count = 1
	balance.zones.storage_capacity_per_cell = 1
	var world := GridScript.new(8, 5, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false)
	for x: int in range(1, 7):
		world.initialize_cell(Vector2i(x, 2), CellDataScript.TerrainMaterial.SOFT_SOIL, true)
	world.metadata = {"start_cell": Vector2i(1, 2), "seed": 8891}
	var path_service := PathServiceScript.new()
	path_service.configure(world, balance)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, balance)
	var colony := ColonySimulationScript.new()
	colony.configure(world, path_service, dig_system, balance)
	var zones = colony.get_zone_system()
	var items = colony.get_item_system()
	var full_storage: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
	_assert_true(zones.paint_zone(ZoneScript.Type.STORAGE, full_storage).ok, "Carrier recovery fixture paints a connected Storage interior")
	colony.fixed_tick(0.05)
	for cell: Vector2i in full_storage:
		_assert_true(colony.add_item_pile(ItemSystemScript.FOOD, cell, 1) > 0, "Carrier recovery fixture fills one Storage cell to capacity")
	var carrier = colony.get_mice()[0]
	carrier.carried_item_type = ItemSystemScript.GENERAL_MATERIAL
	carrier.carried_item_count = 1
	var recovered := false
	for _tick: int in range(200):
		colony.fixed_tick(0.05)
		if carrier.carried_item_count == 0 and items.get_count_at(Vector2i(5, 2)) == 1:
			recovered = true
			break
	_assert_true(recovered, "Carrier crosses full Storage and stashes at the nearest distant ordinary cell")
	_assert_equal(carrier.carried_item_count, 0, "Distant stash recovery clears carried cargo")
	_assert_equal(items.get_total_count(ItemSystemScript.GENERAL_MATERIAL), 1, "Distant stash recovery conserves carried material")


func _context(seed_supplies: bool = true) -> Dictionary:
	var world := GridScript.new(12, 8, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var excavated := x >= 1 and x <= 10 and y >= 2 and y <= 5
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, excavated)
	world.metadata = {"start_cell": Vector2i(1, 3), "seed": 9917}
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, BALANCE)
	var colony := ColonySimulationScript.new()
	colony.configure(world, path_service, dig_system, BALANCE)
	if seed_supplies:
		colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(1, 2), 10)
		colony.add_item_pile(ItemSystemScript.FOOD, Vector2i(10, 5), 8)
	return {"world": world, "path_service": path_service, "dig_system": dig_system, "colony": colony}


func _all_zones_set_up(zones) -> bool:
	var all_zones: Array[Zone] = zones.get_zones()
	if all_zones.size() != 3:
		return false
	for zone: Zone in all_zones:
		if not zone.valid or zone.setup_state != ZoneScript.SetupState.SET_UP:
			return false
	return true


func _all_zones_ready(zones, expected_count: int) -> bool:
	var all_zones: Array[Zone] = zones.get_zones()
	if all_zones.size() != expected_count:
		return false
	for zone: Zone in all_zones:
		if not zone.valid or zone.setup_state != ZoneScript.SetupState.SET_UP:
			return false
	return true


func _all_items_in_usable_storage(colony) -> bool:
	var zones = colony.get_zone_system()
	for pile in colony.get_item_system().get_piles():
		if pile.count <= 0:
			continue
		var zone: Zone = zones.get_zone_at(pile.cell)
		if zone == null or zone.zone_type != ZoneScript.Type.STORAGE or not zone.valid or zone.setup_state != ZoneScript.SetupState.SET_UP:
			return false
	return true


func _storage_respects_capacity(colony) -> bool:
	var items = colony.get_item_system()
	for zone: Zone in colony.get_zone_system().get_zones_by_type(ZoneScript.Type.STORAGE):
		for cell: Vector2i in zone.cells:
			if items.get_count_at(cell) > int(BALANCE.zones.storage_capacity_per_cell):
				return false
	return true


func _first_stored_pile(colony):
	var zones = colony.get_zone_system()
	for pile in colony.get_item_system().get_piles():
		if pile.count <= 0:
			continue
		var zone: Zone = zones.get_zone_at(pile.cell)
		if zone != null and zone.zone_type == ZoneScript.Type.STORAGE:
			return pile
	return null


func _owned_total(colony, item_type: String) -> int:
	var total: int = colony.get_item_system().get_total_count(item_type)
	for mouse in colony.get_mice():
		if mouse.carried_item_type == item_type:
			total += int(mouse.carried_item_count)
	return total


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({"passed": passed, "description": description, "details": "" if passed else "Expected %s, got %s" % [expected, actual]})
