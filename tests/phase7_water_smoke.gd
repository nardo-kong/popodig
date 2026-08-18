extends SceneTree

const SignalSystemScript = preload("res://src/domain/features/signal_system.gd")
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
	print("PHASE7_SMOKE_STAGE app_ready")
	var water = scene.water_system
	var seals = scene.seal_system
	if water == null or seals == null:
		_fail("Runtime WaterSystem or SealSystem is missing")
		return
	var moisture_cells := 0
	var exterior_leaks := 0
	for index: int in range(scene.world_grid.width * scene.world_grid.height):
		var cell: Vector2i = scene.world_grid.index_to_cell(index)
		if scene.world_grid.get_moisture_signal(cell) > 0:
			moisture_cells += 1
			if scene.world_grid.is_exterior(cell):
				exterior_leaks += 1
	if moisture_cells <= 0 or exterior_leaks > 0:
		_fail("Runtime Moisture field is missing or leaks into EXTERIOR")
		return
	print("PHASE7_SMOKE_STAGE moisture_scanned cells=%d" % moisture_cells)
	var reservoirs: Array = scene.worldgen_result.feature_registry.get_features("water_reservoir")
	if reservoirs.is_empty():
		_fail("Generated runtime world has no reservoir")
		return
	var reservoir = reservoirs[0]
	for candidate in reservoirs:
		if candidate.required:
			reservoir = candidate
			break
	var witness := _potential_path(scene.world_grid, scene.world_grid.metadata.start_cell, reservoir.cells)
	print("PHASE7_SMOKE_STAGE witness cells=%d" % witness.size())
	if witness.is_empty():
		_fail("Could not derive executable reservoir witness")
		return
	var inventory_before: int = water.get_conserved_inventory()
	var worker_cell: Vector2i = scene.world_grid.metadata.start_cell
	for cell: Vector2i in witness:
		if scene.world_grid.is_traversable(cell):
			worker_cell = cell
			continue
		var designation: Dictionary = scene.dig_system.designate_path([cell])
		var job = scene.dig_system.claim_next("phase7_smoke", worker_cell)
		if not bool(designation.get("ok", false)) or job == null:
			_fail("Reservoir witness was not executable")
			return
		var completion: Dictionary = scene.dig_system.advance_job("phase7_smoke", job.job_id, 1000.0)
		if not bool(completion.get("completed", false)):
			_fail("Reservoir witness excavation did not complete")
			return
		worker_cell = cell
		if not reservoir.hidden:
			break
	print("PHASE7_SMOKE_STAGE reservoir_revealed hidden=%s" % reservoir.hidden)
	if reservoir.hidden or int(reservoir.metadata.get("reveal_count", 0)) != 1:
		_fail("Runtime excavation did not reveal reservoir exactly once")
		return
	if scene.signal_system.get_recognition_level("water_reservoir") != SignalSystemScript.RecognitionLevel.UNDERSTOOD:
		_fail("Reservoir reveal did not advance Moisture recognition")
		return
	var escape_reaction_observed := false
	for mouse in scene.colony_simulation.get_mice():
		escape_reaction_observed = escape_reaction_observed or bool(mouse.danger_state)
	if not escape_reaction_observed:
		_fail("Reservoir breach did not trigger mouse escape reaction")
		return
	for _tick: int in range(20):
		scene.colony_simulation.fixed_tick(0.2)
	print("PHASE7_SMOKE_STAGE water_ticked units=%d" % water.get_total_water_units())
	if water.get_total_water_units() <= 0 or water.get_conserved_inventory() != inventory_before:
		_fail("Runtime reservoir discharge is missing or violates conservation")
		return
	var endangered := false
	for mouse in scene.colony_simulation.get_mice():
		endangered = endangered or bool(mouse.danger_state)
	if endangered:
		_fail("Mouse remained stuck in short-term escape after reaching safety")
		return
	var seal_cell := _find_seal_cell(scene)
	if seal_cell.x < 0:
		_fail("Could not find a safe runtime seal work cell")
		return
	var material_before: int = scene.colony_simulation.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL)
	var seal_request: Dictionary = scene.colony_simulation.request_seal(seal_cell)
	print("PHASE7_SMOKE_STAGE seal_requested cell=%s" % seal_cell)
	if not bool(seal_request.get("ok", false)):
		_fail("Runtime seal request was rejected")
		return
	for _tick: int in range(500):
		scene.colony_simulation.fixed_tick(0.05)
		if scene.world_grid.is_sealed(seal_cell):
			break
	print("PHASE7_SMOKE_STAGE seal_loop completed=%s" % scene.world_grid.is_sealed(seal_cell))
	if not scene.world_grid.is_sealed(seal_cell):
		_fail("Autonomous runtime mice did not complete seal construction")
		return
	if scene.colony_simulation.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL) != material_before - 1:
		_fail("Runtime seal did not consume exactly one material")
		return
	var expect_debug := _expected_debug()
	if expect_debug:
		if scene.worldgen_debug_overlay.get_mode_name() != "WATER ACTIVE / FLOW":
			_fail("Development did not expose requested water debug overlay")
			return
	else:
		if scene.worldgen_debug_overlay.get_mode_name() != "OFF" or scene.worldgen_debug_overlay.visible:
			_fail("Release exposed Phase 7 water debug data")
			return
	print("PHASE7_WATER_SMOKE_PASS profile_debug=%s moisture_cells=%d water_units=%d reserve_units=%d seals=%d" % [
		expect_debug,
		moisture_cells,
		water.get_total_water_units(),
		water.get_remaining_reserve_units(),
		seals.get_completed_count(),
	])
	quit(0)


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


func _find_seal_cell(scene) -> Vector2i:
	var start: Vector2i = scene.world_grid.metadata.start_cell
	var distances: PackedInt32Array = scene.path_service.build_distance_field(start)
	for index: int in range(distances.size()):
		if distances[index] < 2:
			continue
		var cell: Vector2i = scene.world_grid.index_to_cell(index)
		if scene.world_grid.get_water_units(cell) > 0:
			continue
		var open_neighbors := 0
		for neighbor: Vector2i in scene.world_grid.get_cardinal_neighbors(cell):
			if scene.path_service.is_walkable(neighbor):
				open_neighbors += 1
		if open_neighbors >= 2:
			return cell
	return Vector2i(-1, -1)


func _expected_debug() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=") == "true"
	return true


func _fail(message: String) -> void:
	push_error("PHASE7_WATER_SMOKE_FAIL %s" % message)
	quit(1)
