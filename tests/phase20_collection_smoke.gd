extends SceneTree

const Driver = preload("res://tests/phase20_development_smoke.gd")
const Discovery = preload("res://src/domain/features/discovery_system.gd")


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
		_fail("Scene did not initialise")
		return
	var book = scene.colony_simulation.get_collection_book()
	var choices: Array = []
	for feature in scene.worldgen_result.feature_registry.get_features("discovery"):
		if Discovery.COLLECTIBLES.has(str(feature.metadata.definition_id)) and scene.colony_simulation.get_capabilities().can_dig(feature.anchor):
			choices.append(feature)
	choices.sort_custom(func(a, b) -> bool:
		return a.anchor.distance_squared_to(scene.world_grid.metadata.start_cell) < b.anchor.distance_squared_to(scene.world_grid.metadata.start_cell)
	)
	for feature in choices:
		if Driver._dig_to(scene, feature.anchor) and book.unique_count() > 0:
			break
	if book.unique_count() == 0:
		_fail("No real collectible could be acquired")
		return
	var saved: Dictionary = JSON.parse_string(JSON.stringify(scene._build_save_document()))
	if not scene._apply_loaded_document(saved).ok or book.unique_count() == 0:
		_fail("Collection did not survive full-scene reload")
		return
	var key := InputEventKey.new()
	key.keycode = KEY_C
	key.pressed = true
	scene._unhandled_input(key)
	if not scene._book_open or not scene._paused:
		_fail("C shortcut failed to open and pause collection view")
		return
	if not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(scene._collection_view.get_global_rect()):
		_fail("Collection panel lies outside the viewport")
		return
	print("PHASE20_COLLECTION_SMOKE_PASS real_collectible=true preserved=%d total=18" % book.unique_count())
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--capture":
			scene._slow_poll()
			scene._update_hud()
			await create_timer(0.2).timeout
			RenderingServer.force_draw(false)
			await process_frame
			var image := root.get_texture().get_image()
			if image == null or image.save_png("res://art/qa/screenshots/phase20_collections.png") != OK:
				_fail("Collection capture failed")
				return
	scene._unhandled_input(key)
	if scene._book_open or scene._paused:
		_fail("Closing book did not restore prior pause state")
		return
	quit(0)


func _fail(message: String) -> void:
	push_error("PHASE20_COLLECTION_SMOKE_FAIL " + message)
	quit(1)
