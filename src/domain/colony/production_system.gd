class_name ProductionSystem
extends RefCounted

signal produced(event: Dictionary)

const ZoneScript = preload("res://src/domain/zones/zone.gd")
const Job = preload("res://src/domain/jobs/colony_job.gd")
# Provisional short chains: raw material -> useful home/colony capability.
const RECIPES := {
	"building": {"input": "STONE", "count": 2, "output": "GENERAL_MATERIAL", "yield": 3, "seconds": 6.0},
	"metal": {"input": "ORE", "count": 2, "output": "METAL", "yield": 1, "seconds": 8.0},
}

var _zones
var _items
var _jobs
var _paths
var _orders: Dictionary = {}
var _clock := 0.0
var completed_batches := 0
var waiting_seconds := 0.0


func configure(zones, items, jobs, paths) -> void:
	_zones = zones
	_items = items
	_jobs = jobs
	_paths = paths


func set_recipe(zone_id: int, recipe_id: String) -> Dictionary:
	var zone = _zones.get_zone(zone_id)
	if zone == null or zone.zone_type != ZoneScript.Type.PRODUCTION or not RECIPES.has(recipe_id):
		return {"ok": false, "reason": "INVALID_WORKSHOP"}
	# Recipe changes never invalidate a mouse already carrying a reserved input.
	for job in _jobs.get_zone_jobs(zone_id, Job.Type.PRODUCE):
		if job.state == Job.State.RESERVED:
			return {"ok": false, "reason": "BUSY"}
		_jobs.cancel(job.job_id)
	_orders[zone_id] = {"recipe": recipe_id, "progress": 0.0, "enabled": true}
	return {"ok": true, "reason": "OK"}


func set_enabled(zone_id: int, enabled: bool) -> void:
	if _orders.has(zone_id):
		_orders[zone_id].enabled = enabled
		if not enabled:
			for job in _jobs.get_zone_jobs(zone_id, Job.Type.PRODUCE):
				if job.state == Job.State.PENDING:
					_jobs.cancel(job.job_id)


func status(zone_id: int) -> Dictionary:
	var order: Dictionary = _orders.get(zone_id, {"recipe": "building", "progress": 0.0, "enabled": true})
	var result := order.duplicate(true)
	result["reason"] = "WORKING" if float(order.progress) > 0.0 else "WAITING_INPUT"
	var zone = _zones.get_zone(zone_id)
	if zone == null or not zone.valid:
		result.reason = "UNAVAILABLE"
	elif zone.setup_state != ZoneScript.SetupState.SET_UP:
		result.reason = "SETTING_UP"
	elif not bool(order.enabled):
		result.reason = "PAUSED"
	return result


func fixed_tick(delta: float) -> void:
	_clock += delta
	if _clock < 0.5:
		return
	var elapsed := _clock
	_clock = 0.0
	for zone in _zones.get_zones_by_type(ZoneScript.Type.PRODUCTION, true):
		if not _orders.has(zone.zone_id):
			_orders[zone.zone_id] = {"recipe": "building", "progress": 0.0, "enabled": true}
		var order: Dictionary = _orders[zone.zone_id]
		if not bool(order.enabled) or zone.setup_state != ZoneScript.SetupState.SET_UP:
			continue
		if not _jobs.get_zone_jobs(zone.zone_id, Job.Type.PRODUCE).is_empty():
			continue
		var recipe: Dictionary = RECIPES[order.recipe]
		var candidates: Array[Dictionary] = []
		for pile in _items.get_piles():
			if pile.item_type != recipe.input or pile.available_count() < int(recipe.count):
				continue
			var route: Array[Vector2i] = _paths.find_path(pile.cell, zone.identity_anchor)
			if not route.is_empty():
				candidates.append({"pile_id": pile.pile_id, "distance": route.size()})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.distance) < int(b.distance) or (int(a.distance) == int(b.distance) and int(a.pile_id) < int(b.pile_id))
		)
		var queued := false
		for candidate: Dictionary in candidates:
			if _jobs.enqueue_production(int(candidate.pile_id), zone.identity_anchor, int(recipe.count), zone.zone_id, str(order.recipe)) != null:
				queued = true
				break
		if not queued:
			waiting_seconds += elapsed


func work(job, worker_id: String, delta: float, item_type: String, count: int) -> Dictionary:
	var zone = _zones.get_zone(job.zone_id)
	if zone == null or not zone.valid or zone.zone_type != ZoneScript.Type.PRODUCTION or zone.setup_state != ZoneScript.SetupState.SET_UP:
		return {"ok": false, "reason": "WORKSHOP_UNAVAILABLE"}
	if not _orders.has(job.zone_id) or job.worker_id != worker_id or job.state != Job.State.RESERVED:
		return {"ok": false, "reason": "STALE_PRODUCTION_JOB"}
	var order: Dictionary = _orders[job.zone_id]
	if str(order.recipe) != job.recipe_id or not RECIPES.has(job.recipe_id):
		return {"ok": false, "reason": "RECIPE_CHANGED"}
	var recipe: Dictionary = RECIPES[job.recipe_id]
	if item_type != recipe.input or count != int(recipe.count) or delta <= 0.0:
		return {"ok": false, "reason": "WRONG_INPUT"}
	order.progress = minf(float(recipe.seconds), float(order.progress) + delta)
	if float(order.progress) < float(recipe.seconds):
		return {"ok": true, "completed": false}
	if _items.add_pile(str(recipe.output), zone.identity_anchor, int(recipe.yield)) < 0:
		return {"ok": true, "completed": false, "reason": "OUTPUT_BLOCKED"}
	order.progress = 0.0
	completed_batches += 1
	_jobs.complete(worker_id, job.job_id)
	produced.emit({"recipe": job.recipe_id, "zone": job.zone_id, "cell": zone.identity_anchor, "item": recipe.output, "amount": recipe.yield})
	return {"ok": true, "completed": true}


func to_save_data() -> Dictionary:
	var orders: Array = []
	for zone_id: int in _orders:
		orders.append({"zone_id": zone_id, "recipe": _orders[zone_id].recipe, "progress": _orders[zone_id].progress, "enabled": _orders[zone_id].enabled})
	return {"orders": orders, "completed_batches": completed_batches, "waiting_seconds": waiting_seconds}


func apply_save_data(data: Dictionary) -> Dictionary:
	var restored: Dictionary = {}
	for entry: Variant in data.get("orders", []):
		if not entry is Dictionary or not RECIPES.has(str(entry.get("recipe", ""))):
			return {"ok": false, "error": "unknown production recipe"}
		var recipe: Dictionary = RECIPES[entry.recipe]
		if float(entry.get("progress", -1)) < 0.0 or float(entry.progress) > float(recipe.seconds):
			return {"ok": false, "error": "invalid production progress"}
		restored[int(entry.zone_id)] = {"recipe": str(entry.recipe), "progress": float(entry.progress), "enabled": bool(entry.get("enabled", true))}
	_orders = restored
	completed_batches = maxi(0, int(data.get("completed_batches", 0)))
	waiting_seconds = maxf(0.0, float(data.get("waiting_seconds", 0.0)))
	return {"ok": true, "error": ""}
