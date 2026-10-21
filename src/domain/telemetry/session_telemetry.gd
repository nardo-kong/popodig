class_name SessionTelemetry
extends RefCounted

# 21_BALANCE_TELEMETRY §2 local session metrics. Pure passive recorder: the
# caller owns the clock (`elapsed_seconds`), computes sample aggregates, and
# decides where events come from — so every rule here is unit-testable
# without a scene. Privacy (doc §7): local files only, never networked; the
# game app instantiates this only when debug tools are enabled, so release
# builds collect nothing.

const METRICS_VERSION := 2

## Wall-ish clock in session seconds; the owner updates it each frame.
var elapsed_seconds := 0.0
var wall_seconds := 0.0
var context: Dictionary = {}
var _development_events: Array[Dictionary] = []
var _first_times: Dictionary = {}
var _exact_steps := 0
var _exact_loaded_steps := 0
var _resource_gains: Dictionary = {}
var _production_snapshot: Dictionary = {}

var _cells_excavated := 0
var _cells_by_material := {}
var _dig_batch_cells_total := 0
var _dig_batch_count := 0
var _reinforcements_requested := 0
var _warning_cells := {}
var _warning_events := 0
var _cancellations_after_warning := 0
var _zone_changes := 0
var _saves_by_slot := {}
var _loads := 0
var _breaches := 0
var _water_released_units := 0
var _flooded_storage_peak := 0
var _collapses := 0
var _collapse_cells_total := 0
var _discoveries: Array[Dictionary] = []
var _chapter_advances: Array[Dictionary] = []
var _campaign_completed_elapsed := -1.0
var _mouse_samples := 0
var _idle_mouse_samples := 0
var _mouse_total_samples := 0
var _mouse_steps_total := 0
var _previous_mouse_cells := {}
var _water_samples := 0
var _water_units_last := 0
var _water_units_peak := 0
var _corridor_water_last := 0
var _corridor_water_peak := 0


func record_excavation(material: int) -> void:
	_cells_excavated += 1
	var key := str(material)
	_cells_by_material[key] = int(_cells_by_material.get(key, 0)) + 1


func record_dig_stroke(accepted_cells: int) -> void:
	if accepted_cells <= 0:
		return
	_dig_batch_count += 1
	_dig_batch_cells_total += accepted_cells


func record_reinforcement_requests(accepted_cells: int) -> void:
	_reinforcements_requested += maxi(0, accepted_cells)


## Tracks the active warning set. `level` follows
## StabilitySystem.LEVEL_* (0 = cleared). First entry of a cell into any
## warning level counts as one warning event.
func note_warning(cell: Vector2i, level: int) -> void:
	if level <= 0:
		_warning_cells.erase(cell)
		return
	if not _warning_cells.has(cell):
		_warning_events += 1
	_warning_cells[cell] = true


## Counts only cancelled cells that sat inside an active warning region —
## the doc's "dig cancellations after warnings" adaptation signal.
func record_dig_cancellations(cancelled_cells: Array) -> void:
	for cell: Variant in cancelled_cells:
		if _warning_cells.has(cell as Vector2i):
			_cancellations_after_warning += 1


func record_zone_change() -> void:
	_zone_changes += 1


func record_save(slot_name: String) -> void:
	_saves_by_slot[slot_name] = int(_saves_by_slot.get(slot_name, 0)) + 1


func record_load() -> void:
	_loads += 1


func record_breach(released_units: int) -> void:
	_breaches += 1
	_water_released_units += maxi(0, released_units)


func record_flooded_storage_cells(count: int) -> void:
	_flooded_storage_peak = maxi(_flooded_storage_peak, count)


func record_collapse(cells: Array) -> void:
	_collapses += 1
	_collapse_cells_total += cells.size()


## `open_feature_cells` = how many of the feature's own cells are already
## traversable at reveal — the degraded "how close did you dig before the
## signal fired" proxy (full signal-crossing tracking is out of scope).
func record_discovery(feature_type: String, open_feature_cells: int) -> void:
	_discoveries.append({
		"type": feature_type,
		"elapsed_sec": snappedf(elapsed_seconds, 0.1),
		"open_feature_cells": open_feature_cells,
	})


func record_chapter_advance(chapter: int) -> void:
	_chapter_advances.append({
		"chapter": chapter,
		"elapsed_sec": snappedf(elapsed_seconds, 0.1),
	})


func mark_campaign_complete() -> void:
	if _campaign_completed_elapsed < 0.0:
		_campaign_completed_elapsed = snappedf(elapsed_seconds, 0.1)


## One sample per second from the owner: mouse aggregate + world water.
## `mouse_steps` = summed cell moves since the previous sample (mouse agents
## only expose discrete cells, so this is a 1 Hz travel proxy).
func sample_colony(idle_mice: int, total_mice: int, mouse_steps: int) -> void:
	_mouse_samples += 1
	_idle_mouse_samples += maxi(0, idle_mice)
	_mouse_total_samples += maxi(0, total_mice)
	_mouse_steps_total += maxi(0, mouse_steps)


func sample_water(total_units: int, corridor_units: int) -> void:
	_water_samples += 1
	_water_units_last = total_units
	_water_units_peak = maxi(_water_units_peak, total_units)
	_corridor_water_last = corridor_units
	_corridor_water_peak = maxi(_corridor_water_peak, corridor_units)


func average_dig_batch() -> float:
	if _dig_batch_count == 0:
		return 0.0
	return float(_dig_batch_cells_total) / float(_dig_batch_count)


func idle_ratio() -> float:
	if _mouse_total_samples == 0:
		return 0.0
	return float(_idle_mouse_samples) / float(_mouse_total_samples)


## Discovery gaps in seconds: first discovery measured from session start,
## each next from the previous one.
func discovery_intervals() -> Array[float]:
	var intervals: Array[float] = []
	var previous := 0.0
	for discovery: Dictionary in _discoveries:
		var at := float(discovery.get("elapsed_sec", 0.0))
		intervals.append(maxf(0.0, at - previous))
		previous = at
	return intervals


func to_summary_dict() -> Dictionary:
	return {
		"metrics_version": METRICS_VERSION,
		"session_seconds": snappedf(elapsed_seconds, 0.1),
		"wall_seconds": snappedf(wall_seconds, 0.1),
		"context": context.duplicate(true),
		"development": {"events": _development_events.duplicate(true), "first_times_active_sec": _first_times.duplicate(), "resource_gains": _resource_gains.duplicate(), "travel_steps_exact": _exact_steps, "loaded_travel_steps_exact": _exact_loaded_steps, "production_lifetime_snapshot": _production_snapshot.duplicate(true)},
		"excavation": {
			"cells_total": _cells_excavated,
			"cells_by_material": _cells_by_material.duplicate(),
			"avg_dig_batch": snappedf(average_dig_batch(), 0.01),
			"reinforcement_requests": _reinforcements_requested,
			"dig_cancels_after_warning": _cancellations_after_warning,
		},
		"discoveries": {
			"events": _discoveries.duplicate(true),
			"intervals_sec": discovery_intervals(),
		},
		"water": {
			"breaches": _breaches,
			"released_units": _water_released_units,
			"units_last_sample": _water_units_last,
			"units_peak": _water_units_peak,
			"corridor_units_last_sample": _corridor_water_last,
			"corridor_units_peak": _corridor_water_peak,
			"flooded_storage_cells_peak": _flooded_storage_peak,
		},
		"stability": {
			"warning_events": _warning_events,
			"collapses": _collapses,
			"collapse_cells_total": _collapse_cells_total,
		},
		"colony": {
			"zone_changes": _zone_changes,
			"idle_ratio": snappedf(idle_ratio(), 0.001),
			"mouse_samples": _mouse_samples,
			"mouse_cell_steps": _mouse_steps_total,
		},
		"progression": {
			"chapter_advances": _chapter_advances.duplicate(true),
			"campaign_completed_sec": _campaign_completed_elapsed,
			"saves_by_slot": _saves_by_slot.duplicate(),
			"loads": _loads,
		},
	}


## Writes `user://telemetry/session_<seed>_<stamp>.json`; returns the result
## dictionary {ok, path, error} so the caller can surface failures quietly.
static func write_snapshot(directory: String, seed_value: int, summary: Dictionary) -> Dictionary:
	var dir_access := DirAccess.open(directory)
	if dir_access == null:
		var make_error := DirAccess.make_dir_recursive_absolute(directory)
		if make_error != OK:
			return {"ok": false, "path": "", "error": error_string(make_error)}
		dir_access = DirAccess.open(directory)
		if dir_access == null:
			return {"ok": false, "path": "", "error": "telemetry directory unavailable"}
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var path := directory.path_join("session_seed%d_%s.json" % [seed_value, stamp])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(summary, "  ", false))
	file.close()
	return {"ok": true, "path": path, "error": ""}


func record_development(kind: String, id: String, details: Dictionary = {}) -> void:
	_development_events.append({"kind": kind, "id": id, "active_sec": elapsed_seconds, "details": details.duplicate(true)})
	if not _first_times.has(kind):
		_first_times[kind] = elapsed_seconds


func record_resource_gain(item: String, count: int) -> void:
	if count <= 0:
		return
	_resource_gains[item] = int(_resource_gains.get(item, 0)) + count
	record_development("resource", item, {"amount": count})


func record_travel(loaded: bool) -> void:
	_exact_steps += 1
	if loaded:
		_exact_loaded_steps += 1


func sample_production(production) -> void:
	_production_snapshot = {"completed_batches": production.completed_batches, "input_or_route_wait_seconds": production.waiting_seconds, "active_work_seconds": production.active_work_seconds, "output_blocked_seconds": production.output_blocked_seconds}
