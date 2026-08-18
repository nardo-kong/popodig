extends SceneTree

const WARMUP_SECONDS := 1.5
const SAMPLE_SECONDS := 2.5
const MINIMUM_AVERAGE_FPS := 55.0
const MAXIMUM_P95_FRAME_MS := 33.4
const MAXIMUM_EDIT_BURST_MS := 250.0


func _initialize() -> void:
	call_deferred("_benchmark")


func _benchmark() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 720)
	var packed := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	if packed == null:
		_fail("could not load main scene")
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await create_timer(WARMUP_SECONDS).timeout
	if scene.signal_system == null:
		_fail("runtime SignalSystem is missing")
		return
	var candidates: Array[Vector2i] = []
	for index: int in range(scene.world_grid.width * scene.world_grid.height):
		var cell: Vector2i = scene.world_grid.index_to_cell(index)
		if (
			scene.world_grid.is_solid(cell)
			and not scene.world_grid.is_exterior(cell)
			and not scene.world_grid.is_protected(cell)
			and scene.world_grid.get_feature_id(cell) < 0
		):
			candidates.append(cell)
		if candidates.size() >= 64:
			break
	var updates_before: int = scene.signal_system.get_runtime_update_count()
	var edit_started := Time.get_ticks_usec()
	for cell: Vector2i in candidates:
		scene.world_grid.set_excavated(cell, true)
	var edit_burst_ms := (Time.get_ticks_usec() - edit_started) / 1000.0
	await process_frame
	await process_frame
	var updates: int = scene.signal_system.get_runtime_update_count() - updates_before
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
	print("PHASE6_SIGNAL_BENCHMARK average_fps=%.2f p95_frame_ms=%.2f edit_burst_ms=%.2f edits=%d updates=%d dirty_regions=%d viewport=1280x720 vsync=disabled" % [
		average_fps,
		p95_frame_ms,
		edit_burst_ms,
		candidates.size(),
		updates,
		scene.signal_system.get_dirty_regions().size(),
	])
	if (
		average_fps < MINIMUM_AVERAGE_FPS
		or p95_frame_ms > MAXIMUM_P95_FRAME_MS
		or edit_burst_ms > MAXIMUM_EDIT_BURST_MS
		or updates != candidates.size()
		or scene.signal_system.get_dirty_regions().size() > 32
	):
		_fail("failed frame, update, dirty-region, or edit-burst budget")
		return
	quit(0)


func _fail(message: String) -> void:
	push_error("PHASE6_SIGNAL_BENCHMARK %s" % message)
	quit(1)
