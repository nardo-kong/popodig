class_name ZoneSystem
extends RefCounted

signal zones_changed(change: Dictionary)
signal zone_validity_changed(zone_id: int, valid: bool, reasons: PackedStringArray)
signal setup_state_changed(zone_id: int, setup_state: int)

const WorldGridScript = preload("res://src/domain/world/world_grid.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")

const REASON_OK := "OK"
const REASON_EMPTY_SELECTION := "EMPTY_SELECTION"
const REASON_INVALID_ZONE_TYPE := "INVALID_ZONE_TYPE"
const REASON_OUT_OF_BOUNDS := "OUT_OF_BOUNDS"
const REASON_NOT_EXCAVATED := "NOT_EXCAVATED"
const REASON_NOT_CONNECTED := "NOT_CONNECTED"
const REASON_WET := "WET"
const REASON_FLOODED := "FLOODED"
const REASON_ALREADY_ASSIGNED := "ALREADY_ASSIGNED"
const REASON_NOT_ASSIGNED := "NOT_ASSIGNED"
const REASON_ZONE_NOT_FOUND := "ZONE_NOT_FOUND"
const REASON_WRONG_ZONE_TYPE := "WRONG_ZONE_TYPE"
const REASON_CELL_NOT_IN_ZONE := "CELL_NOT_IN_ZONE"
const REASON_ZONE_INVALID := "ZONE_INVALID"
const REASON_ALREADY_SET_UP := "ALREADY_SET_UP"
const REASON_SETUP_NOT_STARTED := "SETUP_NOT_STARTED"
const REASON_INVALID_AMOUNT := "INVALID_AMOUNT"

var _world
var _path_service
var _zones: Dictionary = {}
var _cell_types: Dictionary = {}
var _zone_by_cell: Dictionary = {}
var _next_zone_id := 1
var _setup_material_per_zone := 1
var _dry_water_max_units := 0
var _max_walkable_water_units := 1
var _world_seed := 0
var _invalidated_storage_requests: Array[Dictionary] = []
var _invalidated_storage_keys: Dictionary = {}
var _colony_distances := PackedInt32Array()
var _colony_distance_revision := -1
var _colony_distance_anchor := Vector2i(-1, -1)
var _pending_refresh_all := false
var _pending_invalidated_cells: Dictionary = {}
var _refresh_batch_count := 0


func configure(world_grid, path_service, balance: Dictionary = {}) -> void:
	if _world != null and _world.cell_changed.is_connected(_on_world_cell_changed):
		_world.cell_changed.disconnect(_on_world_cell_changed)
	_world = world_grid
	_path_service = path_service
	var zones_balance: Dictionary = balance.get("zones", {})
	_setup_material_per_zone = maxi(1, int(zones_balance.get("setup_material_per_zone", 1)))
	_dry_water_max_units = maxi(0, int(zones_balance.get("dry_water_max_units", 0)))
	var pathfinding_balance: Dictionary = balance.get("pathfinding", {})
	_max_walkable_water_units = maxi(
		_dry_water_max_units,
		int(pathfinding_balance.get("max_walkable_water_units", 1))
	)
	_world_seed = int(_world.metadata.get("seed", 0)) if _world != null else 0
	_zones.clear()
	_cell_types.clear()
	_zone_by_cell.clear()
	_next_zone_id = 1
	_invalidated_storage_requests.clear()
	_invalidated_storage_keys.clear()
	_colony_distances.clear()
	_colony_distance_revision = -1
	_colony_distance_anchor = Vector2i(-1, -1)
	_pending_refresh_all = false
	_pending_invalidated_cells.clear()
	_refresh_batch_count = 0
	if _world != null:
		_world.cell_changed.connect(_on_world_cell_changed)


func inspect_cell(zone_type: int, cell: Vector2i) -> Dictionary:
	if not _is_valid_type(zone_type):
		return _inspection(false, REASON_INVALID_ZONE_TYPE, cell)
	if _world == null or not _world.is_in_bounds(cell):
		return _inspection(false, REASON_OUT_OF_BOUNDS, cell)
	if not _world.is_excavated(cell):
		return _inspection(false, REASON_NOT_EXCAVATED, cell)
	var water_units: int = _world.get_water_units(cell)
	if water_units > _max_walkable_water_units:
		return _inspection(false, REASON_FLOODED, cell)
	if zone_type == ZoneScript.Type.STORAGE and water_units > _dry_water_max_units:
		return _inspection(false, REASON_WET, cell)
	if not _is_colony_reachable(cell):
		return _inspection(false, REASON_NOT_CONNECTED, cell)
	if int(_cell_types.get(cell, -1)) == zone_type:
		return _inspection(false, REASON_ALREADY_ASSIGNED, cell)
	return _inspection(true, REASON_OK, cell)


func paint_zone(zone_type: int, cell_values: Array) -> Dictionary:
	if not _is_valid_type(zone_type):
		return _change_result(false, REASON_INVALID_ZONE_TYPE)
	if not _contains_only_cells(cell_values):
		return _change_result(false, REASON_OUT_OF_BOUNDS)
	var cells := _normalize_cells(cell_values)
	if cells.is_empty():
		return _change_result(false, REASON_EMPTY_SELECTION)
	for cell: Vector2i in cells:
		var inspection := inspect_cell(zone_type, cell)
		if not inspection.ok and inspection.reason_code != REASON_ALREADY_ASSIGNED:
			var rejected: Array[Dictionary] = [{"cell": cell, "reason_code": inspection.reason_code}]
			return _change_result(false, inspection.reason_code, [], [], [], [], rejected)
	var changed: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if int(_cell_types.get(cell, -1)) == zone_type:
			continue
		_cell_types[cell] = zone_type
		changed.append(cell)
	if changed.is_empty():
		return _change_result(false, REASON_ALREADY_ASSIGNED)
	return _rebuild_after_change(changed, REASON_OK)


func reassign_cells(zone_type: int, cell_values: Array) -> Dictionary:
	return paint_zone(zone_type, cell_values)


func erase_cells(cell_values: Array) -> Dictionary:
	if not _contains_only_cells(cell_values):
		return _change_result(false, REASON_OUT_OF_BOUNDS)
	var cells := _normalize_cells(cell_values)
	if cells.is_empty():
		return _change_result(false, REASON_EMPTY_SELECTION)
	var changed: Array[Vector2i] = []
	var rejected: Array[Dictionary] = []
	for cell: Vector2i in cells:
		if not _cell_types.has(cell):
			rejected.append({"cell": cell, "reason_code": REASON_NOT_ASSIGNED})
			continue
		_cell_types.erase(cell)
		changed.append(cell)
	if changed.is_empty():
		return _change_result(false, REASON_NOT_ASSIGNED, [], [], [], [], rejected)
	var result := _rebuild_after_change(changed, REASON_OK)
	result.rejected = rejected
	return result


func get_zone(zone_id: int):
	return _zones.get(zone_id)


func get_zone_at(cell: Vector2i):
	var zone_id := int(_zone_by_cell.get(cell, -1))
	return null if zone_id < 0 else _zones.get(zone_id)


func get_zones() -> Array[Zone]:
	var result: Array[Zone] = []
	for zone: Zone in _zones.values():
		result.append(zone.snapshot())
	result.sort_custom(func(a: Zone, b: Zone) -> bool:
		return a.zone_id < b.zone_id
	)
	return result


func get_zones_by_type(zone_type: int, valid_only: bool = false) -> Array[Zone]:
	var result: Array[Zone] = []
	for zone: Zone in _zones.values():
		if zone.zone_type == zone_type and (zone.valid or not valid_only):
			result.append(zone.snapshot())
	result.sort_custom(func(a: Zone, b: Zone) -> bool:
		return a.zone_id < b.zone_id
	)
	return result


func find_best_usable_cell(zone_type: int, origin: Vector2i, require_setup: bool = true) -> Vector2i:
	if not _is_valid_type(zone_type) or _path_service == null:
		return Vector2i(-1, -1)
	var distances: PackedInt32Array = _path_service.build_distance_field(origin)
	var best := Vector2i(-1, -1)
	var best_distance := 2147483647
	var best_suitability := -1.0
	for zone: Zone in _zones.values():
		if zone.zone_type != zone_type or not zone.valid:
			continue
		if require_setup and zone.setup_state != ZoneScript.SetupState.SET_UP:
			continue
		for cell: Vector2i in zone.cells:
			var cell_index: int = _world.cell_to_index(cell)
			var distance: int = -1 if cell_index < 0 or cell_index >= distances.size() else distances[cell_index]
			if distance < 0:
				continue
			if (
				zone.suitability > best_suitability + 0.0001
				or (is_equal_approx(zone.suitability, best_suitability) and (
					distance < best_distance
					or (distance == best_distance and (best.x < 0 or cell.y < best.y or (cell.y == best.y and cell.x < best.x)))
				))
			):
				best = cell
				best_distance = distance
				best_suitability = zone.suitability
	return best


func reserve_best_usable_cell(
	zone_type: int,
	occupant_id: String,
	origin: Vector2i,
	capacity_per_cell: int = 1
) -> Dictionary:
	if occupant_id.is_empty() or capacity_per_cell <= 0 or not _is_valid_type(zone_type):
		return {"ok": false, "reason_code": "INVALID_OCCUPANCY", "zone_id": -1, "cell": Vector2i(-1, -1)}
	release_occupant(occupant_id)
	var distances: PackedInt32Array = _path_service.build_distance_field(origin)
	var best_zone: Zone = null
	var best := Vector2i(-1, -1)
	var best_distance := 2147483647
	var best_suitability := -1.0
	for zone: Zone in _zones.values():
		if zone.zone_type != zone_type or not zone.valid or zone.setup_state != ZoneScript.SetupState.SET_UP:
			continue
		for cell: Vector2i in zone.cells:
			var occupancy := 0
			for occupied_cell: Variant in zone.occupant_refs.values():
				if occupied_cell == cell:
					occupancy += 1
			if occupancy >= capacity_per_cell:
				continue
			var index: int = _world.cell_to_index(cell)
			var distance: int = -1 if index < 0 or index >= distances.size() else distances[index]
			if distance < 0:
				continue
			if (
				zone.suitability > best_suitability + 0.0001
				or (is_equal_approx(zone.suitability, best_suitability) and (
					distance < best_distance
					or (distance == best_distance and (best.x < 0 or cell.y < best.y or (cell.y == best.y and cell.x < best.x)))
				))
			):
				best_zone = zone
				best = cell
				best_distance = distance
				best_suitability = zone.suitability
	if best_zone == null:
		return {"ok": false, "reason_code": "NO_USABLE_ZONE_CELL", "zone_id": -1, "cell": Vector2i(-1, -1)}
	best_zone.occupant_refs[occupant_id] = best
	return {"ok": true, "reason_code": REASON_OK, "zone_id": best_zone.zone_id, "cell": best}


func release_occupant(occupant_id: String) -> bool:
	var released := false
	for zone: Zone in _zones.values():
		released = zone.occupant_refs.erase(occupant_id) or released
	return released


func refresh_zone(zone_id: int) -> bool:
	var zone: Zone = _zones.get(zone_id)
	if zone == null:
		return false
	var was_valid := zone.valid
	_evaluate_zone(zone)
	if was_valid != zone.valid:
		zone_validity_changed.emit(zone.zone_id, zone.valid, zone.invalid_reasons)
		if zone.zone_type == ZoneScript.Type.STORAGE and not zone.valid:
			_queue_all_storage_refs(zone, "STORAGE_INVALIDATED")
	return true


func refresh_all() -> void:
	for zone: Zone in _zones.values():
		refresh_zone(zone.zone_id)


func flush_world_changes() -> void:
	if not _pending_refresh_all and _pending_invalidated_cells.is_empty():
		return
	var invalidated: Array[Vector2i] = []
	for cell: Vector2i in _pending_invalidated_cells:
		if _cell_types.has(cell) and not _world.is_excavated(cell):
			_cell_types.erase(cell)
			invalidated.append(cell)
	_pending_invalidated_cells.clear()
	_pending_refresh_all = false
	_refresh_batch_count += 1
	if not invalidated.is_empty():
		_sort_cells(invalidated)
		_rebuild_after_change(invalidated, "WORLD_INVALIDATED_CELL")
	else:
		refresh_all()


func get_debug_refresh_batch_count() -> int:
	return _refresh_batch_count


func get_setup_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone: Zone in _zones.values():
		if not zone.valid or zone.setup_state == ZoneScript.SetupState.SET_UP:
			continue
		result.append(_setup_request(zone))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.zone_id) < int(b.zone_id)
	)
	return result


func begin_setup(zone_id: int) -> Dictionary:
	var zone: Zone = _zones.get(zone_id)
	if zone == null:
		return _setup_result(false, REASON_ZONE_NOT_FOUND, zone_id)
	if not zone.valid:
		return _setup_result(false, REASON_ZONE_INVALID, zone_id)
	if zone.setup_state == ZoneScript.SetupState.SET_UP:
		return _setup_result(false, REASON_ALREADY_SET_UP, zone_id)
	zone.setup_state = ZoneScript.SetupState.IN_PROGRESS
	setup_state_changed.emit(zone_id, zone.setup_state)
	return _setup_result(true, REASON_OK, zone_id)


func apply_setup_material(zone_id: int, amount: int) -> Dictionary:
	var zone: Zone = _zones.get(zone_id)
	if zone == null:
		return _setup_result(false, REASON_ZONE_NOT_FOUND, zone_id)
	if amount <= 0:
		return _setup_result(false, REASON_INVALID_AMOUNT, zone_id)
	if zone.setup_state != ZoneScript.SetupState.IN_PROGRESS:
		return _setup_result(false, REASON_SETUP_NOT_STARTED, zone_id)
	zone.setup_material_delivered = mini(
		zone.setup_material_required,
		zone.setup_material_delivered + amount
	)
	if zone.setup_material_delivered >= zone.setup_material_required:
		zone.setup_state = ZoneScript.SetupState.SET_UP
		zone.dressing_revision += 1
		_rebuild_dressing_anchors(zone)
		setup_state_changed.emit(zone_id, zone.setup_state)
	var result := _setup_result(true, REASON_OK, zone_id)
	result["completed"] = zone.setup_state == ZoneScript.SetupState.SET_UP
	result["material_delivered"] = zone.setup_material_delivered
	result["material_remaining"] = maxi(0, zone.setup_material_required - zone.setup_material_delivered)
	return result


func get_dressing_contract(zone_id: int) -> Dictionary:
	var zone: Zone = _zones.get(zone_id)
	if zone == null:
		return {"ok": false, "reason_code": REASON_ZONE_NOT_FOUND, "zone_id": zone_id}
	return {
		"ok": true,
		"reason_code": REASON_OK,
		"zone_id": zone.zone_id,
		"zone_type": zone.zone_type,
		"family": zone.get_dressing_family(),
		"seed": zone.dressing_seed,
		"revision": zone.dressing_revision,
		"anchors": zone.dressing_anchors.duplicate(),
		"ready": zone.valid and zone.setup_state == ZoneScript.SetupState.SET_UP,
		"engineering_placeholder": true,
	}


func register_occupant(zone_id: int, occupant_id: String, cell: Vector2i) -> bool:
	var zone: Zone = _zones.get(zone_id)
	if zone == null or occupant_id.is_empty() or not zone.cells.has(cell):
		return false
	zone.occupant_refs[occupant_id] = cell
	return true


func unregister_occupant(zone_id: int, occupant_id: String) -> bool:
	var zone: Zone = _zones.get(zone_id)
	return false if zone == null else zone.occupant_refs.erase(occupant_id)


func register_storage_pile(zone_id: int, pile_id: int, cell: Vector2i) -> bool:
	var zone: Zone = _zones.get(zone_id)
	if zone == null or zone.zone_type != ZoneScript.Type.STORAGE or pile_id < 0 or not zone.cells.has(cell):
		return false
	zone.storage_refs[pile_id] = cell
	if not zone.valid:
		_queue_invalidated_storage(pile_id, zone_id, cell, "STORAGE_INVALIDATED")
	return true


func unregister_storage_pile(zone_id: int, pile_id: int) -> bool:
	var zone: Zone = _zones.get(zone_id)
	if zone == null:
		return false
	_invalidated_storage_keys.erase(_storage_request_key(pile_id))
	return zone.storage_refs.erase(pile_id)


func consume_invalidated_storage_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = _invalidated_storage_requests.duplicate(true)
	_invalidated_storage_requests.clear()
	_invalidated_storage_keys.clear()
	return result


func _rebuild_after_change(changed: Array[Vector2i], reason: String) -> Dictionary:
	var previous_zones: Dictionary = _zones.duplicate()
	var previous_ids: Array[int] = []
	var affected_before: Dictionary = {}
	for zone: Zone in previous_zones.values():
		previous_ids.append(zone.zone_id)
	for cell: Vector2i in changed:
		var previous_id := int(_zone_by_cell.get(cell, -1))
		if previous_id >= 0:
			affected_before[previous_id] = true
	_rebuild_components(previous_zones)
	var created: Array[int] = []
	var removed: Array[int] = []
	for zone_id: int in _zones:
		if not previous_zones.has(zone_id):
			created.append(zone_id)
	for zone_id: int in previous_ids:
		if not _zones.has(zone_id):
			removed.append(zone_id)
	var affected: Dictionary = affected_before
	for cell: Vector2i in changed:
		var zone_id := int(_zone_by_cell.get(cell, -1))
		if zone_id >= 0:
			affected[zone_id] = true
	var affected_ids: Array[int] = []
	for zone_id: int in affected:
		affected_ids.append(zone_id)
	affected_ids.sort()
	created.sort()
	removed.sort()
	var result := _change_result(true, reason, changed, affected_ids, created, removed)
	zones_changed.emit(result)
	return result


func _rebuild_components(previous_zones: Dictionary) -> void:
	var old_zone_by_cell := _zone_by_cell.duplicate()
	var old_storage: Array[Dictionary] = []
	var old_occupants: Array[Dictionary] = []
	for old_zone: Zone in previous_zones.values():
		for pile_id: Variant in old_zone.storage_refs:
			old_storage.append({"pile_id": int(pile_id), "cell": old_zone.storage_refs[pile_id], "from_zone_id": old_zone.zone_id})
		for occupant_id: Variant in old_zone.occupant_refs:
			old_occupants.append({"occupant_id": String(occupant_id), "cell": old_zone.occupant_refs[occupant_id]})
	var components := _build_components()
	var assignments: Dictionary = {}
	var used_old_ids: Dictionary = {}
	for component_index: int in range(components.size()):
		var component: Dictionary = components[component_index]
		var anchor_candidates: Array[int] = []
		for old_zone: Zone in previous_zones.values():
			if old_zone.zone_type == component.type and component.cell_set.has(old_zone.identity_anchor):
				anchor_candidates.append(old_zone.zone_id)
		anchor_candidates.sort()
		for candidate_id: int in anchor_candidates:
			if not used_old_ids.has(candidate_id):
				assignments[component_index] = candidate_id
				used_old_ids[candidate_id] = true
				break
	for component_index: int in range(components.size()):
		if assignments.has(component_index):
			continue
		var component: Dictionary = components[component_index]
		var best_id := -1
		var best_overlap := 0
		for old_zone: Zone in previous_zones.values():
			if old_zone.zone_type != component.type or used_old_ids.has(old_zone.zone_id):
				continue
			var overlap := 0
			for cell: Vector2i in component.cells:
				if int(old_zone_by_cell.get(cell, -1)) == old_zone.zone_id:
					overlap += 1
			if overlap > best_overlap or (overlap == best_overlap and overlap > 0 and old_zone.zone_id < best_id):
				best_id = old_zone.zone_id
				best_overlap = overlap
		if best_id >= 0:
			assignments[component_index] = best_id
			used_old_ids[best_id] = true
	var rebuilt: Dictionary = {}
	_zone_by_cell.clear()
	for component_index: int in range(components.size()):
		var component: Dictionary = components[component_index]
		var zone_id := int(assignments.get(component_index, -1))
		var previous: Zone = null
		if zone_id >= 0:
			previous = previous_zones.get(zone_id)
		else:
			zone_id = _next_zone_id
			_next_zone_id += 1
		var zone := ZoneScript.new(zone_id, int(component.type))
		if previous != null:
			_copy_persistent_state(previous, zone)
		else:
			zone.setup_material_required = _setup_material_per_zone
			zone.dressing_seed = _make_dressing_seed(zone_id, zone.zone_type)
		zone.cells.assign(component.cells)
		if previous == null or not zone.cells.has(zone.identity_anchor):
			zone.identity_anchor = zone.cells[0]
		var geometry_changed := previous == null or previous.cells != zone.cells
		if geometry_changed:
			zone.dressing_revision += 1
		zone.occupant_refs.clear()
		zone.storage_refs.clear()
		_evaluate_zone(zone)
		_rebuild_dressing_anchors(zone)
		rebuilt[zone_id] = zone
		for cell: Vector2i in zone.cells:
			_zone_by_cell[cell] = zone_id
	_zones = rebuilt
	for reference: Dictionary in old_storage:
		var cell: Vector2i = reference.cell
		var zone: Zone = get_zone_at(cell)
		if zone != null and zone.zone_type == ZoneScript.Type.STORAGE:
			zone.storage_refs[int(reference.pile_id)] = cell
			if not zone.valid:
				_queue_invalidated_storage(int(reference.pile_id), zone.zone_id, cell, "STORAGE_INVALIDATED")
		else:
			_queue_invalidated_storage(int(reference.pile_id), int(reference.from_zone_id), cell, "ZONE_REMOVED_OR_REASSIGNED")
	for reference: Dictionary in old_occupants:
		var zone: Zone = get_zone_at(reference.cell)
		if zone != null:
			zone.occupant_refs[String(reference.occupant_id)] = reference.cell
	_sync_world_zone_ids(old_zone_by_cell)


func _build_components() -> Array[Dictionary]:
	var remaining := _cell_types.duplicate()
	var components: Array[Dictionary] = []
	while not remaining.is_empty():
		var starts: Array[Vector2i] = []
		for cell: Vector2i in remaining:
			starts.append(cell)
		_sort_cells(starts)
		var start: Vector2i = starts[0]
		var zone_type := int(remaining[start])
		var cells: Array[Vector2i] = []
		var cell_set: Dictionary = {}
		var queue: Array[Vector2i] = [start]
		remaining.erase(start)
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			cells.append(current)
			cell_set[current] = true
			for neighbor: Vector2i in _world.get_cardinal_neighbors(current):
				if remaining.has(neighbor) and int(remaining[neighbor]) == zone_type:
					remaining.erase(neighbor)
					queue.append(neighbor)
		_sort_cells(cells)
		components.append({"type": zone_type, "cells": cells, "cell_set": cell_set, "anchor": cells[0]})
	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.type) != int(b.type):
			return int(a.type) < int(b.type)
		var a_anchor: Vector2i = a.anchor
		var b_anchor: Vector2i = b.anchor
		return a_anchor.y < b_anchor.y or (a_anchor.y == b_anchor.y and a_anchor.x < b_anchor.x)
	)
	return components


func _evaluate_zone(zone: Zone) -> void:
	zone.invalid_reasons.clear()
	zone.suitability_warnings.clear()
	var shallow_water_cells := 0
	var reachable_cells := 0
	for cell: Vector2i in zone.cells:
		if not _world.is_excavated(cell):
			_append_unique(zone.invalid_reasons, REASON_NOT_EXCAVATED)
		var water_units: int = _world.get_water_units(cell)
		if water_units > _max_walkable_water_units:
			_append_unique(zone.invalid_reasons, REASON_FLOODED)
		elif water_units > _dry_water_max_units:
			shallow_water_cells += 1
			if zone.zone_type == ZoneScript.Type.STORAGE:
				_append_unique(zone.invalid_reasons, REASON_WET)
		if _is_colony_reachable(cell):
			reachable_cells += 1
	if reachable_cells != zone.cells.size():
		_append_unique(zone.invalid_reasons, REASON_NOT_CONNECTED)
	zone.connected_to_colony = reachable_cells == zone.cells.size() and not zone.cells.is_empty()
	zone.valid = not zone.cells.is_empty() and zone.invalid_reasons.is_empty()
	var wet_ratio := float(shallow_water_cells) / maxi(1, zone.cells.size())
	match zone.zone_type:
		ZoneScript.Type.SLEEPING:
			zone.suitability = clampf(1.0 - wet_ratio * 0.35, 0.0, 1.0)
			if shallow_water_cells > 0:
				zone.suitability_warnings.append("DAMP_SLEEPING")
		ZoneScript.Type.STORAGE:
			zone.suitability = clampf(1.0 - wet_ratio * 0.6, 0.0, 1.0)
			if shallow_water_cells > 0:
				zone.suitability_warnings.append("DAMP_STORAGE")
		ZoneScript.Type.FOOD_FORAGE:
			zone.suitability = clampf(1.0 - wet_ratio * 0.05, 0.0, 1.0)
	if not zone.valid:
		zone.suitability = 0.0


func _rebuild_dressing_anchors(zone: Zone) -> void:
	zone.dressing_anchors.clear()
	if zone.cells.is_empty():
		return
	var stride := maxi(1, zone.cells.size() / 3)
	var offset := zone.dressing_seed % stride
	for index: int in range(offset, zone.cells.size(), stride):
		zone.dressing_anchors.append(zone.cells[index])
		if zone.dressing_anchors.size() >= 3:
			break
	if zone.dressing_anchors.is_empty():
		zone.dressing_anchors.append(zone.identity_anchor)


func _copy_persistent_state(source: Zone, target: Zone) -> void:
	target.identity_anchor = source.identity_anchor
	target.setup_state = source.setup_state
	target.setup_material_required = source.setup_material_required
	target.setup_material_delivered = source.setup_material_delivered
	target.dressing_seed = source.dressing_seed
	target.dressing_revision = source.dressing_revision


func _sync_world_zone_ids(previous_zone_by_cell: Dictionary) -> void:
	if _world == null or not _world.has_method("set_zone_id"):
		return
	var all_cells: Dictionary = previous_zone_by_cell.duplicate()
	for cell: Vector2i in _zone_by_cell:
		all_cells[cell] = true
	for cell: Vector2i in all_cells:
		_world.set_zone_id(cell, int(_zone_by_cell.get(cell, -1)))


func _on_world_cell_changed(cell: Vector2i, change_flags: int) -> void:
	var relevant := WorldGridScript.CHANGE_TERRAIN | WorldGridScript.CHANGE_WATER | WorldGridScript.CHANGE_PATHING | WorldGridScript.CHANGE_STABILITY
	if (change_flags & relevant) == 0:
		return
	_pending_refresh_all = true
	if _cell_types.has(cell) and not _world.is_excavated(cell):
		_pending_invalidated_cells[cell] = true


func _is_colony_reachable(cell: Vector2i) -> bool:
	if _path_service == null or not _path_service.is_walkable(cell):
		return false
	var start_value: Variant = _world.metadata.get("start_cell", Vector2i(-1, -1))
	if not start_value is Vector2i:
		return false
	var start_cell: Vector2i = start_value
	var revision: int = _path_service.get_topology_revision()
	if revision != _colony_distance_revision or start_cell != _colony_distance_anchor:
		_colony_distances = _path_service.build_distance_field(start_cell)
		_colony_distance_revision = revision
		_colony_distance_anchor = start_cell
	var index: int = _world.cell_to_index(cell)
	return index >= 0 and index < _colony_distances.size() and _colony_distances[index] >= 0


func _queue_all_storage_refs(zone: Zone, reason: String) -> void:
	for pile_id: Variant in zone.storage_refs:
		_queue_invalidated_storage(int(pile_id), zone.zone_id, zone.storage_refs[pile_id], reason)


func _queue_invalidated_storage(pile_id: int, from_zone_id: int, cell: Vector2i, reason: String) -> void:
	var key := _storage_request_key(pile_id)
	if _invalidated_storage_keys.has(key):
		return
	_invalidated_storage_keys[key] = true
	_invalidated_storage_requests.append({
		"request_id": "storage_relocate:%d" % pile_id,
		"pile_id": pile_id,
		"from_zone_id": from_zone_id,
		"cell": cell,
		"reason_code": reason,
		"emergency": reason == "STORAGE_INVALIDATED",
	})


func _setup_request(zone: Zone) -> Dictionary:
	return {
		"request_id": "zone_setup:%d" % zone.zone_id,
		"zone_id": zone.zone_id,
		"zone_type": zone.zone_type,
		"zone_type_name": zone.get_type_name(),
		"anchor": zone.identity_anchor,
		"material_type": "GENERAL_MATERIAL",
		"material_required": zone.setup_material_required,
		"material_delivered": zone.setup_material_delivered,
		"material_remaining": maxi(0, zone.setup_material_required - zone.setup_material_delivered),
		"dressing_seed": zone.dressing_seed,
	}


func _setup_result(ok: bool, reason: String, zone_id: int) -> Dictionary:
	return {"ok": ok, "reason_code": reason, "zone_id": zone_id, "completed": false}


func _inspection(ok: bool, reason: String, cell: Vector2i) -> Dictionary:
	return {"ok": ok, "reason_code": reason, "cell": cell, "current_zone_id": int(_zone_by_cell.get(cell, -1))}


func _change_result(
	ok: bool,
	reason: String,
	changed: Array[Vector2i] = [],
	affected: Array[int] = [],
	created: Array[int] = [],
	removed: Array[int] = [],
	rejected: Array[Dictionary] = []
) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason,
		"changed_cells": changed,
		"affected_zone_ids": affected,
		"created_zone_ids": created,
		"removed_zone_ids": removed,
		"rejected": rejected,
	}


func _normalize_cells(cell_values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for value: Variant in cell_values:
		if not value is Vector2i:
			return []
		if not seen.has(value):
			seen[value] = true
			result.append(value)
	_sort_cells(result)
	return result


func _contains_only_cells(cell_values: Array) -> bool:
	for value: Variant in cell_values:
		if not value is Vector2i:
			return false
	return true


func _sort_cells(cells: Array[Vector2i]) -> void:
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)


func _append_unique(values: PackedStringArray, value: String) -> void:
	if not values.has(value):
		values.append(value)


func _is_valid_type(zone_type: int) -> bool:
	return zone_type >= ZoneScript.Type.SLEEPING and zone_type <= ZoneScript.Type.FOOD_FORAGE


func _make_dressing_seed(zone_id: int, zone_type: int) -> int:
	return absi(int((_world_seed * 1103515245 + zone_id * 12345 + zone_type * 97) % 2147483647))


func _storage_request_key(pile_id: int) -> String:
	return "pile:%d" % pile_id
