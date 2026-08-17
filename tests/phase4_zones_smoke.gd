extends SceneTree

const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")


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
	var zones = scene.colony_simulation.get_zone_system()
	var app_config = root.get_node("AppConfig")
	if not app_config.cheats_enabled() and not zones.get_zones().is_empty():
		_fail("Release accepted the Phase 4 QA zone setup argument")
		return
	var home: Vector2i = scene.world_grid.metadata.start_cell
	var sleeping: Array[Vector2i] = [home + Vector2i(-3, -1), home + Vector2i(-2, -1), home + Vector2i(-1, -1)]
	var storage_top: Array[Vector2i] = [home + Vector2i(1, -1), home + Vector2i(2, -1)]
	var storage_bottom: Array[Vector2i] = [home + Vector2i(1, 0), home + Vector2i(2, 0)]
	var food: Array[Vector2i] = [home + Vector2i(-2, 1), home + Vector2i(-1, 1)]
	_send_tool_key(scene, KEY_2)
	_send_drag(scene, sleeping[0], sleeping[-1], MOUSE_BUTTON_LEFT)
	_send_tool_key(scene, KEY_3)
	_send_drag(scene, storage_top[0], storage_top[-1], MOUSE_BUTTON_LEFT)
	_send_drag(scene, storage_bottom[0], storage_bottom[-1], MOUSE_BUTTON_LEFT)
	_send_tool_key(scene, KEY_4)
	_send_drag(scene, food[0], food[-1], MOUSE_BUTTON_LEFT)
	await process_frame
	if zones.get_zones().size() != 3:
		_fail("Player-facing zone tools did not create exactly three connected zones")
		return
	if not String(scene.get_node("%ToolStatusLabel").text).contains("current: FOOD/FORAGE ZONE"):
		_fail("Compact HUD does not report the selected player tool")
		return
	var setup_completed := false
	var fixed_ticks := 0
	while fixed_ticks < 1600:
		scene.colony_simulation.fixed_tick(0.05)
		fixed_ticks += 1
		setup_completed = _all_zones_set_up(zones)
		if setup_completed and _all_items_stored(scene) and scene.colony_simulation.get_job_system().get_pending_count() == 0 and scene.colony_simulation.get_job_system().get_active_count() == 0:
			break
	if not setup_completed or not _all_items_stored(scene):
		_fail("Autonomous mice did not set up zones and store loose supplies")
		return
	if not _storage_respects_capacity(scene):
		_fail("Autonomous storage exceeded a logical cell capacity")
		return
	var sleeper = scene.colony_simulation.get_mice()[0]
	sleeper.rest = 0.05
	var saw_zone_rest := false
	for _tick: int in range(240):
		scene.colony_simulation.fixed_tick(0.05)
		if sleeper.get_state_name() == "RESTING":
			var zone: Zone = zones.get_zone_at(sleeper.current_cell)
			if zone != null and zone.zone_type == ZoneScript.Type.SLEEPING:
				saw_zone_rest = true
				break
	if not saw_zone_rest:
		_fail("Low-rest mouse did not autonomously use the Sleeping zone")
		return
	var pile = _first_stored_pile(scene)
	if pile == null:
		_fail("No stored pile exists for resize recovery")
		return
	var resize_cell: Vector2i = pile.cell
	var food_before := _owned_total(scene, ItemSystemScript.FOOD)
	var material_before := _owned_total(scene, ItemSystemScript.GENERAL_MATERIAL)
	_send_tool_key(scene, KEY_3)
	_send_drag(scene, resize_cell, resize_cell, MOUSE_BUTTON_RIGHT)
	var relocated := false
	for _tick: int in range(800):
		scene.colony_simulation.fixed_tick(0.05)
		if (
			scene.colony_simulation.get_item_system().get_count_at(resize_cell) == 0
			and scene.colony_simulation.get_job_system().get_pending_count() == 0
			and scene.colony_simulation.get_job_system().get_active_count() == 0
			and _all_items_stored(scene)
		):
			relocated = true
			break
	if not relocated:
		_fail("Player Storage erase did not trigger autonomous relocation")
		return
	if _owned_total(scene, ItemSystemScript.FOOD) != food_before or _owned_total(scene, ItemSystemScript.GENERAL_MATERIAL) != material_before:
		_fail("Zone resize duplicated or destroyed colony resources")
		return
	print("PHASE4_ZONES_SMOKE_PASS profile_debug=%s zones=%d fixed_ticks=%d food=%d material=%d" % [
		_get_expected_debug_visibility(),
		zones.get_zones().size(),
		fixed_ticks,
		scene.colony_simulation.get_item_system().get_total_count(ItemSystemScript.FOOD),
		scene.colony_simulation.get_item_system().get_total_count(ItemSystemScript.GENERAL_MATERIAL),
	])
	quit(0)


func _send_tool_key(scene: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	scene._unhandled_input(event)


func _send_drag(scene: Node, start_cell: Vector2i, end_cell: Vector2i, button: MouseButton) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.position = _screen_position(scene, start_cell)
	scene._unhandled_input(press)
	if start_cell != end_cell:
		var motion := InputEventMouseMotion.new()
		motion.position = _screen_position(scene, end_cell)
		scene._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = button
	release.pressed = false
	release.position = _screen_position(scene, end_cell)
	scene._unhandled_input(release)


func _screen_position(scene: Node, cell_coord: Vector2i) -> Vector2:
	var local_center: Vector2 = (Vector2(cell_coord) + Vector2(0.5, 0.5)) * scene._logical_cell_size
	return scene.world_view.get_global_transform_with_canvas() * local_center


func _all_zones_set_up(zones) -> bool:
	for zone: Zone in zones.get_zones():
		if not zone.valid or zone.setup_state != ZoneScript.SetupState.SET_UP:
			return false
	return zones.get_zones().size() == 3


func _all_items_stored(scene: Node) -> bool:
	var zones = scene.colony_simulation.get_zone_system()
	for pile in scene.colony_simulation.get_item_system().get_piles():
		if pile.count <= 0:
			continue
		var zone: Zone = zones.get_zone_at(pile.cell)
		if zone == null or zone.zone_type != ZoneScript.Type.STORAGE or not zone.valid or zone.setup_state != ZoneScript.SetupState.SET_UP:
			return false
	return true


func _first_stored_pile(scene: Node):
	var zones = scene.colony_simulation.get_zone_system()
	for pile in scene.colony_simulation.get_item_system().get_piles():
		var zone: Zone = zones.get_zone_at(pile.cell)
		if pile.count > 0 and zone != null and zone.zone_type == ZoneScript.Type.STORAGE:
			return pile
	return null


func _storage_respects_capacity(scene: Node) -> bool:
	var items = scene.colony_simulation.get_item_system()
	for zone: Zone in scene.colony_simulation.get_zone_system().get_zones_by_type(ZoneScript.Type.STORAGE):
		for cell: Vector2i in zone.cells:
			var capacity: int = items.get_cell_capacity(cell)
			if capacity <= 0 or items.get_count_at(cell) > capacity:
				return false
	return true


func _owned_total(scene: Node, item_type: String) -> int:
	var total: int = scene.colony_simulation.get_item_system().get_total_count(item_type)
	for mouse in scene.colony_simulation.get_mice():
		if mouse.carried_item_type == item_type:
			total += int(mouse.carried_item_count)
	return total


func _get_expected_debug_visibility() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=") == "true"
	return true


func _fail(message: String) -> void:
	push_error("PHASE4_ZONES_SMOKE_FAIL %s" % message)
	quit(1)
