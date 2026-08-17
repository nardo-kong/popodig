extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const ChunkScript = preload("res://src/domain/world/world_chunk.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const DesignateCommandScript = preload("res://src/application/commands/designate_dig_command.gd")
const CancelCommandScript = preload("res://src/application/commands/cancel_dig_command.gd")

const BALANCE := {
	"digging": {"base_dig_seconds": 0.8, "simulation_step_seconds": 0.05},
	"mouse": {"move_cells_per_second": 4.0, "dig_work_per_second": 1.0},
	"pathfinding": {"max_walkable_water_units": 1},
}

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_local_path_topology_updates()
	_test_designation_contract_and_cancel_pruning()
	_test_disconnected_cave_is_not_a_colony_anchor()
	_test_frontier_reservation_progress_and_atomic_completion()
	_test_material_hardness_scales_required_work()
	_test_world_dig_dirty_api()
	_test_exterior_never_becomes_a_dig_route()
	return results


func _test_exterior_never_becomes_a_dig_route() -> void:
	var context := _dig_context([Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)])
	var exterior_cell := Vector2i(4, 3)
	context.world.set_exterior(exterior_cell, true)
	var inspection: Dictionary = context.dig_system.inspect_designation(exterior_cell)
	_assert_true(not inspection.ok, "Solid EXTERIOR cannot become a dig designation")
	_assert_equal(inspection.reason_code, DigSystemScript.REASON_NOT_EXCAVATABLE, "EXTERIOR dig rejection uses the stable non-excavatable reason")
	context.world.set_dig_state(exterior_cell, CellDataScript.DigState.QUEUED)
	_assert_true(not context.world.complete_excavation_atomic(exterior_cell), "Atomic excavation completion explicitly rejects EXTERIOR")


func _test_local_path_topology_updates() -> void:
	var world = _solid_world(12, 8, 4)
	_carve(world, [Vector2i(1, 2), Vector2i(2, 2)])
	world.metadata.start_cell = Vector2i(1, 2)
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	_assert_equal(path_service.find_path(Vector2i(1, 2), Vector2i(2, 2)).size(), 2, "Path service traverses excavated cardinal cells")
	_assert_true(path_service.find_path(Vector2i(1, 2), Vector2i(3, 2)).is_empty(), "Solid target is blocked before topology edit")
	path_service.clear_update_history()
	var revision_before: int = path_service.get_topology_revision()
	world.set_excavated(Vector2i(3, 2), true)
	_assert_equal(path_service.get_topology_revision(), revision_before + 1, "Excavation updates path topology synchronously")
	_assert_true(path_service.get_last_updated_chunks().has(Vector2i(0, 0)), "Local topology update records the edited chunk")
	_assert_true(not path_service.get_last_updated_chunks().has(Vector2i(2, 1)), "Local topology update does not rebuild an unrelated chunk")
	_assert_equal(path_service.find_path(Vector2i(1, 2), Vector2i(3, 2)).size(), 3, "New cavity is pathable on the same tick")
	world.set_water_units(Vector2i(2, 2), 2)
	_assert_true(path_service.find_path(Vector2i(1, 2), Vector2i(3, 2)).is_empty(), "Deep water threshold blocks the basic path cache")
	world.set_water_units(Vector2i(2, 2), 1)
	_assert_equal(path_service.find_path(Vector2i(1, 2), Vector2i(3, 2)).size(), 3, "Shallow water remains walkable at configured threshold")


func _test_designation_contract_and_cancel_pruning() -> void:
	var context := _dig_context([Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)])
	var world = context.world
	var dig_system = context.dig_system
	var path: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)]
	var result: Dictionary = DesignateCommandScript.new(dig_system, path).execute()
	_assert_true(result.ok, "Contiguous planned path can be designated from a legal frontier")
	_assert_equal(result.accepted_cells.size(), 3, "Designation reports only newly queued cells")
	_assert_equal(dig_system.get_designated_count(), 3, "Dig system tracks the complete planned path")
	_assert_equal(world.get_dig_state(Vector2i(6, 3)), CellDataScript.DigState.QUEUED, "Downstream planned cell is queued")
	var duplicate: Dictionary = DesignateCommandScript.new(dig_system, [Vector2i(4, 3)]).execute()
	_assert_true(not duplicate.ok, "Repeated single-cell designation is not reported as a mutation")
	_assert_equal(duplicate.reason_code, DigSystemScript.REASON_ALREADY_DESIGNATED, "Repeated designation returns a stable reason code")
	_assert_equal(duplicate.accepted_cells.size(), 0, "Repeated designation accepts zero cells")
	var invalid: Dictionary = DesignateCommandScript.new(dig_system, [Vector2i(7, 3), Vector2i(9, 3)]).execute()
	_assert_equal(invalid.reason_code, DigSystemScript.REASON_NOT_CONTIGUOUS, "Disconnected paint path is rejected with a structured reason")
	_assert_equal(dig_system.get_designated_count(), 3, "Rejected designation is atomic")
	var cancelled: Dictionary = CancelCommandScript.new(dig_system, [Vector2i(5, 3)]).execute()
	_assert_true(cancelled.ok, "A queued middle cell can be cancelled")
	_assert_equal(cancelled.cancelled_cells, [Vector2i(5, 3)], "Cancel result distinguishes explicitly cancelled cells")
	_assert_equal(cancelled.removed_downstream, [Vector2i(6, 3)], "Disconnected downstream designations are pruned")
	_assert_equal(dig_system.get_designated_count(), 1, "Connected upstream designation survives downstream pruning")
	_assert_equal(world.get_dig_state(Vector2i(6, 3)), CellDataScript.DigState.NONE, "Pruned cell clears compact grid dig state")


func _test_disconnected_cave_is_not_a_colony_anchor() -> void:
	var world = _solid_world(10, 7, 4)
	_carve(world, [Vector2i(1, 2), Vector2i(7, 2)])
	world.metadata.start_cell = Vector2i(1, 2)
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, BALANCE)
	var isolated_target := Vector2i(7, 3)
	var inspection: Dictionary = dig_system.inspect_designation(isolated_target)
	_assert_true(not inspection.ok, "Solid next to an isolated natural cave is not a legal colony frontier")
	_assert_equal(inspection.reason_code, DigSystemScript.REASON_NOT_CONNECTED, "Isolated cave rejection explains missing colony connection")
	var isolated: Dictionary = dig_system.designate_path([isolated_target])
	_assert_true(not isolated.ok, "Disconnected cave cannot bootstrap hidden internal designation")
	var bridge: Array[Vector2i] = []
	for x: int in range(7, 0, -1):
		bridge.append(Vector2i(x, 3))
	var connected: Dictionary = dig_system.designate_path(bridge)
	_assert_true(connected.ok, "A continuous planned chain may be painted back to colony topology")
	_assert_equal(connected.accepted_cells.size(), 7, "Reverse-painted planned bridge queues every solid cell")


func _test_frontier_reservation_progress_and_atomic_completion() -> void:
	var context := _dig_context([Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)])
	var world = context.world
	var path_service = context.path_service
	var dig_system = context.dig_system
	dig_system.designate_path([Vector2i(4, 3), Vector2i(5, 3)])
	var frontier: Array[DigJob] = dig_system.derive_frontier_jobs(Vector2i(1, 3))
	_assert_equal(frontier.size(), 1, "Only the first reachable boundary cell becomes an executable frontier job")
	_assert_equal(frontier[0].cell, Vector2i(4, 3), "Frontier derivation preserves the planned path order through topology")
	var job: DigJob = dig_system.claim_next("mouse_a", Vector2i(1, 3))
	_assert_true(job != null, "Reachable frontier job can be reserved")
	_assert_equal(dig_system.get_active_job_count(), 1, "Active job count reflects reservation")
	_assert_true(dig_system.claim_next("mouse_b", Vector2i(1, 3)) == null, "A second worker cannot reserve a downstream or already reserved frontier")
	var wrong_worker: Dictionary = dig_system.advance_job("mouse_b", job.job_id, 0.2)
	_assert_equal(wrong_worker.reason_code, DigSystemScript.REASON_RESERVED_BY_OTHER, "Reservation ownership is enforced")
	var partial: Dictionary = dig_system.advance_job("mouse_a", job.job_id, 0.4)
	_assert_true(partial.ok and not partial.completed, "Hardness-scaled work advances without prematurely excavating")
	_assert_true(is_equal_approx(world.get_dig_progress(Vector2i(4, 3)), 0.5), "Soft soil progress uses provisional base dig time")
	_assert_true(world.is_solid(Vector2i(4, 3)), "Partial work leaves topology solid")
	var completion_events: Array[int] = []
	world.cell_changed.connect(func(cell: Vector2i, flags: int) -> void:
		if cell == Vector2i(4, 3):
			completion_events.append(flags)
	)
	var completed: Dictionary = dig_system.advance_job("mouse_a", job.job_id, 0.4)
	_assert_true(completed.ok and completed.completed, "Required work completes excavation")
	_assert_true(world.is_excavated(Vector2i(4, 3)), "Completion atomically opens traversable topology")
	_assert_equal(world.get_dig_state(Vector2i(4, 3)), CellDataScript.DigState.NONE, "Completion atomically clears designation state")
	_assert_true(is_zero_approx(world.get_dig_progress(Vector2i(4, 3))), "Completion atomically clears progress")
	_assert_equal(completion_events.size(), 1, "Final excavation publishes one atomic cell change")
	_assert_true((completion_events[0] & GridScript.CHANGE_PATHING) != 0, "Atomic completion includes pathing invalidation")
	_assert_true(path_service.is_walkable(Vector2i(4, 3)), "Path cache observes completed topology on the same tick")
	frontier = dig_system.derive_frontier_jobs(Vector2i(1, 3))
	_assert_equal(frontier[0].cell, Vector2i(5, 3), "Completing a cell exposes the next planned frontier")


func _test_world_dig_dirty_api() -> void:
	var world = _solid_world(8, 8, 4)
	var cell := Vector2i(2, 2)
	var chunk = world.get_chunk(Vector2i.ZERO)
	chunk.consume_dirty()
	_assert_true(world.set_dig_state(cell, CellDataScript.DigState.QUEUED), "Grid accepts queued dig state")
	_assert_true(chunk.is_dirty(ChunkScript.DIRTY_JOBS), "Dig mutation dirties only the job overlay contract")
	_assert_true(not chunk.is_dirty(ChunkScript.DIRTY_TERRAIN), "Designation does not dirty terrain presentation")
	_assert_true(world.set_dig_progress(cell, 1.5), "Grid accepts active dig progress")
	_assert_true(is_equal_approx(world.get_dig_progress(cell), 1.0), "Dig progress is clamped to normalized range")
	_assert_true(world.clear_dig(cell), "Clearing a designation succeeds")
	_assert_true(is_zero_approx(world.get_dig_progress(cell)), "Clearing designation also clears progress")


func _test_material_hardness_scales_required_work() -> void:
	var context := _dig_context([Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)])
	var world = context.world
	var dig_system = context.dig_system
	var target := Vector2i(4, 3)
	world.set_material(target, CellDataScript.TerrainMaterial.DAMP_CLAY)
	dig_system.designate_path([target])
	var job: DigJob = dig_system.claim_next("clay_mouse", Vector2i(3, 3))
	var result: Dictionary = dig_system.advance_job("clay_mouse", job.job_id, 0.8)
	_assert_true(result.ok and not result.completed, "One soft-soil base interval does not finish harder damp clay")
	_assert_true(is_equal_approx(world.get_dig_progress(target), 1.0 / 1.45), "Damp clay progress follows material hardness scaling")


func _dig_context(excavated_cells: Array[Vector2i]) -> Dictionary:
	var world = _solid_world(12, 8, 4)
	_carve(world, excavated_cells)
	world.metadata.start_cell = excavated_cells[0]
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, BALANCE)
	return {"world": world, "path_service": path_service, "dig_system": dig_system}


func _solid_world(width: int, height: int, chunk_size: int):
	var world := GridScript.new(width, height, chunk_size)
	for y: int in range(height):
		for x: int in range(width):
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false)
	return world


func _carve(world, cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		world.initialize_cell(cell, CellDataScript.TerrainMaterial.SOFT_SOIL, true)


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
