extends SceneTree

const CellDataScript = preload("res://src/domain/world/cell_data.gd")


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
	if scene.mouse_agent == null or scene.mouse_agent.get_state_name() != "IDLE":
		_fail("One Phase 2 mouse did not spawn idle")
		return
	var app_config = root.get_node("AppConfig")
	if not app_config.cheats_enabled() and scene.dig_system.get_designated_count() != 0:
		_fail("Release accepted the QA auto-designation cheat")
		return
	if not scene.get_node("%GameplayHud").visible:
		_fail("Gameplay DIG HUD is not visible")
		return
	var expect_debug := _get_expected_debug_visibility()
	for debug_control_name: String in ["TopBar", "Footer"]:
		if scene.get_node("%%%s" % debug_control_name).visible != expect_debug:
			_fail("Debug UI visibility mismatch for %s" % debug_control_name)
			return
	# Phase 9 dual-mode inspector: the qualitative player panel is visible
	# in every profile by design.
	if not scene.get_node("%Inspector").visible:
		_fail("Dual-mode inspector must stay visible in every profile")
		return
	var stray_left_release := InputEventMouseButton.new()
	stray_left_release.button_index = MOUSE_BUTTON_LEFT
	stray_left_release.pressed = false
	if scene._handle_dig_input(stray_left_release):
		_fail("Inactive DIG input consumed a left-button release needed by camera drag")
		return
	scene._paint_action = scene.PaintAction.DESIGNATE
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	if scene._paint_action != scene.PaintAction.NONE:
		_fail("Focus loss did not clear a pending DIG paint gesture")
		return
	var cells := _build_test_path(scene.world_grid)
	if cells.size() != 6:
		_fail("Unable to build six-cell dig fixture")
		return
	var target_chunk: Vector2i = scene.world_grid.cell_to_chunk(cells[0])
	var chunk_view = scene.world_view.get_chunk_view(target_chunk)
	var redraws_before: int = chunk_view.dig_overlay_view.redraw_request_count
	_send_drag(scene, cells[0], cells[-1], MOUSE_BUTTON_LEFT)
	if scene._paint_action != scene.PaintAction.NONE:
		_fail("LMB dig drag did not clear its paint state on release")
		return
	if scene.dig_system.get_designated_count() != cells.size():
		_fail("Synthetic LMB drag did not sketch the full legal path")
		return
	for cell_coord: Vector2i in cells:
		if scene.world_grid.get_dig_state(cell_coord) == CellDataScript.DigState.NONE:
			_fail("Dragged path contains an undesignated cell: %s" % cell_coord)
			return
	await process_frame
	await process_frame
	if chunk_view.dig_overlay_view.redraw_request_count <= redraws_before:
		_fail("Designation did not request overlay redraw")
		return
	var fixed_ticks := 0
	while scene.dig_system.get_designated_count() > 0 and fixed_ticks < 4000:
		scene.mouse_agent.fixed_tick(0.05)
		fixed_ticks += 1
	if scene.dig_system.get_designated_count() != 0:
		_fail("Mouse did not finish the sketched path before timeout")
		return
	for cell_coord: Vector2i in cells:
		if not scene.world_grid.is_excavated(cell_coord):
			_fail("Mouse left a designated cell solid: %s" % cell_coord)
			return
	var route: Array[Vector2i] = scene.path_service.find_path(scene.world_grid.metadata.start_cell, cells[-1])
	if route.is_empty():
		_fail("Path service did not expose newly excavated topology")
		return
	var cancel_cells: Array[Vector2i] = [cells[-1] + Vector2i.DOWN, cells[-1] + Vector2i.DOWN * 2]
	_send_drag(scene, cancel_cells[0], cancel_cells[-1], MOUSE_BUTTON_LEFT)
	if scene.dig_system.get_designated_count() != cancel_cells.size():
		_fail("Second path fixture was not designated")
		return
	_send_drag(scene, cancel_cells[0], cancel_cells[0], MOUSE_BUTTON_RIGHT)
	if scene.dig_system.get_designated_count() != 0:
		_fail("Cancelling the dependency root did not prune downstream cells")
		return
	if scene.world_grid.is_excavated(cancel_cells[0]) or scene.world_grid.get_dig_progress(cancel_cells[0]) != 0.0:
		_fail("Cancellation corrupted terrain or retained progress")
		return
	print("PHASE2_PLAYABLE_SMOKE_PASS profile_debug=%s cells=%d fixed_ticks=%d route=%d" % [
		expect_debug,
		cells.size(),
		fixed_ticks,
		route.size(),
	])
	quit(0)


func _build_test_path(world) -> Array[Vector2i]:
	var cursor: Vector2i = world.metadata.start_cell
	while world.is_in_bounds(cursor + Vector2i.DOWN) and world.is_excavated(cursor + Vector2i.DOWN):
		cursor += Vector2i.DOWN
	var result: Array[Vector2i] = []
	for _index: int in range(6):
		cursor += Vector2i.DOWN
		if not world.is_in_bounds(cursor) or world.is_protected(cursor) or not world.is_solid(cursor):
			return []
		result.append(cursor)
	return result


func _send_drag(scene: Node, start_cell: Vector2i, end_cell: Vector2i, button: MouseButton) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.position = _screen_position(scene, start_cell)
	scene._unhandled_input(press)
	if start_cell != end_cell:
		var motion := InputEventMouseMotion.new()
		motion.position = _screen_position(scene, end_cell)
		scene._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = button
	release.pressed = false
	release.position = _screen_position(scene, end_cell)
	scene._unhandled_input(release)


func _screen_position(scene: Node, cell_coord: Vector2i) -> Vector2:
	var local_center: Vector2 = (Vector2(cell_coord) + Vector2(0.5, 0.5)) * scene._logical_cell_size
	return scene.world_view.get_global_transform_with_canvas() * local_center


func _get_expected_debug_visibility() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=") == "true"
	return true


func _fail(message: String) -> void:
	push_error("PHASE2_PLAYABLE_SMOKE_FAIL %s" % message)
	quit(1)
