extends SceneTree

const WARMUP_SECONDS := 2.0
const SAMPLE_SECONDS := 3.0
const MINIMUM_AVERAGE_FPS := 55.0
const MAXIMUM_P95_FRAME_MS := 33.4


func _initialize() -> void:
	call_deferred("_benchmark")


func _benchmark() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 720)
	var packed := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	if packed == null:
		push_error("PHASE2_GAMEPLAY_BENCHMARK could not load main scene")
		quit(1)
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await create_timer(WARMUP_SECONDS).timeout
	var frame_times_ms: Array[float] = []
	var sample_started := Time.get_ticks_usec()
	var previous_frame := sample_started
	while (Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times_ms.append((now - previous_frame) / 1000.0)
		previous_frame = now
	var elapsed_seconds := (Time.get_ticks_usec() - sample_started) / 1000000.0
	frame_times_ms.sort()
	var average_fps := frame_times_ms.size() / elapsed_seconds
	var p95_index := clampi(ceili(frame_times_ms.size() * 0.95) - 1, 0, frame_times_ms.size() - 1)
	var p95_frame_ms := frame_times_ms[p95_index]
	print("PHASE2_GAMEPLAY_BENCHMARK average_fps=%.2f p95_frame_ms=%.2f frames=%d nodes=%d designated=%d mouse=%s viewport=1280x720 vsync=disabled" % [
		average_fps,
		p95_frame_ms,
		frame_times_ms.size(),
		_count_nodes(scene),
		scene.dig_system.get_designated_count(),
		scene.mouse_agent.get_state_name(),
	])
	if average_fps < MINIMUM_AVERAGE_FPS or p95_frame_ms > MAXIMUM_P95_FRAME_MS:
		push_error("PHASE2_GAMEPLAY_BENCHMARK failed frame budget")
		quit(1)
		return
	quit(0)


func _count_nodes(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count
