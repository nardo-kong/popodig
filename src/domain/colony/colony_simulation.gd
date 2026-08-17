class_name ColonySimulation
extends RefCounted

const MouseAgentScript = preload("res://src/domain/colony/mouse_agent.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const JobSystemScript = preload("res://src/domain/jobs/job_system.gd")

var _world
var _path_service
var _dig_system
var _balance: Dictionary = {}
var _item_system
var _job_system
var _mice: Array[MouseAgent] = []


func configure(world_grid, path_service, dig_system, balance: Dictionary = {}) -> void:
	_world = world_grid
	_path_service = path_service
	_dig_system = dig_system
	_balance = balance.duplicate(true)
	_item_system = ItemSystemScript.new()
	_item_system.configure(_world, _path_service)
	_job_system = JobSystemScript.new()
	_job_system.configure(_path_service, _item_system, _balance)
	_mice.clear()
	var requested_count := maxi(1, int(_balance.get("initial_mouse_count", 3)))
	var start_value: Variant = _world.metadata.get("start_cell", Vector2i(-1, -1))
	var start_cell := Vector2i(-1, -1) if not start_value is Vector2i else start_value as Vector2i
	var spawn_cells := _find_spawn_cells(start_cell, requested_count)
	for index: int in range(requested_count):
		var spawn_cell: Vector2i = spawn_cells[index] if index < spawn_cells.size() else start_cell
		add_mouse("mouse_%d" % (index + 1), spawn_cell)


func fixed_tick(delta_seconds: float) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if delta_seconds <= 0.0:
		return results
	_job_system.advance_time(delta_seconds)
	for mouse: MouseAgent in _mice:
		results.append(mouse.fixed_tick(delta_seconds))
	return results


func add_mouse(mouse_id: String, cell: Vector2i):
	if mouse_id.is_empty() or get_mouse(mouse_id) != null or not _path_service.is_walkable(cell):
		return null
	var mouse := MouseAgentScript.new(mouse_id, cell)
	mouse.configure(_world, _path_service, _dig_system, _balance)
	var start_value: Variant = _world.metadata.get("start_cell", cell)
	var home_cell := cell if not start_value is Vector2i else start_value as Vector2i
	mouse.configure_colony(_job_system, _item_system, home_cell, _balance)
	_mice.append(mouse)
	return mouse


func remove_mouse(mouse_id: String) -> bool:
	for index: int in range(_mice.size()):
		if _mice[index].mouse_id != mouse_id:
			continue
		if not _mice[index].release_current_job():
			return false
		_mice.remove_at(index)
		return true
	return false


func get_mice() -> Array[MouseAgent]:
	return _mice.duplicate()


func get_mouse(mouse_id: String):
	for mouse: MouseAgent in _mice:
		if mouse.mouse_id == mouse_id:
			return mouse
	return null


func get_job_system():
	return _job_system


func get_item_system():
	return _item_system


func add_item_pile(item_type: String, cell: Vector2i, count: int) -> int:
	return _item_system.add_pile(item_type, cell, count)


func enqueue_haul(item_type: String, source_pile_id: int, dropoff_cell: Vector2i, count: int, emergency: bool = false):
	return _job_system.enqueue_haul(item_type, source_pile_id, dropoff_cell, count, emergency)


func trigger_danger(danger_cells: Array, safe_cell: Vector2i = Vector2i(-1, -1)) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for mouse: MouseAgent in _mice:
		results.append(mouse.trigger_danger(danger_cells, safe_cell))
	return results


func recover_from_danger() -> void:
	for mouse: MouseAgent in _mice:
		mouse.recover_from_danger()


func setup_qa_demo(food_cell: Vector2i, material_cell: Vector2i, dropoff_cell: Vector2i) -> Dictionary:
	var food_pile_id := add_item_pile(ItemSystemScript.FOOD, food_cell, 8)
	var material_pile_id := add_item_pile(ItemSystemScript.GENERAL_MATERIAL, material_cell, 6)
	var haul_job = enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, material_pile_id, dropoff_cell, 2)
	return {
		"ok": food_pile_id > 0 and material_pile_id > 0 and haul_job != null,
		"food_pile_id": food_pile_id,
		"material_pile_id": material_pile_id,
		"haul_job_id": -1 if haul_job == null else haul_job.job_id,
	}


func get_debug_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mouse: MouseAgent in _mice:
		result.append(mouse.get_debug_snapshot())
	return result


func _find_spawn_cells(start_cell: Vector2i, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var distances: PackedInt32Array = _path_service.build_distance_field(start_cell)
	var candidates: Array[Dictionary] = []
	for index: int in range(distances.size()):
		if distances[index] < 0:
			continue
		candidates.append({"cell": _world.index_to_cell(index), "distance": distances[index]})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.distance) != int(b.distance):
			return int(a.distance) < int(b.distance)
		var a_cell: Vector2i = a.cell
		var b_cell: Vector2i = b.cell
		return a_cell.y < b_cell.y or (a_cell.y == b_cell.y and a_cell.x < b_cell.x)
	)
	for candidate: Dictionary in candidates:
		result.append(candidate.cell)
		if result.size() >= count:
			break
	return result
