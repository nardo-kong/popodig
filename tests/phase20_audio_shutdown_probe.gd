extends SceneTree
# Minimal native WAV shutdown reproduction; see the RC report.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := AudioStreamPlayer.new()
	if OS.get_cmdline_user_args().has("--stream"):
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	root.add_child(player)
	var audio_path := "res://assets/audio/production/ui_tool.wav"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--audio="):
			audio_path = argument.trim_prefix("--audio=")
	player.stream = load(audio_path)
	var repeats := 1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--repeats="):
			repeats = clampi(int(argument.trim_prefix("--repeats=")), 1, 20)
	for index: int in range(repeats):
		player.play()
		await create_timer(0.5).timeout
		player.stop()
		await create_timer(0.5).timeout
		print("AUDIO_PROBE iteration=%d objects=%d resources=%d" % [index, int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	player.stream = null
	player.queue_free()
	await create_timer(1.0).timeout
	print("AUDIO_SHUTDOWN_PROBE_FINISHED inspect shutdown diagnostics separately")
	quit(0)
