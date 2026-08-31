extends SceneTree

const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")


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
	# The campaign starts with one founding mouse (Phase 16); this benchmark
	# scenario explicitly tops up to the three-mouse haul concurrency.
	scene._ensure_qa_mice(3)
	# ColonyView syncs mouse views on its own _process — give it a frame.
	await process_frame
	await process_frame
	var mice: Array = scene.colony_simulation.get_mice()
	if mice.size() != 3 or scene.colony_view.get_mouse_view_count() != 3:
		_fail("Phase 3 did not spawn and present exactly three autonomous mice")
		return
	var expect_debug := _get_expected_debug_visibility()
	if scene.colony_debug_overlay.visible != expect_debug:
		_fail("Colony path/job overlay profile visibility mismatch")
		return
	var item_system = scene.colony_simulation.get_item_system()
	if item_system.get_total_count(ItemSystemScript.FOOD) < 8 or item_system.get_total_count(ItemSystemScript.GENERAL_MATERIAL) < 10:
		_fail("Initial Food and General Material supplies are missing")
		return
	var job_system = scene.colony_simulation.get_job_system()
	var app_config = root.get_node("AppConfig")
	if not app_config.cheats_enabled() and (job_system.get_pending_count() != 0 or job_system.get_active_count() != 0):
		_fail("Release accepted the Phase 3 QA colony setup argument")
		return
	if not scene.get_node("%ColonyStatusLabel").visible:
		_fail("Player-facing colony status is not visible")
		return
	if job_system.get_pending_count() == 0 and job_system.get_active_count() == 0:
		var source_id := _first_pile_id(item_system, ItemSystemScript.GENERAL_MATERIAL)
		if source_id < 0 or scene.colony_simulation.enqueue_haul(
			ItemSystemScript.GENERAL_MATERIAL,
			source_id,
			scene.world_grid.metadata.start_cell,
			2
		) == null:
			_fail("Could not enqueue the playable hauling fixture")
			return
	var material_before := _owned_total(scene, ItemSystemScript.GENERAL_MATERIAL)
	var saw_carrying := false
	var fixed_ticks := 0
	while job_system.get_completed_count() == 0 and fixed_ticks < 1000:
		scene.colony_simulation.fixed_tick(0.05)
		for mouse in mice:
			saw_carrying = saw_carrying or int(mouse.carried_item_count) > 0
		fixed_ticks += 1
	if job_system.get_completed_count() == 0 or not saw_carrying:
		_fail("Three-mouse colony did not visibly carry and complete a haul job")
		return
	if _owned_total(scene, ItemSystemScript.GENERAL_MATERIAL) != material_before:
		_fail("Hauling duplicated or destroyed General Material")
		return
	if not item_system.get_debug_reservations().is_empty() or job_system.get_active_count() != 0:
		_fail("Completed hauling retained an item or job reservation")
		return
	var danger_cells: Array[Vector2i] = []
	for mouse in mice:
		danger_cells.append(mouse.current_cell)
	var danger_results: Array[Dictionary] = scene.colony_simulation.trigger_danger(danger_cells)
	if danger_results.size() != 3:
		_fail("Danger event did not reach all three mice")
		return
	for mouse in mice:
		if not mouse.danger_state:
			_fail("Danger event did not interrupt a mouse")
			return
	for _index: int in range(120):
		scene.colony_simulation.fixed_tick(0.05)
	scene.colony_simulation.recover_from_danger()
	scene.colony_simulation.fixed_tick(0.05)
	for mouse in mice:
		if mouse.danger_state:
			_fail("Mouse did not recover from the event-driven danger state")
			return
	print("PHASE3_COLONY_SMOKE_PASS profile_debug=%s mice=%d haul_ticks=%d completed=%d material=%d" % [
		expect_debug,
		mice.size(),
		fixed_ticks,
		job_system.get_completed_count(),
		_owned_total(scene, ItemSystemScript.GENERAL_MATERIAL),
	])
	quit(0)


func _first_pile_id(item_system, item_type: String) -> int:
	for pile in item_system.get_piles():
		if pile.item_type == item_type and pile.available_count() >= 2:
			return pile.pile_id
	return -1


func _owned_total(scene: Node, item_type: String) -> int:
	var total: int = scene.colony_simulation.get_item_system().get_total_count(item_type)
	for mouse in scene.colony_simulation.get_mice():
		if mouse.carried_item_type == item_type:
			total += int(mouse.carried_item_count)
	return total


func _get_expected_debug_visibility() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=") == "true"
	return true


func _fail(message: String) -> void:
	push_error("PHASE3_COLONY_SMOKE_FAIL %s" % message)
	quit(1)
