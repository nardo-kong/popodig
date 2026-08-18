extends SceneTree

const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const SignalSystemScript = preload("res://src/domain/features/signal_system.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")


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
		_fail("Runtime world generation failed")
		return
	var signals = scene.signal_system
	var roots = scene.root_feature_system
	if signals == null or roots == null:
		_fail("Runtime SignalSystem or RootFeatureSystem is missing")
		return
	var signal_cells := 0
	var exterior_leaks := 0
	for index: int in range(scene.world_grid.width * scene.world_grid.height):
		var cell: Vector2i = scene.world_grid.index_to_cell(index)
		if scene.world_grid.get_root_signal(cell) > 0:
			signal_cells += 1
			if scene.world_grid.is_exterior(cell):
				exterior_leaks += 1
	if signal_cells <= 0 or exterior_leaks > 0:
		_fail("Runtime Root field is missing or leaks into EXTERIOR")
		return
	var witness: Array = scene.world_grid.metadata.get("validation_metrics", {}).get("witness_paths", {}).get("early_food", [])
	if witness.size() <= 1:
		_fail("Validator did not publish an early-food witness")
		return
	var food_before: int = scene.colony_simulation.get_item_system().get_total_count(ItemSystemScript.FOOD)
	var worker_cell: Vector2i = scene.world_grid.metadata.start_cell
	for cell_value: Variant in witness:
		var cell: Vector2i = cell_value
		if scene.world_grid.is_traversable(cell):
			worker_cell = cell
			continue
		var designation: Dictionary = scene.dig_system.designate_path([cell])
		var job = scene.dig_system.claim_next("phase6_smoke", worker_cell)
		if not bool(designation.get("ok", false)) or job == null:
			_fail("Early-food witness was not executable")
			return
		var completion: Dictionary = scene.dig_system.advance_job("phase6_smoke", job.job_id, 1000.0)
		if not bool(completion.get("completed", false)):
			_fail("Early-food witness excavation did not complete")
			return
		worker_cell = cell
	var revealed = null
	for feature in roots.get_revealed_features():
		if bool(feature.metadata.get("food_opportunity", false)):
			revealed = feature
			break
	if revealed == null or signals.get_recognition_level("root_cluster") != SignalSystemScript.RecognitionLevel.UNDERSTOOD:
		_fail("Runtime excavation did not reveal and teach the Root feature")
		return
	var food_after_reveal: int = scene.colony_simulation.get_item_system().get_total_count(ItemSystemScript.FOOD)
	if food_after_reveal <= food_before or int(revealed.metadata.get("reveal_count", 0)) != 1:
		_fail("Root one-shot reaction did not release Food exactly once")
		return
	var repeated: Dictionary = roots.reveal_feature(revealed.id, worker_cell)
	if String(repeated.get("reason_code", "")) != "ALREADY_REVEALED" or scene.colony_simulation.get_item_system().get_total_count(ItemSystemScript.FOOD) != food_after_reveal:
		_fail("Repeated Root exposure duplicated the reaction")
		return
	var zones = scene.colony_simulation.get_zone_system()
	var painted: Dictionary = zones.paint_zone(ZoneScript.Type.FOOD_FORAGE, [worker_cell])
	var zone: Zone = zones.get_zone_at(worker_cell)
	if not bool(painted.get("ok", false)) or zone == null:
		_fail("Revealed Root approach could not be reused as Food/Forage space")
		return
	zones.begin_setup(zone.zone_id)
	zones.apply_setup_material(zone.zone_id, zone.setup_material_required)
	roots.fixed_tick(1000.0)
	if roots.get_feature_state(revealed.id) != "STABLE_STATE" or int(revealed.metadata.get("food_reserve_units", -1)) != 0:
		_fail("Root did not reach finite Stable State through spatial adaptation")
		return
	var expect_debug := _expected_debug()
	if expect_debug:
		if scene.worldgen_debug_overlay.get_mode_name() != "ROOT SIGNAL BANDS":
			_fail("Development did not expose the requested qualitative signal overlay")
			return
	else:
		if scene.worldgen_debug_overlay.get_mode_name() != "OFF" or scene.worldgen_debug_overlay.visible:
			_fail("Release exposed Phase 6 debug signal data")
			return
	print("PHASE6_ROOT_SMOKE_PASS profile_debug=%s signal_cells=%d food_total=%d runtime_updates=%d" % [
		expect_debug,
		signal_cells,
		scene.colony_simulation.get_item_system().get_total_count(ItemSystemScript.FOOD),
		signals.get_runtime_update_count(),
	])
	quit(0)


func _expected_debug() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=") == "true"
	return true


func _fail(message: String) -> void:
	push_error("PHASE6_ROOT_SMOKE_FAIL %s" % message)
	quit(1)
