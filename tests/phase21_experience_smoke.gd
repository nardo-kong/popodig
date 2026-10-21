extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280, 720)
	var locale := "en"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="):
			locale = argument.trim_prefix("--locale=")
	var scene = load("res://scenes/app/game_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	TranslationServer.set_locale(locale)
	scene.tutorial_label.text = scene.tr(scene._tutorial.current_text_key())
	scene._slow_poll()
	scene._update_hud()
	scene._update_inspector()
	var development
	for child in scene.get_node("UI/Root").get_children():
		if child is DevelopmentView:
			development = child
	development._process(0.5)
	await create_timer(0.15).timeout
	if development._show_workshops or is_instance_valid(development._upgrade) or development.size.y > 200:
		_fail("Fresh game overwhelms the player with advanced crafting")
		return
	if scene._toolbar_buttons.size() != 7:
		_fail("Free tool access is missing")
		return
	await _capture("opening_" + locale)
	scene._toggle_help()
	await create_timer(0.1).timeout
	if not scene._paused or not scene.world_camera.input_blocked or not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(scene._help_view.get_global_rect()):
		_fail("Help fails to pause or leaves viewport")
		return
	await _capture("help_" + locale)
	scene._toggle_help()
	if scene._paused or scene.world_camera.input_blocked:
		_fail("Help does not restore prior playing state")
		return
	scene._paused = true
	scene._toggle_help()
	scene._toggle_help()
	if not scene._paused:
		_fail("Help loses an existing pause")
		return
	scene._toggle_settings()
	scene._toggle_settings()
	if not scene._paused:
		_fail("Settings loses an existing pause")
		return
	scene._paused = false
	scene._choose_speed(3)
	scene._simulation_accumulator = 0.0
	var simulated_before: float = scene._simulated_seconds
	scene._process(0.05)
	if not is_equal_approx(scene._simulated_seconds - simulated_before, 0.15):
		_fail("Three-times speed changed fixed-tick accounting")
		return
	scene._paused = true
	simulated_before = scene._simulated_seconds
	scene._process(0.2)
	if scene._simulated_seconds != simulated_before:
		_fail("Paused fast-forward still advances simulation")
		return
	scene._slow_for_danger()
	if scene.time_control.speed != 1:
		_fail("Danger did not visibly restore normal speed")
		return
	# UI fixture only: verify state-dependent affordances, not gameplay success.
	var home: Vector2i = scene.world_grid.metadata.start_cell
	scene.colony_simulation.add_item_pile("STONE", home, 2)
	development._process(0.5)
	if not development._show_workshops or not development._upgrade.disabled:
		_fail("Workshop progression or unaffordable upgrade state is misleading")
		return
	scene.colony_simulation.add_item_pile("METAL", home, 2)
	development._process(0.5)
	if development._upgrade.disabled:
		_fail("Reachable complete cost did not enable the upgrade")
		return
	development._upgrade.pressed.emit()
	if scene.colony_simulation.get_capabilities().level != 1:
		_fail("Upgrade button is not wired to authoritative capability")
		return
	var zones = scene.colony_simulation.get_zone_system()
	if not zones.paint_zone(Zone.Type.PRODUCTION, [home + Vector2i(1, 0)]).ok:
		_fail("Workshop locator fixture could not be designated")
		return
	development._process(0.5)
	var zone = zones.get_zone_at(home + Vector2i(1, 0))
	scene.world_camera.position = Vector2.ZERO
	development._focus_buttons[zone.zone_id].pressed.emit()
	if scene.world_camera.position.distance_to((Vector2(zone.identity_anchor) + Vector2.ONE * 0.5) * 16.0) > 16:
		_fail("Workshop locator button did not focus the actual workshop")
		return
	var saved_view: Dictionary = scene._build_save_document()
	var camera_before: Vector2 = scene.world_camera.position
	scene.world_camera.position = Vector2.ZERO
	if not scene._apply_loaded_document(saved_view).ok or scene.world_camera.position.distance_to(camera_before) > 16:
		_fail("Loading lost the player camera location")
		return
	scene._toolbar_buttons[scene.Tool.PRODUCTION].pressed.emit()
	if scene._current_tool != scene.Tool.PRODUCTION:
		_fail("Clickable toolbar does not select workshop tool")
		return
	print("PHASE21_EXPERIENCE_SMOKE_PASS locale=%s progressive_ui=true help_pause=true real_buttons=true" % locale)
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0)


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	RenderingServer.force_draw(false)
	await process_frame
	root.get_texture().get_image().save_png("res://art/qa/screenshots/phase21_%s%s.png" % [name, "_1920" if root.size.x == 1920 else ""])


func _fail(message: String) -> void:
	push_error("PHASE21_EXPERIENCE_SMOKE_FAIL " + message)
	quit(1)
