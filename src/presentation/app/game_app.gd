extends Node

const HomeProgressScript = preload("res://src/domain/progression/home_progress.gd")
const WorldGenContextScript = preload("res://src/domain/worldgen/world_gen_context.gd")
const CollectionViewScript = preload("res://src/presentation/hud/collection_view.gd")
const DevelopmentViewScript = preload("res://src/presentation/hud/development_view.gd")
const DiscoveryViewScript = preload("res://src/presentation/world/discovery_view.gd")
const DiscoveryScript = preload("res://src/domain/features/discovery_system.gd")
const Resources = preload("res://src/domain/colony/resource_catalog.gd")
const StructuredWorldGeneratorScript = preload("res://src/domain/worldgen/structured_world_generator.gd")
const GridPathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const ColonySimulationScript = preload("res://src/domain/colony/colony_simulation.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")
const DesignateDigCommandScript = preload("res://src/application/commands/designate_dig_command.gd")
const CancelDigCommandScript = preload("res://src/application/commands/cancel_dig_command.gd")
const PaintZoneCommandScript = preload("res://src/application/commands/paint_zone_command.gd")
const EraseZoneCommandScript = preload("res://src/application/commands/erase_zone_command.gd")
const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const SaveServiceScript = preload("res://src/infrastructure/persistence/save_service.gd")
const NotificationModelScript = preload("res://src/presentation/hud/notification_model.gd")
const TimeControlScript = preload("res://src/domain/progression/time_control.gd")
const TimeControlsViewScript = preload("res://src/presentation/hud/time_controls_view.gd")
const StartViewScript = preload("res://src/presentation/hud/start_view.gd")
const ControlsViewScript = preload("res://src/presentation/hud/controls_view.gd")
const ContextTutorialModelScript = preload("res://src/presentation/hud/context_tutorial_model.gd")
const WaterFxViewScript = preload("res://src/presentation/world/water_fx_view.gd")
const VfxViewScript = preload("res://src/presentation/fx/vfx_view.gd")
const AudioDirectorScript = preload("res://src/presentation/audio/audio_director.gd")
const SettingsViewScript = preload("res://src/presentation/hud/settings_view.gd")
const ChapterModelScript = preload("res://src/domain/progression/chapter_model.gd")
const FogOfWarViewScript = preload("res://src/presentation/world/fog_of_war_view.gd")
const SessionTelemetryScript = preload("res://src/domain/telemetry/session_telemetry.gd")
const MouseAgentScript = preload("res://src/domain/colony/mouse_agent.gd")

# Slice objective (docs/qa/18 Beat H): a marked depth goal below the start.
# Phase 16: pacing values are balance-configurable with slice-era fallbacks.
const SLICE_OBJECTIVE_DEPTH_OFFSET := 30
const FOOD_CRITICAL_COUNT := 2
const OPEN_SPACE_TUTORIAL_CELLS := 12
const AUTOSAVE_INTERVAL_SECONDS := 60.0

enum PaintAction {
	NONE,
	DESIGNATE,
	CANCEL,
}

enum Tool {
	DIG,
	SLEEPING,
	STORAGE,
	FOOD_FORAGE,
	SEAL,
	REINFORCE,
	PRODUCTION,
}

@onready var world_view: WorldView = %WorldView
@onready var world_camera: WorldCamera = %WorldCamera
@onready var zone_overlay_view: ZoneOverlayView = %ZoneOverlayView
@onready var colony_view: ColonyView = %ColonyView
@onready var colony_items_view: ColonyItemsView = %ColonyItemsView
@onready var colony_debug_overlay: ColonyDebugOverlay = %ColonyDebugOverlay
@onready var worldgen_debug_overlay = %WorldgenDebugOverlay
@onready var dig_cursor_view: DigCursorView = %DigCursorView
@onready var seed_label: Label = %SeedLabel
@onready var stats_label: Label = %StatsLabel
@onready var inspector_label: Label = %InspectorLabel
@onready var dig_status_label: Label = %DigStatusLabel
@onready var tool_status_label: Label = %ToolStatusLabel
@onready var colony_status_label: Label = %ColonyStatusLabel
@onready var dig_feedback_label: Label = %DigFeedbackLabel
@onready var fps_label: Label = %FpsLabel
@onready var debug_top_bar: Control = %TopBar
@onready var debug_inspector: Control = %Inspector
@onready var debug_footer: Control = %Footer
@onready var notifications_view: NotificationView = %Notifications
@onready var tutorial_label: Label = %TutorialLabel
@onready var objective_label: Label = %ObjectiveLabel

var world_grid
var path_service
var dig_system
var colony_simulation
var signal_system
var root_feature_system
var water_system
var seal_system
var mouse_agent
var worldgen_result
var _vfx_view: VfxView
var _audio_director: AudioDirector
var _settings_view: SettingsView
var _start_view
var _session_started := true
var _quitting := false
static var _build_check_stage := 0
static var _build_check_seed := 0
var _loaded_start_document: Dictionary = {}
var _settings_open := false
var _pause_before_settings := false
var time_control = TimeControlScript.new()
var _time_controls
var _simulated_seconds := 0.0
var chapter_model
var home_progress
var _active_seconds := 0.0
var _campaign_celebrated := false
var _logical_cell_size := 16
var _simulation_step := 0.05
var _simulation_accumulator := 0.0
var _selected_cell := Vector2i(-1, -1)
var _paint_action := PaintAction.NONE
var _current_tool := Tool.DIG
var _last_painted_cell := Vector2i(-1, -1)
var _last_feedback := "feedback.choose_frontier"
var _hover_feedback := "feedback.choose_frontier"
var _feedback_seconds_remaining := 0.0
var _qa_inspector_cell := Vector2i(-1, -1)
var _collection_view
var _discovery_view
var _modal_backdrop: ColorRect
var _help_view
var _help_open := false
var _pause_before_help := false
var _toolbar_buttons: Dictionary = {}
var _book_open := false
var _pause_before_book := false
var _current_seed := 0
var _notifications: NotificationModel
var _tutorial: ContextTutorialModel
var _tutorial_flags: Dictionary = {}
var _paused := false
var _poll_accumulator := 0.0
var _notifications_dirty := false
var _notified_zone_keys: Dictionary = {}
var _mice_were_in_danger := false
var _now_seconds := 0.0
var _objective_target_depth := 0
var _autosave_accumulator := 0.0
var _loaded_from_save := false
var _telemetry: SessionTelemetryScript = null
var _telemetry_seed := 0
var _telemetry_reservoir_cells := {}
var _telemetry_sample_accumulator := 0.0
var _telemetry_previous_mouse_cells := {}
var _stroke_dig_cells := 0
var _stroke_cancelled_cells: Array[Vector2i] = []
var _stroke_reinforce_cells := 0

static var _debug_seed_override_set := false
static var _debug_seed_override := 0
static var _pending_load_path := ""


func _ready() -> void:
	if not AppConfig.get_load_errors().is_empty():
		GameLog.failure("QA", "Configuration errors: %s" % "; ".join(AppConfig.get_load_errors()))
		return
	if _has_user_argument("--verify-playtest") and SaveServiceScript.verification_directory.is_empty():
		SaveServiceScript.verification_directory = OS.get_cache_dir().path_join("dig-down-verify-%d" % OS.get_process_id())
	var worldgen_config := AppConfig.get_document("worldgen")
	var balance_config := AppConfig.get_document("balance")
	time_control.configure(balance_config)
	var digging_balance: Dictionary = balance_config.get("digging", {})
	var seed_value := _debug_seed_override if _debug_seed_override_set else int(worldgen_config.get("default_seed", 137042))
	var main_entry := get_tree().current_scene == self or bool(get_meta("show_start_menu", false))
	if not _pending_load_path.is_empty():
		_loaded_start_document = SaveServiceScript.load_game(_pending_load_path)
		if bool(_loaded_start_document.get("ok", false)):
			seed_value = int(_loaded_start_document.data.header.seed)
	elif main_entry:
		seed_value = int(Time.get_unix_time_from_system() * 1000000) % 2147483647
	_current_seed = seed_value
	worldgen_result = StructuredWorldGeneratorScript.new().generate_result(worldgen_config, seed_value)
	world_grid = worldgen_result.world
	if not worldgen_result.success:
		GameLog.failure("WORLDGEN", "Structured generation rejected seed=%d failures=%s" % [seed_value, worldgen_result.report.get("validation", {}).get("failure_codes", [])])
		return
	_logical_cell_size = int(balance_config.get("logical_cell_size", 16))
	_simulation_step = float(digging_balance.get("simulation_step_seconds", 0.05))
	world_view.configure(
		world_grid,
		_logical_cell_size,
		worldgen_result.feature_registry,
		worldgen_config.get("signal_fields", {})
	)
	world_camera.configure_world_bounds(world_view.get_world_rect())
	world_camera.zoom = Vector2.ONE * clampf(float(balance_config.get("initial_zoom", 1.4)), world_camera.min_zoom, world_camera.max_zoom)
	world_camera.focus_cell(world_grid.metadata.start_cell, _logical_cell_size)
	world_camera.reset_smoothing()
	path_service = GridPathServiceScript.new()
	path_service.configure(world_grid, balance_config)
	dig_system = DigSystemScript.new()
	dig_system.configure(world_grid, path_service, balance_config)
	colony_simulation = ColonySimulationScript.new()
	colony_simulation.configure(
		world_grid,
		path_service,
		dig_system,
		balance_config,
		worldgen_result.feature_registry,
		worldgen_config
	)
	signal_system = colony_simulation.get_signal_system()
	root_feature_system = colony_simulation.get_root_feature_system()
	water_system = colony_simulation.get_water_system()
	seal_system = colony_simulation.get_seal_system()
	world_view.configure_environment(water_system, seal_system, colony_simulation.get_stability_system())
	# Phase 11 presentation layers: animated water shimmer + pooled VFX live in
	# WorldView coordinate space; audio directs the synthesized bank.
	var accessibility: Dictionary = AppConfig.get_document("app").get("accessibility", {})
	var water_fx := WaterFxViewScript.new()
	water_fx.name = "WaterFx"
	world_view.add_child(water_fx)
	water_fx.configure(world_grid, water_system, _logical_cell_size)
	# Fog of war sits above every world visual (mice/props included) but
	# below the cursor and HUD: unexplored ground is dark until dug open.
	var fog := FogOfWarViewScript.new()
	fog.name = "FogOfWar"
	fog.z_index = 27
	world_view.add_child(fog)
	fog.configure(world_grid, _logical_cell_size, maxi(1, int(balance_config.get("fog_radius", 4))), worldgen_result.feature_registry)
	_discovery_view = DiscoveryViewScript.new()
	_discovery_view.z_index = 28
	world_view.add_child(_discovery_view)
	_discovery_view.configure(world_grid, worldgen_result.feature_registry, fog, _logical_cell_size)
	if colony_simulation.get_discovery_system() != null:
		colony_simulation.get_discovery_system().discovered.connect(_on_discovery)
	world_grid.chunk_dirtied.connect(func(_coord: Vector2i, _flags: int) -> void:
		fog.mark_stale()
	)
	_vfx_view = VfxViewScript.new()
	_vfx_view.name = "Vfx"
	world_view.add_child(_vfx_view)
	_vfx_view.set_reduced_particles(bool(accessibility.get("reduced_particles", false)))
	world_camera.reduced_shake = bool(accessibility.get("reduced_shake", false))
	var audio_config: Dictionary = AppConfig.get_document("app").get("audio", {})
	if bool(audio_config.get("enabled", true)) and AudioDirectorScript.audio_enabled:
		_audio_director = AudioDirectorScript.new()
		_audio_director.name = "AudioDirector"
		add_child(_audio_director)
		_audio_director.apply_volumes(audio_config)
	_setup_settings_view(accessibility, audio_config)
	# 21_BALANCE_TELEMETRY §2: local session metrics, debug builds only —
	# release profiles never instantiate the recorder (doc §7 privacy).
	if AppConfig.debug_tools_enabled():
		_telemetry = SessionTelemetryScript.new()
		_telemetry_seed = _current_seed
		_telemetry.context = {"seed": _current_seed, "worldgen_version": int(world_grid.metadata.worldgen_version), "game_version": str(ProjectSettings.get_setting("application/config/version")), "profile": AppConfig.get_profile_name(), "balance": balance_config.duplicate(true), "clock": "active session seconds, excluding pause", "input_source": "interactive"}
		colony_simulation.travelled.connect(_telemetry.record_travel)
	dig_system.cell_excavated.connect(_on_cell_excavated)
	chapter_model = ChapterModelScript.new()
	chapter_model.configure(balance_config)
	home_progress = HomeProgressScript.new()
	chapter_model.chapter_advanced.connect(_on_chapter_advanced)
	colony_simulation.get_production_system().produced.connect(_on_produced)
	colony_simulation.get_capabilities().upgraded.connect(_on_capability_upgraded)
	if root_feature_system != null:
		root_feature_system.feature_reacted.connect(_on_root_feature_reacted)
		root_feature_system.feature_revealed.connect(_on_root_feature_revealed)
		root_feature_system.food_produced.connect(_on_food_produced)
	if water_system != null:
		water_system.reservoir_breached.connect(_on_reservoir_breached)
	var stability = colony_simulation.get_stability_system()
	if stability != null:
		stability.region_collapsed.connect(_on_region_collapsed)
		stability.critical_warning.connect(_on_critical_warning)
		if _telemetry != null:
			stability.warning_changed.connect(_on_telemetry_warning_changed)
	var zone_system_telemetry = colony_simulation.get_zone_system()
	if _telemetry != null and zone_system_telemetry != null:
		zone_system_telemetry.zones_changed.connect(func(_change: Dictionary) -> void:
			_telemetry.record_zone_change()
			_telemetry.record_development("layout_edit", "zones", {"note": "zone edit is a replanning proxy, not player intent"})
		)
		_telemetry_reservoir_cells = _collect_reservoir_cells()
	if _pending_load_path != "":
		var pending_path := _pending_load_path
		_pending_load_path = ""
		var load_result: Dictionary = _loaded_start_document if not _loaded_start_document.is_empty() else SaveServiceScript.load_game(pending_path)
		if bool(load_result.ok):
			var apply_result := _apply_loaded_document(load_result.data)
			if bool(apply_result.ok):
				_loaded_from_save = true
			else:
				GameLog.failure("SAVE", "Loaded save could not be applied: %s" % String(apply_result.error))
		else:
			GameLog.failure("SAVE", "Save could not be loaded: %s" % String(load_result.error))
	if not _loaded_from_save:
		_seed_initial_supplies()
	var mice: Array = colony_simulation.get_mice()
	mouse_agent = mice[0] if not mice.is_empty() else null
	colony_view.configure(colony_simulation, _logical_cell_size)
	var development_view := DevelopmentViewScript.new()
	get_node("UI/Root").add_child(development_view)
	development_view.configure(colony_simulation, home_progress)
	development_view.collection_requested.connect(_toggle_collection_book)
	development_view.focus_requested.connect(func(cell: Vector2i) -> void: world_camera.focus_cell(cell, _logical_cell_size))
	_collection_view = CollectionViewScript.new()
	get_node("UI/Root").add_child(_collection_view)
	_collection_view.configure(colony_simulation.get_collection_book(), home_progress)
	_collection_view.close_requested.connect(_toggle_collection_book)
	_help_view = ControlsViewScript.new()
	get_node("UI/Root").add_child(_help_view)
	_help_view.close_requested.connect(_toggle_help)
	_build_player_toolbar()
	_time_controls = TimeControlsViewScript.new()
	get_node("UI/Root").add_child(_time_controls)
	_time_controls.pause_requested.connect(func() -> void: _paused = not _paused)
	_time_controls.speed_requested.connect(_choose_speed)
	_time_controls.home_requested.connect(func() -> void: world_camera.focus_cell(world_grid.metadata.start_cell, _logical_cell_size))
	_time_controls.focus_requested.connect(_focus_latest)
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.color = Color(0, 0, 0, 0.45)
	_modal_backdrop.z_index = 90
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_backdrop.visible = false
	get_node("UI/Root").add_child(_modal_backdrop)
	get_node("UI/Root").move_child(_collection_view, -1)
	get_node("UI/Root").move_child(_help_view, -1)
	zone_overlay_view.configure(colony_simulation.get_zone_system(), _logical_cell_size)
	var zone_system = colony_simulation.get_zone_system()
	zone_system.setup_state_changed.connect(_on_zone_setup_state_changed)
	colony_items_view.configure(colony_simulation.get_item_system(), _logical_cell_size)
	colony_debug_overlay.configure(colony_simulation, _logical_cell_size)
	worldgen_debug_overlay.configure(world_grid, worldgen_result.feature_registry, _logical_cell_size, signal_system, water_system, colony_simulation.get_stability_system())
	dig_cursor_view.configure(_logical_cell_size)
	seed_label.text = "Seed %d · worldgen v%d · VALID · repairs %d" % [seed_value, world_grid.metadata.worldgen_version, world_grid.metadata.repairs.size()]
	stats_label.text = "%d×%d cells · %d chunks · %.1f KiB · %d features · hash %d" % [
		world_grid.width,
		world_grid.height,
		world_grid.get_chunk_count(),
		world_grid.estimate_storage_bytes() / 1024.0,
		worldgen_result.feature_registry.count(),
		worldgen_result.get_content_hash(),
	]
	if AppConfig.cheats_enabled():
		var requested_overlay := _user_argument_value("--qa-phase7-overlay=")
		if requested_overlay.is_empty():
			requested_overlay = _user_argument_value("--qa-phase6-overlay=")
		if requested_overlay.is_empty():
			requested_overlay = _user_argument_value("--qa-phase5-overlay=")
		if not requested_overlay.is_empty() and worldgen_debug_overlay.set_mode_by_name(requested_overlay):
			stats_label.text += " · overlay %s" % worldgen_debug_overlay.get_mode_name()
	var debug_visible := AppConfig.debug_tools_enabled()
	debug_top_bar.visible = debug_visible
	debug_inspector.visible = true
	debug_footer.visible = debug_visible
	colony_debug_overlay.visible = debug_visible
	worldgen_debug_overlay.visible = debug_visible
	_set_tool(Tool.DIG)
	if not _loaded_from_save:
		Localization.apply()
	_notifications = NotificationModelScript.new()
	notifications_view.bind(_notifications)
	if _tutorial == null:
		_tutorial = ContextTutorialModelScript.new()
		_tutorial.configure_v2(chapter_model.rules_version >= 2)
	tutorial_label.text = Localization.text(_tutorial.current_text_key())
	_objective_target_depth = int(world_grid.metadata.start_cell.y) + int(balance_config.get("tutorial", {}).get("objective_depth_offset", SLICE_OBJECTIVE_DEPTH_OFFSET))
	world_grid.cell_changed.connect(_on_world_cell_changed)
	if (_has_user_argument("--qa-phase2-demo") or _has_user_argument("--qa-phase3-demo")) and AppConfig.cheats_enabled():
		_designate_qa_demo_path()
	if _has_user_argument("--qa-phase3-demo") and AppConfig.cheats_enabled():
		_setup_qa_colony_demo()
	if _has_user_argument("--qa-phase4-demo") and AppConfig.cheats_enabled():
		_setup_qa_zone_demo()
	if AppConfig.cheats_enabled():
		var phase6_demo := _user_argument_value("--qa-phase6-demo=")
		if not phase6_demo.is_empty():
			_setup_qa_root_demo(phase6_demo)
		var phase7_demo := _user_argument_value("--qa-phase7-demo=")
		if not phase7_demo.is_empty():
			_setup_qa_water_demo(phase7_demo)
		var phase8_demo := _user_argument_value("--qa-phase8-demo=")
		if not phase8_demo.is_empty():
			_setup_qa_stability_demo(phase8_demo)
	_update_hud()
	GameLog.info("WORLDGEN", "Phase 7 water-enabled world generated seed=%d content_hash=%d features=%d repairs=%d mice=%d" % [seed_value, worldgen_result.get_content_hash(), worldgen_result.feature_registry.count(), world_grid.metadata.repairs.size(), mice.size()])
	if main_entry and not _loaded_from_save:
		_show_start()
	get_tree().auto_accept_quit = false
	if _has_user_argument("--verify-playtest"):
		_verify_playtest.call_deferred()


func _process(delta: float) -> void:
	if world_grid == null or colony_simulation == null:
		return
	_now_seconds += delta
	if not _paused:
		_active_seconds += delta
		_simulation_accumulator = minf(_simulation_accumulator + time_control.simulation_delta(delta), 0.4 * time_control.speed)
		_autosave_accumulator += delta
		if _autosave_accumulator >= AUTOSAVE_INTERVAL_SECONDS:
			_autosave_accumulator = 0.0
			_save_to_slot("autosave")
	_poll_accumulator += delta
	if _poll_accumulator >= 0.5:
		_slow_poll()
	if _telemetry != null:
		_telemetry.elapsed_seconds = _active_seconds
		_telemetry.wall_seconds = _now_seconds
		_telemetry_sample_accumulator += delta
		if _telemetry_sample_accumulator >= 1.0:
			_telemetry_sample_accumulator = 0.0
			_telemetry_sample_tick()
	var ticks := 0
	while not _paused and _simulation_accumulator >= _simulation_step and ticks < 8 * time_control.speed:
		colony_simulation.fixed_tick(_simulation_step)
		_simulated_seconds += _simulation_step
		_simulation_accumulator -= _simulation_step
		ticks += 1
	_feedback_seconds_remaining = maxf(0.0, _feedback_seconds_remaining - delta)
	_refresh_hovered_cell()
	_update_cursor()
	_update_hud()
	_update_inspector()
	if _notifications_dirty:
		notifications_view.refresh(_now_seconds)
		_notifications_dirty = false
	if AppConfig.debug_tools_enabled():
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


## Any authoritative terrain change (dig completion, seal, collapse) proves the
## colony is actively reshaping the burrow; used for the tutorial's sticky
## "designated" flag so instant witness replays between polls are not missed.
func _on_world_cell_changed(cell_coord: Vector2i, change_flags: int) -> void:
	if (change_flags & world_grid.CHANGE_TERRAIN) != 0 and world_grid.is_traversable(cell_coord):
		_tutorial_flags["designated"] = true


## Phase 10: full-document persistence (docs/tech/15). World mutated state is
## saved in full (never seed-derived); jobs/paths/reservations are rebuilt on
## load per spec §8. Progression carries tutorial state and language choice.
func _build_save_document() -> Dictionary:
	var stability = colony_simulation.get_stability_system()
	var document: Dictionary = {
		"header": SaveServiceScript.build_header(
			int(world_grid.metadata.worldgen_version),
			_current_seed
		),
		"world": world_grid.to_save_data(),
		"features": worldgen_result.feature_registry.to_save_data(),
		"colony": colony_simulation.to_save_data(),
		"progression": {
			"tutorial_step": _tutorial.index,
			"tutorial_step_id": _tutorial.current_id(),
			"home_progress": home_progress.to_save_data(),
			"tutorial_flags": _tutorial_flags.duplicate(true),
			"language": Localization.current(),
			"view": {"cell": [int(world_camera.position.x / _logical_cell_size), int(world_camera.position.y / _logical_cell_size)], "zoom": world_camera.zoom.x},
			# Additive optional key (docs/tech/15): v2 saves without it
			# restore to Chapter 1 via the model's default.
			"chapter_model": chapter_model.to_save_data(),
		},
	}
	if signal_system != null:
		document["signals"] = signal_system.to_save_data()
	if water_system != null:
		document["water"] = water_system.to_save_data()
	if stability != null:
		document["stability"] = stability.to_save_data()
	return document


func _apply_loaded_document(document: Dictionary) -> Dictionary:
	if _tutorial == null:
		_tutorial = ContextTutorialModelScript.new()
		_tutorial.configure_v2(chapter_model.rules_version >= 2)
	if home_progress == null:
		home_progress = HomeProgressScript.new()
	var before: Dictionary = _build_save_document()
	var result: Dictionary = _restore_document(document)
	if not bool(result.ok):
		var rollback: Dictionary = _restore_document(before)
		if not bool(rollback.ok):
			GameLog.failure("SAVE", "Save rollback failed: " + str(rollback.error))
	return result


func _restore_document(document: Dictionary) -> Dictionary:
	var header: Dictionary = document.get("header", {})
	var config_worldgen_version := int(AppConfig.get_document("worldgen").get("worldgen_version", 0))
	if int(header.worldgen_version) < 6 or int(header.worldgen_version) > config_worldgen_version:
		return {"ok": false, "error": "save worldgen version %d does not match the current %d" % [int(header.worldgen_version), config_worldgen_version]}
	var world_result: Dictionary = world_grid.apply_save_data(document.get("world", {}))
	if not bool(world_result.ok):
		return world_result
	# Bulk world restore bypasses per-cell change notifications, so the path
	# service's walkability cache still reflects the fresh generated world;
	# rebuild it before any system consumes restored state (mice may only be
	# placed on restored walkable cells).
	path_service.configure(world_grid, AppConfig.get_document("balance"))
	var feature_result: Dictionary = worldgen_result.feature_registry.apply_save_data(document.get("features", {}))
	if not bool(feature_result.ok):
		return feature_result
	# v6 and v7 share the terrain/strata pipeline. Add only new feature data
	# to a legacy world, keeping the restored terrain and consumed features.
	if int(header.worldgen_version) == 6 and worldgen_result.feature_registry.count("discovery") == 0:
		var context := WorldGenContextScript.new(AppConfig.get_document("worldgen"), int(header.seed))
		context.world = world_grid
		context.feature_registry = worldgen_result.feature_registry
		DiscoveryScript.populate(context)
	if signal_system != null and document.has("signals"):
		var signal_result: Dictionary = signal_system.apply_save_data(document.signals)
		if not signal_result.ok:
			return signal_result
	if water_system != null and document.has("water"):
		var water_result: Dictionary = water_system.apply_save_data(document.water)
		if not water_result.ok:
			return water_result
	var stability = colony_simulation.get_stability_system()
	if stability != null and document.has("stability"):
		var stability_result: Dictionary = stability.apply_save_data(document.stability)
		if not stability_result.ok:
			return stability_result
	var colony_result: Dictionary = colony_simulation.apply_save_data(document.get("colony", {}))
	if not bool(colony_result.ok):
		return colony_result
	var progression: Dictionary = document.get("progression", {})
	var chapter_data: Dictionary = progression.get("chapter_model", {}).duplicate(true)
	if not chapter_data.has("rules_version"):
		chapter_data["rules_version"] = 1 if int(header.worldgen_version) == 6 else 2
	chapter_model.apply_save_data(chapter_data)
	if _tutorial == null:
		_tutorial = ContextTutorialModelScript.new()
	_tutorial.configure_v2(chapter_model.rules_version >= 2)
	if progression.has("tutorial_step_id"):
		_tutorial.restore_id(str(progression.tutorial_step_id))
	else:
		_tutorial.index = 0 if _tutorial.v2 else clampi(int(progression.get("tutorial_step", 0)), 0, _tutorial.STEPS.size() - 1)
	_tutorial_flags = (progression.get("tutorial_flags", {}) as Dictionary).duplicate(true)
	if home_progress == null:
		home_progress = HomeProgressScript.new()
	var home_result: Dictionary = home_progress.apply_save_data(progression.get("home_progress", {}))
	if not home_result.ok:
		return home_result
	_campaign_celebrated = chapter_model.campaign_complete
	tutorial_label.text = Localization.text(_tutorial.current_text_key())
	var restored_mice: Array = colony_simulation.get_mice()
	mouse_agent = restored_mice[0] if not restored_mice.is_empty() else null
	var saved_language := String(progression.get("language", ""))
	if saved_language in Localization.SUPPORTED:
		TranslationServer.set_locale(saved_language)
	var saved_view: Dictionary = progression.get("view", {})
	if saved_view.get("cell", null) is Array and saved_view.cell.size() == 2:
		world_camera.zoom = Vector2.ONE * clampf(float(saved_view.get("zoom", 1.4)), world_camera.min_zoom, world_camera.max_zoom)
		world_camera.focus_cell(Vector2i(int(saved_view.cell[0]), int(saved_view.cell[1])), _logical_cell_size)
		world_camera.reset_smoothing()
	return {"ok": true, "error": ""}


func _save_to_slot(slot_name: String) -> bool:
	var path := SaveServiceScript.get_save_directory().path_join(slot_name + ".json")
	var document := _build_save_document()
	var result: Dictionary = SaveServiceScript.save_game(path, document)
	if bool(result.ok):
		if _telemetry != null:
			_telemetry.record_save(slot_name)
		_push_notification("save", tr("notify.saved"), Vector2i(-1, -1), 2.0, 3.0)
		GameLog.info("SAVE", "Saved slot=%s path=%s" % [slot_name, path])
	else:
		_push_notification("save_failed", tr("notify.save_failed") % String(result.error), Vector2i(-1, -1), 4.0, 4.0)
		GameLog.failure("SAVE", "Save failed slot=%s error=%s" % [slot_name, String(result.error)])

	return bool(result.ok)


func _request_load(slot_name: String) -> void:
	var path := SaveServiceScript.get_save_directory().path_join(slot_name + ".json")
	if not FileAccess.file_exists(path):
		_push_notification("load_missing", tr("notify.load_missing") % slot_name, Vector2i(-1, -1), 4.0, 4.0)
		return
	if _telemetry != null:
		_telemetry.record_load()
	_pending_load_path = path
	_autosave_accumulator = 0.0
	# Deferred: reload must not tear down the scene tree while the F9 input
	# event is still being processed (editor-embedded sessions froze here).
	get_tree().reload_current_scene.call_deferred()


func _slow_poll() -> void:
	_poll_accumulator = 0.0
	_update_tutorial_flags()
	_evaluate_chapter_milestones()
	_update_v2_tutorial_flags()
	if _tutorial.advance(_tutorial_flags):
		tutorial_label.text = Localization.text(_tutorial.current_text_key())
	_update_objective()
	_update_home_progress()
	get_node("UI/Root/TutorialPanel").visible = not chapter_model.campaign_complete and _tutorial.current_id() != "promise"
	_poll_notifications()
	notifications_view.refresh(_now_seconds)
	_update_water_proximity()
	_emit_warning_dust()


## Phase 13 chapter milestones (GDD §13, world/04 §6, colony/10 §14): chapter
## advancement is judged from a context snapshot and grants population growth.
func _evaluate_chapter_milestones() -> void:
	if chapter_model == null or chapter_model.campaign_complete:
		return
	chapter_model.evaluate(_chapter_context())
	if chapter_model.campaign_complete and not _campaign_celebrated:
		_campaign_celebrated = true
		if _telemetry != null:
			_telemetry.mark_campaign_complete()
		_push_notification("campaign", tr("notify.campaign_complete"), _warm_chamber_anchor(), 60.0, 3600.0)
		if _audio_director != null:
			_audio_director.play_discovery_stinger()


## GDD §14: the campaign completes when the final home is stable in the deep
## warm area — a set-up sleeping zone inside the warm chamber's cells.
func _warm_home_ready(zone_system) -> bool:
	var warm_cells: Dictionary = {}
	for feature in worldgen_result.feature_registry.get_features("warm_chamber"):
		if chapter_model != null and chapter_model.rules_version >= 2 and feature.hidden:
			continue
		for cell: Vector2i in feature.cells:
			warm_cells[cell] = true
	var beds := 0
	for zone in zone_system.get_zones_by_type(ZoneScript.Type.SLEEPING, true):
		if zone.setup_state != ZoneScript.SetupState.SET_UP:
			continue
		for cell: Vector2i in zone.cells:
			if warm_cells.has(cell) and world_grid.get_water_units(cell) == 0 and not colony_simulation.get_stability_system().is_job_blocked(cell):
				beds += 1
	if chapter_model == null or chapter_model.rules_version < 2:
		return beds > 0
	var mice: int = colony_simulation.get_mice().size()
	return beds >= mice and _warm_food_stock() >= mice * 2 and colony_simulation.get_capabilities().level >= 2 and colony_simulation.get_production_system().completed_batches > 0


func _warm_chamber_anchor() -> Vector2i:
	for feature in worldgen_result.feature_registry.get_features("warm_chamber"):
		return feature.anchor
	return world_grid.metadata.start_cell


func _zone_ready(zone_system, zone_type: int) -> bool:
	for zone: Zone in zone_system.get_zones_by_type(zone_type, true):
		if zone.setup_state == ZoneScript.SetupState.SET_UP:
			return true
	return false


func _on_chapter_advanced(new_chapter: int, growth_count: int) -> void:
	if _telemetry != null:
		_telemetry.record_chapter_advance(new_chapter)
	var spawned := _spawn_growth_mice(growth_count)
	_push_notification(
		"chapter",
		tr("notify.chapter_advanced") % [_chapter_display_name(new_chapter), spawned],
		world_grid.metadata.start_cell,
		30.0,
		3600.0
	)
	if new_chapter >= ChapterModelScript.CHAPTER_3_OLD_BURROW:
		_push_notification("chapter", tr("notify.campaign_hint"), world_grid.metadata.start_cell, 30.0, 3600.0)


## Spec 10 §14: population grows at milestone points; new mice spawn near the
## start burrow and demand food/sleep like the founding three.
func _spawn_growth_mice(count: int) -> int:
	var start: Vector2i = world_grid.metadata.start_cell
	var spawn_cells: Array[Vector2i] = colony_simulation.find_spawn_cells_near(start, count)
	var spawned := 0
	for index: int in range(spawn_cells.size()):
		var mouse = colony_simulation.add_mouse("mouse_%d" % (colony_simulation.get_mice().size() + 1), spawn_cells[index])
		if mouse != null:
			spawned += 1
	return spawned


func _chapter_display_name(chapter: int) -> String:
	match chapter:
		ChapterModelScript.CHAPTER_2_ADAPT:
			return tr("chapter.2_adapt")
		ChapterModelScript.CHAPTER_3_OLD_BURROW:
			return tr("chapter.3_old_burrow")
		_:
			return tr("chapter.1_settle")


## The drip layer follows the camera toward active water (spec §3): proximity
## is sampled from flooded danger cells so steady-state pools stay quiet.
func _update_water_proximity() -> void:
	if _audio_director == null or water_system == null:
		return
	var near := false
	if water_system.get_active_cell_count() > 0:
		var camera_cell := Vector2i((world_camera.position / float(_logical_cell_size)).floor())
		for water_cell: Vector2i in water_system.get_danger_cells():
			if Vector2(water_cell - camera_cell).length() <= 14.0:
				near = true
				break
	_audio_director.set_water_proximity(near)


## Occasional settling crumbs fall from cells with an active reinforce request,
## so stressed ceilings move even before cracks appear.
func _emit_warning_dust() -> void:
	var stability = colony_simulation.get_stability_system()
	if _vfx_view == null or stability == null:
		return
	var requests: Array = stability.get_requests()
	if requests.is_empty():
		return
	var sample: Dictionary = requests[randi() % requests.size()]
	var cell: Vector2i = sample.get("cell", Vector2i(-1, -1))
	if cell.x >= 0 and world_grid.is_traversable(cell):
		_vfx_view.spawn_warning_dust((Vector2(cell) + Vector2(0.5, 0.5)) * _logical_cell_size)


func _update_tutorial_flags() -> void:
	var open_cells := 0
	for y: int in range(world_grid.height):
		for x: int in range(world_grid.width):
			if world_grid.is_traversable(Vector2i(x, y)):
				open_cells += 1
	var open_space_target := int(AppConfig.get_document("balance").get("tutorial", {}).get("open_space_cells", OPEN_SPACE_TUTORIAL_CELLS))
	if open_cells >= open_space_target:
		_tutorial_flags["open_space"] = true
	_tutorial_flags["_deepest"] = _colony_reached_depth()
	if signal_system != null:
		var root_recognition: String = signal_system.get_recognition_name("root_cluster")
		if root_recognition != "UNKNOWN":
			_tutorial_flags["root_clue"] = true
		var water_recognition: String = signal_system.get_recognition_name("water_reservoir")
		if water_recognition != "UNKNOWN":
			_tutorial_flags["moisture_clue"] = true
	var zone_system = colony_simulation.get_zone_system()
	for zone: Zone in zone_system.get_zones():
		if zone.zone_type == ZoneScript.Type.SLEEPING and zone.setup_state == ZoneScript.SetupState.SET_UP:
			_tutorial_flags["sleeping_zone"] = true
		# Phase 16 fix: the root_found step instructs planning a forage zone;
		# completing it must advance the tutorial (it had no completion flag).
		if zone.zone_type == ZoneScript.Type.FOOD_FORAGE and zone.valid and zone.setup_state == ZoneScript.SetupState.SET_UP:
			_tutorial_flags["forage_ready"] = true


## Depth of the deepest cell the colony actually reached (connected to the
## start), so natural cavities never count toward the slice objective.
func _colony_reached_depth() -> int:
	var start: Vector2i = world_grid.metadata.start_cell
	var distances: PackedInt32Array = path_service.build_distance_field(start)
	var deepest := start.y
	for index: int in range(distances.size()):
		if distances[index] < 0:
			continue
		deepest = maxi(deepest, world_grid.index_to_cell(index).y)
	return deepest


func _update_objective() -> void:
	var deepest := int(_tutorial_flags.get("_deepest", 0))
	var chapter_name := tr("chapter.1_settle") if chapter_model == null else _chapter_display_name(chapter_model.current_chapter)
	var objective_text := "%s · %s" % [chapter_name, tr("hud.objective") % [deepest, _objective_target_depth]]
	if chapter_model != null and chapter_model.campaign_complete:
		objective_text = "%s · %s" % [objective_text, tr("hud.campaign_done")]
	if chapter_model != null and chapter_model.rules_version >= 2:
		objective_text = chapter_name + " · " + _next_v2_goal()
	objective_label.text = objective_text
	if deepest >= _objective_target_depth and not bool(_tutorial_flags.get("objective_reached", false)):
		_tutorial_flags["objective_reached"] = true
		if _tutorial.advance(_tutorial_flags):
			tutorial_label.text = Localization.text(_tutorial.current_text_key())
		_push_notification("milestone", tr("notify.milestone"), Vector2i(world_grid.metadata.start_cell.x, deepest), 30.0, 3600.0)


func _poll_notifications() -> void:
	var item_system = colony_simulation.get_item_system()
	var food_count: int = item_system.get_total_count(ItemSystemScript.FOOD)
	var food_critical := int(AppConfig.get_document("balance").get("tutorial", {}).get("food_critical_count", FOOD_CRITICAL_COUNT))
	if food_count <= food_critical:
		_push_notification("food_low", tr("notify.food_low") % food_count, Vector2i(-1, -1), 6.0, 90.0)
	var in_danger := false
	var danger_cell := Vector2i(-1, -1)
	for mouse in colony_simulation.get_mice():
		if bool(mouse.danger_state):
			in_danger = true
			danger_cell = mouse.current_cell
	if in_danger and not _mice_were_in_danger:
		_push_notification("danger", tr("notify.danger"), danger_cell, 6.0, 20.0)
	_mice_were_in_danger = in_danger
	var zone_system = colony_simulation.get_zone_system()
	for zone: Zone in zone_system.get_zones():
		if zone.valid or zone.invalid_reasons.is_empty():
			continue
		var key := "%d:%s" % [zone.zone_id, zone.invalid_reasons[0]]
		if _notified_zone_keys.has(key):
			continue
		_notified_zone_keys[key] = true
		_push_notification("zone_lost", tr("notify.zone_lost") % _reason_text(String(zone.invalid_reasons[0])), zone.identity_anchor, 6.0, 15.0)


func _push_notification(category: String, text: String, focus_cell: Vector2i, cooldown: float = 10.0, lifetime: float = 6.0) -> void:
	if _notifications == null:
		return
	if _notifications.push(category, text, _now_seconds, focus_cell, lifetime, cooldown):
		_notifications_dirty = true


func _unhandled_input(event: InputEvent) -> void:
	if world_grid == null:
		return
	# F9's reload_current_scene removes this instance from the tree while
	# queued input events are still in flight; get_viewport() is null then.
	var viewport := get_viewport()
	if viewport == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = (event as InputEventKey).keycode
		if code == KEY_H or (code == KEY_ESCAPE and _help_open):
			_toggle_help()
			viewport.set_input_as_handled()
			return
		if (code == KEY_C and not (_start_view != null and _start_view.visible)) or (code == KEY_ESCAPE and _book_open):
			_toggle_collection_book()
			viewport.set_input_as_handled()
			return
	if _book_open or _help_open:
		viewport.set_input_as_handled()
		return
	if _start_view != null and _start_view.visible:
		viewport.set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		_toggle_settings()
		viewport.set_input_as_handled()
		return
	# The settings overlay owns the screen; world input stays blocked until it
	# closes so sliders can't accidentally paint designations underneath.
	if _settings_open:
		viewport.set_input_as_handled()
		return
	if _handle_player_shortcuts(event):
		viewport.set_input_as_handled()
		return
	if _handle_tool_shortcut(event):
		viewport.set_input_as_handled()
		return
	if _handle_dig_input(event):
		viewport.set_input_as_handled()
		return
	if not AppConfig.debug_tools_enabled():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_F2:
			world_view.set_grid_visible(not world_view.is_grid_visible())
			viewport.set_input_as_handled()
		elif key_event.keycode == KEY_F3:
			colony_debug_overlay.visible = not colony_debug_overlay.visible
			viewport.set_input_as_handled()
		elif key_event.keycode == KEY_F4:
			DisplayServer.clipboard_set(str(_current_seed))
			_last_feedback = tr("feedback.copied_seed") % _current_seed
			_feedback_seconds_remaining = 2.0
			viewport.set_input_as_handled()
		elif key_event.keycode == KEY_F5:
			_reload_debug_seed(_current_seed)
			viewport.set_input_as_handled()
		elif key_event.keycode == KEY_F6:
			_reload_debug_seed(_current_seed + 1)
			viewport.set_input_as_handled()
		elif key_event.keycode == KEY_F7:
			_last_feedback = tr("feedback.overlay") % worldgen_debug_overlay.cycle_mode()
			_feedback_seconds_remaining = 2.0
			viewport.set_input_as_handled()
		elif key_event.keycode == KEY_T:
			# 21_BALANCE_TELEMETRY session snapshot (debug builds only).
			_write_telemetry_snapshot()
			viewport.set_input_as_handled()


func _handle_player_shortcuts(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_TAB:
			time_control.cycle()
			_choose_speed(time_control.speed)
			return true
		KEY_SPACE:
			_paused = not _paused
			return true
		KEY_L:
			Localization.cycle()
			tutorial_label.text = Localization.text(_tutorial.current_text_key())
			if _settings_view != null and _settings_view.is_open():
				_settings_view.refresh_localization()
			return true
		# F9 quick-load. Editor note: F9 is also the Godot editor debugger's
		# pause shortcut, so an editor-launched game comes up paused after
		# the load; resume via the toolbar play button (or run standalone).
		KEY_F9:
			_request_load("quicksave")
			return true
		# Ctrl+S, not F8: F8 is the Godot editor's "stop running project"
		# shortcut and kills an editor-launched game before the input arrives.
		KEY_S:
			if key_event.ctrl_pressed or key_event.meta_pressed:
				_save_to_slot("quicksave")
				return true
		KEY_HOME:
			world_camera.focus_cell(world_grid.metadata.start_cell, _logical_cell_size)
			return true
		KEY_N:
			var focus := _notifications.latest_focus_cell(_now_seconds) if _notifications != null else Vector2i(-1, -1)
			if focus.x >= 0:
				world_camera.focus_cell(focus, _logical_cell_size)
				return true
			return false
	return false


func _handle_tool_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_1:
			_set_tool(Tool.DIG)
			return true
		KEY_2:
			_set_tool(Tool.SLEEPING)
			return true
		KEY_3:
			_set_tool(Tool.STORAGE)
			return true
		KEY_4:
			_set_tool(Tool.FOOD_FORAGE)
			return true
		KEY_5:
			_set_tool(Tool.SEAL)
			return true
		KEY_7:
			_set_tool(Tool.PRODUCTION)
			return true
		KEY_6:
			_set_tool(Tool.REINFORCE)
			return true
	return false


func _set_tool(tool: int) -> void:
	_current_tool = clampi(tool, Tool.DIG, Tool.PRODUCTION)
	_end_paint()
	if _audio_director != null:
		_audio_director.play_tool_select()
	var zone_type := _current_zone_type()
	zone_overlay_view.set_editing(_is_zone_tool(), zone_type)
	dig_cursor_view.set_tool_style(_tool_name())
	if _current_tool == Tool.DIG:
		_last_feedback = "feedback.choose_frontier"
	elif _current_tool == Tool.SEAL:
		_last_feedback = "feedback.seal_prompt"
	elif _current_tool == Tool.REINFORCE:
		_last_feedback = "feedback.reinforce_prompt"
	else:
		_last_feedback = "feedback.paint_zone"
	_hover_feedback = _last_feedback
	_feedback_seconds_remaining = 1.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_session()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_end_paint()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and _telemetry != null:
		# Flush the session snapshot on close so a playtest that never
		# presses the snapshot key still leaves its balance data behind.
		_write_telemetry_snapshot()


func _handle_dig_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if Input.is_key_pressed(KEY_SPACE):
					return false
				_begin_paint(PaintAction.DESIGNATE, _viewport_position_to_cell(mouse_event.position))
				return true
			if _paint_action == PaintAction.DESIGNATE:
				_end_paint()
				return true
			return false
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				_begin_paint(PaintAction.CANCEL, _viewport_position_to_cell(mouse_event.position))
			elif _paint_action == PaintAction.CANCEL:
				_end_paint()
			return true
	elif event is InputEventMouseMotion and _paint_action != PaintAction.NONE:
		_paint_to(_viewport_position_to_cell((event as InputEventMouseMotion).position))
		return true
	return false


func _begin_paint(action: int, cell_coord: Vector2i) -> void:
	_paint_action = action
	_last_painted_cell = Vector2i(-1, -1)
	_paint_to(cell_coord)


func _end_paint() -> void:
	if _telemetry != null:
		if _stroke_dig_cells > 0:
			_telemetry.record_dig_stroke(_stroke_dig_cells)
		if not _stroke_cancelled_cells.is_empty():
			_telemetry.record_dig_cancellations(_stroke_cancelled_cells)
		if _stroke_reinforce_cells > 0:
			_telemetry.record_reinforcement_requests(_stroke_reinforce_cells)
	_stroke_dig_cells = 0
	_stroke_cancelled_cells = []
	_stroke_reinforce_cells = 0
	_paint_action = PaintAction.NONE
	_last_painted_cell = Vector2i(-1, -1)


func _paint_to(cell_coord: Vector2i) -> void:
	if not world_grid.is_in_bounds(cell_coord) or cell_coord == _last_painted_cell:
		return
	var cells: Array[Vector2i] = []
	if _last_painted_cell.x < 0:
		cells.append(cell_coord)
	else:
		cells = _cardinal_line(_last_painted_cell, cell_coord)
	_last_painted_cell = cell_coord
	if cells.is_empty():
		return
	var result: Dictionary
	var stability = colony_simulation.get_stability_system()
	if _current_tool == Tool.SEAL:
		var changed: Array[Vector2i] = []
		var rejected: Array[Dictionary] = []
		for cell: Vector2i in cells:
			var seal_result: Dictionary = seal_system.cancel_request(cell) if _paint_action == PaintAction.CANCEL else seal_system.request_seal(cell)
			if bool(seal_result.ok):
				changed.append(cell)
			else:
				rejected.append({"cell": cell, "reason_code": seal_result.reason_code})
		result = {
			"ok": not changed.is_empty(),
			"reason_code": "OK" if not changed.is_empty() else ("NOT_OPEN" if rejected.is_empty() else rejected[0].reason_code),
			"changed_cells": changed,
			"rejected": rejected,
		}
	elif _current_tool == Tool.REINFORCE:
		var changed: Array[Vector2i] = []
		var rejected: Array[Dictionary] = []
		for cell: Vector2i in cells:
			var reinforce_result: Dictionary = (
				stability.cancel_request(cell)
				if _paint_action == PaintAction.CANCEL
				else stability.request_reinforce(cell)
			)
			if bool(reinforce_result.ok):
				changed.append(cell)
			else:
				rejected.append({"cell": cell, "reason_code": reinforce_result.reason_code})
		result = {
			"ok": not changed.is_empty(),
			"reason_code": "OK" if not changed.is_empty() else ("NOT_OPEN" if rejected.is_empty() else rejected[0].reason_code),
			"changed_cells": changed,
			"rejected": rejected,
		}
	elif _current_tool != Tool.DIG:
		if _paint_action == PaintAction.CANCEL:
			result = EraseZoneCommandScript.new(colony_simulation.get_zone_system(), cells).execute()
		else:
			result = PaintZoneCommandScript.new(colony_simulation.get_zone_system(), _current_zone_type(), cells).execute()
	elif _paint_action == PaintAction.CANCEL:
		result = CancelDigCommandScript.new(dig_system, cells).execute()
	else:
		result = DesignateDigCommandScript.new(dig_system, cells).execute()
	if _telemetry != null and bool(result.get("ok", false)):
		if _current_tool == Tool.DIG and _paint_action == PaintAction.DESIGNATE:
			_stroke_dig_cells += (result.get("accepted_cells", []) as Array).size()
		elif _current_tool == Tool.DIG and _paint_action == PaintAction.CANCEL:
			_stroke_cancelled_cells.append_array(result.get("cancelled_cells", []))
		elif _current_tool == Tool.REINFORCE and _paint_action == PaintAction.DESIGNATE:
			_stroke_reinforce_cells += (result.get("changed_cells", []) as Array).size()
	_set_command_feedback(result)


func _cardinal_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cursor := from_cell
	while cursor != to_cell:
		var delta := to_cell - cursor
		if absi(delta.x) >= absi(delta.y) and delta.x != 0:
			cursor.x += signi(delta.x)
		elif delta.y != 0:
			cursor.y += signi(delta.y)
		result.append(cursor)
	return result


func _set_command_feedback(result: Dictionary) -> void:
	_feedback_seconds_remaining = 1.4
	if _audio_director != null:
		if _paint_action == PaintAction.CANCEL:
			_audio_director.play_cancel()
		else:
			_audio_director.play_paint()
	if bool(result.get("ok", false)):
		var changed: Array = result.get("accepted_cells", result.get("cancelled_cells", result.get("changed_cells", [])))
		var changed_count: int = changed.size() + (result.get("removed_downstream", []) as Array).size()
		_last_feedback = tr("feedback.updated") % changed_count
		return
	var rejected: Array = result.get("rejected", [])
	var reason := String(result.get("reason_code", "NOT_EXCAVATABLE"))
	if not rejected.is_empty():
		reason = String(rejected[0].get("reason_code", reason))
	_last_feedback = _reason_text(reason)


func _refresh_hovered_cell() -> void:
	if _qa_inspector_cell.x >= 0:
		if _selected_cell != _qa_inspector_cell:
			_selected_cell = _qa_inspector_cell
			_update_inspector()
		return
	var candidate := _mouse_cell()
	if world_grid.is_in_bounds(candidate) and candidate != _selected_cell:
		_selected_cell = candidate
		_update_inspector()


func _update_cursor() -> void:
	var cell_coord := _mouse_cell()
	if not world_grid.is_in_bounds(cell_coord):
		dig_cursor_view.set_cursor(cell_coord, false, false, false)
		return
	var cancel_mode := _paint_action == PaintAction.CANCEL
	if _current_tool == Tool.SEAL:
		var valid: bool = seal_system.has_request(cell_coord) if cancel_mode else seal_system.inspect_request(cell_coord) == "OK"
		if cancel_mode:
			_hover_feedback = tr("hover.cancel_seal") if valid else _reason_text("REQUEST_NOT_FOUND")
		else:
			var reason: String = seal_system.inspect_request(cell_coord)
			_hover_feedback = tr("hover.seal_ok") if valid else _reason_text(reason)
		dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)
		return
	var stability = colony_simulation.get_stability_system()
	if _current_tool == Tool.REINFORCE and stability != null:
		var has_request: bool = stability.has_request(cell_coord)
		var reason_code: String = stability.inspect_request(cell_coord)
		var valid := has_request if cancel_mode else reason_code == "OK"
		if cancel_mode:
			_hover_feedback = tr("hover.cancel_reinforce") if has_request else _reason_text("REQUEST_NOT_FOUND")
		else:
			_hover_feedback = tr("hover.reinforce_ok") if valid else _reason_text(reason_code)
		dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)
		return
	if _is_zone_tool():
		var zone_system = colony_simulation.get_zone_system()
		var current_zone: Zone = zone_system.get_zone_at(cell_coord)
		var inspection: Dictionary = zone_system.inspect_cell(_current_zone_type(), cell_coord)
		var valid := current_zone != null if cancel_mode else bool(inspection.ok) or String(inspection.reason_code) == "ALREADY_ASSIGNED"
		if cancel_mode:
			_hover_feedback = tr("hover.erase_zone") % _tool_name() if valid else _reason_text("NOT_ASSIGNED")
		elif valid:
			_hover_feedback = tr("hover.paint_zone") % _tool_name()
		else:
			_hover_feedback = _reason_text(String(inspection.reason_code))
		dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)
		return
	var inspection: Dictionary = dig_system.inspect_designation(cell_coord)
	var valid: bool = world_grid.get_dig_state(cell_coord) != CellDataScript.DigState.NONE if cancel_mode else bool(inspection.get("ok", false))
	if cancel_mode:
		_hover_feedback = tr("hover.release_dig") if valid else _reason_text("NOT_DESIGNATED")
	else:
		_hover_feedback = tr("hover.legal_frontier") if valid else _reason_text(String(inspection.get("reason_code", "NOT_EXCAVATABLE")))
	if signal_system != null:
		var clue: String = signal_system.get_qualitative_clue("root_density", cell_coord)
		if not clue.is_empty():
			_hover_feedback += "  %s" % clue
		var moisture_clue: String = signal_system.get_qualitative_clue("moisture", cell_coord)
		if not moisture_clue.is_empty():
			_hover_feedback += "  %s" % moisture_clue
	dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)


func _update_hud() -> void:
	var stability = colony_simulation.get_stability_system()
	dig_status_label.text = tr("hud.dig_status") % [
		dig_system.get_designated_count(),
		seal_system.get_requests().size(),
		stability.get_requests().size() if stability != null else 0,
	]
	dig_status_label.visible = dig_system.get_designated_count() > 0 or not seal_system.get_requests().is_empty() or (stability != null and not stability.get_requests().is_empty())
	tool_status_label.visible = _paused
	tool_status_label.text = (tr("hud.paused_prefix") if _paused else "") + ("目前：" if Localization.current().begins_with("zh") else "Current: ") + _tool_name() + " · H " + ("操作說明" if Localization.current().begins_with("zh") else "Help")
	_refresh_toolbar()
	if _time_controls != null:
		_time_controls.refresh(_paused, time_control.speed)
	var mice: Array = colony_simulation.get_mice()
	var item_system = colony_simulation.get_item_system()
	colony_status_label.text = "%s %d · %s %d · %s %d" % [
		tr("hud.food"),
		item_system.get_total_count(ItemSystemScript.FOOD),
		tr("hud.material"),
		item_system.get_total_count(ItemSystemScript.GENERAL_MATERIAL),
		tr("hud.mice"),
		mice.size(),
	]
	for resource_id: String in ["STONE", "ORE", "METAL"]:
		if item_system.get_total_count(resource_id) == 0 and colony_simulation.get_capabilities().level == 0 and colony_simulation.get_production_system().completed_batches == 0:
			continue
		colony_status_label.text += " · %s %d" % [Resources.display_name(resource_id, Localization.current()), item_system.get_total_count(resource_id)]
	if colony_simulation.get_collection_book().unique_count() > 0:
		colony_status_label.text += " · C %d/18" % colony_simulation.get_collection_book().unique_count()
	dig_feedback_label.visible = _feedback_seconds_remaining > 0.0 or _hover_feedback != "feedback.choose_frontier"
	dig_feedback_label.text = tr(_last_feedback) if _feedback_seconds_remaining > 0.0 else tr(_hover_feedback)


func _player_inspector_text(cell) -> String:
	var lines: Array[String] = []
	if cell.is_exterior():
		return tr("hud.surface")
	if cell.is_traversable():
		lines.append(tr("hud.open_cavity"))
	else:
		var difficulty_key := "inspector.difficulty_low"
		if cell.hardness > 3.0:
			difficulty_key = "inspector.difficulty_extreme"
		elif cell.hardness > 1.5:
			difficulty_key = "inspector.difficulty_high"
		elif cell.hardness > 1.0:
			difficulty_key = "inspector.difficulty_medium"
		lines.append(tr("inspector.dig_difficulty") % [cell.material_name(cell.terrain_material), tr(difficulty_key)])
	if cell.sealed:
		lines.append(tr("inspector.sealed"))
	elif cell.rubble:
		lines.append(tr("inspector.rubble"))
	if cell.water_units > 0:
		lines.append(tr("inspector.water"))
	var clue_text := ""
	if signal_system != null:
		var root_clue: String = signal_system.get_qualitative_clue("root_density", _selected_cell)
		if not root_clue.is_empty():
			clue_text += root_clue
		var moisture_clue: String = signal_system.get_qualitative_clue("moisture", _selected_cell)
		if not moisture_clue.is_empty():
			clue_text += (" · " if not clue_text.is_empty() else "") + moisture_clue
	if not clue_text.is_empty():
		lines.append(tr("inspector.signs") % clue_text)
	var stability = colony_simulation.get_stability_system()
	if stability != null and world_grid.is_traversable(_selected_cell):
		lines.append(tr("inspector.stability") % Localization.text("stability." + String(stability.get_warning_level_name(stability.get_warning_level(_selected_cell))).to_lower()))
	var zone: Zone = colony_simulation.get_zone_system().get_zone_at(_selected_cell)
	if zone != null:
		lines.append(tr("inspector.zone") % _zone_display_name(zone.get_type_name()))
	if cell.feature_id >= 0:
		var feature = worldgen_result.feature_registry.get_feature(cell.feature_id)
		if feature != null and feature.type_id == "discovery" and not bool(feature.metadata.get("claimed", false)) and _discovery_view.signal_band(_selected_cell) > 0:
			var definition: Dictionary = DiscoveryScript.definition_for(str(feature.metadata.definition_id))
			var hints := {"food": ["小芽後面可能藏著食物", "Sprouts suggest food nearby"], "material": ["纖維可能帶來築巢材料", "Fibres suggest nesting materials"], "stone": ["灰色石紋提示可採集的石材", "Grey stone suggests collectable stone"], "ore": ["銅色微光提示礦石", "Copper glints suggest ore"], "collectible": ["小小閃光，也許是值得收藏的驚喜", "A small glimmer — perhaps a keepsake"]}
			var words: Array = hints.get(str(definition.get("kind", "")), [])
			if words.size() == 2:
				lines.append(str(words[0 if Localization.current().begins_with("zh") else 1]))
		if feature != null and not feature.hidden:
			lines.append(tr("inspector.discovered") % _feature_display_name(feature.type_id))
	return "\n".join(lines)


func _zone_display_name(type_name: String) -> String:
	if type_name == "PRODUCTION":
		return "生產區" if Localization.current().begins_with("zh") else "Workshop"
	return tr("zone." + type_name.replace("/", "_").to_lower())


func _feature_display_name(type_id: String) -> String:
	match type_id:
		"root_cluster":
			return tr("feature.root_cluster")
		"water_reservoir":
			return tr("feature.water_reservoir")
		"unstable_pocket":
			return tr("feature.unstable_pocket")
		"rock_mass":
			return tr("feature.rock_mass")
		"foundation":
			return tr("feature.foundation")
		_:
			return type_id.capitalize()


func _need_percent(value: float) -> float:
	return clampf(value * 100.0 if value <= 1.0 else value, 0.0, 100.0)


func _update_inspector() -> void:
	var cell = world_grid.get_cell(_selected_cell)
	if cell == null:
		inspector_label.text = tr("hud.inspector_hint") if not AppConfig.debug_tools_enabled() else "Move over the world to inspect a cell."
		return
	if not AppConfig.debug_tools_enabled():
		inspector_label.text = _player_inspector_text(cell)
		return
	var zone: Zone = colony_simulation.get_zone_system().get_zone_at(_selected_cell)
	var zone_text := "No zone"
	if zone != null:
		var zone_details := "quality %.0f%%" % (zone.suitability * 100.0)
		if not zone.invalid_reasons.is_empty():
			zone_details = "invalid: %s" % ", ".join(zone.invalid_reasons)
		elif not zone.suitability_warnings.is_empty():
			zone_details += " · %s" % ", ".join(zone.suitability_warnings)
		zone_text = "%s · %s · %s\n%s" % [
			zone.get_type_name().replace("_", "/").capitalize(),
			"valid" if zone.valid else "invalid",
			zone.get_setup_state_name().replace("_", " ").capitalize(),
			zone_details,
		]
	var signal_text := "Signals unavailable"
	if signal_system != null:
		signal_text = "Root %d/%s/%s · Moisture %d/%s/%s" % [
			signal_system.get_value("root_density", _selected_cell),
			signal_system.get_band_name(signal_system.get_band("root_density", _selected_cell)),
			signal_system.get_recognition_name("root_cluster"),
			signal_system.get_value("moisture", _selected_cell),
			signal_system.get_band_name(signal_system.get_band("moisture", _selected_cell)),
			signal_system.get_recognition_name("water_reservoir"),
		]
	var stability = colony_simulation.get_stability_system()
	if stability != null and world_grid.is_traversable(_selected_cell):
		var warning_level: int = stability.get_warning_level(_selected_cell)
		signal_text += " · Stability %s" % stability.get_warning_level_name(warning_level)
	var feature_text := "feature %d%s" % [cell.feature_id, " · LANDMARK" if cell.landmark else ""]
	if cell.feature_id >= 0:
		var feature = worldgen_result.feature_registry.get_feature(cell.feature_id)
		if feature != null and not feature.hidden:
			feature_text += " · %s · reserve %d" % [
				String(feature.metadata.get("lifecycle_state", "REVEALED")),
				int(feature.metadata.get("reserve_units", feature.metadata.get("food_reserve_units", 0))),
			]
	inspector_label.text = "Cell (%d, %d) · stratum %d\n%s · hardness %.2f · water %d%s%s\n%s · dig %s %.0f%%%s%s\n%s\n%s · %s" % [
		cell.coord.x,
		cell.coord.y,
		cell.stratum_id,
		cell.material_name(cell.terrain_material),
		cell.hardness,
		cell.water_units,
		" · SEALED" if cell.sealed else "",
		" · RUBBLE" if cell.rubble else "",
		"EXTERIOR" if cell.is_exterior() else ("Excavated" if cell.is_traversable() else "Solid"),
		_dig_state_name(cell.dig_state),
		cell.dig_progress * 100.0,
		" · PROTECTED" if cell.protected_cell else "",
		" · REINFORCED" if cell.reinforced else "",
		feature_text,
		signal_text,
		zone_text,
	]


func _on_root_feature_reacted(_feature_id: int, reaction: Dictionary) -> void:
	var produced := int(reaction.get("food_produced", 0))
	_tutorial_flags["root_revealed"] = true
	if _audio_director != null:
		_audio_director.play_discovery_stinger()
	var anchor := Vector2i(-1, -1)
	var feature = worldgen_result.feature_registry.get_feature(_feature_id)
	if feature != null:
		anchor = feature.anchor
	_push_notification("discovery_root", tr("notify.root_found") % produced, anchor, 25.0)
	_last_feedback = tr("feedback.root_exposed") % produced
	_feedback_seconds_remaining = 5.0


func _on_root_feature_revealed(feature_id: int, feature_type: String, _exposure_cell: Vector2i) -> void:
	_record_telemetry_discovery(feature_type, worldgen_result.feature_registry.get_feature(feature_id))


func _on_reservoir_breached(feature_id: int, cell: Vector2i, _danger_cells: Array, released_units: int) -> void:
	_slow_for_danger()
	_tutorial_flags["breach"] = true
	if _telemetry != null:
		_telemetry.record_breach(released_units)
		_telemetry.record_development("risk", "water_breach", {"units": released_units})
		_record_telemetry_discovery("water_reservoir", worldgen_result.feature_registry.get_feature(feature_id))
	if _vfx_view != null:
		_vfx_view.burst_water((Vector2(cell) + Vector2(0.5, 0.5)) * _logical_cell_size, released_units)
	if _audio_director != null:
		_audio_director.play_breach()
	world_camera.apply_shake(3.0)
	_push_notification("breach", tr("notify.breach") % released_units, cell, 25.0)
	_last_feedback = tr("feedback.reservoir_breach") % released_units
	_feedback_seconds_remaining = 6.0


func _on_region_collapsed(cells: Array, absorbed_water_units: int) -> void:
	if _telemetry != null:
		_telemetry.record_collapse(cells)
	var water_note := "" if int(absorbed_water_units) <= 0 else " %d water sank into the rubble." % int(absorbed_water_units)
	if _vfx_view != null and not cells.is_empty():
		var centroid := Vector2.ZERO
		for cell_value: Variant in cells:
			centroid += Vector2(cell_value as Vector2i)
		centroid = (centroid / float(cells.size()) + Vector2(0.5, 0.5)) * _logical_cell_size
		_vfx_view.burst_collapse(centroid, cells.size())
	if _audio_director != null:
		_audio_director.play_collapse()
	world_camera.apply_shake(4.0)
	_last_feedback = tr("feedback.collapse") % [cells.size(), water_note]
	_feedback_seconds_remaining = 6.0
	if not cells.is_empty():
		_push_notification("collapse", tr("notify.collapse") % cells.size(), cells[0] as Vector2i)


func _on_critical_warning(cells: Array) -> void:
	_slow_for_danger()
	_tutorial_flags["stability_warning"] = true
	if _audio_director != null:
		_audio_director.play_critical()
	if _feedback_seconds_remaining > 0.0:
		return
	if not cells.is_empty():
		_push_notification("stability_critical", tr("notify.critical"), cells[0] as Vector2i, 20.0)
	_last_feedback = tr("feedback.critical_warning") % [
		(cells[0] as Vector2i).x,
		(cells[0] as Vector2i).y,
	]
	_feedback_seconds_remaining = 5.0


## Dig impact feedback: debris/dust burst + material-specific impact sound.
## Adjacent digs also reveal buried Chapter 3 landmarks (old burrow, warm
## chamber) — the same Signal → Reveal courtesy the other features get.
func _on_cell_excavated(cell: Vector2i) -> void:
	var material := int(world_grid.get_material(cell))
	if _telemetry != null:
		_telemetry.record_excavation(material)
	if _vfx_view != null:
		_vfx_view.burst_dig((Vector2(cell) + Vector2(0.5, 0.5)) * _logical_cell_size, material)
	if _audio_director != null:
		_audio_director.play_material_dig(material)
	_check_buried_landmark_discovery(cell)


func _check_buried_landmark_discovery(cell: Vector2i) -> void:
	for feature_type: String in ["old_burrow", "warm_chamber"]:
		var feature_id := _find_hidden_feature_adjacent(cell, feature_type)
		if feature_id < 0:
			continue
		var feature = worldgen_result.feature_registry.get_feature(feature_id)
		if feature != null:
			feature.hidden = false
		_record_telemetry_discovery(feature_type, feature)
		world_grid.mark_region_dirty(
			Rect2i(cell - Vector2i(2, 2), Vector2i(5, 5)),
			world_grid.CHANGE_TERRAIN
		)
		_push_notification(
			"discovery_" + feature_type,
			tr("notify.%s_found" % feature_type),
			cell,
			30.0,
			3600.0
		)
		if _audio_director != null:
			_audio_director.play_discovery_stinger()


func _find_hidden_feature_adjacent(cell: Vector2i, type_id: String) -> int:
	for neighbor: Vector2i in world_grid.get_cardinal_neighbors(cell):
		var feature_id := int(world_grid.get_feature_id(neighbor))
		if feature_id < 0:
			continue
		var feature = worldgen_result.feature_registry.get_feature(feature_id)
		if feature != null and feature.type_id == type_id and bool(feature.hidden):
			return feature_id
	return -1


## 21_BALANCE_TELEMETRY §2 helpers. All no-ops unless the debug-gated
## recorder exists; sampling runs at 1 Hz from _process.
func _record_telemetry_discovery(feature_type: String, feature) -> void:
	if _telemetry == null:
		return
	var open_cells := 0
	if feature != null:
		for feature_cell: Vector2i in feature.cells:
			if world_grid.is_traversable(feature_cell):
				open_cells += 1
	_telemetry.record_discovery(String(feature_type), open_cells)


func _on_telemetry_warning_changed(cell: Vector2i, level: int) -> void:
	if _telemetry != null and level > 0 and not _telemetry._first_times.has("risk"):
		_telemetry.record_development("risk", "stability_warning")
	if _telemetry != null:
		_telemetry.note_warning(cell, level)


func _collect_reservoir_cells() -> Dictionary:
	var cells := {}
	for feature in worldgen_result.feature_registry.get_features("water_reservoir"):
		for reservoir_cell: Vector2i in feature.cells:
			cells[reservoir_cell] = true
	return cells


func _telemetry_sample_tick() -> void:
	if _telemetry != null:
		_telemetry.sample_production(colony_simulation.get_production_system())
	if _telemetry == null:
		return
	_telemetry.context["simulation_seconds"] = _simulated_seconds
	_telemetry.context["current_speed"] = time_control.speed
	var mice: Array = colony_simulation.get_mice()
	var idle := 0
	var steps := 0
	for index: int in range(mice.size()):
		var agent = mice[index]
		if agent.state == MouseAgentScript.State.IDLE:
			idle += 1
		var previous: Vector2i = _telemetry_previous_mouse_cells.get(index, agent.current_cell)
		steps += absi(agent.current_cell.x - previous.x) + absi(agent.current_cell.y - previous.y)
		_telemetry_previous_mouse_cells[index] = agent.current_cell
	_telemetry.sample_colony(idle, mice.size(), steps)
	var total_units := 0
	var corridor_units := 0
	var flooded_storage := 0
	var zone_system = colony_simulation.get_zone_system()
	for y: int in range(world_grid.height):
		for x: int in range(world_grid.width):
			var cell := Vector2i(x, y)
			var units := int(world_grid.get_water_units(cell))
			if units <= 0:
				continue
			total_units += units
			if not _telemetry_reservoir_cells.has(cell):
				corridor_units += units
	_telemetry.sample_water(total_units, corridor_units)
	for zone in zone_system.get_zones_by_type(ZoneScript.Type.STORAGE, false):
		for zone_cell: Vector2i in zone.cells:
			if int(world_grid.get_water_units(zone_cell)) > 0:
				flooded_storage += 1
	_telemetry.record_flooded_storage_cells(flooded_storage)


func _write_telemetry_snapshot() -> void:
	if _telemetry == null:
		return
	var summary: Dictionary = _telemetry.to_summary_dict()
	var directory := ProjectSettings.globalize_path("user://telemetry")
	var result: Dictionary = SessionTelemetryScript.write_snapshot(directory, _telemetry_seed, summary)
	if bool(result.ok):
		GameLog.info("TELEMETRY", "Session snapshot written path=%s" % String(result.path))
		_last_feedback = "telemetry snapshot saved"
		_feedback_seconds_remaining = 2.0
	else:
		GameLog.failure("TELEMETRY", "Snapshot failed path=%s error=%s" % [String(result.path), String(result.error)])


## Zone dressing completion gets its own soft assign cue (spec §2 Interaction).
func _on_zone_setup_state_changed(_zone_id: int, setup_state: int) -> void:
	if setup_state == ZoneScript.SetupState.SET_UP and _audio_director != null:
		_audio_director.play_zone_assign()


## Player settings overlay: saved options override the config defaults for
## this session, and live changes apply to audio/vfx/camera immediately.
func _setup_settings_view(accessibility: Dictionary, audio_config: Dictionary) -> void:
	_settings_view = SettingsViewScript.new()
	_settings_view.name = "Settings"
	($UI/Root as Control).add_child(_settings_view)
	var saved := _settings_view.store
	var effective_audio := audio_config.duplicate(true)
	if saved.load_settings():
		var player := saved.as_audio_accessibility()
		effective_audio["master_volume"] = player.master_volume
		effective_audio["sfx_volume"] = player.sfx_volume
		effective_audio["ambience_volume"] = player.ambience_volume
		effective_audio["music_volume"] = player.music_volume
		accessibility = {
			"reduced_particles": player.reduced_particles,
			"reduced_shake": player.reduced_shake,
		}
		_apply_accessibility(accessibility)
	if _audio_director != null:
		_audio_director.apply_volumes(effective_audio)
	_settings_view.settings_changed.connect(_on_settings_changed)
	_settings_view.resume_requested.connect(_toggle_settings)
	_settings_view.quick_load_confirmed.connect(func() -> void:
		_toggle_settings()
		_request_load("quicksave")
	)


func _apply_accessibility(accessibility: Dictionary) -> void:
	if _vfx_view != null:
		_vfx_view.set_reduced_particles(bool(accessibility.get("reduced_particles", false)))
	world_camera.reduced_shake = bool(accessibility.get("reduced_shake", false))


func _on_settings_changed(audio_accessibility: Dictionary) -> void:
	if _audio_director != null:
		_audio_director.apply_volumes(audio_accessibility)
	_apply_accessibility(audio_accessibility)


func _toggle_settings() -> void:
	_settings_open = not _settings_open
	if _settings_open:
		_pause_before_settings = _paused
		_settings_view.open()
	else:
		_settings_view.close()
	# Settings pause the simulation; the Space pause flag stays independent.
	_paused = true if _settings_open else _pause_before_settings
	_sync_camera_input()


func _mouse_cell() -> Vector2i:
	if _qa_inspector_cell.x >= 0:
		return _qa_inspector_cell
	return world_view.local_position_to_cell(world_view.get_local_mouse_position())


func set_qa_inspector_cell(cell: Vector2i) -> bool:
	if not AppConfig.cheats_enabled() or not world_grid.is_in_bounds(cell):
		return false
	_qa_inspector_cell = cell
	_selected_cell = cell
	_update_inspector()
	return true


func _viewport_position_to_cell(viewport_position: Vector2) -> Vector2i:
	var world_local := world_view.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return world_view.local_position_to_cell(world_local)


func _designate_qa_demo_path() -> void:
	var cursor: Vector2i = world_grid.metadata.start_cell
	while world_grid.is_in_bounds(cursor + Vector2i.DOWN) and world_grid.is_traversable(cursor + Vector2i.DOWN):
		cursor += Vector2i.DOWN
	var cells: Array[Vector2i] = []
	for _index: int in range(9):
		cursor += Vector2i.DOWN
		cells.append(cursor)
	for _index: int in range(5):
		cursor += Vector2i.RIGHT
		cells.append(cursor)
	var result: Dictionary = DesignateDigCommandScript.new(dig_system, cells).execute()
	_set_command_feedback(result)


func _seed_initial_supplies() -> void:
	var home: Vector2i = world_grid.metadata.start_cell
	var food_cell := _find_traversable_cell(home, [Vector2i(-4, 0), Vector2i(-3, 0), Vector2i(-2, 0), Vector2i.LEFT])
	var material_cell := _find_traversable_cell(home, [Vector2i(4, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i.RIGHT])
	colony_simulation.add_item_pile(ItemSystemScript.FOOD, food_cell, 8)
	colony_simulation.add_item_pile(ItemSystemScript.GENERAL_MATERIAL, material_cell, 10)


## QA colony/zone demos benchmark three-mouse concurrency; the campaign now
## starts with a single mouse, so top the population up explicitly.
func _ensure_qa_mice(target: int) -> void:
	var missing: int = target - colony_simulation.get_mice().size()
	if missing <= 0:
		return
	for spawn_cell in colony_simulation.find_spawn_cells_near(world_grid.metadata.start_cell, missing):
		if colony_simulation.add_mouse("mouse_%d" % (colony_simulation.get_mice().size() + 1), spawn_cell) == null:
			break


func _setup_qa_colony_demo() -> void:
	_ensure_qa_mice(3)
	var home: Vector2i = world_grid.metadata.start_cell
	var food_cell := _find_traversable_cell(home, [Vector2i(-4, 0), Vector2i(-3, 0), Vector2i.LEFT])
	var material_cell := _find_traversable_cell(home, [Vector2i(4, 0), Vector2i(3, 0), Vector2i.RIGHT])
	# Route the QA haul across the whole start room so capture timing visibly proves carrying.
	var result: Dictionary = colony_simulation.setup_qa_demo(food_cell, material_cell, food_cell)
	if not bool(result.get("ok", false)):
		GameLog.failure("QA", "Phase 3 colony demo setup failed: %s" % result.get("reason_code", "UNKNOWN"))


func _setup_qa_zone_demo() -> void:
	_ensure_qa_mice(3)
	var home: Vector2i = world_grid.metadata.start_cell
	var zone_system = colony_simulation.get_zone_system()
	var sleeping: Array[Vector2i] = [home + Vector2i(-3, -1), home + Vector2i(-2, -1), home + Vector2i(-1, -1)]
	var storage: Array[Vector2i] = [home + Vector2i(1, -1), home + Vector2i(2, -1), home + Vector2i(1, 0), home + Vector2i(2, 0)]
	var food: Array[Vector2i] = [home + Vector2i(-2, 1), home + Vector2i(-1, 1)]
	var results: Array[Dictionary] = [
		PaintZoneCommandScript.new(zone_system, ZoneScript.Type.SLEEPING, sleeping).execute(),
		PaintZoneCommandScript.new(zone_system, ZoneScript.Type.STORAGE, storage).execute(),
		PaintZoneCommandScript.new(zone_system, ZoneScript.Type.FOOD_FORAGE, food).execute(),
	]
	for result: Dictionary in results:
		if not result.ok:
			GameLog.failure("QA", "Phase 4 zone demo setup failed: %s" % result.reason_code)
	_set_tool(Tool.STORAGE)


func _setup_qa_root_demo(requested_mode: String) -> void:
	var food_roots: Array = []
	for feature in worldgen_result.feature_registry.get_features("root_cluster"):
		if bool(feature.metadata.get("food_opportunity", false)):
			food_roots.append(feature)
	if food_roots.is_empty():
		GameLog.failure("QA", "Phase 6 Root demo has no food-bearing Root Cluster")
		return
	var root_feature = food_roots[0]
	if requested_mode.to_lower() in ["reveal", "stable"]:
		var witness: Array = world_grid.metadata.get("validation_metrics", {}).get("witness_paths", {}).get("early_food", [])
		if not _replay_qa_excavation_witness(witness):
			GameLog.failure("QA", "Phase 6 Root demo could not replay the early-food witness")
			return
		for feature in food_roots:
			if not feature.hidden:
				root_feature = feature
				break
		var forage_cell := Vector2i(-1, -1)
		if not witness.is_empty() and witness[-1] is Vector2i:
			forage_cell = witness[-1]
		if forage_cell.x >= 0:
			var zones = colony_simulation.get_zone_system()
			var painted: Dictionary = zones.paint_zone(ZoneScript.Type.FOOD_FORAGE, [forage_cell])
			var zone: Zone = zones.get_zone_at(forage_cell)
			if bool(painted.get("ok", false)) and zone != null:
				zones.begin_setup(zone.zone_id)
				zones.apply_setup_material(zone.zone_id, zone.setup_material_required)
				root_feature_system.fixed_tick(float(root_feature.metadata.get("forage_interval_seconds", 8.0)))
		_set_tool(Tool.FOOD_FORAGE)
	else:
		var best_cell := _best_root_clue_cell(root_feature)
		set_qa_inspector_cell(best_cell)
		debug_inspector.visible = false
	world_camera.focus_cell(root_feature.anchor, _logical_cell_size)
	set_qa_inspector_cell(root_feature.anchor if not root_feature.hidden else _qa_inspector_cell)


func _best_root_clue_cell(root_feature) -> Vector2i:
	var best_value := -1
	var best_cell: Vector2i = root_feature.anchor
	var search_region: Rect2i = root_feature.get_bounds().grow(6)
	for y: int in range(maxi(0, search_region.position.y), mini(world_grid.height, search_region.end.y)):
		for x: int in range(maxi(0, search_region.position.x), mini(world_grid.width, search_region.end.x)):
			var cell := Vector2i(x, y)
			if world_grid.is_exterior(cell) or world_grid.get_feature_id(cell) >= 0:
				continue
			var value: int = int(world_grid.get_root_signal(cell))
			if value > best_value:
				best_value = value
				best_cell = cell
	return best_cell


func _setup_qa_water_demo(requested_mode: String) -> void:
	var reservoirs: Array = worldgen_result.feature_registry.get_features("water_reservoir")
	if reservoirs.is_empty():
		GameLog.failure("QA", "Phase 7 Water demo has no reservoir")
		return
	var reservoir = reservoirs[0]
	for candidate in reservoirs:
		if candidate.required:
			reservoir = candidate
			break
	var mode := requested_mode.strip_edges().to_lower()
	if mode == "clue":
		var clue_cell := _best_moisture_clue_cell(reservoir)
		world_camera.focus_cell(clue_cell, _logical_cell_size)
		set_qa_inspector_cell(clue_cell)
		_set_tool(Tool.DIG)
		return
	if mode == "seal":
		var seal_cell := _find_qa_seal_cell()
		if seal_cell.x < 0 or not colony_simulation.request_seal(seal_cell).ok:
			GameLog.failure("QA", "Phase 7 Seal demo could not create request")
			return
		for _tick: int in range(500):
			colony_simulation.fixed_tick(0.05)
			if world_grid.is_sealed(seal_cell):
				break
		_set_tool(Tool.SEAL)
		world_camera.focus_cell(seal_cell, _logical_cell_size)
		set_qa_inspector_cell(seal_cell)
		return
	var witness := _qa_potential_path(reservoir.cells)
	if not _replay_qa_until_revealed(witness, reservoir):
		GameLog.failure("QA", "Phase 7 Water demo could not breach reservoir witness")
		return
	for _tick: int in range(16):
		water_system.fixed_tick(0.2)
	var outlet: Vector2i = reservoir.metadata.get("outlet_cell", reservoir.anchor)
	_set_tool(Tool.SEAL)
	world_camera.focus_cell(outlet, _logical_cell_size)
	set_qa_inspector_cell(outlet)


func _best_moisture_clue_cell(reservoir) -> Vector2i:
	var best_value := -1
	var best_cell: Vector2i = reservoir.anchor
	var search_region: Rect2i = reservoir.get_bounds().grow(6)
	for y: int in range(maxi(0, search_region.position.y), mini(world_grid.height, search_region.end.y)):
		for x: int in range(maxi(0, search_region.position.x), mini(world_grid.width, search_region.end.x)):
			var cell := Vector2i(x, y)
			if world_grid.is_exterior(cell) or world_grid.get_feature_id(cell) >= 0:
				continue
			var value: int = int(world_grid.get_moisture_signal(cell))
			if value > best_value:
				best_value = value
				best_cell = cell
	return best_cell


func _qa_potential_path(goals: Array[Vector2i]) -> Array[Vector2i]:
	var start: Vector2i = world_grid.metadata.start_cell
	var goal_lookup: Dictionary = {}
	for goal: Vector2i in goals:
		goal_lookup[goal] = true
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
		for neighbor: Vector2i in world_grid.get_cardinal_neighbors(current):
			if previous.has(neighbor) or world_grid.is_exterior(neighbor) or world_grid.is_protected(neighbor):
				continue
			if not world_grid.is_traversable(neighbor) and not world_grid.is_solid(neighbor):
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


func _replay_qa_until_revealed(witness: Array[Vector2i], feature) -> bool:
	var worker_cell: Vector2i = world_grid.metadata.start_cell
	for cell: Vector2i in witness:
		if world_grid.is_traversable(cell):
			worker_cell = cell
			continue
		var designation: Dictionary = dig_system.designate_path([cell])
		var job = dig_system.claim_next("qa_phase7", worker_cell)
		if not designation.ok or job == null:
			return false
		var completion: Dictionary = dig_system.advance_job("qa_phase7", job.job_id, 1000.0)
		if not completion.completed:
			return false
		worker_cell = cell
		if not feature.hidden:
			return true
	return not feature.hidden


func _find_qa_seal_cell() -> Vector2i:
	var start: Vector2i = world_grid.metadata.start_cell
	var distances: PackedInt32Array = path_service.build_distance_field(start)
	var candidates: Array[Dictionary] = []
	for index: int in range(distances.size()):
		if distances[index] < 2:
			continue
		var cell: Vector2i = world_grid.index_to_cell(index)
		if world_grid.get_water_units(cell) > 0:
			continue
		var open_neighbors := 0
		for neighbor: Vector2i in world_grid.get_cardinal_neighbors(cell):
			if path_service.is_walkable(neighbor):
				open_neighbors += 1
		if open_neighbors >= 2:
			candidates.append({
				"cell": cell,
				"vertical_offset": absi(cell.y - start.y),
				"distance": distances[index],
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.vertical_offset) != int(b.vertical_offset):
			return int(a.vertical_offset) < int(b.vertical_offset)
		if int(a.distance) != int(b.distance):
			return int(a.distance) < int(b.distance)
		return world_grid.cell_to_index(a.cell) < world_grid.cell_to_index(b.cell)
	)
	return Vector2i(-1, -1) if candidates.is_empty() else candidates[0].cell


func _replay_qa_excavation_witness(witness: Array) -> bool:
	if witness.size() <= 1:
		return false
	var worker_cell: Vector2i = world_grid.metadata.start_cell
	for cell_value: Variant in witness:
		if not cell_value is Vector2i:
			return false
		var cell: Vector2i = cell_value
		if world_grid.is_traversable(cell):
			worker_cell = cell
			continue
		var designation: Dictionary = dig_system.designate_path([cell])
		if not bool(designation.get("ok", false)):
			return false
		var job = dig_system.claim_next("qa_phase6", worker_cell)
		if job == null:
			return false
		var completion: Dictionary = dig_system.advance_job("qa_phase6", job.job_id, 1000.0)
		if not bool(completion.get("ok", false)) or not bool(completion.get("completed", false)):
			return false
		worker_cell = cell
	return true


func _setup_qa_stability_demo(requested_mode: String) -> void:
	var mode := requested_mode.strip_edges().to_lower()
	var home: Vector2i = world_grid.metadata.start_cell
	# Phase 13: the stability system rates the CEILING run, so the demo picks
	# a ceiling run and sizes the tunnel span from its weakest material.
	var stability_balance: Dictionary = AppConfig.get_document("balance").get("stability", {})
	var seam := _find_qa_teaching_ceiling(home, stability_balance)
	if int(seam.ceiling_row) < 0:
		GameLog.failure("QA", "Phase 8 Stability demo found no teachable ceiling run")
		return
	var span_count: int
	match mode:
		"clue":
			span_count = mini(4, int(seam.length))
		"collapse":
			# Deliberate over-span: twice the allowed span guarantees the
			# critical band and a bounded collapse.
			span_count = clampi(int(seam.longest_allowed) * 2, 4, mini(14, int(seam.longest_length)))
		_:
			# Warn/reinforce: 90% of the allowed span shows crumb/crack
			# warnings but never reaches critical, so reinforcement can land.
			span_count = clampi(int(float(seam.allowed) * 0.9), 4, mini(9, int(seam.length)))
	var goals: Array[Vector2i] = []
	for index: int in range(span_count):
		if mode == "collapse":
			goals.append(Vector2i(int(seam.longest_start) + index, int(seam.longest_ceiling_row) + 1))
		else:
			goals.append(Vector2i(int(seam.start) + index, int(seam.ceiling_row) + 1))
	var witness := _qa_potential_path(goals)
	if witness.is_empty() or not _replay_qa_excavation_witness(witness):
		GameLog.failure("QA", "Phase 8 Stability demo could not excavate a witness span")
		return
	for _pass: int in range(goals.size() + 1):
		var all_done := true
		var progressed := false
		for goal: Vector2i in goals:
			if world_grid.is_traversable(goal):
				continue
			all_done = false
			var work := Vector2i(-1, -1)
			for neighbor: Vector2i in world_grid.get_cardinal_neighbors(goal):
				if path_service.is_walkable(neighbor):
					work = neighbor
					break
			if work.x < 0:
				continue
			if not bool(dig_system.designate_path([goal]).get("ok", false)):
				continue
			var job = dig_system.claim_next("qa_phase8", work)
			if job == null:
				continue
			if bool(dig_system.advance_job("qa_phase8", job.job_id, 10000.0).get("completed", false)):
				progressed = true
		if all_done or not progressed:
			break
	for _tick: int in range(12):
		colony_simulation.fixed_tick(0.05)
	var stability = colony_simulation.get_stability_system()
	var excavated := 0
	for goal: Vector2i in goals:
		if world_grid.is_traversable(goal):
			excavated += 1
	if excavated < 3:
		GameLog.failure("QA", "Phase 8 Stability demo witness span too short")
		return
	var tunnel_cells: Array[Vector2i] = []
	for x: int in range(int(seam.start), int(seam.start) + excavated):
		tunnel_cells.append(Vector2i(x, int(seam.ceiling_row) + 1))
	world_camera.focus_cell(tunnel_cells[tunnel_cells.size() / 2], _logical_cell_size)
	set_qa_inspector_cell(tunnel_cells[tunnel_cells.size() / 2])
	_set_tool(Tool.REINFORCE)
	match mode:
		"reinforce":
			var start_cell: Vector2i = world_grid.metadata.start_cell
			var request_cells: Array[Vector2i] = []
			for candidate_cell: Vector2i in tunnel_cells:
				if String(stability.inspect_request(candidate_cell)) != "OK":
					continue
				if path_service.find_path(start_cell, candidate_cell).is_empty():
					continue
				request_cells.append(candidate_cell)
			if request_cells.is_empty():
				GameLog.failure("QA", "Phase 8 Reinforce demo found no connected ceiling candidate")
				return
			var supply_cell: Vector2i = world_grid.metadata.start_cell
			for neighbor: Vector2i in world_grid.get_cardinal_neighbors(request_cells[0]):
				if path_service.is_walkable(neighbor):
					supply_cell = neighbor
					break
			colony_simulation.add_item_pile("GENERAL_MATERIAL", supply_cell, request_cells.size() + 1)
			for request_cell: Vector2i in request_cells:
				var request: Dictionary = colony_simulation.request_reinforce(request_cell)
				if not bool(request.get("ok", false)):
					GameLog.failure("QA", "Phase 8 Reinforce demo request rejected: %s" % String(request.get("reason_code", "?")))
					return
			var reinforced_count := 0
			for _tick: int in range(2400):
				colony_simulation.fixed_tick(0.05)
				reinforced_count = 0
				for request_cell: Vector2i in request_cells:
					if world_grid.is_reinforced(request_cell + Vector2i.UP):
						reinforced_count += 1
				if reinforced_count == request_cells.size():
					break
			if reinforced_count < request_cells.size():
				GameLog.failure("QA", "Phase 8 Reinforce demo completed %d/%d supports" % [reinforced_count, request_cells.size()])
				return
			for _tick: int in range(80):
				colony_simulation.fixed_tick(0.05)
			_last_feedback = tr("feedback.reinforce_done") % request_cells.size()
			_feedback_seconds_remaining = 30.0
		"collapse":
			var deadline := 6000
			var demo_collapsed := false
			while deadline > 0:
				colony_simulation.fixed_tick(0.05)
				deadline -= 1
				for tunnel_cell: Vector2i in tunnel_cells:
					if not world_grid.is_traversable(tunnel_cell):
						demo_collapsed = true
						break
				if demo_collapsed:
					break
			if not demo_collapsed:
				GameLog.failure("QA", "Phase 8 Collapse demo never collapsed the over-span")
				return
			for _tick: int in range(40):
				colony_simulation.fixed_tick(0.05)
		_:
			pass


## Phase 13: the stability demo fixtures evaluate the CEILING run (the
## stability system rates roof spans), choosing the teaching band nearest the
## start so the witness path stays short. `allowed` mirrors the stability
## balance spans for the weakest ceiling material in the run.
func _find_qa_teaching_ceiling(home: Vector2i, stability_balance: Dictionary) -> Dictionary:
	var span_short := maxi(1, int(stability_balance.get("span_short", 6)))
	var span_moderate := maxi(1, int(stability_balance.get("span_moderate", 12)))
	var best := {"ceiling_row": -1, "start": -1, "length": 0, "allowed": span_moderate, "distance": 1 << 28}
	var longest := {"ceiling_row": -1, "start": -1, "length": 0, "allowed": span_moderate}
	for ceiling_row: int in range(home.y + 3, mini(world_grid.height - 4, home.y + 16)):
		var tunnel_row := ceiling_row + 1
		var run_start := -1
		var run_allowed := span_moderate
		var run_usable := true
		for x: int in range(2, world_grid.width - 2):
			var ceiling := Vector2i(x, ceiling_row)
			var tunnel := Vector2i(x, tunnel_row)
			var material := int(world_grid.get_material(ceiling))
			var ceiling_usable: bool = (
				world_grid.is_solid(ceiling)
				and not world_grid.is_exterior(ceiling)
				and not world_grid.is_protected(ceiling)
				and world_grid.get_feature_id(ceiling) < 0
			)
			var is_support: bool = material == CellDataScript.TerrainMaterial.STONE or material == CellDataScript.TerrainMaterial.FOUNDATION
			var tunnel_usable: bool = (
				world_grid.is_solid(tunnel)
				and not world_grid.is_exterior(tunnel)
				and not world_grid.is_protected(tunnel)
				and world_grid.get_feature_id(tunnel) < 0
				and world_grid.get_material(tunnel) != CellDataScript.TerrainMaterial.STONE
			)
			if ceiling_usable and not is_support and tunnel_usable:
				if run_start < 0:
					run_start = x
					run_allowed = span_moderate
				run_allowed = mini(run_allowed, span_short if material in [CellDataScript.TerrainMaterial.DAMP_CLAY, CellDataScript.TerrainMaterial.LOOSE_SOIL] else span_moderate)
			else:
				if run_start >= 0:
					_consider_teaching_run(home, best, ceiling_row, run_start, x - run_start, run_allowed)
					_consider_longest_run(longest, ceiling_row, run_start, x - run_start, run_allowed)
				run_start = -1
		if run_start >= 0:
			_consider_teaching_run(home, best, ceiling_row, run_start, world_grid.width - 2 - run_start, run_allowed)
			_consider_longest_run(longest, ceiling_row, run_start, world_grid.width - 2 - run_start, run_allowed)
	if int(longest.length) > int(best.length):
		best["longest_ceiling_row"] = longest.ceiling_row
		best["longest_start"] = longest.start
		best["longest_length"] = longest.length
		best["longest_allowed"] = longest.allowed
	return best


func _consider_longest_run(longest: Dictionary, ceiling_row: int, run_start: int, run_length: int, run_allowed: int) -> void:
	if run_length > int(longest.length):
		longest["ceiling_row"] = ceiling_row
		longest["start"] = run_start
		longest["length"] = run_length
		longest["allowed"] = run_allowed


func _consider_teaching_run(home: Vector2i, best: Dictionary, ceiling_row: int, run_start: int, run_length: int, run_allowed: int) -> void:
	if run_length < 4:
		return
	var center_x := run_start + run_length / 2
	var distance: int = absi(center_x - home.x) + absi(ceiling_row - home.y)
	if distance < int(best.distance) or (distance == int(best.distance) and run_length > int(best.length)):
		best["ceiling_row"] = ceiling_row
		best["start"] = run_start
		best["length"] = run_length
		best["allowed"] = run_allowed
		best["distance"] = distance


func _find_traversable_cell(anchor: Vector2i, offsets: Array[Vector2i]) -> Vector2i:
	for offset: Vector2i in offsets:
		var candidate := anchor + offset
		if world_grid.is_traversable(candidate) and path_service.is_reachable(anchor, candidate):
			return candidate
	return anchor


func _dig_state_name(state: int) -> String:
	match state:
		CellDataScript.DigState.QUEUED:
			return "Queued"
		CellDataScript.DigState.ACTIVE:
			return "Active"
		_:
			return "None"


func _reason_text(reason_code: String) -> String:
	if reason_code == "ABILITY_REQUIRED":
		return "需要更好的鼠群工具，可在工坊加工金屬" if Localization.current().begins_with("zh") else "Better colony tools are needed — refine metal at a workshop"
	match reason_code:
		"OUT_OF_BOUNDS":
			return tr("reason.OUT_OF_BOUNDS")
		"NOT_EXCAVATABLE":
			return tr("reason.NOT_EXCAVATABLE")
		"PROTECTED_FEATURE":
			return tr("reason.PROTECTED_FEATURE")
		"NOT_CONTIGUOUS":
			return tr("reason.NOT_CONTIGUOUS")
		"NOT_CONNECTED_TO_EXCAVATED":
			return tr("reason.NOT_CONNECTED_TO_EXCAVATED")
		"NOT_DESIGNATED":
			return tr("reason.NOT_DESIGNATED")
		"NOT_OPEN":
			return tr("reason.NOT_OPEN")
		"EXTERIOR":
			return tr("reason.EXTERIOR")
		"ALREADY_SEALED":
			return tr("reason.ALREADY_SEALED")
		"ALREADY_REQUESTED":
			return tr("reason.ALREADY_REQUESTED")
		"REQUEST_NOT_FOUND":
			return tr("reason.REQUEST_NOT_FOUND")
		"WATER_DISPLACEMENT_BLOCKED":
			return tr("reason.WATER_DISPLACEMENT_BLOCKED")
		"NO_ROOF":
			return tr("reason.NO_ROOF")
		"ALREADY_REINFORCED":
			return tr("reason.ALREADY_REINFORCED")
		"NOT_EXCAVATED":
			return tr("reason.NOT_EXCAVATED")
		"NOT_CONNECTED":
			return tr("reason.NOT_CONNECTED")
		"FLOODED":
			return tr("reason.FLOODED")
		"WET":
			return tr("reason.WET")
		"ALREADY_ASSIGNED":
			return tr("reason.ALREADY_ASSIGNED")
		"NOT_ASSIGNED":
			return tr("reason.NOT_ASSIGNED")
		_:
			return reason_code.replace("_", " ").capitalize()


func _reload_debug_seed(seed_value: int) -> void:
	if not AppConfig.debug_tools_enabled():
		return
	_debug_seed_override_set = true
	_debug_seed_override = seed_value
	get_tree().reload_current_scene.call_deferred()


func _has_user_argument(argument_name: String) -> bool:
	return OS.get_cmdline_user_args().has(argument_name)


func _user_argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _current_zone_type() -> int:
	match _current_tool:
		Tool.PRODUCTION:
			return ZoneScript.Type.PRODUCTION
		Tool.SLEEPING:
			return ZoneScript.Type.SLEEPING
		Tool.STORAGE:
			return ZoneScript.Type.STORAGE
		Tool.FOOD_FORAGE:
			return ZoneScript.Type.FOOD_FORAGE
		_:
			return ZoneScript.Type.SLEEPING


func _is_zone_tool() -> bool:
	return _current_tool in [Tool.SLEEPING, Tool.STORAGE, Tool.FOOD_FORAGE, Tool.PRODUCTION]


func _tool_name() -> String:
	match _current_tool:
		Tool.PRODUCTION:
			return "生產區" if Localization.current().begins_with("zh") else "Workshop"
		Tool.SLEEPING:
			return tr("tool.sleeping")
		Tool.STORAGE:
			return tr("tool.storage")
		Tool.FOOD_FORAGE:
			return tr("tool.food_forage")
		Tool.SEAL:
			return tr("tool.seal")
		Tool.REINFORCE:
			return tr("tool.reinforce")
		_:
			return tr("tool.dig")


func _on_discovery(event: Dictionary) -> void:
	var definition: Dictionary = DiscoveryScript.definition_for(str(event.definition_id))
	var name: String = str(definition.get("zh" if Localization.current().begins_with("zh") else "en", event.definition_id))
	var reward := ""
	if not str(event.item).is_empty():
		reward = " +%d %s" % [int(event.amount), Resources.display_name(str(event.item), Localization.current())]
	_push_notification("find_%s" % event.id, name + reward, event.cell, 0.0, 8.0)
	if _audio_director != null:
		_audio_director.play_discovery_stinger()
	if _vfx_view != null:
		_vfx_view.burst_dig((Vector2(event.cell) + Vector2(0.5, 0.5)) * _logical_cell_size, 1)
	if _telemetry != null:
		_telemetry.record_discovery(str(event.definition_id), 1)
		if str(definition.get("kind", "")) == "collectible":
			_telemetry.record_development("collection", str(event.definition_id))
		elif not str(event.item).is_empty():
			_telemetry.record_resource_gain(str(event.item), int(event.amount))


func _toggle_collection_book() -> void:
	if _collection_view == null or _settings_open or _help_open:
		return
	_book_open = not _book_open
	if _book_open:
		_pause_before_book = _paused
		_paused = true
		_collection_view.refresh()
	else:
		_paused = _pause_before_book
	_collection_view.visible = _book_open
	if _modal_backdrop != null:
		_modal_backdrop.visible = _book_open or _help_open
	_sync_camera_input()


func _chapter_context() -> Dictionary:
	var zones = colony_simulation.get_zone_system()
	var stability = colony_simulation.get_stability_system()
	var discoveries = colony_simulation.get_discovery_system()
	return {
		"colony_depth": int(_tutorial_flags.get("_deepest", 0)),
		"chapter_depths": world_grid.metadata.get("depth_targets", {}),
		"sleeping_ready": _zone_ready(zones, ZoneScript.Type.SLEEPING),
		"storage_ready": _zone_ready(zones, ZoneScript.Type.STORAGE),
		"food_total": colony_simulation.get_item_system().get_total_count("FOOD"),
		"signals_learned": signal_system != null and signal_system.get_recognition_name("root_cluster") != "UNKNOWN" and signal_system.get_recognition_name("water_reservoir") != "UNKNOWN",
		"water_learned": signal_system != null and signal_system.get_recognition_name("water_reservoir") != "UNKNOWN",
		"water_settled": water_system == null or water_system.is_sleeping() or water_system.get_active_cell_count() == 0,
		"supports_built": stability != null and stability.get_completed_count() > 0,
		"warm_home_ready": _warm_home_ready(zones),
		"discoveries_found": 0 if discoveries == null else discoveries.claimed_count(),
		"production_batches": colony_simulation.get_production_system().completed_batches,
		"capability_level": colony_simulation.get_capabilities().level,
		"collection_count": colony_simulation.get_collection_book().unique_count(),
		"mouse_count": colony_simulation.get_mice().size(),
		"campaign_complete": chapter_model.campaign_complete,
	}


func _update_v2_tutorial_flags() -> void:
	var context := _chapter_context()
	var items = colony_simulation.get_item_system()
	_tutorial_flags["first_find"] = int(context.discoveries_found) > 0
	_tutorial_flags["storage_ready"] = bool(context.storage_ready)
	_tutorial_flags["raw_ready"] = items.get_total_count("STONE") >= 2 or items.get_total_count("ORE") >= 2
	_tutorial_flags["workshop_ready"] = _zone_ready(colony_simulation.get_zone_system(), ZoneScript.Type.PRODUCTION)
	_tutorial_flags["production_ready"] = int(context.production_batches) > 0
	_tutorial_flags["tools_ready"] = int(context.capability_level) >= 1
	_tutorial_flags["food_supply_ready"] = bool(_tutorial_flags.get("forage_ready", false)) or int(context.food_total) >= 10
	_tutorial_flags["chapter2"] = chapter_model.current_chapter >= 2
	_tutorial_flags["supports_ready"] = bool(context.supports_built)
	_tutorial_flags["deep_tools_ready"] = int(context.capability_level) >= 2
	_tutorial_flags["campaign_complete"] = chapter_model.campaign_complete
	for type_id: String in ["old_burrow", "warm_chamber"]:
		for feature in worldgen_result.feature_registry.get_features(type_id):
			if not feature.hidden:
				_tutorial_flags[type_id + "_ready"] = true


func _next_v2_goal() -> String:
	var context := _chapter_context()
	var zh := Localization.current().begins_with("zh")
	if chapter_model.campaign_complete:
		return "暖巢已安頓，繼續探索與收藏吧。" if zh else "Our warm home is ready. Keep exploring and collecting."
	if chapter_model.current_chapter == 1:
		if int(context.discoveries_found) == 0:
			return "追尋土壁的小芽、纖維與閃光。" if zh else "Follow sprouts, fibres or glimmers in the wall."
		if not bool(context.sleeping_ready):
			return "劃出乾燥睡眠區（2）。" if zh else "Make a dry sleeping area (2)."
		if not bool(context.storage_ready):
			return "在物資附近建倉儲（3）。" if zh else "Make a store near supplies (3)."
		if int(context.production_batches) == 0 and not _zone_ready(colony_simulation.get_zone_system(), ZoneScript.Type.PRODUCTION) and colony_simulation.get_item_system().get_total_count("STONE") == 0 and colony_simulation.get_item_system().get_total_count("ORE") == 0:
			return "追尋灰色石紋與銅色礦光，為工坊準備原料。" if zh else "Follow grey stone or copper glints to find workshop inputs."
		if int(context.production_batches) == 0:
			return "建工坊（7），加工第一批物資。" if zh else "Build a workshop (7) and craft a first batch."
		if int(context.capability_level) == 0:
			return "加工金屬，為鼠群升級工具。" if zh else "Refine metal and upgrade colony tools."
		if int(context.food_total) < 10:
			return "備好 10 份食物，迎接新夥伴。" if zh else "Stock 10 food for new arrivals."
		return "向根系更深處探索。" if zh else "Explore deeper among the roots."
	if chapter_model.current_chapter == 2:
		if not bool(context.water_learned):
			return "讀懂潮濕線索，準備安全路線。" if zh else "Read damp clues and prepare a safe route."
		if not bool(context.supports_built):
			return "為工作路線完成一次加固（6）。" if zh else "Reinforce a working route (6)."
		if int(context.capability_level) < 2:
			return "用石材與金屬升級深掘能力。" if zh else "Upgrade deep tools with stone and metal."
		return "穩住水勢，尋找舊鼠穴。" if zh else "Settle the water and find the old burrow."
	return "在暖室為每隻鼠鼠備床，在附近存好糧食並保持通路。" if zh else "Give every mouse a warm-chamber bed, stock food nearby and keep access safe."


func _update_home_progress() -> void:
	if home_progress == null:
		return
	for id: String in home_progress.evaluate(_chapter_context(), _active_seconds):
		if _telemetry != null:
			_telemetry.record_development("home", id)
		var title: String = str(HomeProgressScript.TITLES[id].get("zh" if Localization.current().begins_with("zh") else "en", id))
		_push_notification("home_" + id, title, world_grid.metadata.start_cell, 0.0, 7.0)
	zone_overlay_view.set_collection_count(colony_simulation.get_collection_book().unique_count())


func _on_produced(event: Dictionary) -> void:
	if _telemetry != null:
		_telemetry.record_resource_gain(str(event.item), int(event.amount))
		_telemetry.record_development("production", str(event.recipe), {"zone": event.zone, "input": event.input, "input_amount": event.input_amount, "output": event.item, "amount": event.amount})
	var name := Resources.display_name(str(event.item), Localization.current())
	_push_notification("produced_" + str(event.recipe), ("工坊完成：" if Localization.current().begins_with("zh") else "Workshop made: ") + "%d %s" % [int(event.amount), name], event.cell, 10.0, 5.0)


func _on_capability_upgraded(level: int) -> void:
	if _telemetry != null:
		_telemetry.record_development("upgrade", str(level), {"level": level})
	_push_notification("tools", "鼠群學會了新本領！" if Localization.current().begins_with("zh") else "New tools for the whole colony!", world_grid.metadata.start_cell, 0.0, 7.0)


func _warm_food_stock() -> int:
	var total := 0
	var anchor := _warm_chamber_anchor()
	var zones = colony_simulation.get_zone_system()
	for pile in colony_simulation.get_item_system().get_piles():
		if pile.item_type != "FOOD":
			continue
		var zone = zones.get_zone_at(pile.cell)
		if zone == null or zone.zone_type != ZoneScript.Type.STORAGE or not zone.valid or zone.setup_state != ZoneScript.SetupState.SET_UP:
			continue
		var route: Array[Vector2i] = path_service.find_path(anchor, pile.cell)
		if not route.is_empty() and route.size() <= 13:
			total += pile.available_count()
	return total


func _on_food_produced(_feature_id: int, _cell: Vector2i, count: int) -> void:
	if _telemetry != null:
		_telemetry.record_resource_gain("FOOD", count)


func _toggle_help() -> void:
	if _settings_open or _book_open or _help_view == null:
		return
	_help_open = not _help_open
	if _help_open:
		_pause_before_help = _paused
		_paused = true
		_help_view.refresh()
	else:
		_paused = _pause_before_help
	_help_view.visible = _help_open
	_modal_backdrop.visible = _book_open or _help_open
	_sync_camera_input()


func _build_player_toolbar() -> void:
	var bar := HFlowContainer.new()
	bar.name = "PlayerToolbar"
	bar.alignment = FlowContainer.ALIGNMENT_CENTER
	var rows = get_node("UI/Root/GameplayHud/Margin/Rows")
	rows.add_child(bar)
	rows.move_child(bar, 1)
	for entry: Array in [[1, Tool.DIG], [2, Tool.SLEEPING], [3, Tool.STORAGE], [4, Tool.FOOD_FORAGE], [5, Tool.SEAL], [6, Tool.REINFORCE], [7, Tool.PRODUCTION]]:
		var value: int = entry[1]
		var button := Button.new()
		button.set_meta("shortcut", entry[0])
		button.add_theme_font_size_override("font_size", 13)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _set_tool(value))
		bar.add_child(button)
		_toolbar_buttons[value] = button
	var help := Button.new()
	help.text = "?"
	help.tooltip_text = "H · Help / 操作說明"
	help.focus_mode = Control.FOCUS_NONE
	help.pressed.connect(_toggle_help)
	bar.add_child(help)


func _refresh_toolbar() -> void:
	var names: Array[String] = [tr("tool.dig"), tr("tool.sleeping"), tr("tool.storage"), tr("tool.food_forage"), tr("tool.seal"), tr("tool.reinforce"), "工坊" if Localization.current().begins_with("zh") else "Workshop"]
	for value: int in _toolbar_buttons:
		var button: Button = _toolbar_buttons[value]
		var short_names: Array = ["挖掘", "睡眠", "倉儲", "覓食", "封堵", "加固", "工坊"] if Localization.current().begins_with("zh") else ["Dig", "Sleep", "Store", "Forage", "Seal", "Support", "Craft"]
		button.text = "%d %s" % [int(button.get_meta("shortcut")), short_names[value]]
		button.tooltip_text = names[value]
		button.set_pressed_no_signal(_current_tool == value)


func _choose_speed(value: int) -> void:
	if time_control.set_speed(value) and _telemetry != null:
		_telemetry.record_development("time_speed", str(value))


func _slow_for_danger() -> void:
	if time_control.danger_started():
		_push_notification("speed_safety", "留意危險，已恢復 1× 速度。" if Localization.current().begins_with("zh") else "Watch the danger — returned to 1× speed.", Vector2i(-1, -1), 0.0, 7.0)


func _focus_latest() -> void:
	var cell: Vector2i = _notifications.latest_focus_cell(_now_seconds) if _notifications != null else Vector2i(-1, -1)
	if cell.x >= 0:
		world_camera.focus_cell(cell, _logical_cell_size)


func _show_start() -> void:
	_session_started = false
	_paused = true
	_start_view = StartViewScript.new()
	_start_view.latest_slot = SaveServiceScript.latest_slot()
	get_node("UI/Root").add_child(_start_view)
	_start_view.new_requested.connect(_start_new_home)
	_start_view.continue_requested.connect(_request_load)
	_start_view.help_requested.connect(func() -> void:
		get_node("UI/Root").move_child(_modal_backdrop, -1)
		get_node("UI/Root").move_child(_help_view, -1)
		_toggle_help()
	)
	_start_view.language_requested.connect(func() -> void:
		Localization.cycle()
		_start_view.refresh()
		tutorial_label.text = Localization.text(_tutorial.current_text_key())
	)
	_start_view.quit_requested.connect(_quit_session)
	_sync_camera_input()


func _start_new_home() -> void:
	var archived: Dictionary = SaveServiceScript.archive_slots()
	if not archived.ok:
		_start_view.message = "無法保存舊家園，請檢查儲存空間。" if Localization.current().begins_with("zh") else "Could not preserve the previous home. Please check save storage."
		_start_view.refresh()
		return
	_start_view.visible = false
	_session_started = true
	_paused = false
	_sync_camera_input()
	_save_to_slot("autosave")


func _quit_session() -> void:
	if _quitting:
		return
	_quitting = true
	if _session_started and colony_simulation != null and _tutorial != null:
		if not _save_to_slot("autosave"):
			_quitting = false
			return
	_paused = true
	if _audio_director != null:
		_audio_director.stop_all()
	# Let the audio thread finish its fade and main-thread resource cleanup.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _verify_playtest() -> void:
	if OS.is_debug_build() or AppConfig.debug_tools_enabled() or AppConfig.cheats_enabled() or _telemetry != null:
		push_error("PLAYTEST_BUILD_CHECK_FAIL release/profile isolation")
		get_tree().quit(1)
		return
	if DirAccess.dir_exists_absolute("res://tests") or DirAccess.dir_exists_absolute("res://art/qa"):
		push_error("PLAYTEST_BUILD_CHECK_FAIL exported QA data")
		get_tree().quit(1)
		return
	if _build_check_stage == 0:
		if _start_view == null or not _start_view.visible:
			push_error("PLAYTEST_BUILD_CHECK_FAIL entry menu missing")
			get_tree().quit(1)
			return
		_start_new_home()
		_build_check_seed = _current_seed
		_toolbar_buttons[Tool.SLEEPING].pressed.emit()
		_toggle_help()
		var help_ok: bool = _paused and _help_view.visible
		_toggle_help()
		if not help_ok or _paused or _current_tool != Tool.SLEEPING or not _save_to_slot("quicksave"):
			push_error("PLAYTEST_BUILD_CHECK_FAIL actual controls/save")
			get_tree().quit(1)
			return
		_build_check_stage = 1
		_request_load("quicksave")
		return
	if not _loaded_from_save or _current_seed != _build_check_seed or _start_view != null:
		push_error("PLAYTEST_BUILD_CHECK_FAIL resume/seed")
		get_tree().quit(1)
		return
	print("PLAYTEST_BUILD_CHECK_PASS release=true cheats=false telemetry=false entry=true controls=true save_load=true seed=%d qa_data=false" % _current_seed)
	_quit_session()


func _sync_camera_input() -> void:
	world_camera.input_blocked = _settings_open or _book_open or _help_open or (_start_view != null and _start_view.visible)
