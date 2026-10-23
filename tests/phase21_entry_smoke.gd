extends SceneTree

const Saves = preload("res://src/infrastructure/persistence/save_service.gd")
const Driver = preload("res://tests/phase20_development_smoke.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	Saves.verification_directory = "/private/tmp/popodig-entry-%d" % OS.get_process_id()
	var packed = load("res://scenes/app/game_app.tscn")
	var previous = packed.instantiate()
	root.add_child(previous)
	await process_frame
	previous.set_process(false)
	Saves.save_game(Saves.get_save_directory().path_join("quicksave.json"), previous._build_save_document())
	previous.queue_free()
	await process_frame
	var scene = packed.instantiate()
	scene.set_meta("show_start_menu", true)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_process(false)
	TranslationServer.set_locale("zh")
	if scene._start_view == null or not scene._paused or scene._start_view.latest_slot != "quicksave":
		_fail("Entry lacks a paused, available continue action")
		return
	scene._start_view.refresh()
	await create_timer(0.2).timeout
	if OS.get_cmdline_user_args().has("--capture"):
		RenderingServer.force_draw(false)
		await process_frame
		root.get_texture().get_image().save_png("res://art/qa/screenshots/phase21_start_zh.png")
	scene._start_view.new_requested.emit()
	if not scene._session_started or scene._paused or scene._start_view.visible:
		_fail("New-home action did not start the session")
		return
	if DirAccess.get_files_at(Saves.get_save_directory().path_join("archive")).size() != 1:
		_fail("New home did not preserve previous save")
		return
	var discovery = scene.worldgen_result.feature_registry.get_features("discovery")[0]
	if not Driver._dig_to(scene, discovery.anchor) or not bool(discovery.metadata.get("claimed", false)):
		_fail("New home cannot pursue its first ordinary discovery")
		return
	var expected_seed: int = scene._current_seed
	var found: int = scene.colony_simulation.get_discovery_system().claimed_count()
	if not scene._save_to_slot("quicksave"):
		_fail("Could not save the new home")
		return
	scene._start_view.continue_requested.emit("quicksave")
	var resumed
	for frame: int in range(30):
		await process_frame
		if current_scene != null and current_scene._loaded_from_save:
			resumed = current_scene
			break
	if resumed == null or resumed._current_seed != expected_seed or int(resumed.world_grid.metadata.seed) != expected_seed:
		_fail("Continue regenerated metadata from a different seed")
		return
	if resumed.colony_simulation.get_discovery_system().claimed_count() != found:
		_fail("Continue lost discovery progress")
		return
	print("PHASE21_ENTRY_SMOKE_PASS archived_previous=true normal_first_discovery=true real_scene_reload=true seed=%d" % expected_seed)
	resumed._quit_session()


func _fail(message: String) -> void:
	push_error("PHASE21_ENTRY_SMOKE_FAIL " + message)
	quit(1)
