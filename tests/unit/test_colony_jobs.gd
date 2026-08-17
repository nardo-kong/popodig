extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const JobSystemScript = preload("res://src/domain/jobs/job_system.gd")
const ColonyJobScript = preload("res://src/domain/jobs/colony_job.gd")

const BALANCE := {
	"jobs": {
		"dig_priority": 10.0,
		"haul_priority": 20.0,
		"emergency_priority": 100.0,
		"travel_cost_weight": 0.25,
		"unreachable_retry_seconds": 2.0,
	},
	"pathfinding": {"max_walkable_water_units": 1},
}

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_item_reservation_and_conservation()
	_test_deterministic_utility_and_job_reservation()
	_test_unreachable_cooldown_and_topology_retry()
	return results


func _test_item_reservation_and_conservation() -> void:
	var context := _corridor_context()
	var item_system = context.item_system
	var pile_id: int = item_system.add_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(5, 3), 3)
	_assert_true(pile_id > 0, "General Material pile is created in traversable space")
	var first: Dictionary = item_system.reserve_from_pile("mouse_a", pile_id, 2)
	_assert_true(first.ok, "Worker reserves an exact item quantity")
	_assert_equal(item_system.get_pile(pile_id).reserved_count, 2, "Pile exposes its reserved quantity")
	var duplicate: Dictionary = item_system.reserve_from_pile("mouse_b", pile_id, 2)
	_assert_true(not duplicate.ok, "Reservations cannot overbook a pile")
	var pickup: Dictionary = item_system.pickup(first.reservation_id, "mouse_a")
	_assert_true(pickup.ok, "Reservation owner can pick up reserved material")
	_assert_equal(item_system.get_total_count(ItemSystemScript.GENERAL_MATERIAL), 1, "Pickup removes exactly the carried quantity from piles")
	var dropoff: Dictionary = item_system.dropoff("mouse_a", pickup.item_type, pickup.count, Vector2i(2, 3))
	_assert_true(dropoff.ok, "Carried material can be dropped into a logical pile")
	_assert_equal(item_system.get_total_count(ItemSystemScript.GENERAL_MATERIAL), 3, "Pickup and dropoff conserve General Material")
	_assert_equal(item_system.get_debug_reservations().size(), 0, "Completed pickup leaves no stale item reservation")


func _test_deterministic_utility_and_job_reservation() -> void:
	var context := _corridor_context()
	var item_system = context.item_system
	var job_system = context.job_system
	var pile_id: int = item_system.add_pile(ItemSystemScript.GENERAL_MATERIAL, Vector2i(6, 3), 3)
	_assert_true(
		job_system.enqueue_haul(ItemSystemScript.FOOD, pile_id, Vector2i(2, 3), 1) == null,
		"Haul creation rejects an item type that does not match its source pile"
	)
	var committed: ColonyJob = job_system.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, pile_id, Vector2i(2, 3), 2)
	_assert_true(committed != null, "Haul creation commits available source quantity")
	_assert_true(
		job_system.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, pile_id, Vector2i(3, 3), 2) == null,
		"Haul creation rejects source-pile oversubscription before it can deadlock"
	)
	job_system.cancel(committed.job_id)
	var normal: ColonyJob = job_system.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, pile_id, Vector2i(2, 3), 1)
	var emergency: ColonyJob = job_system.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, pile_id, Vector2i(3, 3), 1, true)
	var claimed: ColonyJob = job_system.claim_best("mouse_a", Vector2i(1, 3))
	_assert_equal(claimed.job_id, emergency.job_id, "Emergency utility deterministically outranks normal hauling")
	_assert_equal(claimed.job_type, ColonyJobScript.Type.EMERGENCY_HAUL, "Emergency haul retains its explicit job type")
	var second: ColonyJob = job_system.claim_best("mouse_b", Vector2i(1, 3))
	_assert_equal(second.job_id, normal.job_id, "Second worker receives the remaining single-worker job")
	_assert_true(claimed.worker_id != second.worker_id, "Exclusive jobs cannot duplicate their worker reservation")
	_assert_equal(job_system.get_active_count(), 2, "Active count matches unique reservations")
	_assert_equal(item_system.get_debug_reservations().size(), 2, "Job and item reservations are acquired atomically")
	_assert_true(job_system.release_worker("mouse_a"), "Worker can release an unfinished job")
	_assert_equal(job_system.get_pending_count(), 1, "Released job returns to the deterministic pending queue")


func _test_unreachable_cooldown_and_topology_retry() -> void:
	var world = _solid_world(10, 7)
	_carve(world, [Vector2i(1, 3), Vector2i(2, 3), Vector2i(7, 3)])
	world.metadata.start_cell = Vector2i(1, 3)
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var item_system := ItemSystemScript.new()
	item_system.configure(world, path_service)
	var job_system := JobSystemScript.new()
	job_system.configure(path_service, item_system, BALANCE)
	var pile_id: int = item_system.add_pile(ItemSystemScript.FOOD, Vector2i(7, 3), 2)
	var job: ColonyJob = job_system.enqueue_haul(ItemSystemScript.FOOD, pile_id, Vector2i(2, 3), 1)
	_assert_true(job_system.claim_best("mouse_a", Vector2i(1, 3)) == null, "Unreachable haul is not selected")
	_assert_equal(job_system.get_unreachable_attempt_count("mouse_a", job.job_id), 1, "First unreachable evaluation is recorded")
	_assert_true(job_system.claim_best("mouse_a", Vector2i(1, 3)) == null, "Cooldown suppresses immediate unreachable reselection")
	_assert_equal(job_system.get_unreachable_attempt_count("mouse_a", job.job_id), 1, "Cooldown prevents selection storms")
	job_system.advance_time(2.1)
	job_system.claim_best("mouse_a", Vector2i(1, 3))
	_assert_equal(job_system.get_unreachable_attempt_count("mouse_a", job.job_id), 2, "Unreachable job retries after configured cooldown")
	for x: int in range(3, 8):
		world.set_excavated(Vector2i(x, 3), true)
	job_system.advance_time(0.05)
	var reachable: ColonyJob = job_system.claim_best("mouse_a", Vector2i(1, 3))
	_assert_true(reachable != null, "Topology revision clears cooldown and exposes newly reachable work")
	_assert_equal(reachable.job_id, job.job_id, "Retry claims the original job without duplication")


func _corridor_context() -> Dictionary:
	var world = _solid_world(10, 7)
	var corridor: Array[Vector2i] = []
	for x: int in range(1, 9):
		corridor.append(Vector2i(x, 3))
	_carve(world, corridor)
	world.metadata.start_cell = Vector2i(1, 3)
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var item_system := ItemSystemScript.new()
	item_system.configure(world, path_service)
	var job_system := JobSystemScript.new()
	job_system.configure(path_service, item_system, BALANCE)
	return {"world": world, "path_service": path_service, "item_system": item_system, "job_system": job_system}


func _solid_world(width: int, height: int):
	var world := GridScript.new(width, height, 4)
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
	results.append({"passed": passed, "description": description, "details": "" if passed else "Expected %s, got %s" % [expected, actual]})
