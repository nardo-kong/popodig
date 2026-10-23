extends SceneTree

# Native device diagnostic for #17. Dummy is only a comparison, never proof
# of audible output. Run without --headless and listen separately.
const Director = preload("res://src/presentation/audio/audio_director.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var director := Director.new()
	root.add_child(director)
	var samples: Array[Dictionary] = []
	for index: int in range(10):
		director.play_tool_select()
		await create_timer(0.2).timeout
		samples.append({"index": index, "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"seconds_since_mix": AudioServer.get_time_since_last_mix(),
			"ambience_position": director._ambience_player.get_playback_position()})
	var advancing: bool = float(samples[-1].seconds_since_mix) < 0.25 and float(samples[-1].ambience_position) > 0.25
	print("NATIVE_AUDIO_PROBE " + JSON.stringify({"driver": AudioServer.get_driver_name(),
		"mix_advancing": advancing, "listening_test": "pending", "samples": samples}))
	director.stop_all()
	await create_timer(0.5).timeout
	director.queue_free()
	await create_timer(0.2).timeout
	quit(0 if advancing else 1)
