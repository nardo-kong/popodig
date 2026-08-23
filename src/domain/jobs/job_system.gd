class_name JobSystem
extends RefCounted

signal job_changed(job_id: int, state: int)

const ColonyJobScript = preload("res://src/domain/jobs/colony_job.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")

var _path_service
var _item_system
var _jobs: Dictionary = {}
var _worker_jobs: Dictionary = {}
var _cooldown_until: Dictionary = {}
var _unreachable_attempts: Dictionary = {}
var _next_job_id := 1
var _time_seconds := 0.0
var _last_topology_revision := 0
var _travel_cost_weight := 0.25
var _unreachable_retry_seconds := 2.0
var _haul_priority := 20.0
var _zone_setup_priority := 15.0
var _seal_priority := 35.0
var _reinforce_priority := 30.0
var _emergency_priority := 100.0
var _hazard_filter: Callable = Callable()
var _completed_count := 0


func configure(path_service, item_system, balance: Dictionary = {}) -> void:
	_path_service = path_service
	_item_system = item_system
	_jobs.clear()
	_worker_jobs.clear()
	_cooldown_until.clear()
	_unreachable_attempts.clear()
	_next_job_id = 1
	_time_seconds = 0.0
	_last_topology_revision = 0 if _path_service == null else _path_service.get_topology_revision()
	_completed_count = 0
	var jobs: Dictionary = balance.get("jobs", {})
	_travel_cost_weight = maxf(0.0, float(jobs.get("travel_cost_weight", 0.25)))
	_unreachable_retry_seconds = maxf(0.1, float(jobs.get("unreachable_retry_seconds", 2.0)))
	_haul_priority = float(jobs.get("haul_priority", 20.0))
	_zone_setup_priority = float(jobs.get("zone_setup_priority", 15.0))
	_seal_priority = float(jobs.get("seal_priority", 35.0))
	_reinforce_priority = float(jobs.get("reinforce_priority", 30.0))
	_emergency_priority = float(jobs.get("emergency_priority", 100.0))


func set_hazard_filter(filter: Callable) -> void:
	_hazard_filter = filter


func _is_hazard_blocked(cell: Vector2i) -> bool:
	return _hazard_filter.is_valid() and bool(_hazard_filter.call(cell))


func enqueue_haul(
	item_type: String,
	source_pile_id: int,
	dropoff_cell: Vector2i,
	count: int,
	emergency: bool = false,
	target_zone_id: int = -1,
	destination_capacity: int = -1
):
	if _item_system == null or count <= 0:
		return null
	if item_type != ItemSystemScript.FOOD and item_type != ItemSystemScript.GENERAL_MATERIAL:
		return null
	var source_pile: ItemPile = _item_system.get_pile(source_pile_id)
	if source_pile == null or source_pile.item_type != item_type:
		return null
	if _committed_source_count(source_pile_id) + count > source_pile.count:
		return null
	var job := ColonyJobScript.new()
	job.job_id = _next_job_id
	_next_job_id += 1
	job.job_type = (
		ColonyJobScript.Type.EMERGENCY_HAUL
		if emergency
		else ColonyJobScript.Type.HAUL_FOOD if item_type == ItemSystemScript.FOOD else ColonyJobScript.Type.HAUL_MATERIAL
	)
	job.priority = _emergency_priority if emergency else _haul_priority
	job.source_pile_id = source_pile_id
	job.target_cell = dropoff_cell
	job.item_type = item_type
	job.item_count = count
	job.zone_id = target_zone_id
	if destination_capacity > 0:
		var dropoff_reservation: Dictionary = _item_system.reserve_dropoff(
			"job:%d" % job.job_id,
			dropoff_cell,
			count,
			destination_capacity
		)
		if not dropoff_reservation.ok:
			return null
		job.dropoff_reservation_id = int(dropoff_reservation.reservation_id)
	_jobs[job.job_id] = job
	job_changed.emit(job.job_id, job.state)
	return job


func enqueue_zone_setup(source_pile_id: int, target_cell: Vector2i, count: int, zone_id: int):
	if _item_system == null or count <= 0 or zone_id < 0:
		return null
	var source_pile: ItemPile = _item_system.get_pile(source_pile_id)
	if source_pile == null or source_pile.item_type != ItemSystemScript.GENERAL_MATERIAL:
		return null
	if _committed_source_count(source_pile_id) + count > source_pile.count:
		return null
	var job := ColonyJobScript.new()
	job.job_id = _next_job_id
	_next_job_id += 1
	job.job_type = ColonyJobScript.Type.ZONE_SETUP
	job.priority = _zone_setup_priority
	job.source_pile_id = source_pile_id
	job.target_cell = target_cell
	job.item_type = ItemSystemScript.GENERAL_MATERIAL
	job.item_count = count
	job.zone_id = zone_id
	_jobs[job.job_id] = job
	job_changed.emit(job.job_id, job.state)
	return job


func enqueue_seal(source_pile_id: int, work_cell: Vector2i, seal_cell: Vector2i, count: int = 1):
	if _item_system == null or count <= 0:
		return null
	var source_pile: ItemPile = _item_system.get_pile(source_pile_id)
	if source_pile == null or source_pile.item_type != ItemSystemScript.GENERAL_MATERIAL:
		return null
	if _committed_source_count(source_pile_id) + count > source_pile.count:
		return null
	var job := ColonyJobScript.new()
	job.job_id = _next_job_id
	_next_job_id += 1
	job.job_type = ColonyJobScript.Type.SEAL
	job.priority = _seal_priority
	job.source_pile_id = source_pile_id
	job.target_cell = work_cell
	job.action_cell = seal_cell
	job.item_type = ItemSystemScript.GENERAL_MATERIAL
	job.item_count = count
	_jobs[job.job_id] = job
	job_changed.emit(job.job_id, job.state)
	return job


func enqueue_reinforce(source_pile_id: int, work_cell: Vector2i, reinforce_cell: Vector2i, count: int = 1):
	if _item_system == null or count <= 0:
		return null
	var source_pile: ItemPile = _item_system.get_pile(source_pile_id)
	if source_pile == null or source_pile.item_type != ItemSystemScript.GENERAL_MATERIAL:
		return null
	if _committed_source_count(source_pile_id) + count > source_pile.count:
		return null
	var job := ColonyJobScript.new()
	job.job_id = _next_job_id
	_next_job_id += 1
	job.job_type = ColonyJobScript.Type.REINFORCE
	job.priority = _reinforce_priority
	job.source_pile_id = source_pile_id
	job.target_cell = work_cell
	job.action_cell = reinforce_cell
	job.item_type = ItemSystemScript.GENERAL_MATERIAL
	job.item_count = count
	_jobs[job.job_id] = job
	job_changed.emit(job.job_id, job.state)
	return job


func claim_best(worker_id: String, worker_cell: Vector2i, needs: Dictionary = {}):
	if worker_id.is_empty() or _path_service == null or _item_system == null:
		return null
	if _worker_jobs.has(worker_id):
		return _jobs.get(int(_worker_jobs[worker_id]))
	_refresh_topology_cooldowns()
	var candidates: Array[Dictionary] = []
	var stale_job_ids: Array[int] = []
	for job: ColonyJob in _jobs.values():
		if job.state != ColonyJobScript.State.PENDING:
			continue
		var pile: ItemPile = _item_system.get_pile(job.source_pile_id)
		if pile == null:
			stale_job_ids.append(job.job_id)
			continue
		if pile.count < job.item_count:
			stale_job_ids.append(job.job_id)
			continue
		if pile.available_count() < job.item_count:
			continue
		var reinforces_hazard := job.job_type == ColonyJobScript.Type.REINFORCE
		if not reinforces_hazard:
			if _is_hazard_blocked(job.target_cell):
				continue
			if job.action_cell.x >= 0 and _is_hazard_blocked(job.action_cell):
				continue
		var cooldown_key := _cooldown_key(worker_id, job.job_id)
		if float(_cooldown_until.get(cooldown_key, 0.0)) > _time_seconds:
			continue
		var to_source: Array[Vector2i] = _path_service.find_path(worker_cell, pile.cell)
		var to_target: Array[Vector2i] = _path_service.find_path(pile.cell, job.target_cell)
		if to_source.is_empty() or to_target.is_empty():
			mark_unreachable(worker_id, job.job_id)
			continue
		var travel_cost := float(to_source.size() + to_target.size() - 2)
		var urgency := 25.0 if job.job_type == ColonyJobScript.Type.EMERGENCY_HAUL else 0.0
		urgency += float(needs.get("job_urgency_bonus", 0.0))
		var score := job.priority + urgency - travel_cost * _travel_cost_weight
		candidates.append({"job": job, "score": score, "travel": travel_cost})
	for job_id: int in stale_job_ids:
		cancel(job_id)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) > float(b.score)
		return int(a.job.job_id) < int(b.job.job_id)
	)
	for candidate: Dictionary in candidates:
		var job: ColonyJob = candidate.job
		var reservation: Dictionary = _item_system.reserve_from_pile(worker_id, job.source_pile_id, job.item_count)
		if not reservation.ok:
			continue
		job.state = ColonyJobScript.State.RESERVED
		job.worker_id = worker_id
		job.item_reservation_id = int(reservation.reservation_id)
		_worker_jobs[worker_id] = job.job_id
		job_changed.emit(job.job_id, job.state)
		return job
	return null


func complete(worker_id: String, job_id: int) -> bool:
	var job: ColonyJob = _jobs.get(job_id)
	if (
		job == null
		or job.state != ColonyJobScript.State.RESERVED
		or job.worker_id != worker_id
		or job.item_reservation_id >= 0
		or job.dropoff_reservation_id >= 0
	):
		return false
	job.state = ColonyJobScript.State.COMPLETED
	_worker_jobs.erase(worker_id)
	_jobs.erase(job_id)
	_completed_count += 1
	job_changed.emit(job_id, job.state)
	return true


func complete_reserved_dropoff(worker_id: String, job_id: int, item_type: String, count: int) -> Dictionary:
	var job: ColonyJob = _jobs.get(job_id)
	if job == null or job.state != ColonyJobScript.State.RESERVED or job.worker_id != worker_id:
		return {"ok": false, "reason_code": "INVALID_JOB"}
	if job.dropoff_reservation_id < 0:
		return {"ok": false, "reason_code": "NO_DROPOFF_RESERVATION"}
	var result: Dictionary = _item_system.complete_reserved_dropoff(
		job.dropoff_reservation_id,
		"job:%d" % job.job_id,
		worker_id,
		item_type,
		count
	)
	if result.ok:
		job.dropoff_reservation_id = -1
	return result


func mark_item_picked_up(worker_id: String, job_id: int) -> bool:
	var job: ColonyJob = _jobs.get(job_id)
	if job == null or job.state != ColonyJobScript.State.RESERVED or job.worker_id != worker_id:
		return false
	job.item_reservation_id = -1
	return true


func release_worker(worker_id: String) -> bool:
	if not _worker_jobs.has(worker_id):
		return false
	var job_id := int(_worker_jobs[worker_id])
	_worker_jobs.erase(worker_id)
	var job: ColonyJob = _jobs.get(job_id)
	if job == null:
		_item_system.release_worker(worker_id)
		return false
	if job.item_reservation_id < 0:
		job.state = ColonyJobScript.State.CANCELLED
		_release_job_dropoff(job)
		_jobs.erase(job_id)
		job_changed.emit(job_id, job.state)
		return true
	_item_system.release_worker(worker_id)
	job.state = ColonyJobScript.State.PENDING
	job.worker_id = ""
	job.item_reservation_id = -1
	job_changed.emit(job.job_id, job.state)
	return true


func cancel(job_id: int) -> bool:
	var job: ColonyJob = _jobs.get(job_id)
	if job == null:
		return false
	if not job.worker_id.is_empty():
		_worker_jobs.erase(job.worker_id)
		if job.item_reservation_id >= 0:
			_item_system.release_worker(job.worker_id)
	_release_job_dropoff(job)
	job.state = ColonyJobScript.State.CANCELLED
	_jobs.erase(job_id)
	job_changed.emit(job_id, job.state)
	return true


func mark_unreachable(worker_id: String, job_id: int) -> void:
	var key := _cooldown_key(worker_id, job_id)
	_cooldown_until[key] = _time_seconds + _unreachable_retry_seconds
	_unreachable_attempts[key] = int(_unreachable_attempts.get(key, 0)) + 1


func advance_time(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	_time_seconds += delta_seconds
	_refresh_topology_cooldowns()


func get_job(job_id: int):
	return _jobs.get(job_id)


func get_jobs() -> Array[ColonyJob]:
	var result: Array[ColonyJob] = []
	for job: ColonyJob in _jobs.values():
		result.append(job.snapshot())
	result.sort_custom(func(a: ColonyJob, b: ColonyJob) -> bool:
		return a.job_id < b.job_id
	)
	return result


func get_zone_jobs(zone_id: int, job_type: int = -1) -> Array[ColonyJob]:
	var result: Array[ColonyJob] = []
	for job: ColonyJob in _jobs.values():
		if job.zone_id != zone_id or (job_type >= 0 and job.job_type != job_type):
			continue
		result.append(job.snapshot())
	result.sort_custom(func(a: ColonyJob, b: ColonyJob) -> bool:
		return a.job_id < b.job_id
	)
	return result


func get_active_count() -> int:
	return _worker_jobs.size()


func get_pending_count() -> int:
	var count := 0
	for job: ColonyJob in _jobs.values():
		if job.state == ColonyJobScript.State.PENDING:
			count += 1
	return count


func get_completed_count() -> int:
	return _completed_count


func get_unreachable_attempt_count(worker_id: String, job_id: int) -> int:
	return int(_unreachable_attempts.get(_cooldown_key(worker_id, job_id), 0))


func get_debug_jobs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job: ColonyJob in get_jobs():
		result.append({
			"job_id": job.job_id,
			"type": job.get_type_name(),
			"state": job.state,
			"worker_id": job.worker_id,
			"source_pile_id": job.source_pile_id,
			"target_cell": job.target_cell,
			"action_cell": job.action_cell,
			"item_type": job.item_type,
			"item_count": job.item_count,
			"zone_id": job.zone_id,
			"dropoff_reservation_id": job.dropoff_reservation_id,
		})
	return result


func _refresh_topology_cooldowns() -> void:
	if _path_service == null:
		return
	var revision: int = _path_service.get_topology_revision()
	if revision == _last_topology_revision:
		return
	_last_topology_revision = revision
	_cooldown_until.clear()


func _cooldown_key(worker_id: String, job_id: int) -> String:
	return "%s:%d" % [worker_id, job_id]


func _committed_source_count(source_pile_id: int) -> int:
	var committed := 0
	for job: ColonyJob in _jobs.values():
		if job.source_pile_id != source_pile_id:
			continue
		# A reserved job with no item reservation has already picked the item up,
		# so its cargo no longer commits stock remaining in the source pile.
		if job.state == ColonyJobScript.State.PENDING or job.item_reservation_id >= 0:
			committed += job.item_count
	return committed


func _release_job_dropoff(job: ColonyJob) -> void:
	if job.dropoff_reservation_id < 0:
		return
	_item_system.release_dropoff(job.dropoff_reservation_id, "job:%d" % job.job_id)
	job.dropoff_reservation_id = -1
