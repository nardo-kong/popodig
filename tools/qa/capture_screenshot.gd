extends SceneTree

const DEFAULT_OUTPUT := "res://art/qa/screenshots/phase_2_digging.png"
const TARGET_SIZE := Vector2i(1280, 720)
const ZoneScript = preload("res://src/domain/zones/zone.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var output_path := _get_output_path()
	var target_size := _get_target_size()
	var absolute_directory := ProjectSettings.globalize_path(output_path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		push_error("Unable to create screenshot directory: %s" % error_string(directory_error))
		quit(1)
		return
	root.size = target_size
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if _has_user_argument("--qa-visual-room"):
		scene_path = "res://scenes/qa/visual_test_room.tscn"
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Main scene could not be loaded")
		quit(1)
		return
	if _has_user_argument("--qa-mouse-master=on"):
		const MouseViewScript = preload("res://src/presentation/entities/mouse_view.gd")
		MouseViewScript.master_default = true
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if not _apply_qa_camera_override(scene):
		quit(1)
		return
	if _has_user_argument("--wait-for-wet-storage"):
		if not await _prepare_wet_storage_evidence(scene):
			push_error("Screenshot fixture never reached evacuated wet-Storage evidence")
			quit(1)
			return
		await process_frame
	elif _has_user_argument("--wait-for-zones"):
		var deadline_usec := Time.get_ticks_usec() + 8000000
		while Time.get_ticks_usec() < deadline_usec and not _has_ready_zone_layout(scene):
			await process_frame
		if not _has_ready_zone_layout(scene):
			push_error("Screenshot fixture never reached a ready zone layout")
			quit(1)
			return
		await process_frame
	elif _has_user_argument("--wait-for-carry"):
		var deadline_usec := Time.get_ticks_usec() + 5000000
		while Time.get_ticks_usec() < deadline_usec and not _has_visible_carrier(scene):
			await process_frame
		if not _has_visible_carrier(scene):
			push_error("Screenshot fixture never reached a visible carrying state")
			quit(1)
			return
		await process_frame
	else:
		await create_timer(2.2).timeout
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Viewport did not produce an image")
		quit(1)
		return
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("Screenshot save failed: %s" % error_string(save_error))
		quit(1)
		return
	print("SCREENSHOT_SAVED path=%s width=%d height=%d" % [output_path, image.get_width(), image.get_height()])
	quit(0)


func _get_output_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var candidate := argument.trim_prefix("--output=")
			if candidate.begins_with("res://"):
				return candidate
	return DEFAULT_OUTPUT


func _get_target_size() -> Vector2i:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--size="):
			continue
		var parts := argument.trim_prefix("--size=").to_lower().split("x")
		if parts.size() == 2:
			var parsed := Vector2i(int(parts[0]), int(parts[1]))
			if parsed.x >= 640 and parsed.y >= 360:
				return parsed
	return TARGET_SIZE


func _has_visible_carrier(scene: Node) -> bool:
	var simulation: Variant = scene.get("colony_simulation")
	if simulation == null:
		return false
	for mouse in simulation.get_mice():
		if int(mouse.carried_item_count) > 0:
			return true
	return false


func _has_ready_zone_layout(scene: Node) -> bool:
	return _has_ready_zone_layout_count(scene, 3)


func _has_ready_zone_layout_count(scene: Node, expected_count: int) -> bool:
	var simulation: Variant = scene.get("colony_simulation")
	if simulation == null:
		return false
	var zone_system = simulation.get_zone_system()
	if simulation.get_job_system().get_pending_count() > 0 or simulation.get_job_system().get_active_count() > 0:
		return false
	for mouse in simulation.get_mice():
		if mouse.carried_item_count > 0:
			return false
	var zones: Array = zone_system.get_zones()
	if zones.size() != expected_count:
		return false
	for zone in zones:
		if not zone.valid or zone.get_setup_state_name() != "SET_UP":
			return false
	for pile in simulation.get_item_system().get_piles():
		if pile.count <= 0:
			continue
		var zone = zone_system.get_zone_at(pile.cell)
		if zone == null or zone.get_type_name() != "STORAGE" or not zone.valid:
			return false
	return true


func _prepare_wet_storage_evidence(scene: Node) -> bool:
	var simulation: Variant = scene.get("colony_simulation")
	if simulation == null:
		return false
	var zones = simulation.get_zone_system()
	var home: Vector2i = scene.world_grid.metadata.start_cell
	var fallback_cell := home + Vector2i(4, 0)
	var painted: Dictionary = zones.paint_zone(ZoneScript.Type.STORAGE, [fallback_cell])
	if not painted.ok:
		return false
	var ready_deadline := Time.get_ticks_usec() + 8000000
	while Time.get_ticks_usec() < ready_deadline and not _has_ready_zone_layout_count(scene, 4):
		await process_frame
	if not _has_ready_zone_layout_count(scene, 4):
		return false
	var wet_cell := Vector2i(-1, -1)
	for pile in simulation.get_item_system().get_piles():
		var storage_zone: Zone = zones.get_zone_at(pile.cell)
		if pile.count > 0 and storage_zone != null and storage_zone.zone_type == ZoneScript.Type.STORAGE:
			wet_cell = pile.cell
			break
	if wet_cell.x < 0:
		return false
	scene.world_grid.set_water_units(wet_cell, 1)
	var evacuation_deadline := Time.get_ticks_usec() + 8000000
	while Time.get_ticks_usec() < evacuation_deadline and not _has_evacuated_wet_storage(scene, wet_cell):
		await process_frame
	if not _has_evacuated_wet_storage(scene, wet_cell):
		return false
	scene._set_tool(2)
	var locked: bool = scene.set_qa_inspector_cell(wet_cell)
	scene._feedback_seconds_remaining = 0.0
	return locked


func _has_evacuated_wet_storage(scene: Node, wet_cell: Vector2i) -> bool:
	var simulation = scene.colony_simulation
	var zones = simulation.get_zone_system()
	# Accept both terminal states of the current zone lifecycle: the zone
	# still WET-invalidated, or already autonomously re-validated once dry
	# (hazard became an opportunity again) — in either case the cell must be
	# fully evacuated below.
	var wet_zone: Zone = zones.get_zone_at(wet_cell)
	if wet_zone != null and not wet_zone.valid and not wet_zone.invalid_reasons.has("WET"):
		return false
	if simulation.get_item_system().get_count_at(wet_cell) > 0:
		return false
	if simulation.get_job_system().get_pending_count() > 0 or simulation.get_job_system().get_active_count() > 0:
		return false
	for mouse in simulation.get_mice():
		if mouse.carried_item_count > 0:
			return false
	for pile in simulation.get_item_system().get_piles():
		if pile.count <= 0:
			continue
		var zone: Zone = zones.get_zone_at(pile.cell)
		if zone == null or zone.zone_type != ZoneScript.Type.STORAGE or not zone.valid or zone.setup_state != ZoneScript.SetupState.SET_UP:
			return false
	return true


func _has_user_argument(argument_name: String) -> bool:
	return OS.get_cmdline_user_args().has(argument_name)


func _user_argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


## QA-only camera control for art evidence captures; refuses the release
## profile so release-clean screenshots cannot be repositioned accidentally.
func _apply_qa_camera_override(scene: Node) -> bool:
	var zoom_text := _user_argument_value("--qa-zoom=")
	var focus_text := _user_argument_value("--qa-focus=")
	if zoom_text.is_empty() and focus_text.is_empty():
		return true
	if _user_argument_value("--profile=") == "release":
		push_error("Camera override is not allowed in release-clean captures")
		return false
	var camera: Camera2D = scene.get("world_camera")
	if camera == null:
		if scene.scene_file_path != "res://scenes/qa/visual_test_room.tscn":
			push_error("Scene has no world camera for QA override")
			return false
		return true
	if not zoom_text.is_empty():
		camera.zoom = Vector2.ONE * clampf(float(zoom_text), camera.min_zoom, camera.max_zoom)
	if not focus_text.is_empty():
		var focus_cell_coord := Vector2i.ZERO
		if focus_text == "start":
			focus_cell_coord = scene.world_grid.metadata.start_cell
		else:
			var parts := focus_text.split(",")
			if parts.size() != 2:
				push_error("--qa-focus expects 'start' or x,y cell coordinates")
				return false
			focus_cell_coord = Vector2i(int(parts[0]), int(parts[1]))
		camera.focus_cell(focus_cell_coord, int(scene.get("_logical_cell_size")))
	camera.reset_smoothing()
	return true
