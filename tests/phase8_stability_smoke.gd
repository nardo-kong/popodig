extends SceneTree

const StabilitySystemScript = preload("res://src/domain/features/stability_system.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/app/game_app.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	print("PHASE8_SMOKE_STAGE app_ready")
	var stability = scene.colony_simulation.get_stability_system()
	if stability == null:
		_fail("Runtime StabilitySystem is missing")
		return
	var seam: Dictionary = scene._find_qa_soft_soil_seam(scene.world_grid.metadata.start_cell)
	print("PHASE8_SMOKE_STAGE seam=%s" % str(seam))
	if int(seam.row) < 0 or int(seam.length) < 9:
		_fail("Runtime world has no long soft-soil seam for the stability witness")
		return
	var goals: Array[Vector2i] = []
	for x: int in range(int(seam.start), int(seam.start) + 9):
		goals.append(Vector2i(x, int(seam.row)))
	var witness := _potential_path(scene.world_grid, scene.world_grid.metadata.start_cell, goals)
	print("PHASE8_SMOKE_STAGE witness cells=%d" % witness.size())
	if witness.is_empty():
		_fail("Could not derive an executable stability witness")
		return
	var worker_cell: Vector2i = scene.world_grid.metadata.start_cell
	for cell: Vector2i in witness:
		if scene.world_grid.is_traversable(cell):
			worker_cell = cell
			continue
		var designation: Dictionary = scene.dig_system.designate_path([cell])
		var job = scene.dig_system.claim_next("phase8_smoke", worker_cell)
		if not bool(designation.get("ok", false)) or job == null:
			_fail("Stability witness was not executable")
			return
		var completion: Dictionary = scene.dig_system.advance_job("phase8_smoke", job.job_id, 1000.0)
		if not bool(completion.get("completed", false)):
			_fail("Stability witness excavation did not complete")
			return
		worker_cell = cell
	for _pass: int in range(goals.size() + 1):
		var all_done := true
		var progressed := false
		for goal: Vector2i in goals:
			if scene.world_grid.is_traversable(goal):
				continue
			all_done = false
			var work := Vector2i(-1, -1)
			for neighbor: Vector2i in scene.world_grid.get_cardinal_neighbors(goal):
				if scene.path_service.is_walkable(neighbor):
					work = neighbor
					break
			if work.x < 0:
				continue
			var designation: Dictionary = scene.dig_system.designate_path([goal])
			if not bool(designation.get("ok", false)):
				continue
			var job = scene.dig_system.claim_next("phase8_smoke", work)
			if job == null:
				continue
			var completion: Dictionary = scene.dig_system.advance_job("phase8_smoke", job.job_id, 1000.0)
			if bool(completion.get("completed", false)):
				progressed = true
		if all_done or not progressed:
			break
	var excavated := 0
	for goal: Vector2i in goals:
		if scene.world_grid.is_traversable(goal):
			excavated += 1
	if excavated < 8:
		_fail("Stability witness tunnel could not be excavated")
		return
	for _tick: int in range(12):
		scene.colony_simulation.fixed_tick(0.05)
	var row: int = int(seam.row)
	var levels: Dictionary = {}
	for x: int in range(int(seam.start), int(seam.start) + excavated):
		levels[stability.get_warning_level(Vector2i(x, row))] = true
	print("PHASE8_SMOKE_STAGE warnings levels=%s" % str(levels.keys()))
	var warned := false
	for level_value: Variant in levels.keys():
		warned = warned or int(level_value) > StabilitySystemScript.LEVEL_STABLE
	if not warned:
		_fail("Excavated span produced no warning band at all")
		return
	var request_cell := Vector2i(-1, -1)
	for goal: Vector2i in goals:
		if String(stability.inspect_request(goal)) == "OK":
			request_cell = goal
			break
	if request_cell.x < 0:
		_fail("No ceiling-backed reinforce candidate found along the witness span")
		return
	var request: Dictionary = scene.colony_simulation.request_reinforce(request_cell)
	print("PHASE8_SMOKE_STAGE reinforce_requested cell=%s ok=%s" % [str(request_cell), str(request.get("ok", false))])
	if not bool(request.get("ok", false)):
		_fail("Runtime reinforcement request was rejected: %s" % String(request.get("reason_code", "?")))
		return
	if not scene.colony_simulation.get_stability_system().has_request(request_cell):
		_fail("Requested reinforcement did not persist as a pending colony job source")
		return
	if not bool(scene.colony_simulation.get_stability_system().cancel_request(request_cell).get("ok", false)):
		_fail("Pending reinforcement could not be cancelled")
		return
	var expect_debug := _expected_debug()
	if expect_debug:
		if scene.worldgen_debug_overlay.set_mode_by_name("stability") and scene.worldgen_debug_overlay.get_mode_name() != "STABILITY WARNINGS":
			_fail("Development did not expose the stability debug overlay")
			return
	else:
		if scene.worldgen_debug_overlay.visible:
			_fail("Release exposed Phase 8 stability debug data")
			return
	for mouse in scene.colony_simulation.get_mice():
		if not scene.path_service.is_walkable(mouse.current_cell):
			_fail("Mouse stranded inside solid terrain after stability simulation")
			return
	print("PHASE8_STABILITY_SMOKE_PASS profile_debug=%s reinforcements=%d critical=%d" % [
		expect_debug,
		stability.get_completed_count(),
		stability.get_debug_snapshot().critical_cells,
	])
	quit(0)


func _expected_debug() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=") == "true"
	return true


func _potential_path(world, start: Vector2i, goals: Array[Vector2i]) -> Array[Vector2i]:
	var goal_lookup: Dictionary = {}
	for cell: Vector2i in goals:
		goal_lookup[cell] = true
	var previous: Dictionary = {start: Vector2i(-1, -1)}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var reached := Vector2i(-1, -1)
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if goal_lookup.has(current):
			reached = current
			break
		for neighbor: Vector2i in world.get_cardinal_neighbors(current):
			if previous.has(neighbor) or world.is_exterior(neighbor) or world.is_protected(neighbor):
				continue
			if not world.is_traversable(neighbor) and not world.is_solid(neighbor):
				continue
			previous[neighbor] = current
			queue.append(neighbor)
	if reached.x < 0:
		return []
	var path: Array[Vector2i] = []
	var cursor := reached
	while cursor.x >= 0:
		path.append(cursor)
		cursor = previous.get(cursor, Vector2i(-1, -1))
	path.reverse()
	return path


func _fail(message: String) -> void:
	push_error("PHASE8_STABILITY_SMOKE_FAIL %s" % message)
	quit(1)
