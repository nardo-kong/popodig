extends SceneTree

const DEFAULT_INPUT := "res://art/qa/screenshots/phase_0_foundation.png"
const TARGET_SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	var input_path := _get_input_path()
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(input_path))
	if load_error != OK:
		push_error("Screenshot could not be loaded: %s" % error_string(load_error))
		quit(1)
		return
	if image.get_size() != TARGET_SIZE:
		push_error("Unexpected screenshot dimensions: %s" % image.get_size())
		quit(1)
		return
	var samples := [
		image.get_pixel(0, 0),
		image.get_pixel(TARGET_SIZE.x / 2, TARGET_SIZE.y / 2),
		image.get_pixel(TARGET_SIZE.x - 1, TARGET_SIZE.y - 1),
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
