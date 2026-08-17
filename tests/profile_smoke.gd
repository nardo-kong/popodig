extends SceneTree

const AppConfigScript = preload("res://src/infrastructure/config/app_config.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app_config := AppConfigScript.new()
	root.add_child(app_config)
	var expected := "development"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-profile="):
			expected = argument.trim_prefix("--expect-profile=")
	var actual: String = app_config.get_profile_name()
	if actual != expected:
		push_error("PROFILE_SMOKE expected=%s actual=%s" % [expected, actual])
		quit(1)
		return
	if actual == "release" and (app_config.debug_tools_enabled() or app_config.cheats_enabled()):
		push_error("PROFILE_SMOKE release profile exposes debug capability")
		quit(1)
		return
	if actual == "development" and not app_config.debug_tools_enabled():
		push_error("PROFILE_SMOKE development profile hides debug tools")
		quit(1)
		return
	print("PROFILE_SMOKE_PASS profile=%s debug_tools=%s" % [actual, app_config.debug_tools_enabled()])
	quit(0)
