extends RefCounted

# Unit tests: 21_BALANCE_TELEMETRY §2 session recorder — excavation counters,
# dig batch average, warning-gated cancellations, discovery intervals on a
# caller-owned clock, water/stability aggregates, sampling, summary shape.

const SessionTelemetryScript = preload("res://src/domain/telemetry/session_telemetry.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	results = []
	_test_excavation_counters()
	_test_dig_batch_average()
	_test_warning_cancellations()
	_test_water_and_stability()
	_test_discovery_intervals_and_progression()
	_test_sampling_aggregates()
	_test_summary_shape_and_snapshot()
	return results


func _test_excavation_counters() -> void:
	var telemetry = SessionTelemetryScript.new()
	telemetry.record_excavation(1)
	telemetry.record_excavation(1)
	telemetry.record_excavation(4)
	var summary: Dictionary = telemetry.to_summary_dict()
	_assert_true(int(summary.excavation.cells_total) == 3, "Total excavated cells counted")
	_assert_true(int(summary.excavation.cells_by_material.get("1", 0)) == 2, "Excavation counted per material")
	_assert_true(int(summary.excavation.reinforcement_requests) == 0, "Reinforcements start at zero")
	telemetry.record_reinforcement_requests(3)
	telemetry.record_reinforcement_requests(2)
	_assert_true(int(telemetry.to_summary_dict().excavation.reinforcement_requests) == 5, "Reinforcement requests accumulate")


func _test_dig_batch_average() -> void:
	var telemetry = SessionTelemetryScript.new()
	_assert_true(telemetry.average_dig_batch() == 0.0, "Empty batch average is zero")
	telemetry.record_dig_stroke(2)
	telemetry.record_dig_stroke(6)
	telemetry.record_dig_stroke(0)
	_assert_true(absf(telemetry.average_dig_batch() - 4.0) < 0.001, "Average batch ignores empty strokes")
	var summary: Dictionary = telemetry.to_summary_dict()
	_assert_true(int(summary.colony.zone_changes) == 0, "Zone changes start at zero")


func _test_warning_cancellations() -> void:
	var telemetry = SessionTelemetryScript.new()
	var warned := Vector2i(5, 7)
	var other := Vector2i(9, 9)
	telemetry.note_warning(warned, 1)
	telemetry.note_warning(warned, 2)
	telemetry.note_warning(other, 3)
	telemetry.note_warning(warned, 0)
	telemetry.record_dig_cancellations([warned, other, warned])
	var summary: Dictionary = telemetry.to_summary_dict()
	_assert_true(int(summary.stability.warning_events) == 2, "Each cell's first warning entry counts once (cleared cell can re-arm)")
	_assert_true(int(summary.excavation.dig_cancels_after_warning) == 1, "Only currently-warned cells count as adaptation cancellations")


func _test_water_and_stability() -> void:
	var telemetry = SessionTelemetryScript.new()
	telemetry.record_breach(12)
	telemetry.record_breach(8)
	telemetry.record_flooded_storage_cells(2)
	telemetry.record_flooded_storage_cells(5)
	telemetry.record_flooded_storage_cells(1)
	telemetry.record_collapse(["a", "b", "c"])
	telemetry.record_collapse(["d"])
	telemetry.sample_water(30, 4)
	telemetry.sample_water(20, 2)
	var summary: Dictionary = telemetry.to_summary_dict()
	_assert_true(int(summary.water.breaches) == 2 and int(summary.water.released_units) == 20, "Breach count and released units accumulate")
	_assert_true(int(summary.water.flooded_storage_cells_peak) == 5, "Flooded storage keeps the peak, not the sum")
	_assert_true(int(summary.stability.collapses) == 2 and int(summary.stability.collapse_cells_total) == 4, "Collapses count events and cells")
	_assert_true(int(summary.water.units_last_sample) == 20 and int(summary.water.units_peak) == 30, "Water sampling keeps last and peak")


func _test_discovery_intervals_and_progression() -> void:
	var telemetry = SessionTelemetryScript.new()
	telemetry.elapsed_seconds = 100.0
	telemetry.record_discovery("root_cluster", 3)
	telemetry.elapsed_seconds = 250.5
	telemetry.record_discovery("water_reservoir", 9)
	var intervals: Array[float] = telemetry.discovery_intervals()
	_assert_true(intervals.size() == 2 and absf(intervals[0] - 100.0) < 0.01 and absf(intervals[1] - 150.5) < 0.01, "Discovery intervals measure start-to-first and gap-to-next")
	telemetry.record_chapter_advance(2)
	telemetry.mark_campaign_complete()
	telemetry.elapsed_seconds = 999.0
	telemetry.mark_campaign_complete()
	telemetry.record_save("autosave")
	telemetry.record_save("quicksave")
	telemetry.record_save("autosave")
	telemetry.record_load()
	var summary: Dictionary = telemetry.to_summary_dict()
	_assert_true(int(summary.discoveries.events[1].open_feature_cells) == 9, "Discovery events keep open-feature-cell proxy")
	_assert_true(absf(float(summary.progression.campaign_completed_sec) - 250.5) < 0.01, "Campaign completion stamps the first time only")
	_assert_true(int(summary.progression.saves_by_slot.get("autosave", 0)) == 2, "Saves counted per slot (autosave visible)")
	_assert_true(int(summary.progression.loads) == 1, "Loads counted")


func _test_sampling_aggregates() -> void:
	var telemetry = SessionTelemetryScript.new()
	_assert_true(telemetry.idle_ratio() == 0.0, "No samples means zero idle ratio")
	telemetry.sample_colony(1, 4, 7)
	telemetry.sample_colony(2, 4, 3)
	telemetry.record_zone_change()
	telemetry.record_zone_change()
	telemetry.record_zone_change()
	var summary: Dictionary = telemetry.to_summary_dict()
	_assert_true(absf(float(summary.colony.idle_ratio) - 0.375) < 0.001, "Idle ratio is sample-weighted")
	_assert_true(int(summary.colony.mouse_cell_steps) == 10, "Mouse travel proxy sums sampled steps")
	_assert_true(int(summary.colony.zone_changes) == 3, "Zone changes accumulate")


func _test_summary_shape_and_snapshot() -> void:
	var telemetry = SessionTelemetryScript.new()
	telemetry.elapsed_seconds = 42.0
	var summary: Dictionary = telemetry.to_summary_dict()
	for section: String in ["excavation", "discoveries", "water", "stability", "colony", "progression"]:
		_assert_true(summary.has(section), "Summary has section %s" % section)
	var as_text := JSON.stringify(summary)
	_assert_true(as_text.contains("\"metrics_version\""), "Summary serializes to JSON")
	var directory := ProjectSettings.globalize_path("user://telemetry_test")
	var result: Dictionary = SessionTelemetryScript.write_snapshot(directory, 137042, summary)
	_assert_true(bool(result.ok) and FileAccess.file_exists(String(result.path)), "Snapshot writes a file under the requested directory")
	if bool(result.ok):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(String(result.path)))
	DirAccess.remove_absolute(directory)


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})
