extends SceneTree

const DEFAULT_INPUT := "res://art/qa/screenshots/phase_2_digging.png"
const TARGET_SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	var input_path := _get_input_path()
	var target_size := _get_target_size()
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(input_path))
	if load_error != OK:
		push_error("Screenshot could not be loaded: %s" % error_string(load_error))
		quit(1)
		return
	if image.get_size() != target_size:
		push_error("Unexpected screenshot dimensions: %s" % image.get_size())
		quit(1)
		return
	var samples := [
		image.get_pixel(0, 0),
		image.get_pixel(target_size.x / 2, target_size.y / 2),
		image.get_pixel(target_size.x - 1, target_size.y - 1),
	]
	var all_identical: bool = samples[0].is_equal_approx(samples[1]) and samples[1].is_equal_approx(samples[2])
	if all_identical:
		push_error("Screenshot appears visually empty/uniform")
		quit(1)
		return
	print("SCREENSHOT_VALID path=%s width=%d height=%d" % [input_path, image.get_width(), image.get_height()])
	quit(0)


func _get_input_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--input="):
			var candidate := argument.trim_prefix("--input=")
			if candidate.begins_with("res://"):
				return candidate
	return DEFAULT_INPUT


func _get_target_size() -> Vector2i:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--size="):
			continue
		var parts := argument.trim_prefix("--size=").to_lower().split("x")
		if parts.size() == 2:
			return Vector2i(int(parts[0]), int(parts[1]))
	return TARGET_SIZE
