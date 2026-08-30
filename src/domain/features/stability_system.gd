class_name StabilitySystem
extends RefCounted

# Phase 8 local stability model (docs/systems/09_STABILITY_COLLAPSE_SPEC.md).
# Stability is local, legible, and bounded: horizontal roof spans between
# supports warn through escalating bands, then collapse within a configured
# radius. No global load paths are calculated.

signal warning_changed(cell: Vector2i, level: int)
signal critical_warning(cells: Array)
signal region_collapsed(cells: Array, absorbed_water_units: int)
signal danger_cleared()

const WorldGridScript = preload("res://src/domain/world/world_grid.gd")
const CellDataScript = preload("res://src/domain/world/cell_data.gd")

const LEVEL_STABLE := 0
const LEVEL_CRUMBS := 1
const LEVEL_CRACKING := 2
const LEVEL_CRITICAL := 3

const REASON_OK := "OK"
const REASON_OUT_OF_BOUNDS := "OUT_OF_BOUNDS"
const REASON_NOT_OPEN := "NOT_OPEN"
const REASON_EXTERIOR := "EXTERIOR"
const REASON_NO_ROOF := "NO_ROOF"
const REASON_ALREADY_REINFORCED := "ALREADY_REINFORCED"
const REASON_ALREADY_REQUESTED := "ALREADY_REQUESTED"
const REASON_REQUEST_NOT_FOUND := "REQUEST_NOT_FOUND"
const REASON_INSUFFICIENT_MATERIAL := "INSUFFICIENT_MATERIAL"

const SUPPORT_FEATURE_TYPES: Array[String] = ["root_cluster", "rock_mass"]

# Mirrors config/balance/core.json "stability"; balance values override.
const DEFAULT_CONFIG := {
	"span_short": 6,
	"span_moderate": 12,
	"span_high": 24,
	"crumbs_ratio": 0.6,
	"cracking_ratio": 0.85,
	"critical_grace_seconds": 8.0,
	"max_collapse_radius": 3,
	"reinforce_material_per_cell": 1,
	"item_damage_fraction": 0.25,
}

var _world
var _feature_registry
var _dig_system
var _water_system
var _config: Dictionary = {}
var _thresholds: Array[int] = [35, 60, 80]
var _span_by_material := {}
var _crumbs_ratio := 0.6
var _cracking_ratio := 0.85
var _critical_grace_seconds := 8.0
var _max_collapse_radius := 3
var _reinforce_material_required := 1

var _pending_rows: Dictionary = {}
var _deadlines: Dictionary = {}
var _requests: Dictionary = {}
var _next_request_id := 1
var _completed_count := 0
var _critical_cells: Dictionary = {}
var _absorbed_water_units := 0
var _collapsed_cells_total := 0
var _mutating := false


func configure(
	world_grid,
	feature_registry,
	dig_system,
	water_system,
	balance: Dictionary = {},
	instability_thresholds: Array = []
) -> void:
	_disconnect_sources()
	_world = world_grid
	_feature_registry = feature_registry
	_dig_system = dig_system
	_water_system = water_system
	_config = DEFAULT_CONFIG.duplicate()
	_config.merge(balance.get("stability", {}), true)
	_span_by_material = {
		CellDataScript.TerrainMaterial.LOOSE_SOIL: maxi(1, int(_config.get("span_short", 3))),
		CellDataScript.TerrainMaterial.DAMP_CLAY: maxi(1, int(_config.get("span_short", 3))),
		CellDataScript.TerrainMaterial.SOFT_SOIL: maxi(1, int(_config.get("span_moderate", 6))),
		CellDataScript.TerrainMaterial.ROOT_SOIL: maxi(1, int(_config.get("span_moderate", 6))),
		CellDataScript.TerrainMaterial.STONE: maxi(1, int(_config.get("span_high", 12))),
		CellDataScript.TerrainMaterial.FOUNDATION: maxi(1, int(_config.get("span_high", 12))),
	}
	_crumbs_ratio = clampf(float(_config.get("crumbs_ratio", 0.6)), 0.01, 0.99)
	_cracking_ratio = clampf(float(_config.get("cracking_ratio", 0.85)), _crumbs_ratio, 1.0)
	_critical_grace_seconds = maxf(0.0, float(_config.get("critical_grace_seconds", 8.0)))
	_max_collapse_radius = maxi(1, int(_config.get("max_collapse_radius", 3)))
	_reinforce_material_required = maxi(1, int(_config.get("reinforce_material_per_cell", 1)))
	var thresholds := instability_thresholds if instability_thresholds.size() == 3 else [35, 60, 80]
	_thresholds = [int(thresholds[0]), int(thresholds[1]), int(thresholds[2])]
	if _thresholds[0] <= 0 or _thresholds[1] <= _thresholds[0] or _thresholds[2] <= _thresholds[1]:
		_thresholds = [35, 60, 80]
	_pending_rows.clear()
	_deadlines.clear()
	_requests.clear()
	_next_request_id = 1
	_completed_count = 0
	_critical_cells.clear()
	_absorbed_water_units = 0
	_collapsed_cells_total = 0
	if _world != null:
		_world.cell_changed.connect(_on_world_cell_changed)
		_evaluate_row_range(0, _world.height - 1)
	if _dig_system != null:
		_dig_system.cell_excavated.connect(_on_cell_excavated)


func _evaluate_row_range(from_row: int, to_row: int) -> void:
	if _world == null:
		return
	for row: int in range(maxi(0, from_row), mini(_world.height - 1, to_row) + 1):
		_evaluate_row(row)


func fixed_tick(delta_seconds: float) -> Dictionary:
	var result := {
		"rows_evaluated": 0,
		"collapses": 0,
		"cells_filled": 0,
		"critical_cells": _critical_cells.size(),
	}
	if delta_seconds <= 0.0 or _world == null:
		return result
	result.collapses += _advance_deadlines(delta_seconds)
	result.rows_evaluated += _drain_pending_rows(256)
	result.cells_filled = _collapsed_cells_total
	result.critical_cells = _critical_cells.size()
	return result


func request_reinforce(cell: Vector2i) -> Dictionary:
	var reason := inspect_request(cell)
	if reason != REASON_OK:
		return _result(false, reason, -1, cell)
	var request := {
		"request_id": _next_request_id,
		"cell": cell,
		"material_type": "GENERAL_MATERIAL",
		"material_required": _reinforce_material_required,
	}
	_next_request_id += 1
	_requests[cell] = request
	_mark_region_dirty(cell)
	return _result(true, REASON_OK, int(request.request_id), cell)


func inspect_request(cell: Vector2i) -> String:
	if _world == null or not _world.is_in_bounds(cell):
		return REASON_OUT_OF_BOUNDS
	if _world.is_exterior(cell):
		return REASON_EXTERIOR
	if not _world.is_traversable(cell):
		return REASON_NOT_OPEN
	if _world.is_reinforced(cell + Vector2i.UP):
		return REASON_ALREADY_REINFORCED
	if _requests.has(cell):
		return REASON_ALREADY_REQUESTED
	if not _world.is_solid(cell + Vector2i.UP):
		return REASON_NO_ROOF
	return REASON_OK


func complete_reinforcement(cell: Vector2i, delivered_material: int) -> Dictionary:
	var request: Dictionary = _requests.get(cell, {})
	if request.is_empty():
		return _result(false, REASON_REQUEST_NOT_FOUND, -1, cell)
	if delivered_material < int(request.material_required):
		return _result(false, REASON_INSUFFICIENT_MATERIAL, int(request.request_id), cell)
	if inspect_request(cell) == REASON_OUT_OF_BOUNDS or not _world.is_traversable(cell):
		_cancel_internal(cell, REASON_NOT_OPEN)
		return _result(false, REASON_NOT_OPEN, int(request.request_id), cell)
	var roof := cell + Vector2i.UP
	if not _world.is_solid(roof) or _world.is_reinforced(roof):
		_cancel_internal(cell, REASON_NO_ROOF)
		return _result(false, REASON_NO_ROOF, int(request.request_id), cell)
	_mutating = true
	_world.set_reinforced(roof, true)
	_mutating = false
	_requests.erase(cell)
	_completed_count += 1
	_queue_row_range(cell.y - 2, cell.y + 2)
	_mark_region_dirty(cell)
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
	for cell: Vector2i in _requests:
		result.append((_requests[cell] as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.request_id) < int(b.request_id)
	)
	return result


func get_completed_count() -> int:
	return _completed_count


func get_warning_level(cell: Vector2i) -> int:
	if _world == null or not _world.is_in_bounds(cell):
		return LEVEL_STABLE
	var value: int = _world.get_stability_base(cell)
	if value < _thresholds[0]:
		return LEVEL_STABLE
	if value < _thresholds[1]:
		return LEVEL_CRUMBS
	if value < _thresholds[2]:
		return LEVEL_CRACKING
	return LEVEL_CRITICAL


func get_warning_level_name(level: int) -> String:
	match level:
		LEVEL_CRUMBS:
			return "CRUMBS"
		LEVEL_CRACKING:
			return "CRACKING"
		LEVEL_CRITICAL:
			return "CRITICAL"
		_:
			return "STABLE"


func is_job_blocked(cell: Vector2i) -> bool:
	return get_warning_level(cell) == LEVEL_CRITICAL


func is_danger_active() -> bool:
	return not _critical_cells.is_empty()


func is_cell_in_danger_region(cell: Vector2i) -> bool:
	return _critical_cells.has(cell)


func get_danger_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in _critical_cells.keys():
		if value is Vector2i:
			result.append(value as Vector2i)
	return result


func get_absorbed_water_units() -> int:
	return _absorbed_water_units


func get_reinforced_support_bonus(cell: Vector2i) -> int:
	if _world != null and _world.is_in_bounds(cell) and _world.is_reinforced(cell):
		return maxi(1, int(_config.get("span_high", 12)))
	return 0


func get_debug_snapshot() -> Dictionary:
	return {
		"critical_cells": _critical_cells.size(),
		"pending_rows": _pending_rows.size(),
		"reinforce_requests": _requests.size(),
		"reinforce_completed": _completed_count,
		"absorbed_water_units": _absorbed_water_units,
		"collapsed_cells_total": _collapsed_cells_total,
	}


func queue_region(cell: Vector2i) -> void:
	_queue_row_range(cell.y - 2, cell.y + 2)


func _drain_pending_rows(limit: int) -> int:
	var processed := 0
	var keys: Array = _pending_rows.keys()
	keys.sort()
	for row_value: Variant in keys:
		if processed >= limit:
			break
		var row := int(row_value)
		_pending_rows.erase(row_value)
		if row >= 0 and (_world == null or row < _world.height):
			_evaluate_row(row)
		processed += 1
	return processed


func _evaluate_row(row_y: int) -> void:
	var width: int = _world.width
	var desired: Dictionary = {}
	var x := 0
	while x < width:
		if not _is_roof_cell(Vector2i(x, row_y)):
			x += 1
			continue
		var run_start := x
		while x < width and _is_roof_cell(Vector2i(x, row_y)):
			x += 1
		var run_end := x
		var left_grounded := run_start == 0 or _is_grounded_end(Vector2i(run_start - 1, row_y))
		var right_grounded := run_end >= width or _is_grounded_end(Vector2i(run_end, row_y))
		_evaluate_run(row_y, run_start, run_end, left_grounded, right_grounded, desired)
	for open_x: int in range(width):
		var open_cell := Vector2i(open_x, row_y + 1)
		var level := int(desired.get(open_x, LEVEL_STABLE))
		_apply_warning(open_cell, level)


func _is_roof_cell(cell: Vector2i) -> bool:
	if _world.is_exterior(cell) or not _world.is_solid(cell) or _world.is_protected(cell):
		return false
	return _is_open(cell + Vector2i.DOWN)


func _is_grounded_end(cell: Vector2i) -> bool:
	if not _world.is_in_bounds(cell) or _world.is_exterior(cell):
		return true
	if not _world.is_solid(cell):
		return false
	return not _is_open(cell + Vector2i.DOWN)


func _evaluate_run(
	row_y: int,
	run_start: int,
	run_end: int,
	left_grounded: bool,
	right_grounded: bool,
	desired: Dictionary
) -> void:
	var members: Array[int] = []
	for member_x: int in range(run_start, run_end):
		members.append(member_x)
	var supports: Dictionary = {}
	for member_x: int in members:
		if _is_support_member(Vector2i(member_x, row_y)):
			supports[member_x] = true
	var weak: Array[int] = []
	var left_anchored := left_grounded
	for member_x: int in members:
		if supports.has(member_x):
			if not weak.is_empty():
				_rate_segment(row_y, weak, left_anchored, true, desired)
				weak = []
			left_anchored = true
		else:
			weak.append(member_x)
	if not weak.is_empty():
		_rate_segment(row_y, weak, left_anchored, right_grounded, desired)


func _rate_segment(row_y: int, members: Array[int], left_anchor: bool, right_anchor: bool, desired: Dictionary) -> void:
	var allowed := _allowed_span(members, row_y)
	var effective_length := float(members.size())
	if not left_anchor:
		effective_length += 0.5
	if not right_anchor:
		effective_length += 0.5
	var ratio := effective_length / float(maxi(1, allowed))
	var level := LEVEL_STABLE
	if ratio >= 1.0:
		level = LEVEL_CRITICAL
	elif ratio >= _cracking_ratio:
		level = LEVEL_CRACKING
	elif ratio >= _crumbs_ratio:
		level = LEVEL_CRUMBS
	for member_x: Variant in members:
		var open_cell := Vector2i(int(member_x), row_y + 1)
		desired[open_cell.x] = maxi(int(desired.get(open_cell.x, LEVEL_STABLE)), level)


func _allowed_span(members: Array[int], row_y: int) -> int:
	var weakest := maxi(1, int(_config.get("span_high", 12)))
	for member_x: Variant in members:
		var cell := Vector2i(int(member_x), row_y)
		var material: int = _world.get_material(cell)
		var span: int = int(_span_by_material.get(material, maxi(1, int(_config.get("span_moderate", 6)))))
		weakest = mini(weakest, span)
	return weakest


func _apply_warning(open_cell: Vector2i, level: int) -> void:
	if not _is_open(open_cell):
		level = LEVEL_STABLE
	var value := 0
	match level:
		LEVEL_CRUMBS:
			value = _thresholds[0]
		LEVEL_CRACKING:
			value = _thresholds[1]
		LEVEL_CRITICAL:
			value = _thresholds[2] + 5
	var previous_level := get_warning_level(open_cell)
	if previous_level == level and not (level == LEVEL_CRITICAL and not _deadlines.has(open_cell)):
		return
	_mutating = true
	_world.set_stability_base(open_cell, value)
	_mutating = false
	warning_changed.emit(open_cell, level)
	if level == LEVEL_CRITICAL:
		if not _deadlines.has(open_cell):
			_deadlines[open_cell] = _critical_grace_seconds
		if not _critical_cells.has(open_cell):
			var newly_critical: Array[Vector2i] = [open_cell]
			_critical_cells[open_cell] = true
			critical_warning.emit(newly_critical)
	else:
		_deadlines.erase(open_cell)
		_note_critical_removed(open_cell)


func _note_critical_removed(cell: Vector2i) -> void:
	if _critical_cells.erase(cell) and _critical_cells.is_empty():
		danger_cleared.emit()


func _advance_deadlines(delta_seconds: float) -> int:
	var expired: Array[Vector2i] = []
	for cell_value: Variant in _deadlines.keys():
		if not cell_value is Vector2i:
			continue
		var remaining: float = float(_deadlines[cell_value]) - delta_seconds
		if remaining <= 0.0:
			expired.append(cell_value as Vector2i)
		else:
			_deadlines[cell_value] = remaining
	if expired.is_empty():
		return 0
	expired.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	var groups := _group_adjacent(expired)
	for group: Array[Vector2i] in groups:
		_perform_collapse(group)
	return groups.size()


func _group_adjacent(cells: Array[Vector2i]) -> Array[Array]:
	var remaining: Dictionary = {}
	for cell: Vector2i in cells:
		remaining[cell] = true
	var groups: Array[Array] = []
	while not remaining.is_empty():
		var seed_cell: Vector2i = remaining.keys()[0]
		remaining.erase(seed_cell)
		var group: Array[Vector2i] = [seed_cell]
		var queue: Array[Vector2i] = [seed_cell]
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				var neighbor: Vector2i = current + offset
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					group.append(neighbor)
					queue.append(neighbor)
		group.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)
		groups.append(group)
	return groups


func _perform_collapse(expired_seeds: Array[Vector2i]) -> void:
	var cluster: Dictionary = {}
	for seed_cell: Vector2i in expired_seeds:
		if _is_open(seed_cell):
			cluster[seed_cell] = true
	var frontier: Array[Vector2i] = expired_seeds.duplicate()
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for neighbor: Vector2i in _world.get_cardinal_neighbors(current):
			if cluster.has(neighbor) or not _is_open(neighbor):
				continue
			# Collapse stops where supported ground begins: stone, seals,
			# reinforcement, roots and protected cells arrest the debris field.
			var ceiling := neighbor + Vector2i.UP
			if _world.is_in_bounds(ceiling) and _world.is_solid(ceiling) and _is_support_member(ceiling):
				continue
			if not _within_collapse_radius(neighbor, expired_seeds):
				continue
			cluster[neighbor] = true
			frontier.append(neighbor)
	var filled: Array[Vector2i] = []
	var cells: Array = cluster.keys()
	cells.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_cell: Vector2i = a
		var b_cell: Vector2i = b
		return a_cell.y < b_cell.y or (a_cell.y == b_cell.y and a_cell.x < b_cell.x)
	)
	for cell_value: Variant in cells:
		var cell: Vector2i = cell_value
		_displace_water_before_fill(cell, cluster)
		_cancel_internal(cell, "COLLAPSED")
		if _world.set_excavated(cell, false):
			_deadlines.erase(cell)
			_note_critical_removed(cell)
			_world.set_stability_base(cell, 0)
			_world.set_rubble(cell, true)
			filled.append(cell)
	_collapsed_cells_total += filled.size()
	if not filled.is_empty():
		_queue_row_range(filled[0].y - 3, filled[-1].y + 3)
		region_collapsed.emit(filled, 0)


func _within_collapse_radius(candidate: Vector2i, seeds: Array[Vector2i]) -> bool:
	for seed_cell: Vector2i in seeds:
		var dx := absi(candidate.x - seed_cell.x)
		var dy := absi(candidate.y - seed_cell.y)
		if maxi(dx, dy) <= _max_collapse_radius:
			return true
	return false


func _displace_water_before_fill(cell: Vector2i, cluster: Dictionary) -> void:
	var units: int = _world.get_water_units(cell)
	if units <= 0:
		return
	var capacity := 4 if _water_system == null else maxi(1, int(_water_system.get_cell_capacity()))
	var candidates: Array[Vector2i] = []
	for neighbor: Vector2i in _world.get_cardinal_neighbors(cell):
		if cluster.has(neighbor) or not _is_open(neighbor):
			continue
		if _world.get_water_units(neighbor) >= capacity:
			continue
		candidates.append(neighbor)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _world.cell_to_index(a) < _world.cell_to_index(b)
	)
	var remaining := units
	for target: Vector2i in candidates:
		var current: int = _world.get_water_units(target)
		var amount := mini(remaining, capacity - current)
		_world.set_water_units(target, current + amount)
		if _water_system != null:
			_water_system.wake_region(target)
		remaining -= amount
		if remaining <= 0:
			break
	_absorbed_water_units += remaining
	_world.set_water_units(cell, 0)


func _cancel_internal(cell: Vector2i, reason_code: String) -> void:
	var request: Dictionary = _requests.get(cell, {})
	if request.is_empty():
		return
	_requests.erase(cell)
	_mark_region_dirty(cell)


func _is_open(cell: Vector2i) -> bool:
	return _world.is_in_bounds(cell) and _world.is_traversable(cell)


func _is_support_member(cell: Vector2i) -> bool:
	if _world.is_reinforced(cell) or _world.is_sealed(cell):
		return true
	var material: int = _world.get_material(cell)
	if material in [CellDataScript.TerrainMaterial.STONE, CellDataScript.TerrainMaterial.FOUNDATION]:
		return true
	var feature_id: int = _world.get_feature_id(cell)
	if feature_id >= 0 and _feature_registry != null:
		var feature = _feature_registry.get_feature(feature_id)
		if feature != null and String(feature.type_id) in SUPPORT_FEATURE_TYPES:
			return true
	return false


func _queue_row_range(from_row: int, to_row: int) -> void:
	if _world == null:
		return
	for row: int in range(maxi(0, from_row), mini(_world.height - 1, to_row) + 1):
		_pending_rows[row] = true


func _mark_region_dirty(cell: Vector2i) -> void:
	if _world == null:
		return
	_world.mark_region_dirty(Rect2i(cell - Vector2i(1, 2), Vector2i(3, 4)), WorldGridScript.CHANGE_TERRAIN)


func _on_world_cell_changed(cell: Vector2i, change_flags: int) -> void:
	if _mutating:
		return
	if (change_flags & (WorldGridScript.CHANGE_TERRAIN | WorldGridScript.CHANGE_STABILITY)) != 0:
		_queue_row_range(cell.y - 2, cell.y + 2)


func _on_cell_excavated(cell: Vector2i) -> void:
	_queue_row_range(cell.y - 3, cell.y + 3)


func _disconnect_sources() -> void:
	if _world != null and _world.cell_changed.is_connected(_on_world_cell_changed):
		_world.cell_changed.disconnect(_on_world_cell_changed)
	if _dig_system != null and _dig_system.cell_excavated.is_connected(_on_cell_excavated):
		_dig_system.cell_excavated.disconnect(_on_cell_excavated)


func _result(ok: bool, reason_code: String, request_id: int, cell: Vector2i) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"request_id": request_id,
		"cell": cell,
	}


## Phase 10 persistence (docs/tech/15 spec 09 §12): warning deadlines, pending
## reinforcement requests, and counters. Rubble/support flags live in the grid.
func to_save_data() -> Dictionary:
	var deadlines: Array = []
	for cell: Vector2i in _deadlines.keys():
		deadlines.append([cell.x, cell.y, snappedf(float(_deadlines[cell]), 0.01)])
	var requests: Array = []
	for cell: Vector2i in _requests.keys():
		var request: Dictionary = _requests[cell]
		requests.append({
			"request_id": int(request.request_id),
			"cell": [cell.x, cell.y],
			"material_required": int(request.material_required),
		})
	var critical: Array = []
	for cell: Vector2i in _critical_cells.keys():
		critical.append([cell.x, cell.y])
	var pending_rows: Array = []
	for row: Variant in _pending_rows.keys():
		pending_rows.append(int(row))
	return {
		"deadlines": deadlines,
		"requests": requests,
		"next_request_id": _next_request_id,
		"completed_count": _completed_count,
		"critical_cells": critical,
		"pending_rows": pending_rows,
		"collapsed_cells_total": _collapsed_cells_total,
		"absorbed_water_units": _absorbed_water_units,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	_deadlines.clear()
	for entry: Variant in data.get("deadlines", []):
		if entry is not Array or entry.size() != 3:
			return {"ok": false, "error": "malformed stability deadline"}
		_deadlines[Vector2i(int(entry[0]), int(entry[1]))] = float(entry[2])
	_requests.clear()
	for entry: Variant in data.get("requests", []):
		if entry is not Dictionary:
			return {"ok": false, "error": "malformed stability request"}
		var cell_entry: Array = entry.cell
		if cell_entry.size() != 2:
			return {"ok": false, "error": "malformed stability request cell"}
		var cell := Vector2i(int(cell_entry[0]), int(cell_entry[1]))
		_requests[cell] = {
			"request_id": int(entry.request_id),
			"cell": cell,
			"material_type": "GENERAL_MATERIAL",
			"material_required": int(entry.material_required),
		}
		_next_request_id = maxi(_next_request_id, int(entry.request_id) + 1)
	_critical_cells.clear()
	for entry: Variant in data.get("critical_cells", []):
		if entry is not Array or entry.size() != 2:
			return {"ok": false, "error": "malformed stability critical cell"}
		_critical_cells[Vector2i(int(entry[0]), int(entry[1]))] = true
	_pending_rows.clear()
	for row: Variant in data.get("pending_rows", []):
		_pending_rows[int(row)] = true
	_next_request_id = maxi(1, int(data.get("next_request_id", 1)))
	_completed_count = int(data.get("completed_count", 0))
	_collapsed_cells_total = int(data.get("collapsed_cells_total", 0))
	_absorbed_water_units = int(data.get("absorbed_water_units", 0))
	return {"ok": true, "error": ""}
