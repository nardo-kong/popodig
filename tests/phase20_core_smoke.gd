extends SceneTree

const ZoneScript = preload("res://src/domain/zones/zone.gd")
const DiscoveryViewScript = preload("res://src/presentation/world/discovery_view.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/app/game_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	if scene.colony_simulation == null:
		_fail("Main scene did not initialise")
		return
	var colony = scene.colony_simulation
	var items = colony.get_item_system()
	var registry = scene.worldgen_result.feature_registry
	var target = registry.get_features("discovery")[1]
	var goals: Array[Vector2i] = [target.anchor]
	var path: Array[Vector2i] = scene._qa_potential_path(goals)
	if path.is_empty():
		_fail("Initial building-material promise has no legal approach")
		return
	var before: int = items.get_total_count("GENERAL_MATERIAL")
	# Use actual autonomous mouse work, not instant QA excavation or reward injection.
	for cell: Vector2i in path:
		if bool(target.metadata.get("claimed", false)):
			break
		if scene.world_grid.is_traversable(cell):
			continue
		if not scene.dig_system.designate_path([cell]).ok:
			_fail("Approach is not freely designatable")
			return
		for tick: int in range(2400):
			colony.fixed_tick(0.05)
			if scene.world_grid.is_traversable(cell):
				break
	if not bool(target.metadata.get("claimed", false)) or items.get_total_count("GENERAL_MATERIAL") != before + 6:
		_fail("Mouse excavation failed to release the material discovery")
		return
	var zones = colony.get_zone_system()
	var home: Vector2i = scene.world_grid.metadata.start_cell
	if not zones.paint_zone(ZoneScript.Type.STORAGE, [home + Vector2i(1, 0), home + Vector2i(2, 0)]).ok:
		_fail("Could not designate storage")
		return
	for tick: int in range(2400):
		colony.fixed_tick(0.05)
	var housed := 0
	for pile in items.get_piles():
		if pile.item_type == "GENERAL_MATERIAL":
			var zone = zones.get_zone_at(pile.cell)
			if zone != null and zone.zone_type == ZoneScript.Type.STORAGE:
				housed += pile.count
	if housed != before + 5:
		_fail("New material was not autonomously hauled after one setup material was used")
		return
	var document: Dictionary = JSON.parse_string(JSON.stringify(scene._build_save_document()))
	if int(document.header.save_schema_version) != 3:
		_fail("2.0 save schema was not applied")
		return
	if not scene._apply_loaded_document(document).ok:
		_fail("Full scene save/load failed")
		return
	var claim: Dictionary = colony.get_discovery_system().claim(target.id, target.metadata.exposure)
	if claim.ok or claim.get("reason", "") != "ALREADY_CLAIMED":
		_fail("Scene reload allowed duplicate discovery reward")
		return
	print("PHASE20_CORE_SMOKE_PASS material_housed=%d schema=3 autonomous_dig_and_haul=true" % housed)
	quit(0)


func _fail(message: String) -> void:
	push_error("PHASE20_CORE_SMOKE_FAIL " + message)
	quit(1)
