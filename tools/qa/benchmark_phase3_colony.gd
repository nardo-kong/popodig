extends SceneTree

const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")

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
		_fail("could not load main scene")
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	if scene.colony_simulation.get_mice().size() != 3:
		_fail("did not instantiate three mice")
		return
	var added_jobs := _enqueue_parallel_haul_fixture(scene)
	if added_jobs < 9:
		_fail("could not enqueue sustained parallel hauling fixture")
		return
	var peak_hauling_mice := 0
	var peak_active_jobs := 0
	var peak_item_reservations := 0
	var warmup_started := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - warmup_started) / 1000000.0 < WARMUP_SECONDS:
		await process_frame
		peak_hauling_mice = maxi(peak_hauling_mice, _hauling_mouse_count(scene))
		peak_active_jobs = maxi(peak_active_jobs, scene.colony_simulation.get_job_system().get_active_count())
		peak_item_reservations = maxi(peak_item_reservations, scene.colony_simulation.get_item_system().get_debug_reservations().size())
	var frame_times_ms: Array[float] = []
	var concurrent_frames := 0
	var sample_started := Time.get_ticks_usec()
	var previous_frame := sample_started
	while (Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times_ms.append((now - previous_frame) / 1000.0)
		previous_frame = now
		var hauling_mice := _hauling_mouse_count(scene)
		var active_jobs: int = scene.colony_simulation.get_job_system().get_active_count()
		peak_hauling_mice = maxi(peak_hauling_mice, hauling_mice)
		peak_active_jobs = maxi(peak_active_jobs, active_jobs)
		peak_item_reservations = maxi(peak_item_reservations, scene.colony_simulation.get_item_system().get_debug_reservations().size())
		if hauling_mice >= 3 and active_jobs >= 3:
			concurrent_frames += 1
	var elapsed_seconds := (Time.get_ticks_usec() - sample_started) / 1000000.0
	frame_times_ms.sort()
	var average_fps := frame_times_ms.size() / elapsed_seconds
	var p95_index := clampi(ceili(frame_times_ms.size() * 0.95) - 1, 0, frame_times_ms.size() - 1)
	var p95_frame_ms := frame_times_ms[p95_index]
	var concurrent_ratio := float(concurrent_frames) / maxf(1.0, float(frame_times_ms.size()))
	print("PHASE3_COLONY_BENCHMARK average_fps=%.2f p95_frame_ms=%.2f frames=%d nodes=%d mice=3 peak_hauling=%d peak_active_jobs=%d peak_item_reservations=%d concurrent_ratio=%.2f queued_hauls=%d dig_jobs=%d viewport=1280x720 vsync=disabled" % [
		average_fps,
		p95_frame_ms,
		frame_times_ms.size(),
		_count_nodes(scene),
		peak_hauling_mice,
		peak_active_jobs,
		peak_item_reservations,
		concurrent_ratio,
		added_jobs,
		scene.dig_system.get_designated_count(),
	])
	if (
		average_fps < MINIMUM_AVERAGE_FPS
		or p95_frame_ms > MAXIMUM_P95_FRAME_MS
		or peak_hauling_mice < 3
		or peak_active_jobs < 3
		or peak_item_reservations < 3
		or concurrent_ratio < 0.5
	):
		_fail("failed frame budget")
		return
	quit(0)


func _count_nodes(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count


func _enqueue_parallel_haul_fixture(scene: Node) -> int:
	var item_system = scene.colony_simulation.get_item_system()
	var source_id := -1
	for pile in item_system.get_piles():
		if pile.item_type == ItemSystemScript.GENERAL_MATERIAL:
			source_id = pile.pile_id
			break
	if source_id < 0:
		return 0
	var home: Vector2i = scene.world_grid.metadata.start_cell
	var target := home
	for offset: Vector2i in [Vector2i(-4, 0), Vector2i(-3, 0), Vector2i(-2, 0), Vector2i.LEFT]:
		var candidate := home + offset
		if scene.world_grid.is_in_bounds(candidate) and scene.path_service.is_walkable(candidate):
			target = candidate
			break
	var added := 0
	for _index: int in range(12):
		if scene.colony_simulation.enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, source_id, target, 1) != null:
			added += 1
	return added


func _hauling_mouse_count(scene: Node) -> int:
	var count := 0
	for mouse in scene.colony_simulation.get_mice():
		if String(mouse.current_job_id).begins_with("job:"):
			count += 1
	return count


func _fail(message: String) -> void:
	push_error("PHASE3_COLONY_BENCHMARK %s" % message)
	quit(1)
