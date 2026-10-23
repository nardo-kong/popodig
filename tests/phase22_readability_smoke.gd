extends SceneTree

var scene
var locale := "zh"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280, 720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="):
			locale = argument.trim_prefix("--locale=")
	scene = load("res://scenes/app/game_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.world_camera.set_process(false)
	TranslationServer.set_locale(locale)
	scene._slow_poll()
	scene._update_hud()
	scene._development_view._process(0.5)
	await create_timer(0.15).timeout
	var food
	var material
	for pile in scene.colony_simulation.get_item_system().get_piles():
		if pile.item_type == "FOOD":
			food = pile
		elif pile.item_type == "GENERAL_MATERIAL":
			material = pile
	await _hover(food.cell)
	if not _expect_tip("resource", "FOOD") or not str(scene._hover_view._info.title).contains(str(food.count)):
		_fail("Actual pointer hover does not identify food and its real quantity")
		return
	await _capture("food")
	await _hover(material.cell)
	if not _expect_tip("resource", "GENERAL_MATERIAL"):
		_fail("Actual pointer hover does not explain building material")
		return
	await _capture("materials")
	var clue = scene.worldgen_result.feature_registry.get_features("discovery")[0]
	await _hover(clue.anchor)
	if not scene._hover_view.visible or scene._hover_view._info.kind != "clue" or not scene._hover_view._info.has("glyph"):
		_fail("A wall clue is not identified separately from a supply pile")
		return
	await _capture("clue")
	# A presentation-only fixture puts an exposed root on an actual visible
	# wall. This verifies recognition and marker placement, not gameplay progress.
	var home: Vector2i = scene.world_grid.metadata.start_cell
	var root_cell := home + Vector2i(0, 2)
	var feature := GeneratedFeature.new("root_cluster", root_cell, [root_cell])
	feature.hidden = false
	feature.metadata = {"food_opportunity": true, "food_reserve_units": 8}
	scene.worldgen_result.feature_registry.add_feature(feature)
	scene.world_grid.set_feature_id(root_cell, feature.id)
	scene._discovery_view._fog.mark_stale()
	await create_timer(0.3).timeout
	scene._refresh_root_teaching()
	scene._development_view._process(0.5)
	await _hover(root_cell)
	if not _expect_tip("root", "ROOT") or not str(scene._hover_view._info.action).contains("4"):
		_fail("Exposed roots do not explain how to forage")
		return
	await _capture("roots")
	var paused_before: bool = scene._paused
	await _key(KEY_I)
	if not scene._guide_open or not scene._paused or not scene.world_camera.input_blocked:
		_fail("Actual I shortcut does not open and pause the picture guide")
		return
	if not Rect2(Vector2.ZERO, scene.get_node("UI/Root").size).encloses(scene._resource_guide.get_global_rect()):
		_fail("Picture guide leaves the viewport")
		return
	if scene._hover_view.visible:
		_fail("Hover card remains over a modal guide")
		return
	await _capture("guide")
	await _key(KEY_ESCAPE)
	if scene._guide_open or scene._paused != paused_before or scene.world_camera.input_blocked:
		_fail("Guide does not restore prior playing state")
		return
	# Hover is click-through: a normal left-click still designates nearby soil.
	var target := home
	for x: int in range(1, 9):
		var cell := home + Vector2i(-x, 0)
		if bool(scene.dig_system.inspect_designation(cell).ok):
			target = cell
			break
	if target == home:
		_fail("No ordinary reachable soil for click-through check")
		return
	await _hover(target)
	var position := _point(target)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = position
		root.push_input(click, true)
		await process_frame
	if scene.dig_system.get_designated_count() == 0:
		_fail("Hover card steals the normal digging click")
		return
	print("PHASE22_READABILITY_SMOKE_PASS locale=%s size=%d actual_pointer=true food=true materials=true clues=true roots=true guide_keys=true click_through=true" % [locale, root.size.x])
	scene.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0)


func _point(cell: Vector2i) -> Vector2:
	return scene.world_view.get_global_transform_with_canvas() * ((Vector2(cell) + Vector2.ONE * 0.5) * 16.0)


func _hover(cell: Vector2i) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _point(cell)
	motion.global_position = motion.position
	root.push_input(motion, true)
	await process_frame
	scene._refresh_hovered_cell()
	scene._update_inspector()
	scene._update_hover_tip(0.2)
	await process_frame


func _expect_tip(kind: String, icon: String) -> bool:
	if not scene._hover_view.visible:
		print("HOVER_DIAGNOSTIC selected=%s expected_kind=%s info=%s hovered_gui=%s actual_mouse=%s" % [scene._selected_cell, kind, scene._hover_view._info, root.gui_get_hovered_control(), root.get_mouse_position()])
		return false
	return scene._hover_view._info.kind == kind and scene._hover_view._info.icon == icon


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	scene._update_hover_tip(0.2)
	await process_frame


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	RenderingServer.force_draw(false)
	await process_frame
	root.get_texture().get_image().save_png("res://art/qa/screenshots/phase22_%s_%s_%d.png" % [name, locale, root.size.x])


func _fail(message: String) -> void:
	push_error("PHASE22_READABILITY_SMOKE_FAIL " + message)
	quit(1)
