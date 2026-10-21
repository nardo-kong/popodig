extends SceneTree

const Driver = preload("res://tests/phase20_development_smoke.gd")
const Zones = preload("res://src/domain/zones/zone.gd")
var scene


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/app/game_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	if scene.colony_simulation == null:
		_fail("Scene initialisation failed")
		return
	var colony = scene.colony_simulation
	var home: Vector2i = scene.world_grid.metadata.start_cell
	if not _resource("FOOD", 14):
		_fail("Early food could not be secured")
		return
	var storage: Array[Vector2i] = []
	for x: int in range(-2, 3):
		storage.append(home + Vector2i(x, 0))
	if not _zone(Zones.Type.SLEEPING, [home + Vector2i(-3, 0)]) or not _zone(Zones.Type.STORAGE, storage):
		_fail("Initial housing and storage could not be furnished")
		return
	if not _resource("STONE", 2) or not _resource("ORE", 4):
		_fail("Early workshop inputs could not be secured")
		return
	if not _zone(Zones.Type.PRODUCTION, [home + Vector2i(3, 0)]):
		_fail("Workshop setup failed")
		return
	var workshop = colony.get_zone_system().get_zone_at(home + Vector2i(3, 0))
	var production = colony.get_production_system()
	if not _craft(workshop.zone_id, "building", "GENERAL_MATERIAL", colony.get_item_system().get_total_count("GENERAL_MATERIAL") + 3):
		_fail("First construction batch failed")
		return
	if not _craft(workshop.zone_id, "metal", "METAL", 2) or not colony.get_capabilities().upgrade().ok:
		_fail("First shared capability could not be earned")
		return
	print("CAMPAIGN_STAGE reinforced time=%.1f" % scene._active_seconds)
	if not _resource("STONE", 8) or not _resource("ORE", 8) or not _craft(workshop.zone_id, "metal", "METAL", 4) or not colony.get_capabilities().upgrade().ok:
		_fail("Deep capability could not be earned")
		return
	var stability = colony.get_stability_system()
	var requested := false
	for x: int in range(-4, 5):
		var cell := home + Vector2i(x, -1)
		if stability.request_reinforce(cell).ok:
			requested = true
			break
	if not requested:
		for cell: Vector2i in scene.world_grid.get_cardinal_neighbors(home):
			if stability.request_reinforce(cell).ok:
				requested = true
				break
	for tick: int in range(4000):
		Driver.advance(scene)
		if stability.get_completed_count() > 0:
			break
	if stability.get_completed_count() == 0:
		_fail("A real reinforcement could not be completed")
		return
	var landmarks = scene.worldgen_result.feature_registry
	var old = landmarks.get_features("old_burrow")[0]
	if not _landmark(old):
		_fail("No safe old-burrow approach could be excavated")
		return
	var warm = landmarks.get_features("warm_chamber")[0]
	if not _landmark(warm):
		_fail("Warm chamber could not be reached")
		return
	scene._slow_poll()
	if not bool(scene._chapter_context().water_learned):
		var clues: Array[Vector2i] = []
		for index: int in range(scene.world_grid.width * scene.world_grid.height):
			var cell: Vector2i = scene.world_grid.index_to_cell(index)
			if scene.world_grid.get_moisture_signal(cell) > 0 and scene.world_grid.get_feature_id(cell) < 0 and not scene.world_grid.is_protected(cell):
				clues.append(cell)
		clues.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(home) < b.distance_squared_to(home))
		for cell: Vector2i in clues:
			if Driver._dig_to(scene, cell):
				scene._slow_poll()
				if bool(scene._chapter_context().water_learned):
					break
	if not _resource("FOOD", 14):
		_fail("Colony could not replenish food after expansion")
		return
	for tick: int in range(400):
		Driver.advance(scene)
	scene._slow_poll()
	if scene.chapter_model.current_chapter < 3:
		_fail("Campaign milestone held despite supplies/tools/routes: %s" % scene._chapter_context())
		return
	print("CAMPAIGN_STAGE old_burrow mice=%d time=%.1f" % [colony.get_mice().size(), scene._active_seconds])
	var beds: Array[Vector2i] = []
	var new_store: Array[Vector2i] = []
	for x: int in range(-2, 3):
		beds.append(warm.anchor + Vector2i(x, 0))
		new_store.append(warm.anchor + Vector2i(x, 1))
	if not _zone(Zones.Type.SLEEPING, beds) or not _zone(Zones.Type.STORAGE, new_store):
		_fail("Warm housing and nearby storage could not be furnished")
		return
	# A deliberate relocation: retire the old store so haulers supply the new home.
	colony.get_zone_system().erase_cells(storage)
	for tick: int in range(3000):
		Driver.advance(scene)
		if scene._warm_food_stock() >= colony.get_mice().size() * 2:
			break
	for attempt: int in range(10):
		if scene._warm_food_stock() >= colony.get_mice().size() * 2:
			break
		if not _resource("FOOD", colony.get_item_system().get_total_count("FOOD") + 5, warm.anchor):
			_fail("Could not supply final home")
			return
		for tick: int in range(2000):
			Driver.advance(scene)
	scene._slow_poll()
	if not scene.chapter_model.campaign_complete:
		_fail("Final home was not accepted: stock=%d context=%s" % [scene._warm_food_stock(), scene._chapter_context()])
		return
	var saved: Dictionary = JSON.parse_string(JSON.stringify(scene._build_save_document()))
	scene.SaveServiceScript.save_game("/private/tmp/popodig-campaign-complete.json", saved)
	if not scene._apply_loaded_document(saved).ok or not scene.chapter_model.campaign_complete or not scene.home_progress.unlocked.has("deep_home"):
		_fail("Completed campaign and home memories did not survive reload")
		return
	if root.get_node("AppConfig").get_profile_name() == "release" and scene._telemetry != null:
		_fail("Release unexpectedly collected telemetry")
		return
	print("PHASE20_CAMPAIGN_SMOKE_PASS input=automated_normal_commands cheats=false simulated_seconds=%.1f mice=%d home_food=%d memories=%d" % [scene._active_seconds, colony.get_mice().size(), scene._warm_food_stock(), scene.home_progress.unlocked.size()])
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--capture":
			scene.world_camera.focus_cell(warm.anchor, scene._logical_cell_size)
			scene._update_hud()
			await create_timer(0.6).timeout
			RenderingServer.force_draw(false)
			await process_frame
			var image := root.get_texture().get_image()
			if image != null:
				image.save_png("res://art/qa/screenshots/phase20_warm_home.png")
	if scene._telemetry != null:
		scene._telemetry_sample_tick()
		var evidence := FileAccess.open("res://art/qa/reports/phase20_campaign_telemetry.json", FileAccess.WRITE)
		if evidence != null:
			evidence.store_string(JSON.stringify(scene._telemetry.to_summary_dict(), "  "))
			evidence.close()
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	call_deferred("quit", 0)


func _resource(item: String, minimum: int, origin: Vector2i = Vector2i(-1, -1)) -> bool:
	var colony = scene.colony_simulation
	print("CAMPAIGN_RESOURCE item=%s need=%d stock=%d time=%.1f" % [item, minimum, colony.get_item_system().get_total_count(item), scene._active_seconds])
	if origin.x < 0:
		origin = scene.world_grid.metadata.start_cell
	if item == "FOOD" and colony.get_item_system().get_total_count(item) < minimum:
		var roots: Array = scene.worldgen_result.feature_registry.get_features("root_cluster")
		roots.sort_custom(func(a, b) -> bool: return a.anchor.distance_squared_to(origin) < b.anchor.distance_squared_to(origin))
		for root_feature in roots:
			if not bool(root_feature.metadata.get("food_opportunity", false)) or int(root_feature.metadata.get("food_reserve_units", 0)) <= 0:
				continue
			print("CAMPAIGN_ROOT target=%s reserve=%d" % [root_feature.anchor, int(root_feature.metadata.get("food_reserve_units", 0))])
			var exposed := false
			for cell: Vector2i in root_feature.cells:
				for neighbor: Vector2i in scene.world_grid.get_cardinal_neighbors(cell):
					if Driver._dig_to(scene, neighbor):
						if not root_feature.hidden and _zone(Zones.Type.FOOD_FORAGE, [neighbor]):
							exposed = true
							break
				if exposed:
					break
			if exposed:
				for tick: int in range(1800):
					Driver.advance(scene)
					if colony.get_item_system().get_total_count(item) >= minimum:
						return true
	var choices: Array = []
	for feature in scene.worldgen_result.feature_registry.get_features("discovery"):
		if bool(feature.metadata.get("claimed", false)):
			continue
		var definition: Dictionary = scene.DiscoveryScript.definition_for(str(feature.metadata.definition_id))
		if str(definition.get("item", "")) == item and colony.get_capabilities().can_dig(feature.anchor):
			choices.append(feature)
	choices.sort_custom(func(a, b) -> bool: return a.anchor.distance_squared_to(origin) < b.anchor.distance_squared_to(origin))
	for feature in choices:
		if colony.get_item_system().get_total_count(item) >= minimum:
			return true
		Driver._dig_to(scene, feature.anchor)
	return colony.get_item_system().get_total_count(item) >= minimum


func _zone(type: int, cells: Array[Vector2i]) -> bool:
	var zones = scene.colony_simulation.get_zone_system()
	for cell: Vector2i in cells:
		if not scene.world_grid.is_traversable(cell) and not Driver._dig_to(scene, cell):
			return false
	if not zones.paint_zone(type, cells).ok:
		return false
	for tick: int in range(4000):
		Driver.advance(scene)
		var ready := true
		for cell: Vector2i in cells:
			var zone = zones.get_zone_at(cell)
			if zone == null or not zone.valid or zone.setup_state != Zones.SetupState.SET_UP:
				ready = false
		if ready:
			return true
	return false


func _craft(zone_id: int, recipe: String, item: String, amount: int) -> bool:
	var colony = scene.colony_simulation
	var production = colony.get_production_system()
	var selected := false
	for tick: int in range(2000):
		if production.set_recipe(zone_id, recipe).ok:
			selected = true
			break
		Driver.advance(scene)
	if not selected:
		return false
	for tick: int in range(10000):
		Driver.advance(scene)
		if colony.get_item_system().get_total_count(item) >= amount:
			production.set_enabled(zone_id, false)
			return true
	production.set_enabled(zone_id, false)
	return false


func _fail(message: String) -> void:
	push_error("PHASE20_CAMPAIGN_SMOKE_FAIL " + message)
	quit(1)


func _landmark(feature) -> bool:
	if not feature.hidden:
		return true
	var choices: Array[Vector2i] = []
	for cell: Vector2i in feature.cells:
		for neighbor: Vector2i in scene.world_grid.get_cardinal_neighbors(cell):
			if not choices.has(neighbor) and not scene.world_grid.is_protected(neighbor):
				choices.append(neighbor)
	var home: Vector2i = scene.world_grid.metadata.start_cell
	choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(home) < b.distance_squared_to(home))
	for cell: Vector2i in choices:
		if Driver._dig_to(scene, cell) and not feature.hidden:
			return true
	return not feature.hidden
