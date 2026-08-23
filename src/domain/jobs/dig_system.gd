class_name DigSystem
extends RefCounted

signal designation_changed(cell: Vector2i, designated: bool)
signal job_changed(job_id: int, state: int)
signal cell_excavated(cell: Vector2i)

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const DigJobScript = preload("res://src/domain/jobs/dig_job.gd")

const REASON_OK := "OK"
const REASON_EMPTY_SELECTION := "EMPTY_SELECTION"
const REASON_OUT_OF_BOUNDS := "OUT_OF_BOUNDS"
const REASON_NOT_EXCAVATABLE := "NOT_EXCAVATABLE"
const REASON_PROTECTED_FEATURE := "PROTECTED_FEATURE"
const REASON_NOT_CONTIGUOUS := "NOT_CONTIGUOUS"
const REASON_NOT_CONNECTED := "NOT_CONNECTED_TO_EXCAVATED"
const REASON_ALREADY_DESIGNATED := "ALREADY_DESIGNATED"
const REASON_NOT_DESIGNATED := "NOT_DESIGNATED"
const REASON_NOT_FRONTIER := "NOT_FRONTIER"
const REASON_RESERVED_BY_OTHER := "RESERVED_BY_OTHER"
const REASON_STALE_JOB := "STALE_JOB"
const REASON_INVALID_DELTA := "INVALID_DELTA"
const REASON_NO_JOB := "NO_JOB"

var _world
var _path_service
var _base_dig_seconds := 0.8
var _jobs_by_cell: Dictionary = {}
var _jobs_by_id: Dictionary = {}
var _worker_job_ids: Dictionary = {}
var _next_job_id := 1
var _colony_reachable: Dictionary = {}
var _colony_topology_revision := -1
var _cached_colony_anchor := Vector2i(-1, -1)
var _hazard_filter: Callable = Callable()


func set_hazard_filter(filter: Callable) -> void:
	_hazard_filter = filter


func _is_hazard_blocked(cell: Vector2i) -> bool:
	return _hazard_filter.is_valid() and bool(_hazard_filter.call(cell))


func configure(world_grid, path_service, balance: Dictionary = {}) -> void:
	_world = world_grid
	_path_service = path_service
	var digging: Dictionary = balance.get("digging", {})
	_base_dig_seconds = maxf(0.01, float(digging.get("base_dig_seconds", 0.8)))
	_jobs_by_cell.clear()
	_jobs_by_id.clear()
	_worker_job_ids.clear()
	_next_job_id = 1
	_colony_reachable.clear()
	_colony_topology_revision = -1
	_cached_colony_anchor = Vector2i(-1, -1)
	_rebuild_existing_designations()


func inspect_designation(cell: Vector2i) -> Dictionary:
	if _world == null or not _world.is_in_bounds(cell):
		return {"ok": false, "reason_code": REASON_OUT_OF_BOUNDS, "cell": cell}
	if _world.is_exterior(cell):
		return {"ok": false, "reason_code": REASON_NOT_EXCAVATABLE, "cell": cell}
	if _world.is_protected(cell):
		return {"ok": false, "reason_code": REASON_PROTECTED_FEATURE, "cell": cell}
	if not _world.is_solid(cell):
		return {"ok": false, "reason_code": REASON_NOT_EXCAVATABLE, "cell": cell}
	if _world.get_dig_state(cell) != CellDataScript.DigState.NONE:
		return {"ok": false, "reason_code": REASON_ALREADY_DESIGNATED, "cell": cell}
	for neighbor: Vector2i in _world.get_cardinal_neighbors(cell):
		if _is_colony_reachable(neighbor) or _jobs_by_cell.has(neighbor):
			return {"ok": true, "reason_code": REASON_OK, "cell": cell}
	return {"ok": false, "reason_code": REASON_NOT_CONNECTED, "cell": cell}


func designate_path(cell_values: Array) -> Dictionary:
	var cells := _normalized_cells(cell_values)
	if cells.size() != cell_values.size():
		return _designation_result(false, REASON_OUT_OF_BOUNDS)
	if cells.is_empty():
		return _designation_result(false, REASON_EMPTY_SELECTION)
	var seen: Dictionary = {}
	for index: int in range(cells.size()):
		var cell: Vector2i = cells[index]
		var validation_reason := _validate_excavatable(cell)
		if validation_reason != REASON_OK:
			return _designation_rejection(validation_reason, cell)
		if seen.has(cell):
			return _designation_rejection(REASON_NOT_CONTIGUOUS, cell)
		seen[cell] = true
		if index > 0 and _manhattan(cells[index - 1], cell) != 1:
			return _designation_rejection(REASON_NOT_CONTIGUOUS, cell)
	if not _selection_has_connection(cells):
		return _designation_rejection(REASON_NOT_CONNECTED, cells[0])
	var accepted: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if _jobs_by_cell.has(cell):
			continue
		accepted.append(cell)
		_world.set_dig_state(cell, CellDataScript.DigState.QUEUED)
		_create_job(cell)
		designation_changed.emit(cell, true)
	if accepted.is_empty():
		return _designation_rejection(REASON_ALREADY_DESIGNATED, cells[0])
	return _designation_result(true, REASON_OK, accepted)


func cancel(cell_values: Array) -> Dictionary:
	var cells := _normalized_cells(cell_values)
	if cells.size() != cell_values.size():
		return _cancel_result(false, REASON_OUT_OF_BOUNDS)
	if cells.is_empty():
		return _cancel_result(false, REASON_EMPTY_SELECTION)
	var cancelled: Array[Vector2i] = []
	var rejected: Array[Dictionary] = []
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		if _world == null or not _world.is_in_bounds(cell):
			rejected.append({"cell": cell, "reason_code": REASON_OUT_OF_BOUNDS})
			continue
		if not _jobs_by_cell.has(cell):
			rejected.append({"cell": cell, "reason_code": REASON_NOT_DESIGNATED})
			continue
		_remove_job(cell, true)
		cancelled.append(cell)
	var downstream := _prune_disconnected_designations()
	var ok := not cancelled.is_empty()
	var reason := REASON_OK if ok else REASON_NOT_DESIGNATED
	return _cancel_result(ok, reason, cancelled, downstream, rejected)


func derive_frontier_jobs(worker_cell: Vector2i) -> Array[DigJob]:
	var candidates: Array[DigJob] = []
	if _world == null or _path_service == null or not _path_service.is_walkable(worker_cell):
		return candidates
	var distances: PackedInt32Array = _path_service.build_distance_field(worker_cell)
	for cell: Vector2i in _jobs_by_cell:
		var job: DigJob = _jobs_by_cell[cell]
		if job.state != DigJobScript.State.QUEUED:
			continue
		var work_result := _find_best_work_cell(cell, distances)
		if not work_result.found:
			continue
		if _is_hazard_blocked(work_result.cell):
			continue
		var candidate: DigJob = job.snapshot()
		candidate.work_cell = work_result.cell
		candidate.set_meta("path_length", work_result.path_length)
		candidates.append(candidate)
	candidates.sort_custom(func(a: DigJob, b: DigJob) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		var a_distance: int = a.get_meta("path_length", 2147483647)
		var b_distance: int = b.get_meta("path_length", 2147483647)
		if a_distance != b_distance:
			return a_distance < b_distance
		return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x)
	)
	return candidates


func claim_next(worker_id: String, worker_cell: Vector2i):
	if worker_id.is_empty():
		return null
	if _worker_job_ids.has(worker_id):
		var existing_id: int = _worker_job_ids[worker_id]
		var existing: DigJob = _jobs_by_id.get(existing_id)
		if existing != null:
			return existing
		_worker_job_ids.erase(worker_id)
	var candidates := derive_frontier_jobs(worker_cell)
	if candidates.is_empty():
		return null
	var selected: DigJob = _jobs_by_id.get(candidates[0].job_id)
	if selected == null or selected.state != DigJobScript.State.QUEUED:
		return null
	selected.state = DigJobScript.State.RESERVED
	selected.worker_id = worker_id
	selected.work_cell = candidates[0].work_cell
	_worker_job_ids[worker_id] = selected.job_id
	_world.set_dig_state(selected.cell, CellDataScript.DigState.ACTIVE)
	job_changed.emit(selected.job_id, selected.state)
	return selected


func advance_job(worker_id: String, job_id: int, work_amount: float) -> Dictionary:
	if work_amount <= 0.0:
		return _job_result(false, REASON_INVALID_DELTA)
	var job: DigJob = _jobs_by_id.get(job_id)
	if job == null:
		return _job_result(false, REASON_STALE_JOB)
	if job.state != DigJobScript.State.RESERVED or job.worker_id != worker_id:
		return _job_result(false, REASON_RESERVED_BY_OTHER, job)
	if not _world.is_solid(job.cell) or _world.get_dig_state(job.cell) != CellDataScript.DigState.ACTIVE:
		_remove_job(job.cell, true)
		return _job_result(false, REASON_STALE_JOB)
	if not _world.is_traversable(job.work_cell) or _manhattan(job.work_cell, job.cell) != 1:
		release_worker(worker_id)
		return _job_result(false, REASON_NOT_FRONTIER, job)
	job.completed_work = minf(job.required_work, job.completed_work + work_amount)
	if job.completed_work + 0.00001 < job.required_work:
		_world.set_dig_progress(job.cell, job.normalized_progress())
		return _job_result(true, REASON_OK, job, false)
	if not _world.complete_excavation_atomic(job.cell):
		_remove_job(job.cell, true)
		return _job_result(false, REASON_STALE_JOB)
	var completed_cell := job.cell
	job.state = DigJobScript.State.COMPLETED
	_worker_job_ids.erase(worker_id)
	_jobs_by_cell.erase(completed_cell)
	_jobs_by_id.erase(job.job_id)
	job_changed.emit(job.job_id, job.state)
	cell_excavated.emit(completed_cell)
	return _job_result(true, REASON_OK, job, true)


func release_worker(worker_id: String) -> bool:
	if not _worker_job_ids.has(worker_id):
		return false
	var job_id: int = _worker_job_ids[worker_id]
	_worker_job_ids.erase(worker_id)
	var job: DigJob = _jobs_by_id.get(job_id)
	if job == null:
		return false
	job.state = DigJobScript.State.QUEUED
	job.worker_id = ""
	job.work_cell = Vector2i(-1, -1)
	_world.set_dig_state(job.cell, CellDataScript.DigState.QUEUED)
	job_changed.emit(job.job_id, job.state)
	return true


func get_designated_count() -> int:
	return _jobs_by_cell.size()


func get_designated_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _jobs_by_cell:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _world.cell_to_index(a) < _world.cell_to_index(b)
	)
	return cells


func get_active_job_count() -> int:
	return _worker_job_ids.size()


func get_job(job_id: int):
	return _jobs_by_id.get(job_id)


func _validate_excavatable(cell: Vector2i) -> String:
	if _world == null or not _world.is_in_bounds(cell):
		return REASON_OUT_OF_BOUNDS
	if _world.is_exterior(cell):
		return REASON_NOT_EXCAVATABLE
	if _world.is_protected(cell):
		return REASON_PROTECTED_FEATURE
	if not _world.is_solid(cell):
		return REASON_NOT_EXCAVATABLE
	return REASON_OK


func _selection_has_connection(cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		for neighbor: Vector2i in _world.get_cardinal_neighbors(cell):
			if _is_colony_reachable(neighbor) or _jobs_by_cell.has(neighbor):
				return true
	return false


func _create_job(cell: Vector2i) -> void:
	var job := DigJobScript.new(_next_job_id, cell)
	_next_job_id += 1
	job.required_work = maxf(0.01, _base_dig_seconds * _world.get_hardness(cell))
	job.completed_work = _world.get_dig_progress(cell) * job.required_work
	_jobs_by_cell[cell] = job
	_jobs_by_id[job.job_id] = job


func _rebuild_existing_designations() -> void:
	if _world == null:
		return
	for index: int in range(_world.width * _world.height):
		var cell: Vector2i = _world.index_to_cell(index)
		if _world.get_dig_state(cell) != CellDataScript.DigState.NONE:
			_world.set_dig_state(cell, CellDataScript.DigState.QUEUED)
			_create_job(cell)
	_prune_disconnected_designations()


func _find_best_work_cell(target: Vector2i, distances: PackedInt32Array) -> Dictionary:
	var found := false
	var best_cell := Vector2i(-1, -1)
	var best_length := 2147483647
	for candidate: Vector2i in _world.get_cardinal_neighbors(target):
		if not _path_service.is_walkable(candidate):
			continue
		var candidate_index: int = _world.cell_to_index(candidate)
		var path_length: int = distances[candidate_index]
		if path_length < 0:
			continue
		if not found or path_length < best_length:
			found = true
			best_cell = candidate
			best_length = path_length
	return {"found": found, "cell": best_cell, "path_length": best_length}


func _prune_disconnected_designations() -> Array[Vector2i]:
	var connected: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in _jobs_by_cell:
		for neighbor: Vector2i in _world.get_cardinal_neighbors(cell):
			if _is_colony_reachable(neighbor):
				connected[cell] = true
				queue.append(cell)
				break
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for neighbor: Vector2i in _world.get_cardinal_neighbors(current):
			if _jobs_by_cell.has(neighbor) and not connected.has(neighbor):
				connected[neighbor] = true
				queue.append(neighbor)
	var removed: Array[Vector2i] = []
	var existing: Array[Vector2i] = []
	for cell: Vector2i in _jobs_by_cell:
		existing.append(cell)
	for cell: Vector2i in existing:
		if connected.has(cell):
			continue
		_remove_job(cell, true)
		removed.append(cell)
	removed.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return removed


func _is_colony_reachable(cell: Vector2i) -> bool:
	if _path_service == null or not _path_service.is_walkable(cell):
		return false
	var start_value: Variant = _world.metadata.get("start_cell", Vector2i(-1, -1))
	if not start_value is Vector2i:
		return false
	var start_cell: Vector2i = start_value
	_refresh_colony_reachable_cache(start_cell)
	return _colony_reachable.has(_world.cell_to_index(cell))


func _refresh_colony_reachable_cache(start_cell: Vector2i) -> void:
	var revision: int = _path_service.get_topology_revision()
	if revision == _colony_topology_revision and start_cell == _cached_colony_anchor:
		return
	_colony_reachable.clear()
	_colony_topology_revision = revision
	_cached_colony_anchor = start_cell
	var distances: PackedInt32Array = _path_service.build_distance_field(start_cell)
	for index: int in range(distances.size()):
		if distances[index] >= 0:
			_colony_reachable[index] = true


func _remove_job(cell: Vector2i, clear_world_state: bool) -> void:
	var job: DigJob = _jobs_by_cell.get(cell)
	if job == null:
		return
	if not job.worker_id.is_empty():
		_worker_job_ids.erase(job.worker_id)
	job.state = DigJobScript.State.CANCELLED
	job_changed.emit(job.job_id, job.state)
	_jobs_by_id.erase(job.job_id)
	_jobs_by_cell.erase(cell)
	if clear_world_state:
		_world.clear_dig(cell)
		designation_changed.emit(cell, false)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _normalized_cells(cell_values: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for value: Variant in cell_values:
		if not value is Vector2i:
			return []
		cells.append(value)
	return cells


func _designation_rejection(reason: String, cell: Vector2i) -> Dictionary:
	return _designation_result(false, reason, [], [{"cell": cell, "reason_code": reason}])


func _designation_result(ok: bool, reason: String, accepted: Array[Vector2i] = [], rejected: Array[Dictionary] = []) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason,
		"accepted_cells": accepted,
		"rejected": rejected,
		"cancelled_cells": [],
		"removed_downstream": [],
	}


func _cancel_result(
	ok: bool,
	reason: String,
	cancelled: Array[Vector2i] = [],
	downstream: Array[Vector2i] = [],
	rejected: Array[Dictionary] = []
) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason,
		"accepted_cells": [],
		"rejected": rejected,
		"cancelled_cells": cancelled,
		"removed_downstream": downstream,
	}


func _job_result(ok: bool, reason: String, job = null, completed: bool = false) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason,
		"job_id": -1 if job == null else job.job_id,
		"cell": Vector2i(-1, -1) if job == null else job.cell,
		"progress": 0.0 if job == null else job.normalized_progress(),
		"completed": completed,
	}
