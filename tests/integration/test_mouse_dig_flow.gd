extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const MouseAgentScript = preload("res://src/domain/colony/mouse_agent.gd")

const BALANCE := {
	"digging": {"base_dig_seconds": 0.8, "simulation_step_seconds": 0.05},
	"mouse": {"move_cells_per_second": 4.0, "dig_work_per_second": 1.0},
	"pathfinding": {"max_walkable_water_units": 1},
}

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_mouse_executes_multi_cell_path()
	_test_mouse_recovers_from_cancelled_job()
	return results


func _test_mouse_executes_multi_cell_path() -> void:
	var context := _context()
	var world = context.world
	var dig_system = context.dig_system
	var mouse = context.mouse
	var designated: Dictionary = dig_system.designate_path([Vector2i(4, 3), Vector2i(5, 3)])
	_assert_true(designated.ok, "Integration setup designates a two-cell tunnel")
	var completed_cells: Array[Vector2i] = []
	for tick_index: int in range(60):
		var before_four: bool = world.is_excavated(Vector2i(4, 3))
		var before_five: bool = world.is_excavated(Vector2i(5, 3))
		mouse.fixed_tick(0.2)
		if not before_four and world.is_excavated(Vector2i(4, 3)):
			completed_cells.append(Vector2i(4, 3))
		if not before_five and world.is_excavated(Vector2i(5, 3)):
			completed_cells.append(Vector2i(5, 3))
		if dig_system.get_designated_count() == 0 and mouse.get_state_name() == "IDLE":
			break
	_assert_equal(completed_cells, [Vector2i(4, 3), Vector2i(5, 3)], "One mouse autonomously unfolds the planned tunnel in frontier order")
	_assert_true(world.is_excavated(Vector2i(4, 3)) and world.is_excavated(Vector2i(5, 3)), "Autonomous loop permanently changes both cells to cavity")
	_assert_equal(dig_system.get_designated_count(), 0, "Completed tunnel leaves no stale designation jobs")
	_assert_equal(dig_system.get_active_job_count(), 0, "Completed tunnel releases the worker reservation")
	_assert_equal(mouse.get_state_name(), "IDLE", "Mouse returns to idle after planned work finishes")
	_assert_true(context.path_service.is_reachable(Vector2i(1, 3), Vector2i(5, 3)), "Completed tunnel is immediately traversable end to end")


func _test_mouse_recovers_from_cancelled_job() -> void:
	var context := _context()
	var dig_system = context.dig_system
	var mouse = context.mouse
	dig_system.designate_path([Vector2i(4, 3)])
	mouse.fixed_tick(0.2)
	_assert_true(mouse.get_state_name() != "IDLE", "Mouse claims a valid job before cancellation")
	var cancelled: Dictionary = dig_system.cancel([Vector2i(4, 3)])
	_assert_true(cancelled.ok, "Active reservation may be cancelled safely")
	var recovery: Dictionary = mouse.fixed_tick(0.2)
	_assert_true(recovery.ok, "Mouse tick recovers normally after its job disappears")
	_assert_equal(mouse.get_state_name(), "IDLE", "Mouse does not remain stuck in a cancelled work state")
	_assert_equal(mouse.get_current_job_cell(), Vector2i(-1, -1), "Mouse clears stale job inspection state")


func _context() -> Dictionary:
	var world := GridScript.new(12, 8, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false)
	for cell: Vector2i in [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]:
		world.initialize_cell(cell, CellDataScript.TerrainMaterial.SOFT_SOIL, true)
	world.metadata.start_cell = Vector2i(1, 3)
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var dig_system := DigSystemScript.new()
	dig_system.configure(world, path_service, BALANCE)
	var mouse := MouseAgentScript.new("mouse_test", Vector2i(1, 3))
	mouse.configure(world, path_service, dig_system, BALANCE)
	return {"world": world, "path_service": path_service, "dig_system": dig_system, "mouse": mouse}


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
