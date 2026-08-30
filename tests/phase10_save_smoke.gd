extends SceneTree

const SaveServiceScript = preload("res://src/infrastructure/persistence/save_service.gd")

# Phase 10 save/load smoke (docs/tech/15_DATA_SAVE_SPEC.md §16): drives the
# runtime app into an active water breach, saves the full document, loads it
# into a second app instance through the pending-load path, then compares
# terrain topology, water conservation, feature state, zones, and mice, and
# reports save/load performance timings.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/app/game_app.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var source = packed.instantiate()
	root.add_child(source)
	source._paused = true
	await process_frame
	await process_frame
	print("PHASE10_SMOKE_STAGE app_ready")
	var water = source.water_system
	if water == null:
		_fail("Runtime WaterSystem is missing")
		return
	var reservoirs: Array = source.worldgen_result.feature_registry.get_features("water_reservoir")
	if reservoirs.is_empty():
		_fail("Generated runtime world has no reservoir")
		return
	var reservoir = reservoirs[0]
	for candidate in reservoirs:
		if candidate.required:
			reservoir = candidate
			break
	var witness := _potential_path(source.world_grid, source.world_grid.metadata.start_cell, reservoir.cells)
	if witness.is_empty():
		_fail("Could not derive executable reservoir witness")
		return
	var worker_cell: Vector2i = source.world_grid.metadata.start_cell
	var dug_tunnel := Vector2i(-1, -1)
	for cell: Vector2i in witness:
		if source.world_grid.is_traversable(cell):
			worker_cell = cell
			continue
		var designation: Dictionary = source.dig_system.designate_path([cell])
		var job = source.dig_system.claim_next("phase10_smoke", worker_cell)
		if not bool(designation.get("ok", false)) or job == null:
			_fail("Reservoir witness was not executable")
			return
		var completion: Dictionary = source.dig_system.advance_job("phase10_smoke", job.job_id, 1000.0)
		if not bool(completion.get("completed", false)):
			_fail("Reservoir witness excavation did not complete")
			return
		worker_cell = cell
		dug_tunnel = cell
		if not reservoir.hidden:
			break
	for _tick: int in range(6):
		source.colony_simulation.fixed_tick(0.2)
	if water.get_total_water_units() <= 0:
		_fail("Mid-breach state has no discharged water to persist")
		return
	# Regression coverage for the F9 load-order bug: park a mouse inside a
	# tunnel that only exists in the save (the fresh generated world has it
	# solid), so the load must rebuild pathfinding before restoring mice.
	if dug_tunnel.x >= 0:
		source.colony_simulation.get_mice()[0].current_cell = dug_tunnel
	print("PHASE10_SMOKE_STAGE mid_breach units=%d hidden=%s dug_tunnel=%s" % [water.get_total_water_units(), reservoir.hidden, dug_tunnel])

	var save_path := OS.get_environment("TEMP").path_join("digdown_phase10_smoke_save.json")
	DirAccess.remove_absolute(save_path)
	var save_started := Time.get_ticks_usec()
	var document: Dictionary = source._build_save_document()
	var build_ms := float(Time.get_ticks_usec() - save_started) / 1000.0
	var write_result: Dictionary = SaveServiceScript.save_game(save_path, document)
	var write_ms := float(Time.get_ticks_usec() - save_started) / 1000.0 - build_ms
	if not bool(write_result.ok):
		_fail("Save write failed: %s" % String(write_result.error))
		return
	var header: Dictionary = document.header
	if int(header.save_schema_version) != SaveServiceScript.SAVE_SCHEMA_VERSION:
		_fail("Save header schema version mismatch")
		return
	var file_size := FileAccess.open(save_path, FileAccess.READ).get_length()
	print("PHASE10_SMOKE_STAGE saved build_ms=%.2f write_ms=%.2f bytes=%d" % [build_ms, write_ms, file_size])

	var loaded = packed.instantiate()
	var app_script: Script = loaded.get_script()
	app_script.set("_pending_load_path", save_path)
	root.add_child(loaded)
	loaded._paused = true
	await process_frame
	await process_frame
	# Pure load+apply cost measured on a throwaway third instance so the
	# comparison instance only ever applies the document once (via _ready).
	var load_started := Time.get_ticks_usec()
	var load_result: Dictionary = SaveServiceScript.load_game(save_path)
	if not bool(load_result.ok):
		_fail("Save load failed: %s" % String(load_result.error))
		return
	var timing = packed.instantiate()
	root.add_child(timing)
	timing._paused = true
	await process_frame
	var apply_result: Dictionary = timing._apply_loaded_document(load_result.data)
	var load_ms := float(Time.get_ticks_usec() - load_started) / 1000.0
	timing.queue_free()
	if not bool(apply_result.ok):
		_fail("Loaded document apply failed: %s" % String(apply_result.error))
		return
	print("PHASE10_SMOKE_STAGE loaded load_ms=%.2f" % load_ms)

	if not _terrain_topology_matches(source, loaded):
		_fail("Terrain topology differs after load (spec §16)")
		return
	if source.water_system.get_conserved_inventory() != loaded.water_system.get_conserved_inventory():
		_fail("Water inventory is not conserved after load (spec §16)")
		return
	if source.water_system.get_total_water_units() != loaded.water_system.get_total_water_units():
		_fail("Placed water units differ after load (spec §16)")
		return
	# JSON parsing promotes every int to float, so post-load save data is
	# compared by semantic equivalence (int 0 == float 0.0), not by hash.
	if not _save_data_equivalent(source.worldgen_result.feature_registry.to_save_data(), loaded.worldgen_result.feature_registry.to_save_data()):
		_fail("Feature reveal/reserve state differs after load (spec §16)")
		return
	if not _save_data_equivalent(source.colony_simulation.get_zone_system().to_save_data(), loaded.colony_simulation.get_zone_system().to_save_data()):
		_fail("Zone state differs after load (spec §16)")
		return
	if source.colony_simulation.get_mice().size() != loaded.colony_simulation.get_mice().size():
		_fail("Mouse count differs after load (spec §16)")
		return
	if dug_tunnel.x >= 0:
		# The rebuilt cache must agree with the restored grid (a flooded
		# tunnel is legitimately unwalkable; a solid fresh-world cell is not).
		var expected_walkable: bool = loaded.world_grid.is_traversable(dug_tunnel) and loaded.world_grid.get_water_units(dug_tunnel) <= 1
		if loaded.path_service.is_walkable(dug_tunnel) != expected_walkable:
			_fail("Path service did not rebuild walkability over the restored world")
			return
	if not _save_data_equivalent(source.colony_simulation.get_item_system().to_save_data(), loaded.colony_simulation.get_item_system().to_save_data()):
		_fail("Item piles differ after load (spec §16)")
		return
	for mouse in loaded.colony_simulation.get_mice():
		if not loaded.world_grid.is_traversable(mouse.current_cell):
			_fail("Loaded mouse is not on a traversable cell (spec §16)")
			return
	var rescued_item_types := ["FOOD", "GENERAL_MATERIAL"]
	for item_type: String in rescued_item_types:
		if source.colony_simulation.get_item_system().get_total_count(item_type) != loaded.colony_simulation.get_item_system().get_total_count(item_type):
			_fail("Item total for %s differs after load (spec §16)" % item_type)
			return
	print("PHASE10_SAVE_SMOKE_PASS bytes=%d build_ms=%.2f write_ms=%.2f load_ms=%.2f" % [file_size, build_ms, write_ms, load_ms])
	DirAccess.remove_absolute(save_path)
	quit(0)


func _save_data_equivalent(expected: Variant, actual: Variant) -> bool:
	if expected is Dictionary and actual is Dictionary:
		if (expected as Dictionary).size() != (actual as Dictionary).size():
			return false
		for key: Variant in (expected as Dictionary).keys():
			if not (actual as Dictionary).has(key):
				return false
			if not _save_data_equivalent((expected as Dictionary)[key], (actual as Dictionary)[key]):
				return false
		return true
	if expected is Array and actual is Array:
		if (expected as Array).size() != (actual as Array).size():
			return false
		for index: int in range((expected as Array).size()):
			if not _save_data_equivalent((expected as Array)[index], (actual as Array)[index]):
				return false
		return true
	if expected is Vector2i and actual is Vector2i:
		return expected == actual
	if expected is float or expected is int or actual is float or actual is int:
		if expected is bool or actual is bool:
			return expected == actual
		return is_equal_approx(float(expected), float(actual))
	return expected == actual


func _terrain_topology_matches(source, loaded) -> bool:
	if source.world_grid.width != loaded.world_grid.width or source.world_grid.height != loaded.world_grid.height:
		return false
	for y: int in range(source.world_grid.height):
		for x: int in range(source.world_grid.width):
			var cell := Vector2i(x, y)
			if source.world_grid.get_material(cell) != loaded.world_grid.get_material(cell):
				return false
			if source.world_grid.is_traversable(cell) != loaded.world_grid.is_traversable(cell):
				return false
	return true


func _potential_path(world, start: Vector2i, goals: Array) -> Array[Vector2i]:
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
	printerr("PHASE10_SAVE_SMOKE_FAIL " + message)
	quit(1)
