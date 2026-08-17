class_name GridPathService
extends RefCounted

const WorldGridScript = preload("res://src/domain/world/world_grid.gd")

var _world
var _walkable := PackedByteArray()
var _max_walkable_water_units := 1
var _topology_revision := 0
var _updated_chunks: Dictionary = {}


func configure(world_grid, balance: Dictionary = {}) -> void:
	if _world != null and _world.cell_changed.is_connected(_on_cell_changed):
		_world.cell_changed.disconnect(_on_cell_changed)
	_world = world_grid
	var pathfinding: Dictionary = balance.get("pathfinding", {})
	_max_walkable_water_units = maxi(0, int(pathfinding.get("max_walkable_water_units", 1)))
	_rebuild_all()
	_updated_chunks.clear()
	_topology_revision = 0
	if _world != null:
		_world.cell_changed.connect(_on_cell_changed)


func is_walkable(cell_coord: Vector2i) -> bool:
	if _world == null:
		return false
	var index: int = _world.cell_to_index(cell_coord)
	return index >= 0 and _walkable[index] == 1


func find_path(start: Vector2i, goal: Vector2i, forbidden_cells: Dictionary = {}) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if _world == null or not is_walkable(start) or not is_walkable(goal) or forbidden_cells.has(goal):
		return empty_path
	if start == goal:
		return [start]
	var cell_count: int = _world.width * _world.height
	var previous := PackedInt32Array()
	previous.resize(cell_count)
	previous.fill(-2)
	var start_index: int = _world.cell_to_index(start)
	var goal_index: int = _world.cell_to_index(goal)
	previous[start_index] = -1
	var queue := PackedInt32Array([start_index])
	var head := 0
	while head < queue.size():
		var current_index := queue[head]
		head += 1
		var current: Vector2i = _world.index_to_cell(current_index)
		for neighbor: Vector2i in _world.get_cardinal_neighbors(current):
			var neighbor_index: int = _world.cell_to_index(neighbor)
			if previous[neighbor_index] != -2 or _walkable[neighbor_index] == 0 or forbidden_cells.has(neighbor):
				continue
			previous[neighbor_index] = current_index
			if neighbor_index == goal_index:
				return _reconstruct_path(previous, goal_index)
			queue.append(neighbor_index)
	return empty_path


func is_reachable(start: Vector2i, goal: Vector2i) -> bool:
	return not find_path(start, goal).is_empty()


func build_distance_field(start: Vector2i, forbidden_cells: Dictionary = {}) -> PackedInt32Array:
	var distances := PackedInt32Array()
	if _world == null:
		return distances
	distances.resize(_world.width * _world.height)
	distances.fill(-1)
	if not is_walkable(start):
		return distances
	var start_index: int = _world.cell_to_index(start)
	distances[start_index] = 0
	var queue := PackedInt32Array([start_index])
	var head := 0
	while head < queue.size():
		var current_index := queue[head]
		head += 1
		var current: Vector2i = _world.index_to_cell(current_index)
		for neighbor: Vector2i in _world.get_cardinal_neighbors(current):
			var neighbor_index: int = _world.cell_to_index(neighbor)
			if distances[neighbor_index] >= 0 or _walkable[neighbor_index] == 0 or forbidden_cells.has(neighbor):
				continue
			distances[neighbor_index] = distances[current_index] + 1
			queue.append(neighbor_index)
	return distances


func get_topology_revision() -> int:
	return _topology_revision


func get_last_updated_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for chunk_coord: Vector2i in _updated_chunks:
		result.append(chunk_coord)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result


func clear_update_history() -> void:
	_updated_chunks.clear()


func _rebuild_all() -> void:
	_walkable.clear()
	if _world == null:
		return
	_walkable.resize(_world.width * _world.height)
	for index: int in range(_walkable.size()):
		_refresh_cell(index)


func _refresh_cell(index: int) -> void:
	var cell_coord: Vector2i = _world.index_to_cell(index)
	_walkable[index] = 1 if _world.is_traversable(cell_coord) and _world.get_water_units(cell_coord) <= _max_walkable_water_units else 0


func _on_cell_changed(cell_coord: Vector2i, change_flags: int) -> void:
	if (change_flags & WorldGridScript.CHANGE_PATHING) == 0:
		return
	var index: int = _world.cell_to_index(cell_coord)
	if index < 0:
		return
	_refresh_cell(index)
	_topology_revision += 1
	_record_affected_chunks(cell_coord)


func _record_affected_chunks(cell_coord: Vector2i) -> void:
	var own_chunk: Vector2i = _world.cell_to_chunk(cell_coord)
	_updated_chunks[own_chunk] = true
	for neighbor: Vector2i in _world.get_cardinal_neighbors(cell_coord):
		var neighbor_chunk: Vector2i = _world.cell_to_chunk(neighbor)
		if neighbor_chunk != own_chunk:
			_updated_chunks[neighbor_chunk] = true


func _reconstruct_path(previous: PackedInt32Array, goal_index: int) -> Array[Vector2i]:
	var reversed: Array[Vector2i] = []
	var cursor := goal_index
	while cursor >= 0:
		reversed.append(_world.index_to_cell(cursor))
		cursor = previous[cursor]
	reversed.reverse()
	return reversed
