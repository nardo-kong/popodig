extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const ColonySimulationScript = preload("res://src/domain/colony/colony_simulation.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_three_mouse_management_and_debug_contract()
	_test_hunger_interrupts_low_priority_dig()
	_test_rest_uses_home_fallback()
	_test_danger_interrupt_flee_and_recover()
	_test_danger_route_avoids_warning_cells()
	_test_blocked_hazard_cell_can_escape()
	_test_blocked_carrier_escapes_without_losing_cargo()
	_test_topology_change_repaths_haul()
	_test_invalidated_dropoff_reroutes_without_deadlock()
	_test_long_soak_conserves_resources_and_reservations()
	return results


func _test_three_mouse_management_and_debug_contract() -> void:
	var context := _simulation_context(_balance(3), 12)
	var colony = context.colony
	var mice: Array[MouseAgent] = colony.get_mice()
	_assert_equal(mice.size(), 3, "ColonySimulation creates the configured three mice")
	var ids: Dictionary = {}
	for mouse: MouseAgent in mice:
		ids[mouse.mouse_id] = true
	_assert_equal(ids.size(), 3, "Managed mice have unique stable IDs")
	_assert_true(colony.remove_mouse("mouse_2"), "Reusable colony management can remove a mouse safely")
	_assert_true(colony.add_mouse("mouse_4", context.world.metadata.start_cell) != null, "Reusable colony management can add a mouse")
	_assert_equal(colony.get_mice().size(), 3, "Population returns to three after replacement")
	var snapshot: Dictionary = colony.get_debug_snapshots()[0]
	for key: String in ["state", "current_cell", "current_job_id", "path", "hunger", "rest", "danger", "repath_count", "carried_item_type"]:
		_assert_true(snapshot.has(key), "Mouse debug snapshot exposes %s" % key)


func _test_hunger_interrupts_low_priority_dig() -> void:
	var balance := _balance(1)
	var context := _simulation_context(balance, 12)
	var colony = context.colony
	var mouse: MouseAgent = colony.get_mice()[0]
	var food_cell := Vector2i(3, 3)
	colony.add_item_pile(ItemSystemScript.FOOD, food_cell, 2)
	context.dig_system.designate_path([Vector2i(11, 3)])
	colony.fixed_tick(0.05)
	_assert_true(mouse.current_job_id.begins_with("dig:"), "Mouse initially claims low-priority digging")
	mouse.hunger = 0.8
	var interrupted: Dictionary = mouse.fixed_tick(0.05)
	_assert_equal(interrupted.reason_code, "HUNGER_INTERRUPTED", "Hunger interrupts low-priority work at threshold")
	_assert_true(mouse.current_job_id.begins_with("eat:"), "Interrupted mouse reserves reachable food autonomously")
	_assert_equal(context.dig_system.get_active_job_count(), 0, "Interrupted dig reservation returns to the queue")
	for _tick: int in range(40):
		colony.fixed_tick(0.1)
		if mouse.hunger < 0.2:
			break
	_assert_true(mouse.hunger < 0.2, "Mouse reaches food and restores hunger without direct control")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.FOOD), 1, "Eating consumes exactly one Food item")


func _test_rest_uses_home_fallback() -> void:
	var context := _simulation_context(_balance(1), 12)
	var colony = context.colony
	var mouse: MouseAgent = colony.get_mice()[0]
	mouse.current_cell = Vector2i(8, 3)
	mouse.rest = 0.1
	var result: Array[Dictionary] = colony.fixed_tick(0.05)
	_assert_equal(result[0].reason_code, "REST_INTERRUPTED", "Low rest starts autonomous fallback rest behavior")
	_assert_true(mouse.current_job_id.begins_with("rest:"), "Rest action targets the temporary home fallback")
	for _tick: int in range(100):
		colony.fixed_tick(0.1)
		if mouse.rest >= 0.9:
			break
	_assert_equal(mouse.current_cell, context.world.metadata.start_cell, "Pre-zone rest returns mouse to start-cell home fallback")
	_assert_true(mouse.rest >= 0.9, "Rest recovers to configured resume threshold")


func _test_danger_interrupt_flee_and_recover() -> void:
	var context := _simulation_context(_balance(1), 12)
	var colony = context.colony
	var mouse: MouseAgent = colony.get_mice()[0]
	context.dig_system.designate_path([Vector2i(11, 3)])
	colony.fixed_tick(0.05)
	var danger_cell := mouse.current_cell
	var safe_cell := Vector2i(5, 3)
	var interrupts: Array[Dictionary] = colony.trigger_danger([danger_cell], safe_cell)
	_assert_true(interrupts[0].ok, "Danger event immediately interrupts current work")
	_assert_true(mouse.danger_state, "Mouse exposes event-driven danger state")
	_assert_equal(context.dig_system.get_active_job_count(), 0, "Danger releases the interrupted work reservation")
	for _tick: int in range(40):
		colony.fixed_tick(0.1)
		if mouse.current_cell == safe_cell:
			break
	_assert_equal(mouse.current_cell, safe_cell, "Danger response reaches requested safe fallback")
	_assert_equal(mouse.get_state_name(), "FLEEING", "Mouse waits safely until the hazard recovers")
	colony.recover_from_danger()
	_assert_true(not mouse.danger_state, "Recovery event clears danger state")
	_assert_equal(mouse.get_state_name(), "IDLE", "Recovered mouse resumes autonomous scheduling from idle")


func _test_danger_route_avoids_warning_cells() -> void:
	var context := _simulation_context(_balance(1), 12, true)
	var colony = context.colony
	var mouse: MouseAgent = colony.get_mice()[0]
	mouse.current_cell = Vector2i(2, 3)
	var warning_cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
	var interrupted: Array[Dictionary] = colony.trigger_danger(warning_cells, Vector2i(8, 3))
	_assert_true(interrupted[0].ok, "Danger route fixture finds a safe detour")
	var planned_path: Array[Vector2i] = mouse.get_current_path()
	var crosses_warning := false
	for cell: Vector2i in planned_path:
		if warning_cells.has(cell):
			crosses_warning = true
	_assert_true(not crosses_warning, "Flee path avoids traversable event-warning cells instead of crossing the hazard")


func _test_topology_change_repaths_haul() -> void:
	var context := _simulation_context(_balance(1), 10, true)
	var colony = context.colony
	var mouse: MouseAgent = colony.get_mice()[0]
	var pile_id: int = colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(8, 3), 1)
	colony.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, pile_id, Vector2i(1, 3), 1)
	colony.fixed_tick(0.05)
	_assert_true(mouse.current_job_id.begins_with("job:"), "Mouse claims reachable haul before topology edit")
	context.world.set_excavated(Vector2i(2, 3), false)
	for _tick: int in range(100):
		colony.fixed_tick(0.1)
		if colony.get_job_system().get_completed_count() == 1:
			break
	_assert_true(mouse.repath_count >= 1, "Topology revision triggers path recomputation")
	_assert_equal(colony.get_job_system().get_completed_count(), 1, "Mouse completes haul through alternate topology")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL), 1, "Repath preserves carried resource quantity")


func _test_blocked_hazard_cell_can_escape() -> void:
	var context := _simulation_context(_balance(1), 12, true)
	var colony = context.colony
	var mouse: MouseAgent = colony.get_mice()[0]
	mouse.current_cell = Vector2i(5, 3)
	context.world.set_water_units(mouse.current_cell, 2)
	_assert_true(not context.path_service.is_walkable(mouse.current_cell), "Hazard setup makes the occupied cell nontraversable")
	var interrupted: Array[Dictionary] = colony.trigger_danger([mouse.current_cell], Vector2i(1, 3))
	_assert_true(interrupted[0].ok, "Danger interface can build an escape route from a newly blocked occupied cell")
	for _tick: int in range(50):
		colony.fixed_tick(0.1)
		if mouse.current_cell == Vector2i(1, 3):
			break
	_assert_equal(mouse.current_cell, Vector2i(1, 3), "Mouse exits deep water through a walkable neighbor and reaches safety")
	_assert_true(mouse.danger_state, "Escaped mouse stays in safety mode until explicit recovery")


func _test_blocked_carrier_escapes_without_losing_cargo() -> void:
	var context := _simulation_context(_balance(1), 12, true)
	var colony = context.colony
	var mouse: MouseAgent = colony.get_mice()[0]
	var pile_id: int = colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(8, 3), 2)
	colony.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, pile_id, Vector2i(1, 3), 2)
	for _tick: int in range(100):
		colony.fixed_tick(0.1)
		if mouse.carried_item_count == 2:
			break
	_assert_equal(mouse.carried_item_count, 2, "Hazard fixture reaches the carrying phase")
	context.world.set_excavated(mouse.current_cell, false)
	var owned_before: int = colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL) + mouse.carried_item_count
	_assert_true(not colony.remove_mouse(mouse.mouse_id), "Population removal refuses to destroy cargo that cannot be stashed")
	_assert_equal(colony.get_mice().size(), 1, "Rejected population removal keeps the carrier alive")
	colony.trigger_danger([mouse.current_cell], Vector2i(1, 3))
	_assert_equal(
		colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL) + mouse.carried_item_count,
		owned_before,
		"Danger interruption never clears cargo when the occupied cell cannot accept a drop"
	)
	for _tick: int in range(100):
		colony.fixed_tick(0.1)
		if mouse.current_cell == Vector2i(1, 3) and mouse.carried_item_count == 0:
			break
	_assert_equal(mouse.current_cell, Vector2i(1, 3), "Blocked carrier escapes to the requested safe cell")
	_assert_equal(mouse.carried_item_count, 0, "Escaped carrier stashes cargo only after reaching valid terrain")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL), owned_before, "Emergency escape conserves all carried material")


func _test_invalidated_dropoff_reroutes_without_deadlock() -> void:
	var context := _simulation_context(_balance(1), 12, true)
	var colony = context.colony
	var mouse: MouseAgent = colony.get_mice()[0]
	var target := Vector2i(2, 3)
	var pile_id: int = colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(9, 3), 1)
	colony.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, pile_id, target, 1)
	for _tick: int in range(160):
		colony.fixed_tick(0.05)
		if mouse.current_cell == target and mouse.get_state_name() == "HAULING":
			break
	_assert_true(mouse.current_cell == target and mouse.carried_item_count == 1, "Dropoff invalidation fixture arrives with cargo")
	context.world.set_excavated(target, false)
	var reroute: Array[Dictionary] = colony.fixed_tick(0.05)
	_assert_equal(reroute[0].reason_code, "DROPOFF_REROUTED", "Invalid dropoff starts a deterministic safe reroute")
	for _tick: int in range(80):
		colony.fixed_tick(0.05)
		if colony.get_job_system().get_completed_count() == 1:
			break
	_assert_equal(colony.get_job_system().get_completed_count(), 1, "Rerouted dropoff completes instead of remaining HAULING forever")
	_assert_equal(colony.get_job_system().get_active_count(), 0, "Rerouted dropoff releases its job reservation")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL), 1, "Rerouted dropoff conserves cargo")


func _test_long_soak_conserves_resources_and_reservations() -> void:
	var balance := _balance(3)
	balance.mouse.hunger_per_second = 0.02
	balance.mouse.rest_drain_per_second = 0.012
	var context := _simulation_context(balance, 20, true)
	var colony = context.colony
	var material_id: int = colony.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(18, 3), 30)
	colony.add_item_pile(ItemSystemScript.FOOD, Vector2i(10, 3), 30)
	for _index: int in range(15):
		colony.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, material_id, Vector2i(2, 3), 1)
	var reservation_violation := false
	var resource_violation := false
	for _tick: int in range(2000):
		colony.fixed_tick(0.05)
		var active_ids: Dictionary = {}
		var carried_material := 0
		for mouse: MouseAgent in colony.get_mice():
			if not mouse.current_job_id.is_empty():
				if active_ids.has(mouse.current_job_id):
					reservation_violation = true
				active_ids[mouse.current_job_id] = true
			if mouse.carried_item_type == ItemSystemScript.GENERAL_MATERIAL:
				carried_material += mouse.carried_item_count
		if colony.get_job_system().get_active_count() > 3 or colony.get_item_system().get_debug_reservations().size() > 3:
			reservation_violation = true
		if colony.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL) + carried_material != 30:
			resource_violation = true
	_assert_true(not reservation_violation, "Three-mouse soak never duplicates jobs or item reservations")
	_assert_true(not resource_violation, "Long soak never duplicates or loses General Material")
	_assert_equal(colony.get_job_system().get_completed_count(), 15, "Long soak completes every queued haul")
	_assert_equal(colony.get_job_system().get_active_count(), 0, "Completed soak leaves no reserved general jobs")
	_assert_equal(colony.get_job_system().get_pending_count(), 0, "Completed soak leaves no deadlocked pending work")
	_assert_true(colony.get_item_system().get_debug_reservations().size() <= 3, "Only live need reservations may remain after soak")


func _simulation_context(balance: Dictionary, width: int, excavate_room: bool = false) -> Dictionary:
	var world := GridScript.new(width, 7, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var excavated := y == 3 and x >= 1 and x < width - 1
			if excavate_room:
				excavated = y >= 2 and y <= 4 and x >= 1 and x < width - 1
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, excavated)
	world.metadata.start_cell = Vector2i(1, 3)
	var path_service := PathServiceScript.new()
	path_service.configure(world, balance)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, balance)
	var colony := ColonySimulationScript.new()
	colony.configure(world, path_service, dig_system, balance)
	return {"world": world, "path_service": path_service, "dig_system": dig_system, "colony": colony}


func _balance(mouse_count: int) -> Dictionary:
	return {
		"initial_mouse_count": mouse_count,
		"digging": {"base_dig_seconds": 0.8, "simulation_step_seconds": 0.05},
		"mouse": {
			"move_cells_per_second": 4.0,
			"dig_work_per_second": 1.0,
			"initial_hunger": 0.0,
			"hunger_per_second": 0.0,
			"food_restore": 0.75,
			"hunger_seek_threshold": 0.5,
			"hunger_critical_threshold": 0.9,
			"initial_rest": 1.0,
			"rest_drain_per_second": 0.0,
			"rest_seek_threshold": 0.25,
			"rest_critical_threshold": 0.08,
			"rest_recover_per_second": 0.6,
			"rest_resume_threshold": 0.9,
			"need_interrupt_priority_ceiling": 25.0,
		},
		"jobs": {
			"dig_priority": 10.0,
			"haul_priority": 20.0,
			"emergency_priority": 100.0,
			"travel_cost_weight": 0.25,
			"unreachable_retry_seconds": 2.0,
		},
		"pathfinding": {"max_walkable_water_units": 1},
		"stability": {"span_short": 99, "span_moderate": 99, "span_high": 99},
	}


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({"passed": passed, "description": description, "details": "" if passed else "Expected %s, got %s" % [expected, actual]})
