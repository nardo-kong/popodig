extends SceneTree

const GeneratorScript = preload("res://src/domain/worldgen/structured_world_generator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/app/game_app.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if scene.worldgen_result == null or not scene.worldgen_result.success:
		_fail("Structured world generation did not produce a playable scene")
		return
	var report: Dictionary = scene.worldgen_result.report
	if report.get("stage_order", []) != GeneratorScript.STAGE_ORDER:
		_fail("Runtime world did not execute the locked structured pipeline")
		return
	if not bool(scene.world_grid.metadata.get("generation_valid", false)):
		_fail("Runtime world bypassed final independent validation")
		return
	if not (report.get("validation", {}).get("failure_codes", []) as Array).is_empty():
		_fail("Runtime world retained validation failures")
		return
	if scene.worldgen_result.feature_registry.get_features_by_role("landmark").size() != 6:
		_fail("Runtime world is missing required macro landmarks")
		return
	if scene.world_grid.metadata.get("signal_emitters", []).size() < 3:
		_fail("Runtime world is missing feature signal hooks")
		return
	var config: Dictionary = root.get_node("AppConfig").get_document("worldgen")
	var replay = GeneratorScript.new().generate_result(config, int(report.seed))
	if not replay.success or replay.get_content_hash() != scene.worldgen_result.get_content_hash():
		_fail("Runtime seed does not replay to the same canonical content hash")
		return
	var different = GeneratorScript.new().generate_result(config, int(report.seed) + 1)
	if not different.success or different.get_content_hash() == replay.get_content_hash():
		_fail("Adjacent runtime seed did not produce a distinct valid world")
		return
	var expect_debug := _expected_debug()
	if scene.get_node("%TopBar").visible != expect_debug or scene.worldgen_debug_overlay.visible != expect_debug:
		_fail("Worldgen debug UI visibility does not match the selected build profile")
		return
	if expect_debug:
		if scene.worldgen_debug_overlay.get_mode_name() != "FEATURE IDS":
			_fail("Development QA overlay argument did not select the feature layer")
			return
	else:
		if scene.worldgen_debug_overlay.get_mode_name() != "OFF":
			_fail("Release profile accepted a worldgen QA overlay argument")
			return
		var f7 := InputEventKey.new()
		f7.keycode = KEY_F7
		f7.pressed = true
		scene._unhandled_input(f7)
		if scene.worldgen_debug_overlay.get_mode_name() != "OFF":
			_fail("Release input exposed the worldgen debug overlay")
			return
	print("PHASE5_WORLDGEN_SMOKE_PASS profile_debug=%s seed=%d hash=%d features=%d repairs=%d" % [
		expect_debug,
		int(report.seed),
		replay.get_content_hash(),
		int(report.feature_count),
		(report.get("repairs", []) as Array).size(),
	])
	quit(0)


func _expected_debug() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=") == "true"
	return true


func _fail(message: String) -> void:
	push_error("PHASE5_WORLDGEN_SMOKE_FAIL %s" % message)
	quit(1)
