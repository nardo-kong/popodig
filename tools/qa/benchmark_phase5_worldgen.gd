extends SceneTree

const AppConfigScript = preload("res://src/infrastructure/config/app_config.gd")
const GeneratorScript = preload("res://src/domain/worldgen/structured_world_generator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var loaded: Dictionary = AppConfigScript.load_json_document("res://config/worldgen/default.json")
	if not bool(loaded.get("ok", false)):
		push_error("Unable to load worldgen config")
		quit(1)
		return
	loaded.data["instrument_stage_stdout"] = true
	var seed_value := 137042
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
	var started := Time.get_ticks_usec()
	var result = GeneratorScript.new().generate_result(loaded.data, seed_value)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	var compact_attempts: Array[Dictionary] = []
	for attempt_record: Dictionary in result.report.get("attempt_history", []):
		var metrics: Dictionary = attempt_record.get("initial_metrics", {})
		compact_attempts.append({
			"attempt": int(attempt_record.get("attempt", -1)),
			"initial_failure_codes": attempt_record.get("initial_failure_codes", []),
			"final_failure_codes": attempt_record.get("final_failure_codes", []),
			"repair_count": int(attempt_record.get("repair_count", 0)),
			"first_reservoir_cost": int(metrics.get("first_reservoir_cost", -1)),
			"decision_knot_diagnostics": metrics.get("decision_knot_diagnostics", []),
		})
	print("PERF_PHASE5_WORLDGEN seed=%d valid=%s elapsed_ms=%.2f reported_ms=%.2f attempt=%d repairs=%d features=%d hash=%d failures=%s attempts=%s stages=%s" % [
		seed_value,
		result.success,
		elapsed_ms,
		float(result.report.get("total_generation_ms", 0.0)),
		int(result.report.get("attempt", -1)),
		(result.report.get("repairs", []) as Array).size(),
		int(result.report.get("feature_count", 0)),
		result.get_content_hash(),
		result.report.get("validation", {}).get("failure_codes", []),
		compact_attempts,
		result.report.get("stage_timings_ms", {}),
	])
	quit(0 if result.success else 1)
