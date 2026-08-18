class_name SealSystem
extends RefCounted

const WorldGridScript = preload("res://src/domain/world/world_grid.gd")

signal seal_requested(request_id: int, cell: Vector2i)
signal seal_completed(request_id: int, cell: Vector2i)
signal seal_cancelled(request_id: int, cell: Vector2i, reason_code: String)

const REASON_OK := "OK"
const REASON_OUT_OF_BOUNDS := "OUT_OF_BOUNDS"
const REASON_NOT_OPEN := "NOT_OPEN"
const REASON_EXTERIOR := "EXTERIOR"
const REASON_ALREADY_SEALED := "ALREADY_SEALED"
const REASON_ALREADY_REQUESTED := "ALREADY_REQUESTED"
const REASON_REQUEST_NOT_FOUND := "REQUEST_NOT_FOUND"
const REASON_INSUFFICIENT_MATERIAL := "INSUFFICIENT_MATERIAL"
const REASON_WATER_DISPLACEMENT_BLOCKED := "WATER_DISPLACEMENT_BLOCKED"

var _world
var _water_system
var _requests: Dictionary = {}
var _next_request_id := 1
var _completed_count := 0


func configure(world_grid, water_system = null) -> void:
	if _world != null and _world.cell_changed.is_connected(_on_world_cell_changed):
		_world.cell_changed.disconnect(_on_world_cell_changed)
	_world = world_grid
	_water_system = water_system
	_requests.clear()
	_next_request_id = 1
	_completed_count = 0
	if _world != null:
		_world.cell_changed.connect(_on_world_cell_changed)


func request_seal(cell: Vector2i) -> Dictionary:
	var reason := inspect_request(cell)
	if reason != REASON_OK:
		return _result(false, reason, -1, cell)
	var request := {
		"request_id": _next_request_id,
		"cell": cell,
		"material_type": "GENERAL_MATERIAL",
		"material_required": 1,
		"blocked": false,
	}
	_next_request_id += 1
	_requests[cell] = request
	_world.mark_region_dirty(Rect2i(cell, Vector2i.ONE), WorldGridScript.CHANGE_TERRAIN)
	seal_requested.emit(int(request.request_id), cell)
	return _result(true, REASON_OK, int(request.request_id), cell)


func inspect_request(cell: Vector2i) -> String:
	if _world == null or not _world.is_in_bounds(cell):
		return REASON_OUT_OF_BOUNDS
	if _world.is_exterior(cell):
		return REASON_EXTERIOR
	if _world.is_sealed(cell):
		return REASON_ALREADY_SEALED
	if _requests.has(cell):
		return REASON_ALREADY_REQUESTED
	if not _world.is_excavated(cell):
		return REASON_NOT_OPEN
	return REASON_OK


func complete_seal(cell: Vector2i, delivered_material: int) -> Dictionary:
	var request: Dictionary = _requests.get(cell, {})
	if request.is_empty():
		return _result(false, REASON_REQUEST_NOT_FOUND, -1, cell)
	if delivered_material < int(request.material_required):
		return _result(false, REASON_INSUFFICIENT_MATERIAL, int(request.request_id), cell)
	if not _world.is_excavated(cell) or _world.is_exterior(cell) or _world.is_sealed(cell):
		_cancel_internal(cell, REASON_NOT_OPEN)
		return _result(false, REASON_NOT_OPEN, int(request.request_id), cell)
	if not _displace_water(cell):
		request.blocked = true
		_requests[cell] = request
		return _result(false, REASON_WATER_DISPLACEMENT_BLOCKED, int(request.request_id), cell)
	if not _world.set_sealed(cell, true):
		return _result(false, REASON_NOT_OPEN, int(request.request_id), cell)
	_requests.erase(cell)
	_world.mark_region_dirty(Rect2i(cell, Vector2i.ONE), WorldGridScript.CHANGE_TERRAIN)
	_completed_count += 1
	if _water_system != null:
		_water_system.wake_region(cell)
	seal_completed.emit(int(request.request_id), cell)
	return _result(true, REASON_OK, int(request.request_id), cell)


func cancel_request(cell: Vector2i) -> Dictionary:
	if not _requests.has(cell):
		return _result(false, REASON_REQUEST_NOT_FOUND, -1, cell)
	var request: Dictionary = _requests[cell]
	_cancel_internal(cell, "PLAYER_CANCELLED")
	return _result(true, REASON_OK, int(request.request_id), cell)


func has_request(cell: Vector2i) -> bool:
	return _requests.has(cell)


func get_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stale: Array[Vector2i] = []
	for cell: Vector2i in _requests:
		if not _world.is_excavated(cell) or _world.is_exterior(cell) or _world.is_sealed(cell):
			stale.append(cell)
		elif not bool((_requests[cell] as Dictionary).get("blocked", false)):
			result.append((_requests[cell] as Dictionary).duplicate(true))
	for cell: Vector2i in stale:
		_cancel_internal(cell, REASON_NOT_OPEN)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.request_id) < int(b.request_id)
	)
	return result


func get_completed_count() -> int:
	return _completed_count


func _displace_water(cell: Vector2i) -> bool:
	var units: int = int(_world.get_water_units(cell))
	if units <= 0:
		return true
	var capacity := 4 if _water_system == null else int(_water_system.get_cell_capacity())
	var candidates: Array[Vector2i] = []
	var free_total := 0
	for neighbor: Vector2i in _world.get_cardinal_neighbors(cell):
		if not _world.is_excavated(neighbor) or _world.is_exterior(neighbor) or _world.is_sealed(neighbor):
			continue
		var free := maxi(0, capacity - int(_world.get_water_units(neighbor)))
		if free <= 0:
			continue
		candidates.append(neighbor)
		free_total += free
	if free_total < units:
		return false
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y > b.y or (a.y == b.y and _world.cell_to_index(a) < _world.cell_to_index(b))
	)
	var remaining := units
	for target: Vector2i in candidates:
		var current: int = int(_world.get_water_units(target))
		var amount := mini(remaining, capacity - current)
		_world.set_water_units(target, current + amount)
		remaining -= amount
		if _water_system != null:
			_water_system.wake_region(target)
		if remaining <= 0:
			break
	_world.set_water_units(cell, 0)
	return remaining == 0


func _cancel_internal(cell: Vector2i, reason_code: String) -> void:
	var request: Dictionary = _requests.get(cell, {})
	if request.is_empty():
		return
	_requests.erase(cell)
	_world.mark_region_dirty(Rect2i(cell, Vector2i.ONE), WorldGridScript.CHANGE_TERRAIN)
	seal_cancelled.emit(int(request.request_id), cell, reason_code)


func _on_world_cell_changed(changed_cell: Vector2i, change_flags: int) -> void:
	if change_flags == 0:
		return
	for cell: Vector2i in _requests:
		if absi(cell.x - changed_cell.x) + absi(cell.y - changed_cell.y) > 1:
			continue
		var request: Dictionary = _requests[cell]
		if bool(request.get("blocked", false)):
			request.blocked = false
			_requests[cell] = request


func _result(ok: bool, reason_code: String, request_id: int, cell: Vector2i) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"request_id": request_id,
		"cell": cell,
	}
