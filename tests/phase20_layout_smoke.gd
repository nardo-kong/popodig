extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var width := 1280
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--width="):
			width = int(argument.trim_prefix("--width="))
	root.size = Vector2i(width, 720 if width == 1280 else 1080)
	var scene = load("res://scenes/app/game_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	var loaded: Dictionary = scene.SaveServiceScript.load_game("/private/tmp/popodig-campaign-complete.json")
	if not loaded.ok or not scene._apply_loaded_document(loaded.data).ok or not scene.chapter_model.campaign_complete:
		_fail("Run phase20_campaign_smoke first to create a genuine completed save")
		return
	scene._slow_poll()
	scene._update_hud()
	for index: int in range(3):
		scene._push_notification("layout_%d" % index, "Our warm home is complete. Keep exploring, collecting and shaping the burrow together.", scene._warm_chamber_anchor(), 0.0, 30.0)
	scene.notifications_view.refresh(scene._now_seconds)
	scene.world_camera.zoom = Vector2(2.0, 2.0)
	scene.world_camera.focus_cell(scene._warm_chamber_anchor() + Vector2i(0, 9), scene._logical_cell_size)
	await create_timer(0.65).timeout
	var development: Control
	for child in scene.get_node("UI/Root").get_children():
		if child is DevelopmentView:
			development = child
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	if development == null or not viewport_rect.encloses(development.get_global_rect()) or development.get_global_rect().intersects(scene.notifications_view.get_global_rect()):
		_fail("Development panel or notifications overlap/leave viewport")
		return
	RenderingServer.force_draw(false)
	await process_frame
	root.get_texture().get_image().save_png("res://art/qa/screenshots/phase20_warm_home_%d.png" % width)
	scene._toggle_collection_book()
	await create_timer(0.1).timeout
	if not viewport_rect.encloses(scene._collection_view.get_global_rect()):
		_fail("Collection panel leaves viewport")
		return
	RenderingServer.force_draw(false)
	await process_frame
	root.get_texture().get_image().save_png("res://art/qa/screenshots/phase20_collections_%d.png" % width)
	print("PHASE20_LAYOUT_SMOKE_PASS width=%d completed_save=true nonoverlap=true collection_bounds=true" % width)
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0)


func _fail(message: String) -> void:
	push_error("PHASE20_LAYOUT_SMOKE_FAIL " + message)
	quit(1)
