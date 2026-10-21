extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/app/game_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var saved: Dictionary = scene.SaveServiceScript.load_game("/private/tmp/popodig-campaign-complete.json")
	if not saved.ok or not scene._apply_loaded_document(saved.data).ok:
		push_error("PHASE20_HOME_BENCHMARK_FAIL run campaign smoke first")
		quit(1)
		return
	scene.world_camera.focus_cell(scene._warm_chamber_anchor(), scene._logical_cell_size)
	await create_timer(2.0).timeout
	var samples: Array[float] = []
	var started := Time.get_ticks_usec()
	var previous := started
	while Time.get_ticks_usec() - started < 3000000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	var fps := samples.size() / ((Time.get_ticks_usec() - started) / 1000000.0)
	samples.sort()
	var p95: float = samples[ceili(samples.size() * 0.95) - 1]
	print("PHASE20_HOME_BENCHMARK fps=%.2f p95_frame_ms=%.2f viewport=1280x720 mice=%d real_completed_save=true vsync=off" % [fps, p95, scene.colony_simulation.get_mice().size()])
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if fps >= 55 and p95 <= 33.4 else 1)
