extends Node

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
var _logical_cell_size := 16
var _simulation_step := 0.05
var _simulation_accumulator := 0.0
var _selected_cell := Vector2i(-1, -1)
var _paint_action := PaintAction.NONE
var _current_tool := Tool.DIG
var _last_painted_cell := Vector2i(-1, -1)
var _last_feedback := "Choose any legal frontier cell."
var _hover_feedback := "Choose any legal frontier cell."
var _feedback_seconds_remaining := 0.0
var _qa_inspector_cell := Vector2i(-1, -1)
var _current_seed := 0

static var _debug_seed_override_set := false
static var _debug_seed_override := 0


func _ready() -> void:
	if not AppConfig.get_load_errors().is_empty():
		GameLog.failure("QA", "Configuration errors: %s" % "; ".join(AppConfig.get_load_errors()))
		return
	var worldgen_config := AppConfig.get_document("worldgen")
	var balance_config := AppConfig.get_document("balance")
	var digging_balance: Dictionary = balance_config.get("digging", {})
	var seed_value := _debug_seed_override if _debug_seed_override_set else int(worldgen_config.get("default_seed", 137042))
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
	world_camera.focus_cell(world_grid.metadata.start_cell, _logical_cell_size)
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
	world_view.configure_environment(water_system, seal_system)
	if root_feature_system != null:
		root_feature_system.feature_reacted.connect(_on_root_feature_reacted)
	if water_system != null:
		water_system.reservoir_breached.connect(_on_reservoir_breached)
	_seed_initial_supplies()
	var mice: Array = colony_simulation.get_mice()
	mouse_agent = mice[0] if not mice.is_empty() else null
	colony_view.configure(colony_simulation, _logical_cell_size)
	zone_overlay_view.configure(colony_simulation.get_zone_system(), _logical_cell_size)
	colony_items_view.configure(colony_simulation.get_item_system(), _logical_cell_size)
	colony_debug_overlay.configure(colony_simulation, _logical_cell_size)
	worldgen_debug_overlay.configure(world_grid, worldgen_result.feature_registry, _logical_cell_size, signal_system, water_system)
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
	debug_inspector.visible = debug_visible
	debug_footer.visible = debug_visible
	colony_debug_overlay.visible = debug_visible
	worldgen_debug_overlay.visible = debug_visible
	_set_tool(Tool.DIG)
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
	_update_hud()
	GameLog.info("WORLDGEN", "Phase 7 water-enabled world generated seed=%d content_hash=%d features=%d repairs=%d mice=%d" % [seed_value, worldgen_result.get_content_hash(), worldgen_result.feature_registry.count(), world_grid.metadata.repairs.size(), mice.size()])


func _process(delta: float) -> void:
	if world_grid == null or colony_simulation == null:
		return
	_simulation_accumulator = minf(_simulation_accumulator + delta, 0.4)
	var ticks := 0
	while _simulation_accumulator >= _simulation_step and ticks < 8:
		colony_simulation.fixed_tick(_simulation_step)
		_simulation_accumulator -= _simulation_step
		ticks += 1
	_feedback_seconds_remaining = maxf(0.0, _feedback_seconds_remaining - delta)
	_refresh_hovered_cell()
	_update_cursor()
	_update_hud()
	if AppConfig.debug_tools_enabled():
		_update_inspector()
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if world_grid == null:
		return
	if _handle_tool_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_dig_input(event):
		get_viewport().set_input_as_handled()
		return
	if not AppConfig.debug_tools_enabled():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_F2:
			world_view.set_grid_visible(not world_view.is_grid_visible())
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F3:
			colony_debug_overlay.visible = not colony_debug_overlay.visible
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F4:
			DisplayServer.clipboard_set(str(_current_seed))
			_last_feedback = "Copied replay seed %d." % _current_seed
			_feedback_seconds_remaining = 2.0
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F5:
			_reload_debug_seed(_current_seed)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F6:
			_reload_debug_seed(_current_seed + 1)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F7:
			_last_feedback = "Worldgen overlay: %s" % worldgen_debug_overlay.cycle_mode()
			_feedback_seconds_remaining = 2.0
			get_viewport().set_input_as_handled()


func _handle_tool_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_1, KEY_ESCAPE:
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
	return false


func _set_tool(tool: int) -> void:
	_current_tool = clampi(tool, Tool.DIG, Tool.SEAL)
	_end_paint()
	var zone_type := _current_zone_type()
	zone_overlay_view.set_editing(_is_zone_tool(), zone_type)
	dig_cursor_view.set_tool_style(_tool_name())
	if _current_tool == Tool.DIG:
		_last_feedback = "Choose any legal frontier cell."
	elif _current_tool == Tool.SEAL:
		_last_feedback = "Mark an open cell for autonomous sealing."
	else:
		_last_feedback = "Paint any legal excavated cell."
	_hover_feedback = _last_feedback
	_feedback_seconds_remaining = 1.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_end_paint()


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
	elif _current_tool != Tool.DIG:
		if _paint_action == PaintAction.CANCEL:
			result = EraseZoneCommandScript.new(colony_simulation.get_zone_system(), cells).execute()
		else:
			result = PaintZoneCommandScript.new(colony_simulation.get_zone_system(), _current_zone_type(), cells).execute()
	elif _paint_action == PaintAction.CANCEL:
		result = CancelDigCommandScript.new(dig_system, cells).execute()
	else:
		result = DesignateDigCommandScript.new(dig_system, cells).execute()
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
	if bool(result.get("ok", false)):
		var changed: Array = result.get("accepted_cells", result.get("cancelled_cells", result.get("changed_cells", [])))
		var changed_count: int = changed.size() + (result.get("removed_downstream", []) as Array).size()
		_last_feedback = "%d cell%s updated." % [changed_count, "" if changed_count == 1 else "s"]
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
			_hover_feedback = "Cancel this pending seal." if valid else _reason_text("REQUEST_NOT_FOUND")
		else:
			var reason: String = seal_system.inspect_request(cell_coord)
			_hover_feedback = "Seal here; a mouse will bring 1 Material." if valid else _reason_text(reason)
		dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)
		return
	if _is_zone_tool():
		var zone_system = colony_simulation.get_zone_system()
		var current_zone: Zone = zone_system.get_zone_at(cell_coord)
		var inspection: Dictionary = zone_system.inspect_cell(_current_zone_type(), cell_coord)
		var valid := current_zone != null if cancel_mode else bool(inspection.ok) or String(inspection.reason_code) == "ALREADY_ASSIGNED"
		if cancel_mode:
			_hover_feedback = "Erase %s area." % current_zone.get_type_name().replace("_", "/").capitalize() if valid else _reason_text("NOT_ASSIGNED")
		elif valid:
			_hover_feedback = "%s · paint excavated space." % _tool_name()
		else:
			_hover_feedback = _reason_text(String(inspection.reason_code))
		dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)
		return
	var inspection: Dictionary = dig_system.inspect_designation(cell_coord)
	var valid: bool = world_grid.get_dig_state(cell_coord) != CellDataScript.DigState.NONE if cancel_mode else bool(inspection.get("ok", false))
	if cancel_mode:
		_hover_feedback = "Release this planned dig." if valid else _reason_text("NOT_DESIGNATED")
	else:
		_hover_feedback = "Legal frontier — paint freely from here." if valid else _reason_text(String(inspection.get("reason_code", "NOT_EXCAVATABLE")))
	if signal_system != null:
		var clue: String = signal_system.get_qualitative_clue("root_density", cell_coord)
		if not clue.is_empty():
			_hover_feedback += "  %s" % clue
		var moisture_clue: String = signal_system.get_qualitative_clue("moisture", cell_coord)
		if not moisture_clue.is_empty():
			_hover_feedback += "  %s" % moisture_clue
	dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)


func _update_hud() -> void:
	dig_status_label.text = "%s · LMB paint · RMB clear  |  dig queued %d · seals %d" % [_tool_name(), dig_system.get_designated_count(), seal_system.get_requests().size()]
	tool_status_label.text = "1 Dig · 2 Sleep · 3 Storage · 4 Food/Forage · 5 Seal  |  current: %s" % _tool_name()
	var mice: Array = colony_simulation.get_mice()
	var active_count := 0
	var carrying_count := 0
	var highest_hunger := 0.0
	var lowest_rest := 100.0
	for agent in mice:
		if String(agent.get_state_name()) != "IDLE":
			active_count += 1
		if int(agent.carried_item_count) > 0:
			carrying_count += 1
		highest_hunger = maxf(highest_hunger, _need_percent(float(agent.hunger)))
		lowest_rest = minf(lowest_rest, _need_percent(float(agent.rest)))
	var item_system = colony_simulation.get_item_system()
	var zones: Array = colony_simulation.get_zone_system().get_zones()
	var ready_zones := 0
	for zone: Zone in zones:
		if zone.valid and zone.setup_state == ZoneScript.SetupState.SET_UP:
			ready_zones += 1
	colony_status_label.text = "MICE %d · active %d · carrying %d  |  Food %d · Material %d  |  Zones %d/%d · Hunger %.0f%% · Rest %.0f%%" % [
		mice.size(),
		active_count,
		carrying_count,
		item_system.get_total_count(ItemSystemScript.FOOD),
		item_system.get_total_count(ItemSystemScript.GENERAL_MATERIAL),
		ready_zones,
		zones.size(),
		highest_hunger,
		lowest_rest,
	]
	dig_feedback_label.text = _last_feedback if _feedback_seconds_remaining > 0.0 else _hover_feedback


func _need_percent(value: float) -> float:
	return clampf(value * 100.0 if value <= 1.0 else value, 0.0, 100.0)


func _update_inspector() -> void:
	var cell = world_grid.get_cell(_selected_cell)
	if cell == null:
		inspector_label.text = "Move over the world to inspect a cell."
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
	var feature_text := "feature %d%s" % [cell.feature_id, " · LANDMARK" if cell.landmark else ""]
	if cell.feature_id >= 0:
		var feature = worldgen_result.feature_registry.get_feature(cell.feature_id)
		if feature != null and not feature.hidden:
			feature_text += " · %s · reserve %d" % [
				String(feature.metadata.get("lifecycle_state", "REVEALED")),
				int(feature.metadata.get("reserve_units", feature.metadata.get("food_reserve_units", 0))),
			]
	inspector_label.text = "Cell (%d, %d) · stratum %d\n%s · hardness %.2f · water %d%s\n%s · dig %s %.0f%%%s\n%s\n%s · %s" % [
		cell.coord.x,
		cell.coord.y,
		cell.stratum_id,
		cell.material_name(cell.terrain_material),
		cell.hardness,
		cell.water_units,
		" · SEALED" if cell.sealed else "",
		"EXTERIOR" if cell.is_exterior() else ("Excavated" if cell.is_traversable() else "Solid"),
		_dig_state_name(cell.dig_state),
		cell.dig_progress * 100.0,
		" · PROTECTED" if cell.protected_cell else "",
		feature_text,
		signal_text,
		zone_text,
	]


func _on_root_feature_reacted(_feature_id: int, reaction: Dictionary) -> void:
	var produced := int(reaction.get("food_produced", 0))
	_last_feedback = "Root Cluster exposed. %d food released; nearby Food/Forage space can stabilize it." % produced
	_feedback_seconds_remaining = 5.0


func _on_reservoir_breached(_feature_id: int, _cell: Vector2i, _danger_cells: Array, released_units: int) -> void:
	_last_feedback = "Reservoir breached: %d unit released. Mice are evacuating; dig drainage or use Seal." % released_units
	_feedback_seconds_remaining = 6.0


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


func _setup_qa_colony_demo() -> void:
	var home: Vector2i = world_grid.metadata.start_cell
	var food_cell := _find_traversable_cell(home, [Vector2i(-4, 0), Vector2i(-3, 0), Vector2i.LEFT])
	var material_cell := _find_traversable_cell(home, [Vector2i(4, 0), Vector2i(3, 0), Vector2i.RIGHT])
	# Route the QA haul across the whole start room so capture timing visibly proves carrying.
	var result: Dictionary = colony_simulation.setup_qa_demo(food_cell, material_cell, food_cell)
	if not bool(result.get("ok", false)):
		GameLog.failure("QA", "Phase 3 colony demo setup failed: %s" % result.get("reason_code", "UNKNOWN"))


func _setup_qa_zone_demo() -> void:
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
	match reason_code:
		"OUT_OF_BOUNDS":
			return "Outside the finite world."
		"NOT_EXCAVATABLE":
			return "This cell is already open or cannot be excavated."
		"PROTECTED_FEATURE":
			return "Protected boundary or structure."
		"NOT_CONTIGUOUS":
			return "Continue from the current planned path."
		"NOT_CONNECTED_TO_EXCAVATED":
			return "Start from a reachable excavated frontier."
		"NOT_DESIGNATED":
			return "There is no pending dig to cancel here."
		"NOT_OPEN":
			return "Seals require an excavated interior cell."
		"EXTERIOR":
			return "The exterior shaft cannot be sealed."
		"ALREADY_SEALED":
			return "This cell is already sealed; use Dig to remove it."
		"ALREADY_REQUESTED":
			return "A seal is already planned here."
		"REQUEST_NOT_FOUND":
			return "There is no pending seal to cancel here."
		"WATER_DISPLACEMENT_BLOCKED":
			return "Adjacent cells need room before this wet seal can be completed."
		"NOT_EXCAVATED":
			return "Zones can only use excavated space."
		"NOT_CONNECTED":
			return "This open cell is not connected to the colony."
		"FLOODED":
			return "Standing water makes this cell unsuitable."
		"WET":
			return "Move stores before shallow water rises."
		"ALREADY_ASSIGNED":
			return "This cell already has that zone type."
		"NOT_ASSIGNED":
			return "There is no zone to erase here."
		_:
			return reason_code.replace("_", " ").capitalize()


func _reload_debug_seed(seed_value: int) -> void:
	if not AppConfig.debug_tools_enabled():
		return
	_debug_seed_override_set = true
	_debug_seed_override = seed_value
	get_tree().reload_current_scene()


func _has_user_argument(argument_name: String) -> bool:
	return OS.get_cmdline_user_args().has(argument_name)


func _user_argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _current_zone_type() -> int:
	match _current_tool:
		Tool.SLEEPING:
			return ZoneScript.Type.SLEEPING
		Tool.STORAGE:
			return ZoneScript.Type.STORAGE
		Tool.FOOD_FORAGE:
			return ZoneScript.Type.FOOD_FORAGE
		_:
			return ZoneScript.Type.SLEEPING


func _is_zone_tool() -> bool:
	return _current_tool in [Tool.SLEEPING, Tool.STORAGE, Tool.FOOD_FORAGE]


func _tool_name() -> String:
	match _current_tool:
		Tool.SLEEPING:
			return "SLEEPING ZONE"
		Tool.STORAGE:
			return "STORAGE ZONE"
		Tool.FOOD_FORAGE:
			return "FOOD/FORAGE ZONE"
		Tool.SEAL:
			return "SEAL"
		_:
			return "DIG"
