extends SceneTree

const DEFAULT_OUTPUT := "res://art/qa/screenshots/phase_2_digging.png"
const TARGET_SIZE := Vector2i(1280, 720)


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
	var packed := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	if packed == null:
		push_error("Main scene could not be loaded")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if _has_user_argument("--wait-for-carry"):
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


func _has_user_argument(argument_name: String) -> bool:
	return OS.get_cmdline_user_args().has(argument_name)
