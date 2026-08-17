class_name MouseAgent
extends RefCounted

signal state_changed(mouse_id: String, state: int)
signal moved(mouse_id: String, from_cell: Vector2i, to_cell: Vector2i)

enum State {
	IDLE,
	MOVING,
	DIGGING,
}

const DigJobScript = preload("res://src/domain/jobs/dig_job.gd")

var mouse_id := ""
var current_cell := Vector2i(-1, -1)
var state: int = State.IDLE

var _world
var _path_service
var _dig_system
var _move_cells_per_second := 4.0
var _dig_work_per_second := 1.0
var _move_progress := 0.0
var _path: Array[Vector2i] = []
var _current_job


func _init(id: Variant = "mouse_1", start_cell: Vector2i = Vector2i.ZERO) -> void:
	mouse_id = str(id)
	current_cell = start_cell


func configure(world_grid, path_service, dig_system, balance: Dictionary = {}) -> void:
	_world = world_grid
	_path_service = path_service
	_dig_system = dig_system
	var mouse: Dictionary = balance.get("mouse", {})
	_move_cells_per_second = maxf(0.01, float(mouse.get("move_cells_per_second", 4.0)))
	_dig_work_per_second = maxf(0.01, float(mouse.get("dig_work_per_second", 1.0)))
	_reset_job()


func fixed_tick(delta_seconds: float) -> Dictionary:
	if delta_seconds <= 0.0:
		return _tick_result(false, "INVALID_DELTA")
	if _world == null or _path_service == null or _dig_system == null:
		return _tick_result(false, "SERVICE_UNAVAILABLE")
	if not _path_service.is_walkable(current_cell):
		_reset_job(true)
		return _tick_result(false, "CURRENT_CELL_NOT_WALKABLE")
	if _current_job != null and _dig_system.get_job(_current_job.job_id) == null:
		_reset_job()
	if state == State.IDLE:
		return _claim_job()
	if state == State.MOVING:
		return _advance_movement(delta_seconds)
	return _advance_digging(delta_seconds)


func get_state_name() -> String:
	match state:
		State.IDLE:
			return "IDLE"
		State.MOVING:
			return "MOVING"
		State.DIGGING:
			return "DIGGING"
		_:
			return "UNKNOWN"


func get_current_job_cell() -> Vector2i:
	return Vector2i(-1, -1) if _current_job == null else _current_job.cell


func _claim_job() -> Dictionary:
	_current_job = _dig_system.claim_next(mouse_id, current_cell)
	if _current_job == null:
		return _tick_result(true, "NO_JOB")
	_path = _path_service.find_path(current_cell, _current_job.work_cell)
	if _path.is_empty():
		_dig_system.release_worker(mouse_id)
		_reset_job()
		return _tick_result(false, "PATH_NOT_FOUND")
	_path.pop_front()
	_move_progress = 0.0
	_set_state(State.DIGGING if _path.is_empty() else State.MOVING)
	return _tick_result(true, "JOB_CLAIMED")


func _advance_movement(delta_seconds: float) -> Dictionary:
	if _current_job == null:
		_reset_job()
		return _tick_result(false, "STALE_JOB")
	_move_progress += delta_seconds * _move_cells_per_second
	while _move_progress >= 1.0 and not _path.is_empty():
		var next_cell: Vector2i = _path[0]
		if not _path_service.is_walkable(next_cell):
			if not _rebuild_path():
				_dig_system.release_worker(mouse_id)
				_reset_job()
				return _tick_result(false, "PATH_INTERRUPTED")
			next_cell = _path[0]
		_path.pop_front()
		var previous := current_cell
		current_cell = next_cell
		_move_progress -= 1.0
		moved.emit(mouse_id, previous, current_cell)
	if _path.is_empty():
		_set_state(State.DIGGING)
	return _tick_result(true, "OK")


func _advance_digging(delta_seconds: float) -> Dictionary:
	if _current_job == null:
		_reset_job()
		return _tick_result(false, "STALE_JOB")
	if current_cell != _current_job.work_cell:
		if not _rebuild_path():
			_dig_system.release_worker(mouse_id)
			_reset_job()
			return _tick_result(false, "NOT_AT_WORK_CELL")
		_set_state(State.MOVING)
		return _tick_result(true, "PATH_REBUILT")
	var result: Dictionary = _dig_system.advance_job(
		mouse_id,
		_current_job.job_id,
		delta_seconds * _dig_work_per_second
	)
	if result.get("completed", false):
		_reset_job()
	elif not result.get("ok", false):
		_reset_job()
	result["mouse_id"] = mouse_id
	result["state"] = get_state_name()
	result["current_cell"] = current_cell
	return result


func _rebuild_path() -> bool:
	if _current_job == null:
		return false
	_path = _path_service.find_path(current_cell, _current_job.work_cell)
	if _path.is_empty():
		return false
	_path.pop_front()
	return true


func _reset_job(release_reservation: bool = false) -> void:
	if release_reservation and _dig_system != null:
		_dig_system.release_worker(mouse_id)
	_current_job = null
	_path.clear()
	_move_progress = 0.0
	_set_state(State.IDLE)


func _set_state(next_state: int) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(mouse_id, state)


func _tick_result(ok: bool, reason: String) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason,
		"mouse_id": mouse_id,
		"state": get_state_name(),
		"current_cell": current_cell,
		"job_cell": get_current_job_cell(),
		"completed": false,
	}
