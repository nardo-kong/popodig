class_name MouseAgent
extends RefCounted

signal state_changed(mouse_id: String, state: int)
signal moved(mouse_id: String, from_cell: Vector2i, to_cell: Vector2i)
signal needs_changed(mouse_id: String, hunger: float, rest: float)
signal danger_changed(mouse_id: String, in_danger: bool)

enum State {
	IDLE,
	MOVING,
	DIGGING,
	HAULING,
	EATING,
	RESTING,
	FLEEING,
}

const ACTION_NONE := "NONE"
const ACTION_DIG := "DIG"
const ACTION_HAUL_PICKUP := "HAUL_PICKUP"
const ACTION_HAUL_DROPOFF := "HAUL_DROPOFF"
const ACTION_EAT := "EAT"
const ACTION_REST := "REST"
const ACTION_FLEE := "FLEE"
const ACTION_STASH := "STASH"

const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")

var mouse_id := ""
var current_cell := Vector2i(-1, -1)
var state: int = State.IDLE
var hunger := 0.0
var rest := 1.0
var danger_state := false
var current_job_id := ""
var carried_item_type := ""
var carried_item_count := 0
var path_state := "EMPTY"
var path_revision := 0
var repath_count := 0

var _world
var _path_service
var _dig_system
var _job_system
var _item_system
var _needs_enabled := false
var _home_cell := Vector2i(-1, -1)
var _move_cells_per_second := 4.0
var _dig_work_per_second := 1.0
var _hunger_per_second := 0.008
var _food_restore := 0.75
var _hunger_seek_threshold := 0.65
var _hunger_critical_threshold := 0.9
var _rest_drain_per_second := 0.004
var _rest_seek_threshold := 0.25
var _rest_critical_threshold := 0.08
var _rest_recover_per_second := 0.3
var _rest_resume_threshold := 0.9
var _need_interrupt_priority_ceiling := 25.0
var _dig_job_priority := 10.0
var _retry_seconds := 2.0
var _food_retry_remaining := 0.0
var _rest_retry_remaining := 0.0
var _move_progress := 0.0
var _path: Array[Vector2i] = []
var _travel_target := Vector2i(-1, -1)
var _action_kind := ACTION_NONE
var _current_priority := 0.0
var _current_dig_job
var _current_general_job
var _item_reservation_id := -1
var _danger_cells: Dictionary = {}


func _init(id: Variant = "mouse_1", start_cell: Vector2i = Vector2i.ZERO) -> void:
	mouse_id = str(id)
	current_cell = start_cell


func configure(world_grid, path_service, dig_system, balance: Dictionary = {}) -> void:
	_world = world_grid
	_path_service = path_service
	_dig_system = dig_system
	_job_system = null
	_item_system = null
	_needs_enabled = false
	_apply_balance(balance)
	_reset_action()


func configure_colony(job_system, item_system, home_cell: Vector2i, balance: Dictionary = {}) -> void:
	_job_system = job_system
	_item_system = item_system
	_home_cell = home_cell
	_needs_enabled = true
	_apply_balance(balance)
	var mouse: Dictionary = balance.get("mouse", {})
	hunger = clampf(float(mouse.get("initial_hunger", 0.0)), 0.0, 1.0)
	rest = clampf(float(mouse.get("initial_rest", 1.0)), 0.0, 1.0)
	_food_retry_remaining = 0.0
	_rest_retry_remaining = 0.0


func fixed_tick(delta_seconds: float) -> Dictionary:
	if delta_seconds <= 0.0:
		return _tick_result(false, "INVALID_DELTA")
	if _world == null or _path_service == null or _dig_system == null:
		return _tick_result(false, "SERVICE_UNAVAILABLE")
	_advance_needs(delta_seconds)
	if danger_state:
		return _advance_danger(delta_seconds)
	_validate_current_action()
	if _needs_enabled:
		var need_result := _try_begin_need_action()
		if not need_result.is_empty():
			return need_result
	if state == State.IDLE:
		return _claim_work()
	if state == State.MOVING:
		return _advance_movement(delta_seconds)
	if state == State.DIGGING:
		return _advance_digging(delta_seconds)
	if state == State.HAULING:
		return _advance_hauling()
	if state == State.EATING:
		return _consume_reserved_food()
	if state == State.RESTING:
		return _advance_rest(delta_seconds)
	return _tick_result(true, "IDLE")


func trigger_danger(danger_cells: Array, safe_cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	_danger_cells.clear()
	for value: Variant in danger_cells:
		if value is Vector2i:
			_danger_cells[value] = true
	_interrupt_current(true)
	danger_state = true
	danger_changed.emit(mouse_id, true)
	var flee_target := _select_flee_target(safe_cell)
	_action_kind = ACTION_FLEE
	_current_priority = 1000.0
	current_job_id = "danger"
	if flee_target.x < 0 or not _start_travel(flee_target, ACTION_FLEE):
		_set_state(State.FLEEING)
		path_state = "BLOCKED"
		return _tick_result(false, "NO_SAFE_ROUTE")
	return _tick_result(true, "DANGER_INTERRUPTED")


func recover_from_danger() -> void:
	if not danger_state:
		return
	danger_state = false
	_danger_cells.clear()
	danger_changed.emit(mouse_id, false)
	if _action_kind == ACTION_FLEE:
		_stash_carried_if_possible()
		_reset_action()


func get_state_name() -> String:
	match state:
		State.IDLE:
			return "IDLE"
		State.MOVING:
			return "MOVING"
		State.DIGGING:
			return "DIGGING"
		State.HAULING:
			return "HAULING"
		State.EATING:
			return "EATING"
		State.RESTING:
			return "RESTING"
		State.FLEEING:
			return "FLEEING"
		_:
			return "UNKNOWN"


func get_current_job_cell() -> Vector2i:
	if _current_dig_job != null:
		return _current_dig_job.cell
	if _current_general_job != null:
		return _current_general_job.target_cell
	return _travel_target


func get_current_path() -> Array[Vector2i]:
	var result: Array[Vector2i] = [current_cell]
	result.append_array(_path)
	return result


func get_debug_snapshot() -> Dictionary:
	return {
		"mouse_id": mouse_id,
		"state": get_state_name(),
		"current_cell": current_cell,
		"current_job_id": current_job_id,
		"action": _action_kind,
		"job_cell": get_current_job_cell(),
		"path": get_current_path(),
		"path_state": path_state,
		"path_revision": path_revision,
		"repath_count": repath_count,
		"hunger": hunger,
		"rest": rest,
		"danger": danger_state,
		"carried_item_type": carried_item_type,
		"carried_item_count": carried_item_count,
	}


func release_current_job() -> bool:
	_interrupt_current(false)
	return _stash_carried_if_possible()


func _apply_balance(balance: Dictionary) -> void:
	var mouse: Dictionary = balance.get("mouse", {})
	var jobs: Dictionary = balance.get("jobs", {})
	_move_cells_per_second = maxf(0.01, float(mouse.get("move_cells_per_second", 4.0)))
	_dig_work_per_second = maxf(0.01, float(mouse.get("dig_work_per_second", 1.0)))
	_hunger_per_second = maxf(0.0, float(mouse.get("hunger_per_second", 0.008)))
	_food_restore = clampf(float(mouse.get("food_restore", 0.75)), 0.01, 1.0)
	_hunger_seek_threshold = clampf(float(mouse.get("hunger_seek_threshold", 0.65)), 0.0, 1.0)
	_hunger_critical_threshold = clampf(float(mouse.get("hunger_critical_threshold", 0.9)), _hunger_seek_threshold, 1.0)
	_rest_drain_per_second = maxf(0.0, float(mouse.get("rest_drain_per_second", 0.004)))
	_rest_seek_threshold = clampf(float(mouse.get("rest_seek_threshold", 0.25)), 0.0, 1.0)
	_rest_critical_threshold = clampf(float(mouse.get("rest_critical_threshold", 0.08)), 0.0, _rest_seek_threshold)
	_rest_recover_per_second = maxf(0.01, float(mouse.get("rest_recover_per_second", 0.3)))
	_rest_resume_threshold = clampf(float(mouse.get("rest_resume_threshold", 0.9)), _rest_seek_threshold, 1.0)
	_need_interrupt_priority_ceiling = float(mouse.get("need_interrupt_priority_ceiling", 25.0))
	_dig_job_priority = float(jobs.get("dig_priority", 10.0))
	_retry_seconds = maxf(0.1, float(jobs.get("unreachable_retry_seconds", 2.0)))


func _advance_needs(delta_seconds: float) -> void:
	if not _needs_enabled:
		return
	var previous_hunger := hunger
	var previous_rest := rest
	hunger = clampf(hunger + _hunger_per_second * delta_seconds, 0.0, 1.0)
	if state != State.RESTING:
		rest = clampf(rest - _rest_drain_per_second * delta_seconds, 0.0, 1.0)
	_food_retry_remaining = maxf(0.0, _food_retry_remaining - delta_seconds)
	_rest_retry_remaining = maxf(0.0, _rest_retry_remaining - delta_seconds)
	if not is_equal_approx(previous_hunger, hunger) or not is_equal_approx(previous_rest, rest):
		needs_changed.emit(mouse_id, hunger, rest)


func _try_begin_need_action() -> Dictionary:
	if _action_kind == ACTION_EAT:
		return {}
	if _action_kind != ACTION_EAT and hunger >= _hunger_seek_threshold and _food_retry_remaining <= 0.0:
		if _can_interrupt_for_need(hunger >= _hunger_critical_threshold):
			if _begin_eating():
				return _tick_result(true, "HUNGER_INTERRUPTED")
			_food_retry_remaining = _retry_seconds
	if _action_kind != ACTION_REST and rest <= _rest_seek_threshold and _rest_retry_remaining <= 0.0:
		if _can_interrupt_for_need(rest <= _rest_critical_threshold):
			if _begin_resting():
				return _tick_result(true, "REST_INTERRUPTED")
			_rest_retry_remaining = _retry_seconds
	return {}


func _can_interrupt_for_need(critical: bool) -> bool:
	return _action_kind == ACTION_NONE or critical or _current_priority <= _need_interrupt_priority_ceiling


func _begin_eating() -> bool:
	if _item_system == null:
		return false
	var candidate: Dictionary = _item_system.find_nearest_available(ItemSystemScript.FOOD, 1, current_cell)
	if not candidate.ok:
		return false
	_interrupt_current(false)
	var reservation: Dictionary = _item_system.reserve_from_pile(mouse_id, int(candidate.pile_id), 1)
	if not reservation.ok:
		return false
	_item_reservation_id = int(reservation.reservation_id)
	current_job_id = "eat:%d" % _item_reservation_id
	_current_priority = 90.0
	return _start_travel(reservation.cell, ACTION_EAT)


func _begin_resting() -> bool:
	if _home_cell.x < 0 or not _path_service.is_walkable(_home_cell):
		return false
	var route: Array[Vector2i] = _path_service.find_path(current_cell, _home_cell)
	if route.is_empty():
		return false
	_interrupt_current(false)
	current_job_id = "rest:%s" % mouse_id
	_current_priority = 80.0
	return _start_travel(_home_cell, ACTION_REST)


func _claim_work() -> Dictionary:
	if carried_item_count > 0:
		if _stash_carried_if_possible():
			pass
		elif _begin_carried_stash():
			return _tick_result(true, "CARRY_STASH_STARTED")
		else:
			return _tick_result(false, "CARRY_STASH_BLOCKED")
	if _needs_enabled and _job_system != null:
		_current_general_job = _job_system.claim_best(mouse_id, current_cell, {"hunger": hunger, "rest": rest})
		if _current_general_job != null:
			var pile: ItemPile = _item_system.get_pile(_current_general_job.source_pile_id)
			if pile == null:
				_job_system.release_worker(mouse_id)
				_current_general_job = null
			else:
				current_job_id = "job:%d" % _current_general_job.job_id
				_current_priority = _current_general_job.priority
				_item_reservation_id = _current_general_job.item_reservation_id
				if _start_travel(pile.cell, ACTION_HAUL_PICKUP):
					return _tick_result(true, "JOB_CLAIMED")
				_job_system.mark_unreachable(mouse_id, _current_general_job.job_id)
				_job_system.release_worker(mouse_id)
				_reset_action()
	_current_dig_job = _dig_system.claim_next(mouse_id, current_cell)
	if _current_dig_job == null:
		return _tick_result(true, "NO_JOB")
	current_job_id = "dig:%d" % _current_dig_job.job_id
	_current_priority = _dig_job_priority
	if not _start_travel(_current_dig_job.work_cell, ACTION_DIG):
		_dig_system.release_worker(mouse_id)
		_reset_action()
		return _tick_result(false, "PATH_NOT_FOUND")
	return _tick_result(true, "JOB_CLAIMED")


func _advance_movement(delta_seconds: float) -> Dictionary:
	if _path_service.get_topology_revision() != path_revision:
		if not _rebuild_path():
			return _handle_unreachable("TOPOLOGY_REPATH_FAILED")
	_move_progress += delta_seconds * _move_cells_per_second
	while _move_progress >= 1.0 and not _path.is_empty():
		var next_cell: Vector2i = _path[0]
		if not _path_service.is_walkable(next_cell):
			if not _rebuild_path():
				return _handle_unreachable("PATH_INTERRUPTED")
			next_cell = _path[0]
		_path.pop_front()
		var previous := current_cell
		current_cell = next_cell
		_move_progress -= 1.0
		moved.emit(mouse_id, previous, current_cell)
	if _path.is_empty():
		path_state = "ARRIVED"
		_set_arrival_state()
	return _tick_result(true, "OK")


func _advance_digging(delta_seconds: float) -> Dictionary:
	if _current_dig_job == null:
		_reset_action()
		return _tick_result(false, "STALE_JOB")
	var result: Dictionary = _dig_system.advance_job(
		mouse_id,
		_current_dig_job.job_id,
		delta_seconds * _dig_work_per_second
	)
	if result.get("completed", false) or not result.get("ok", false):
		_reset_action()
	result["mouse_id"] = mouse_id
	result["state"] = get_state_name()
	result["current_cell"] = current_cell
	return result


func _advance_hauling() -> Dictionary:
	if _current_general_job == null:
		_reset_action()
		return _tick_result(false, "STALE_JOB")
	if _action_kind == ACTION_HAUL_PICKUP:
		var pickup: Dictionary = _item_system.pickup(_item_reservation_id, mouse_id)
		if not pickup.ok:
			_job_system.release_worker(mouse_id)
			_reset_action()
			return _tick_result(false, pickup.reason_code)
		carried_item_type = String(pickup.item_type)
		carried_item_count = int(pickup.count)
		_item_reservation_id = -1
		_job_system.mark_item_picked_up(mouse_id, _current_general_job.job_id)
		if not _start_travel(_current_general_job.target_cell, ACTION_HAUL_DROPOFF):
			_cancel_carried_job()
			return _tick_result(false, "DROPOFF_UNREACHABLE")
		return _tick_result(true, "ITEM_PICKED_UP")
	var dropoff: Dictionary = _item_system.dropoff(mouse_id, carried_item_type, carried_item_count, current_cell)
	if not dropoff.ok:
		var fallback := _find_carried_drop_cell()
		if fallback.x >= 0 and fallback != current_cell and _start_travel(fallback, ACTION_HAUL_DROPOFF):
			return _tick_result(true, "DROPOFF_REROUTED")
		_job_system.cancel(_current_general_job.job_id)
		_current_general_job = null
		_reset_action()
		return _tick_result(false, "DROPOFF_BLOCKED_CARRY_RETAINED")
	carried_item_type = ""
	carried_item_count = 0
	_job_system.complete(mouse_id, _current_general_job.job_id)
	_reset_action()
	return _tick_result(true, "HAUL_COMPLETED")


func _consume_reserved_food() -> Dictionary:
	var pickup: Dictionary = _item_system.pickup(_item_reservation_id, mouse_id)
	if not pickup.ok:
		_reset_action()
		return _tick_result(false, pickup.reason_code)
	hunger = clampf(hunger - _food_restore, 0.0, 1.0)
	_item_reservation_id = -1
	_reset_action()
	needs_changed.emit(mouse_id, hunger, rest)
	return _tick_result(true, "ATE_FOOD")


func _advance_rest(delta_seconds: float) -> Dictionary:
	rest = clampf(rest + _rest_recover_per_second * delta_seconds, 0.0, 1.0)
	needs_changed.emit(mouse_id, hunger, rest)
	if rest >= _rest_resume_threshold:
		_reset_action()
		return _tick_result(true, "REST_COMPLETED")
	return _tick_result(true, "RESTING")


func _advance_danger(delta_seconds: float) -> Dictionary:
	if state == State.MOVING:
		return _advance_movement(delta_seconds)
	_stash_carried_if_possible()
	return _tick_result(true, "SAFE_WAIT")


func _start_travel(target: Vector2i, action_kind: String) -> bool:
	var route: Array[Vector2i] = _find_route_from_current(target, action_kind == ACTION_FLEE)
	if route.is_empty():
		return false
	_travel_target = target
	_action_kind = action_kind
	_path = route
	_path.pop_front()
	_move_progress = 0.0
	path_revision = _path_service.get_topology_revision()
	path_state = "ARRIVED" if _path.is_empty() else "FOLLOWING"
	if _path.is_empty():
		_set_arrival_state()
	else:
		_set_state(State.MOVING)
	return true


func _rebuild_path() -> bool:
	var route: Array[Vector2i] = _find_route_from_current(_travel_target, _action_kind == ACTION_FLEE)
	repath_count += 1
	path_revision = _path_service.get_topology_revision()
	if route.is_empty():
		path_state = "REPATH_FAILED"
		return false
	_path = route
	_path.pop_front()
	path_state = "ARRIVED" if _path.is_empty() else "FOLLOWING"
	return true


func _set_arrival_state() -> void:
	match _action_kind:
		ACTION_DIG:
			_set_state(State.DIGGING)
		ACTION_HAUL_PICKUP, ACTION_HAUL_DROPOFF:
			_set_state(State.HAULING)
		ACTION_EAT:
			_set_state(State.EATING)
		ACTION_REST:
			_set_state(State.RESTING)
		ACTION_FLEE:
			_set_state(State.FLEEING)
		ACTION_STASH:
			if _stash_carried_if_possible():
				_reset_action()
			else:
				_set_state(State.IDLE)
		_:
			_set_state(State.IDLE)


func _handle_unreachable(reason: String) -> Dictionary:
	if _current_general_job != null:
		_job_system.mark_unreachable(mouse_id, _current_general_job.job_id)
		if carried_item_count > 0:
			_cancel_carried_job()
		else:
			_job_system.release_worker(mouse_id)
	elif _current_dig_job != null:
		_dig_system.release_worker(mouse_id)
	elif _action_kind == ACTION_EAT and _item_system != null:
		_item_system.release_worker(mouse_id)
	if _action_kind == ACTION_FLEE:
		_set_state(State.FLEEING)
		path_state = "BLOCKED"
		return _tick_result(false, reason)
	_reset_action()
	return _tick_result(false, reason)


func _interrupt_current(for_danger: bool) -> void:
	if _current_general_job != null:
		if carried_item_count > 0:
			_cancel_carried_job()
		else:
			_job_system.release_worker(mouse_id)
	elif _current_dig_job != null:
		_dig_system.release_worker(mouse_id)
	elif _action_kind == ACTION_EAT and _item_system != null:
		_item_system.release_worker(mouse_id)
	_reset_action()
	if for_danger:
		_food_retry_remaining = 0.0
		_rest_retry_remaining = 0.0


func _cancel_carried_job() -> void:
	_stash_carried_if_possible()
	if _current_general_job != null and _job_system != null:
		_job_system.cancel(_current_general_job.job_id)


func _validate_current_action() -> void:
	if _current_dig_job != null and _dig_system.get_job(_current_dig_job.job_id) == null:
		_reset_action()
	if _current_general_job != null and _job_system.get_job(_current_general_job.job_id) == null:
		_stash_carried_if_possible()
		_reset_action()


func _stash_carried_if_possible() -> bool:
	if carried_item_count <= 0:
		return true
	if _item_system == null:
		return false
	var drop_cell := current_cell
	if not _world.is_in_bounds(drop_cell) or not _world.is_excavated(drop_cell):
		drop_cell = _find_carried_drop_cell()
	if drop_cell.x < 0 or drop_cell != current_cell:
		return false
	var dropoff: Dictionary = _item_system.dropoff(mouse_id, carried_item_type, carried_item_count, drop_cell)
	if not dropoff.ok:
		return false
	carried_item_type = ""
	carried_item_count = 0
	return true


func _find_carried_drop_cell() -> Vector2i:
	if _world.is_in_bounds(current_cell) and _world.is_excavated(current_cell):
		return current_cell
	for neighbor: Vector2i in _world.get_cardinal_neighbors(current_cell):
		if _path_service.is_walkable(neighbor):
			return neighbor
	if _is_safe_reachable(_home_cell):
		return _home_cell
	return Vector2i(-1, -1)


func _begin_carried_stash() -> bool:
	var stash_cell := _find_carried_drop_cell()
	if stash_cell.x < 0:
		return false
	current_job_id = "stash:%s" % mouse_id
	_current_priority = 95.0
	if _start_travel(stash_cell, ACTION_STASH):
		return true
	current_job_id = ""
	_current_priority = 0.0
	return false


func _select_flee_target(requested: Vector2i) -> Vector2i:
	if _is_safe_reachable(requested):
		return requested
	if _is_safe_reachable(_home_cell):
		return _home_cell
	if not _path_service.is_walkable(current_cell):
		for neighbor: Vector2i in _world.get_cardinal_neighbors(current_cell):
			if _path_service.is_walkable(neighbor) and not _danger_cells.has(neighbor):
				return neighbor
	var distances: PackedInt32Array = _path_service.build_distance_field(current_cell, _danger_cells)
	var best := Vector2i(-1, -1)
	var best_distance := 2147483647
	for index: int in range(distances.size()):
		if distances[index] < 0 or distances[index] > best_distance:
			continue
		var cell: Vector2i = _world.index_to_cell(index)
		if _danger_cells.has(cell):
			continue
		if distances[index] < best_distance or best.x < 0 or cell.y < best.y or (cell.y == best.y and cell.x < best.x):
			best = cell
			best_distance = distances[index]
	return best


func _is_safe_reachable(cell: Vector2i) -> bool:
	return cell.x >= 0 and not _danger_cells.has(cell) and not _find_route_from_current(cell, true).is_empty()


func _find_route_from_current(target: Vector2i, avoid_danger: bool = false) -> Array[Vector2i]:
	var forbidden: Dictionary = _danger_cells if avoid_danger else {}
	var direct: Array[Vector2i] = _path_service.find_path(current_cell, target, forbidden)
	if not direct.is_empty() or _path_service.is_walkable(current_cell):
		return direct
	var best: Array[Vector2i] = []
	for neighbor: Vector2i in _world.get_cardinal_neighbors(current_cell):
		if not _path_service.is_walkable(neighbor):
			continue
		if forbidden.has(neighbor):
			continue
		var candidate: Array[Vector2i] = _path_service.find_path(neighbor, target, forbidden)
		if candidate.is_empty():
			continue
		if best.is_empty() or candidate.size() < best.size():
			best = candidate
	if best.is_empty():
		return best
	best.push_front(current_cell)
	return best


func _reset_action() -> void:
	_current_dig_job = null
	_current_general_job = null
	_item_reservation_id = -1
	current_job_id = ""
	_action_kind = ACTION_NONE
	_current_priority = 0.0
	_path.clear()
	_travel_target = Vector2i(-1, -1)
	_move_progress = 0.0
	path_state = "EMPTY"
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
		"current_job_id": current_job_id,
		"completed": false,
	}
