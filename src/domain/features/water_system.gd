class_name WaterSystem
extends RefCounted

signal reservoir_breached(feature_id: int, exposure_cell: Vector2i, danger_cells: Array, released_units: int)
signal reservoir_state_changed(feature_id: int, state: String)
signal water_transferred(from_cell: Vector2i, to_cell: Vector2i, units: int)
signal danger_cleared()
signal sleeping_changed(sleeping: bool)

const WorldGridScript = preload("res://src/domain/world/world_grid.gd")

const STATE_SIGNAL := "SIGNAL"
const STATE_REACTION := "REACTION"
const STATE_ADAPTATION := "ADAPTATION"
const STATE_STABLE := "STABLE_STATE"

var _world
var _feature_registry
var _signal_system
var _dig_system
var _config: Dictionary = {}
var _step_seconds := 0.2
var _capacity := 4
var _max_transfers := 256
var _source_release := 2
var _breach_initial := 1
var _stable_quiet_steps := 3
var _danger_radius := 3
var _danger_water_units := 2
var _accumulator := 0.0
var _active_cells: Dictionary = {}
var _quiet_steps := 0
var _sleeping := true
var _mutating_water := false
var _danger_active := false
var _danger_cells: Dictionary = {}
var _last_flows: Array[Dictionary] = []
var _total_steps := 0
var _total_transfers := 0


func configure(world_grid, feature_registry, signal_system, dig_system, balance: Dictionary = {}) -> void:
	_disconnect_sources()
	_world = world_grid
	_feature_registry = feature_registry
	_signal_system = signal_system
	_dig_system = dig_system
	_config = balance.get("water", {}).duplicate(true)
	_capacity = maxi(1, int(_config.get("cell_capacity_units", 4)))
	_step_seconds = maxf(0.01, float(_config.get("simulation_step_seconds", 0.2)))
	_max_transfers = maxi(1, int(_config.get("max_transfers_per_step", 256)))
	_source_release = maxi(1, int(_config.get("source_release_per_step", 2)))
	_breach_initial = maxi(0, int(_config.get("breach_initial_units", 1)))
	_stable_quiet_steps = maxi(1, int(_config.get("stable_quiet_steps", 3)))
	_danger_radius = maxi(1, int(_config.get("danger_radius", 3)))
	_danger_water_units = maxi(1, int(_config.get("danger_water_units", 2)))
	_accumulator = 0.0
	_active_cells.clear()
	_quiet_steps = 0
	_sleeping = true
	_mutating_water = false
	_danger_active = false
	_danger_cells.clear()
	_last_flows.clear()
	_total_steps = 0
	_total_transfers = 0
	_initialize_reservoirs()
	_scan_existing_water()
	if _world != null:
		_world.cell_changed.connect(_on_world_cell_changed)
	if _dig_system != null:
		_dig_system.cell_excavated.connect(_on_cell_excavated)


func fixed_tick(delta_seconds: float) -> Dictionary:
	var result := {
		"steps": 0,
		"transfers": 0,
		"units_moved": 0,
		"units_discharged": 0,
		"sleeping": _sleeping,
	}
	if delta_seconds <= 0.0 or _world == null or _sleeping:
		return result
	_accumulator += delta_seconds
	while _accumulator + 0.000001 >= _step_seconds:
		_accumulator -= _step_seconds
		var step_result := _simulate_step()
		result.steps += 1
		result.transfers += int(step_result.transfers)
		result.units_moved += int(step_result.units_moved)
		result.units_discharged += int(step_result.units_discharged)
	result.sleeping = _sleeping
	return result


func reveal_reservoir(feature_id: int, exposure_cell: Vector2i) -> Dictionary:
	var feature = _feature_registry.get_feature(feature_id) if _feature_registry != null else null
	if feature == null or feature.type_id != "water_reservoir":
		return _result(false, "FEATURE_NOT_FOUND", feature_id, exposure_cell)
	if not _is_valid_exposure(feature, exposure_cell):
		return _result(false, "INVALID_EXPOSURE", feature_id, exposure_cell)
	if not feature.hidden:
		return _result(false, "ALREADY_REVEALED", feature_id, exposure_cell)
	feature.hidden = false
	feature.metadata.reveal_count = int(feature.metadata.get("reveal_count", 0)) + 1
	feature.metadata.revealed_at = exposure_cell
	feature.metadata.outlet_cell = exposure_cell
	_set_feature_state(feature, STATE_REACTION)
	var released := _discharge_feature(feature, _breach_initial)
	feature.metadata.reaction_fired = true
	var danger_cells := _build_danger_cells(exposure_cell)
	_danger_cells.clear()
	for cell: Vector2i in danger_cells:
		_danger_cells[cell] = true
	_danger_active = true
	_cancel_dangerous_designations(danger_cells)
	if _signal_system != null:
		_signal_system.mark_feature_understood("water_reservoir")
	_set_feature_state(feature, STATE_ADAPTATION)
	_wake_cell(exposure_cell)
	reservoir_breached.emit(feature.id, exposure_cell, danger_cells, released)
	var result := _result(true, "OK", feature.id, exposure_cell)
	result.released_units = released
	result.danger_cells = danger_cells
	return result


func get_cell_capacity() -> int:
	return _capacity


func is_sleeping() -> bool:
	return _sleeping


func is_danger_active() -> bool:
	return _danger_active


func is_cell_in_danger_region(cell: Vector2i) -> bool:
	return _danger_cells.has(cell)


func get_danger_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in _danger_cells.keys():
		if value is Vector2i:
			result.append(value as Vector2i)
	return result


func get_active_cell_count() -> int:
	return _active_cells.size()


func get_total_water_units() -> int:
	if _world == null:
		return 0
	var total := 0
	for index: int in range(_world.width * _world.height):
		total += _world.get_water_units(_world.index_to_cell(index))
	return total


func get_remaining_reserve_units() -> int:
	var total := 0
	if _feature_registry == null:
		return total
	for feature in _feature_registry.get_features("water_reservoir"):
		total += maxi(0, int(feature.metadata.get("reserve_units", 0)))
	return total


func get_conserved_inventory() -> int:
	return get_total_water_units() + get_remaining_reserve_units()


func get_last_flows() -> Array[Dictionary]:
	return _last_flows.duplicate(true)


func get_debug_snapshot() -> Dictionary:
	return {
		"sleeping": _sleeping,
		"active_cells": _active_cells.size(),
		"water_units": get_total_water_units(),
		"reserve_units": get_remaining_reserve_units(),
		"total_steps": _total_steps,
		"total_transfers": _total_transfers,
		"danger_active": _danger_active,
	}


func wake_region(cell: Vector2i) -> void:
	_wake_cell(cell)


func _simulate_step() -> Dictionary:
	var discharged := _discharge_sources()
	var flow := _flow_active_cells()
	var changed := discharged + int(flow.units_moved)
	_total_steps += 1
	_total_transfers += int(flow.transfers)
	if changed > 0:
		_quiet_steps = 0
	else:
		_quiet_steps += 1
	if _quiet_steps >= _stable_quiet_steps:
		_set_sleeping(true)
	_update_danger_state()
	_update_reservoir_stable_states()
	return {
		"transfers": int(flow.transfers),
		"units_moved": int(flow.units_moved),
		"units_discharged": discharged,
	}


func _flow_active_cells() -> Dictionary:
	var candidates: Array[Vector2i] = []
	for value: Variant in _active_cells.keys():
		if value is Vector2i:
			candidates.append(value)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y > b.y or (a.y == b.y and a.x < b.x)
	)
	var operations := 0
	var units_moved := 0
	var step_flows: Array[Dictionary] = []
	var next_active: Dictionary = {}
	for cell: Vector2i in candidates:
		var source_units: int = int(_world.get_water_units(cell))
		if source_units <= 0 or not _is_water_open(cell):
			continue
		var target := _select_flow_target(cell, source_units)
		if target.x >= 0 and operations < _max_transfers:
			var target_units: int = int(_world.get_water_units(target))
			var amount := _transfer_amount(cell, target, source_units, target_units)
			if amount > 0:
				_set_water(cell, source_units - amount)
				_set_water(target, target_units + amount)
				step_flows.append({"from": cell, "to": target, "units": amount})
				water_transferred.emit(cell, target, amount)
				operations += 1
				units_moved += amount
				_activate_into(next_active, cell)
				_activate_into(next_active, target)
		if _world.get_water_units(cell) > 0:
			_activate_into(next_active, cell)
	_active_cells = next_active
	if not step_flows.is_empty():
		_last_flows = step_flows
	return {"transfers": operations, "units_moved": units_moved}


func _select_flow_target(cell: Vector2i, source_units: int) -> Vector2i:
	var below := cell + Vector2i.DOWN
	if _is_water_open(below) and _world.get_water_units(below) < _capacity:
		return below
	var horizontal: Array[Vector2i] = []
	for target: Vector2i in [cell + Vector2i.LEFT, cell + Vector2i.RIGHT]:
		if not _is_water_open(target):
			continue
		var target_units: int = int(_world.get_water_units(target))
		if target_units + 1 < source_units and target_units < _capacity:
			horizontal.append(target)
	horizontal.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_units: int = int(_world.get_water_units(a))
		var b_units: int = int(_world.get_water_units(b))
		return a_units < b_units or (a_units == b_units and _world.cell_to_index(a) < _world.cell_to_index(b))
	)
	return Vector2i(-1, -1) if horizontal.is_empty() else horizontal[0]


func _transfer_amount(from_cell: Vector2i, to_cell: Vector2i, source_units: int, target_units: int) -> int:
	var free := _capacity - target_units
	if free <= 0:
		return 0
	if to_cell.y > from_cell.y:
		return mini(source_units, free)
	return mini(free, maxi(1, (source_units - target_units) / 2))


func _discharge_sources() -> int:
	var discharged := 0
	if _feature_registry == null:
		return discharged
	for feature in _feature_registry.get_features("water_reservoir"):
		if feature.hidden or int(feature.metadata.get("reserve_units", 0)) <= 0:
			continue
		discharged += _discharge_feature(feature, _source_release)
	return discharged


func _discharge_feature(feature, requested: int) -> int:
	var outlet_value: Variant = feature.metadata.get("outlet_cell", Vector2i(-1, -1))
	if not outlet_value is Vector2i:
		return 0
	var outlet: Vector2i = outlet_value
	if not _is_water_open(outlet):
		return 0
	var reserve := maxi(0, int(feature.metadata.get("reserve_units", 0)))
	var amount := mini(mini(requested, reserve), _capacity - _world.get_water_units(outlet))
	if amount <= 0:
		return 0
	_set_water(outlet, _world.get_water_units(outlet) + amount)
	feature.metadata.reserve_units = reserve - amount
	feature.metadata.discharged_units = int(feature.metadata.get("discharged_units", 0)) + amount
	_wake_cell(outlet)
	return amount


func _on_cell_excavated(cell: Vector2i) -> void:
	_wake_cell(cell)
	var candidate_ids: Dictionary = {}
	var owner_id := int(_world.get_feature_id(cell))
	if owner_id >= 0:
		candidate_ids[owner_id] = true
	for neighbor: Vector2i in _world.get_cardinal_neighbors(cell):
		var neighbor_id := int(_world.get_feature_id(neighbor))
		if neighbor_id >= 0:
			candidate_ids[neighbor_id] = true
	var ids: Array = candidate_ids.keys()
	ids.sort()
	for feature_id: int in ids:
		var feature = _feature_registry.get_feature(feature_id) if _feature_registry != null else null
		if feature != null and feature.type_id == "water_reservoir" and feature.hidden:
			reveal_reservoir(feature_id, cell)


func _on_world_cell_changed(cell: Vector2i, change_flags: int) -> void:
	if _mutating_water:
		return
	if (change_flags & (WorldGridScript.CHANGE_TERRAIN | WorldGridScript.CHANGE_WATER)) != 0:
		_wake_cell(cell)


func _wake_cell(cell: Vector2i) -> void:
	if _world == null or not _world.is_in_bounds(cell):
		return
	_activate_into(_active_cells, cell)
	_quiet_steps = 0
	_set_sleeping(false)


func _activate_into(target: Dictionary, cell: Vector2i) -> void:
	if _world.is_in_bounds(cell):
		target[cell] = true
	for neighbor: Vector2i in _world.get_cardinal_neighbors(cell):
		target[neighbor] = true


func _set_water(cell: Vector2i, units: int) -> void:
	_mutating_water = true
	_world.set_water_units(cell, units)
	_mutating_water = false


func _set_sleeping(value: bool) -> void:
	if _sleeping == value:
		return
	_sleeping = value
	sleeping_changed.emit(value)


func _initialize_reservoirs() -> void:
	if _feature_registry == null:
		return
	for feature in _feature_registry.get_features("water_reservoir"):
		feature.metadata.lifecycle_state = String(feature.metadata.get("lifecycle_state", STATE_SIGNAL if feature.hidden else STATE_ADAPTATION))
		feature.metadata.reaction_fired = bool(feature.metadata.get("reaction_fired", not feature.hidden))
		feature.metadata.reveal_count = int(feature.metadata.get("reveal_count", 0 if feature.hidden else 1))
		feature.metadata.reserve_units = maxi(0, int(feature.metadata.get("reserve_units", 0)))
		feature.metadata.initial_reserve_units = int(feature.metadata.get("initial_reserve_units", feature.metadata.reserve_units))
		feature.metadata.discharged_units = int(feature.metadata.get("discharged_units", 0))


func _scan_existing_water() -> void:
	if _world == null:
		return
	for index: int in range(_world.width * _world.height):
		var cell: Vector2i = _world.index_to_cell(index)
		if _world.get_water_units(cell) > 0:
			_activate_into(_active_cells, cell)
	if not _active_cells.is_empty():
		_set_sleeping(false)


func _build_danger_cells(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset_y: int in range(-_danger_radius, _danger_radius + 1):
		var horizontal := _danger_radius - absi(offset_y)
		for offset_x: int in range(-horizontal, horizontal + 1):
			var cell := center + Vector2i(offset_x, offset_y)
			if _world.is_in_bounds(cell) and not _world.is_exterior(cell):
				result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _world.cell_to_index(a) < _world.cell_to_index(b)
	)
	return result


func _cancel_dangerous_designations(danger_cells: Array[Vector2i]) -> void:
	if _dig_system == null or not _dig_system.has_method("get_designated_cells"):
		return
	var danger_lookup: Dictionary = {}
	for cell: Vector2i in danger_cells:
		danger_lookup[cell] = true
	var cancelled: Array[Vector2i] = []
	for cell: Vector2i in _dig_system.get_designated_cells():
		if danger_lookup.has(cell):
			cancelled.append(cell)
	if not cancelled.is_empty():
		_dig_system.cancel(cancelled)


func _update_danger_state() -> void:
	if not _danger_active:
		return
	for value: Variant in _danger_cells.keys():
		if value is Vector2i and _world.get_water_units(value) >= _danger_water_units:
			return
	if _quiet_steps < _stable_quiet_steps:
		return
	_danger_active = false
	_danger_cells.clear()
	danger_cleared.emit()


func _update_reservoir_stable_states() -> void:
	if not _sleeping or _feature_registry == null:
		return
	for feature in _feature_registry.get_features("water_reservoir"):
		if not feature.hidden and String(feature.metadata.get("lifecycle_state", "")) != STATE_STABLE:
			_set_feature_state(feature, STATE_STABLE)


func _set_feature_state(feature, state: String) -> void:
	if String(feature.metadata.get("lifecycle_state", "")) == state:
		return
	feature.metadata.lifecycle_state = state
	reservoir_state_changed.emit(feature.id, state)


func _is_valid_exposure(feature, exposure_cell: Vector2i) -> bool:
	if not _world.is_traversable(exposure_cell):
		return false
	if feature.cells.has(exposure_cell):
		return true
	for neighbor: Vector2i in _world.get_cardinal_neighbors(exposure_cell):
		if feature.cells.has(neighbor):
			return true
	return false


func _is_water_open(cell: Vector2i) -> bool:
	return _world.is_in_bounds(cell) and _world.is_excavated(cell) and not _world.is_exterior(cell) and not _world.is_sealed(cell)


func _disconnect_sources() -> void:
	if _world != null and _world.cell_changed.is_connected(_on_world_cell_changed):
		_world.cell_changed.disconnect(_on_world_cell_changed)
	if _dig_system != null and _dig_system.cell_excavated.is_connected(_on_cell_excavated):
		_dig_system.cell_excavated.disconnect(_on_cell_excavated)


func _result(ok: bool, reason_code: String, feature_id: int, cell: Vector2i) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"feature_id": feature_id,
		"cell": cell,
	}
