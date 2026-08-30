extends SceneTree

const WARMUP_SECONDS := 2.0
const SAMPLE_SECONDS := 3.0
const MINIMUM_AVERAGE_FPS := 55.0
const MAXIMUM_P95_FRAME_MS := 33.4
# Phase 11 added the persistent presentation layers (WaterFxView, VfxView,
# AudioDirector + player pool = +9 nodes); Phase 12 added the settings
# overlay (~+23 nodes); the budget follows the scene graph.
const MAXIMUM_NODE_COUNT := 150


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
	var ready_deadline := Time.get_ticks_usec() + 8000000
	while Time.get_ticks_usec() < ready_deadline and not _zone_layout_ready(scene):
		await process_frame
	if not _zone_layout_ready(scene):
		_fail("zone fixture did not reach stable setup/storage state")
		return
	for mouse in scene.colony_simulation.get_mice():
		mouse.rest = 0.05
	var peak_sleeping := 0
	var warmup_started := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - warmup_started) / 1000000.0 < WARMUP_SECONDS:
		await process_frame
		peak_sleeping = maxi(peak_sleeping, _sleeping_mouse_count(scene))
	var frame_times_ms: Array[float] = []
	var sample_started := Time.get_ticks_usec()
	var previous_frame := sample_started
	while (Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times_ms.append((now - previous_frame) / 1000.0)
		previous_frame = now
		peak_sleeping = maxi(peak_sleeping, _sleeping_mouse_count(scene))
	var elapsed_seconds := (Time.get_ticks_usec() - sample_started) / 1000000.0
	frame_times_ms.sort()
	var average_fps := frame_times_ms.size() / elapsed_seconds
	var p95_index := clampi(ceili(frame_times_ms.size() * 0.95) - 1, 0, frame_times_ms.size() - 1)
	var p95_frame_ms := frame_times_ms[p95_index]
	var node_count := _count_nodes(scene)
	var zones: Array = scene.colony_simulation.get_zone_system().get_zones()
	var zone_cells := 0
	for zone in zones:
		zone_cells += zone.cells.size()
	print("PHASE4_ZONES_BENCHMARK average_fps=%.2f p95_frame_ms=%.2f frames=%d nodes=%d mice=3 zones=%d zone_cells=%d peak_sleeping=%d viewport=1280x720 vsync=disabled" % [
		average_fps,
		p95_frame_ms,
		frame_times_ms.size(),
		node_count,
		zones.size(),
		zone_cells,
		peak_sleeping,
	])
	if average_fps < MINIMUM_AVERAGE_FPS or p95_frame_ms > MAXIMUM_P95_FRAME_MS or node_count > MAXIMUM_NODE_COUNT or peak_sleeping < 3:
		_fail("failed frame, node, or autonomous sleeping budget")
		return
	quit(0)


func _zone_layout_ready(scene: Node) -> bool:
	var simulation = scene.colony_simulation
	var zones: Array = simulation.get_zone_system().get_zones()
	if zones.size() != 3 or simulation.get_job_system().get_pending_count() > 0 or simulation.get_job_system().get_active_count() > 0:
		return false
	for zone in zones:
		if not zone.valid or zone.get_setup_state_name() != "SET_UP":
			return false
	for pile in simulation.get_item_system().get_piles():
		if pile.count <= 0:
			continue
		var zone = simulation.get_zone_system().get_zone_at(pile.cell)
		if zone == null or zone.get_type_name() != "STORAGE":
			return false
	return true


func _sleeping_mouse_count(scene: Node) -> int:
	var count := 0
	for mouse in scene.colony_simulation.get_mice():
		if mouse.get_state_name() == "RESTING":
			count += 1
	return count


func _count_nodes(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count


func _fail(message: String) -> void:
	push_error("PHASE4_ZONES_BENCHMARK %s" % message)
	quit(1)
