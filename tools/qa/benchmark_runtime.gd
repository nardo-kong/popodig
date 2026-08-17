extends SceneTree

const GeneratorScript = preload("res://src/domain/world/simple_world_generator.gd")
const WorldViewScript = preload("res://src/presentation/world/world_view.gd")

const WARMUP_SECONDS := 2.0
const SAMPLE_SECONDS := 3.0
const MINIMUM_AVERAGE_FPS := 55.0
const MAXIMUM_P95_FRAME_MS := 33.4


func _initialize() -> void:
	call_deferred("_benchmark")


func _benchmark() -> void:
	root.size = Vector2i(1280, 720)
	var world = GeneratorScript.new().generate({"world_size": [240, 260], "chunk_size": 16}, 9001)
	var host := Node2D.new()
	root.add_child(host)
	var world_view = WorldViewScript.new()
	host.add_child(world_view)
	world_view.configure(world, 16)
	var camera := Camera2D.new()
	camera.position = Vector2(world.width, world.height) * 8.0
	camera.zoom = Vector2.ONE * 0.8
	host.add_child(camera)
	await create_timer(WARMUP_SECONDS).timeout
	var edit_started := Time.get_ticks_usec()
	for index: int in range(128):
		var edit_cell := Vector2i(40 + index % 32, 80 + index / 32)
		world.set_excavated(edit_cell, true)
	await process_frame
	await process_frame
	var edit_burst_ms := (Time.get_ticks_usec() - edit_started) / 1000.0
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
	print("RUNTIME_BENCHMARK world=240x260 chunk_views=%d average_fps=%.2f p95_frame_ms=%.2f edit_burst_ms=%.2f frames=%d viewport=1280x720" % [
		world_view.get_chunk_view_count(),
		average_fps,
		p95_frame_ms,
		edit_burst_ms,
		frame_times_ms.size(),
	])
	if average_fps < MINIMUM_AVERAGE_FPS or p95_frame_ms > MAXIMUM_P95_FRAME_MS:
		push_error("RUNTIME_BENCHMARK failed provisional Phase 1 frame budget")
		quit(1)
		return
	quit(0)
