extends SceneTree

const ZoneScript = preload("res://src/domain/zones/zone.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/app/game_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	if scene.colony_simulation == null:
		_fail("Scene initialisation failed")
		return
	var colony = scene.colony_simulation
	for definition_id: String in ["stone_seam", "ore_seam"]:
		var choices: Array = []
		for feature in scene.worldgen_result.feature_registry.get_features("discovery"):
			if str(feature.metadata.definition_id) == definition_id and colony.get_capabilities().can_dig(feature.anchor):
				choices.append(feature)
		choices.sort_custom(func(a, b) -> bool:
			return a.anchor.distance_squared_to(scene.world_grid.metadata.start_cell) < b.anchor.distance_squared_to(scene.world_grid.metadata.start_cell)
		)
		var collected := false
		for feature in choices:
			if _dig_to(scene, feature.anchor):
				collected = bool(feature.metadata.get("claimed", false))
				if collected:
					break
		if not collected:
			_fail("Could not autonomously reach resource " + definition_id)
			return
	var home: Vector2i = scene.world_grid.metadata.start_cell
	var zones = colony.get_zone_system()
	var result: Dictionary = zones.paint_zone(ZoneScript.Type.PRODUCTION, [home + Vector2i(2, 0)])
	if not result.ok:
		_fail("Workshop could not be designated")
		return
	var zone = zones.get_zone_at(home + Vector2i(2, 0))
	var production = colony.get_production_system()
	if not _wait_batches(colony, 1):
		_fail("Raw stone did not become usable building materials")
		return
	production.set_enabled(zone.zone_id, false)
	if not production.set_recipe(zone.zone_id, "metal").ok or not _wait_batches(colony, 3):
		_fail("Ore did not become two physical metal units")
		return
	production.set_enabled(zone.zone_id, false)
	var upgrade: Dictionary = colony.get_capabilities().upgrade()
	if not upgrade.ok:
		_fail("Produced metal could not unlock shared tools")
		return
	var save: Dictionary = JSON.parse_string(JSON.stringify(scene._build_save_document()))
	if not scene._apply_loaded_document(save).ok or colony.get_capabilities().level != 1:
		_fail("Development state did not survive scene reload")
		return
	print("PHASE20_DEVELOPMENT_SMOKE_PASS actual_discovery_to_production_to_upgrade=true batches=%d loaded_steps=%d" % [production.completed_batches, colony.loaded_travel_steps])
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--capture":
			scene._slow_poll()
			scene._update_hud()
			await create_timer(0.6).timeout
			await process_frame
			await process_frame
			RenderingServer.force_draw(false)
			await process_frame
			var image := root.get_texture().get_image()
			if image == null or image.is_empty() or image.save_png("res://art/qa/screenshots/phase20_workshop.png") != OK:
				_fail("Workshop evidence image failed")
				return
	quit(0)


func _wait_batches(colony, expected: int) -> bool:
	for tick: int in range(6000):
		colony.fixed_tick(0.05)
		if colony.get_production_system().completed_batches >= expected:
			return true
	return false


func _dig_to(scene, target: Vector2i) -> bool:
	var world = scene.world_grid
	var start: Vector2i = world.metadata.start_cell
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: Vector2i(-1, -1)}
	var index := 0
	while index < queue.size() and not previous.has(target):
		var current: Vector2i = queue[index]
		index += 1
		for cell: Vector2i in world.get_cardinal_neighbors(current):
			if previous.has(cell) or world.is_exterior(cell) or world.is_protected(cell):
				continue
			if world.is_solid(cell) and not scene.colony_simulation.get_capabilities().can_dig(cell):
				continue
			previous[cell] = current
			queue.append(cell)
	if not previous.has(target):
		return false
	var path: Array[Vector2i] = []
	var current := target
	while current != start:
		path.push_front(current)
		current = previous[current]
	for cell: Vector2i in path:
		if world.is_traversable(cell):
			continue
		if not scene.dig_system.designate_path([cell]).ok:
			return false
		for tick: int in range(3000):
			scene.colony_simulation.fixed_tick(0.05)
			if world.is_traversable(cell):
				break
		if not world.is_traversable(cell):
			print("SMOKE_APPROACH_BLOCKED cell=%s mouse=%s warning=%s" % [cell, scene.colony_simulation.get_mice()[0].get_debug_snapshot(), scene.colony_simulation.get_stability_system().get_warning_level(cell)])
			return false
	return true


func _fail(message: String) -> void:
	push_error("PHASE20_DEVELOPMENT_SMOKE_FAIL " + message)
	quit(1)
