extends "res://tests/test_case.gd"

const Telemetry = preload("res://src/domain/telemetry/session_telemetry.gd")


func run() -> Array[Dictionary]:
	var telemetry := Telemetry.new()
	telemetry.context = {"input_source": "automated test", "seed": 137042}
	telemetry.elapsed_seconds = 12.0
	telemetry.wall_seconds = 40.0
	telemetry.record_resource_gain("GENERAL_MATERIAL", 6)
	telemetry.record_resource_gain("GENERAL_MATERIAL", 0)
	telemetry.record_travel(true)
	telemetry.record_travel(false)
	telemetry.record_development("production", "metal", {"amount": 1})
	telemetry.elapsed_seconds = 18.0
	telemetry.record_development("production", "metal", {"amount": 1})
	var summary: Dictionary = telemetry.to_summary_dict()
	assert_equal(summary.development.resource_gains.GENERAL_MATERIAL, 6, "Resource gains record actual acquired amount")
	assert_equal(summary.development.travel_steps_exact, 2, "Exact travel counts movement events")
	assert_equal(summary.development.loaded_travel_steps_exact, 1, "Loaded travel is counted separately")
	assert_equal(summary.development.first_times_active_sec.production, 12.0, "First production timestamp is not replaced by later batches")
	assert_equal(summary.development.events.size(), 3, "Zero gain does not invent a resource event")
	assert_equal(summary.session_seconds, 18.0, "Active clock is distinct from paused wall time")
	assert_equal(summary.wall_seconds, 40.0, "Wall time remains available for interpreting waits")
	telemetry.record_load()
	assert_equal(telemetry.to_summary_dict().development.events.size(), 3, "Recording load does not replay development rewards")
	assert_true(JSON.parse_string(JSON.stringify(summary)) is Dictionary, "Development metrics remain JSON serializable")
	return results
