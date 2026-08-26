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
const NotificationModelScript = preload("res://src/presentation/hud/notification_model.gd")
const ContextTutorialModelScript = preload("res://src/presentation/hud/context_tutorial_model.gd")

# Slice objective (docs/qa/18 Beat H): a marked depth goal below the start.
const SLICE_OBJECTIVE_DEPTH_OFFSET := 30
const FOOD_CRITICAL_COUNT := 2
const OPEN_SPACE_TUTORIAL_CELLS := 12

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
var _logical_cell_size := 16
var _simulation_step := 0.05
var _simulation_accumulator := 0.0
var _selected_cell := Vector2i(-1, -1)
var _paint_action := PaintAction.NONE
var _current_tool := Tool.DIG
var _last_painted_cell := Vector2i(-1, -1)
var _last_feedback := "从任意合法的边界格开始挖掘。"
var _hover_feedback := "从任意合法的边界格开始挖掘。"
var _feedback_seconds_remaining := 0.0
var _qa_inspector_cell := Vector2i(-1, -1)
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
	world_view.configure_environment(water_system, seal_system, colony_simulation.get_stability_system())
	if root_feature_system != null:
		root_feature_system.feature_reacted.connect(_on_root_feature_reacted)
	if water_system != null:
		water_system.reservoir_breached.connect(_on_reservoir_breached)
	var stability = colony_simulation.get_stability_system()
	if stability != null:
		stability.region_collapsed.connect(_on_region_collapsed)
		stability.critical_warning.connect(_on_critical_warning)
	_seed_initial_supplies()
	var mice: Array = colony_simulation.get_mice()
	mouse_agent = mice[0] if not mice.is_empty() else null
	colony_view.configure(colony_simulation, _logical_cell_size)
	zone_overlay_view.configure(colony_simulation.get_zone_system(), _logical_cell_size)
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
	_notifications = NotificationModelScript.new()
	notifications_view.bind(_notifications)
	_tutorial = ContextTutorialModelScript.new()
	tutorial_label.text = _tutorial.current_text()
	_objective_target_depth = int(world_grid.metadata.start_cell.y) + SLICE_OBJECTIVE_DEPTH_OFFSET
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


func _process(delta: float) -> void:
	if world_grid == null or colony_simulation == null:
		return
	_now_seconds += delta
	if not _paused:
		_simulation_accumulator = minf(_simulation_accumulator + delta, 0.4)
	_poll_accumulator += delta
	if _poll_accumulator >= 0.5:
		_slow_poll()
	var ticks := 0
	while not _paused and _simulation_accumulator >= _simulation_step and ticks < 8:
		colony_simulation.fixed_tick(_simulation_step)
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


func _slow_poll() -> void:
	_poll_accumulator = 0.0
	_update_tutorial_flags()
	if _tutorial.advance(_tutorial_flags):
		tutorial_label.text = _tutorial.current_text()
	_update_objective()
	_poll_notifications()
	notifications_view.refresh(_now_seconds)


func _update_tutorial_flags() -> void:
	var open_cells := 0
	for y: int in range(world_grid.height):
		for x: int in range(world_grid.width):
			if world_grid.is_traversable(Vector2i(x, y)):
				open_cells += 1
	if open_cells >= OPEN_SPACE_TUTORIAL_CELLS:
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
	objective_label.text = "目标：向下探索，抵达深度 %d/%d" % [deepest, _objective_target_depth]
	if deepest >= _objective_target_depth and not bool(_tutorial_flags.get("objective_reached", false)):
		_tutorial_flags["objective_reached"] = true
		if _tutorial.advance(_tutorial_flags):
			tutorial_label.text = _tutorial.current_text()
		_push_notification("milestone", "巢穴已抵达目标深度——垂直切片目标达成！", Vector2i(world_grid.metadata.start_cell.x, deepest), 30.0, 3600.0)


func _poll_notifications() -> void:
	var item_system = colony_simulation.get_item_system()
	var food_count: int = item_system.get_total_count(ItemSystemScript.FOOD)
	if food_count <= FOOD_CRITICAL_COUNT:
		_push_notification("food_low", "食物告急！只剩 %d 份——寻找根簇或规划觅食区。" % food_count, Vector2i(-1, -1), 6.0, 90.0)
	var in_danger := false
	var danger_cell := Vector2i(-1, -1)
	for mouse in colony_simulation.get_mice():
		if bool(mouse.danger_state):
			in_danger = true
			danger_cell = mouse.current_cell
	if in_danger and not _mice_were_in_danger:
		_push_notification("danger", "有鼠鼠遇险，正在自动撤离到安全处。", danger_cell, 6.0, 20.0)
	_mice_were_in_danger = in_danger
	var zone_system = colony_simulation.get_zone_system()
	for zone: Zone in zone_system.get_zones():
		if zone.valid or zone.invalid_reasons.is_empty():
			continue
		var key := "%d:%s" % [zone.zone_id, zone.invalid_reasons[0]]
		if _notified_zone_keys.has(key):
			continue
		_notified_zone_keys[key] = true
		_push_notification("zone_lost", "区划失效（%s）——物资和床位需要新家。" % String(zone.invalid_reasons[0]), zone.anchor, 6.0, 15.0)


func _push_notification(category: String, text: String, focus_cell: Vector2i, cooldown: float = 10.0, lifetime: float = 6.0) -> void:
	if _notifications == null:
		return
	if _notifications.push(category, text, _now_seconds, focus_cell, lifetime, cooldown):
		_notifications_dirty = true


func _unhandled_input(event: InputEvent) -> void:
	if world_grid == null:
		return
	if _handle_player_shortcuts(event):
		get_viewport().set_input_as_handled()
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
			_last_feedback = "已复制回放种子 %d。" % _current_seed
			_feedback_seconds_remaining = 2.0
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F5:
			_reload_debug_seed(_current_seed)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F6:
			_reload_debug_seed(_current_seed + 1)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F7:
			_last_feedback = "世界生成叠加层：%s" % worldgen_debug_overlay.cycle_mode()
			_feedback_seconds_remaining = 2.0
			get_viewport().set_input_as_handled()


func _handle_player_shortcuts(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_SPACE:
			_paused = not _paused
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
		KEY_6:
			_set_tool(Tool.REINFORCE)
			return true
	return false


func _set_tool(tool: int) -> void:
	_current_tool = clampi(tool, Tool.DIG, Tool.REINFORCE)
	_end_paint()
	var zone_type := _current_zone_type()
	zone_overlay_view.set_editing(_is_zone_tool(), zone_type)
	dig_cursor_view.set_tool_style(_tool_name())
	if _current_tool == Tool.DIG:
		_last_feedback = "从任意合法的边界格开始挖掘。"
	elif _current_tool == Tool.SEAL:
		_last_feedback = "指定一个洞穴格，鼠鼠会自动搬运材料封堵。"
	elif _current_tool == Tool.REINFORCE:
		_last_feedback = "指定一个天花板格，鼠鼠会自动搬运材料加固。"
	else:
		_last_feedback = "在合法的洞穴地面上涂抹区划。"
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
		_last_feedback = "已更新 %d 格。" % changed_count
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
			_hover_feedback = "取消这个待处理的封堵。" if valid else _reason_text("REQUEST_NOT_FOUND")
		else:
			var reason: String = seal_system.inspect_request(cell_coord)
			_hover_feedback = "在此封堵；鼠鼠会带来 1 份材料。" if valid else _reason_text(reason)
		dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)
		return
	var stability = colony_simulation.get_stability_system()
	if _current_tool == Tool.REINFORCE and stability != null:
		var has_request: bool = stability.has_request(cell_coord)
		var reason_code: String = stability.inspect_request(cell_coord)
		var valid := has_request if cancel_mode else reason_code == "OK"
		if cancel_mode:
			_hover_feedback = "取消这个待处理的加固。" if has_request else _reason_text("REQUEST_NOT_FOUND")
		else:
			_hover_feedback = "加固此天花板；鼠鼠会带来 1 份材料。" if valid else _reason_text(reason_code)
		dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)
		return
	if _is_zone_tool():
		var zone_system = colony_simulation.get_zone_system()
		var current_zone: Zone = zone_system.get_zone_at(cell_coord)
		var inspection: Dictionary = zone_system.inspect_cell(_current_zone_type(), cell_coord)
		var valid := current_zone != null if cancel_mode else bool(inspection.ok) or String(inspection.reason_code) == "ALREADY_ASSIGNED"
		if cancel_mode:
			_hover_feedback = "擦除%s。" % _tool_name() if valid else _reason_text("NOT_ASSIGNED")
		elif valid:
			_hover_feedback = "%s · 在已挖掘的空间上涂抹。" % _tool_name()
		else:
			_hover_feedback = _reason_text(String(inspection.reason_code))
		dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)
		return
	var inspection: Dictionary = dig_system.inspect_designation(cell_coord)
	var valid: bool = world_grid.get_dig_state(cell_coord) != CellDataScript.DigState.NONE if cancel_mode else bool(inspection.get("ok", false))
	if cancel_mode:
		_hover_feedback = "释放这个已规划的挖掘。" if valid else _reason_text("NOT_DESIGNATED")
	else:
		_hover_feedback = "合法边界——可以从这里自由规划。" if valid else _reason_text(String(inspection.get("reason_code", "NOT_EXCAVATABLE")))
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
	dig_status_label.text = "左键涂抹 · 右键清除  |  待挖 %d · 封堵 %d · 加固 %d" % [
		dig_system.get_designated_count(),
		seal_system.get_requests().size(),
		stability.get_requests().size() if stability != null else 0,
	]
	tool_status_label.text = ("⏸ 已暂停（按空格继续） · " if _paused else "") + "1 挖掘 · 2 睡眠 · 3 存储 · 4 觅食 · 5 封堵 · 6 加固  |  当前：%s" % _tool_name()
	var mice: Array = colony_simulation.get_mice()
	var item_system = colony_simulation.get_item_system()
	colony_status_label.text = "食物 %d · 材料 %d · 鼠鼠 %d" % [
		item_system.get_total_count(ItemSystemScript.FOOD),
		item_system.get_total_count(ItemSystemScript.GENERAL_MATERIAL),
		mice.size(),
	]
	dig_feedback_label.text = _last_feedback if _feedback_seconds_remaining > 0.0 else _hover_feedback


func _player_inspector_text(cell) -> String:
	var lines: Array[String] = []
	if cell.is_exterior():
		return "地表"
	if cell.is_traversable():
		lines.append("洞穴空间")
	else:
		var difficulty := "低"
		if cell.hardness > 3.0:
			difficulty = "极高"
		elif cell.hardness > 1.5:
			difficulty = "高"
		elif cell.hardness > 1.0:
			difficulty = "中"
		lines.append("%s · 开挖难度：%s" % [cell.material_name(cell.terrain_material), difficulty])
	if cell.sealed:
		lines.append("已封堵")
	elif cell.rubble:
		lines.append("坍塌碎石——可以重新挖开")
	if cell.water_units > 0:
		lines.append("有积水")
	var clue_text := ""
	if signal_system != null:
		var root_clue: String = signal_system.get_qualitative_clue("root_density", _selected_cell)
		if not root_clue.is_empty():
			clue_text += root_clue
		var moisture_clue: String = signal_system.get_qualitative_clue("moisture", _selected_cell)
		if not moisture_clue.is_empty():
			clue_text += (" · " if not clue_text.is_empty() else "") + moisture_clue
	if not clue_text.is_empty():
		lines.append("迹象：%s" % clue_text)
	var stability = colony_simulation.get_stability_system()
	if stability != null and world_grid.is_traversable(_selected_cell):
		lines.append("稳定：%s" % stability.get_warning_level_name(stability.get_warning_level(_selected_cell)))
	var zone: Zone = colony_simulation.get_zone_system().get_zone_at(_selected_cell)
	if zone != null:
		lines.append("区划：%s" % zone.get_type_name().replace("_", "/").capitalize())
	if cell.feature_id >= 0:
		var feature = worldgen_result.feature_registry.get_feature(cell.feature_id)
		if feature != null and not feature.hidden:
			lines.append("发现：%s" % _feature_display_name(feature.type_id))
	return "\n".join(lines)


func _feature_display_name(type_id: String) -> String:
	match type_id:
		"root_cluster":
			return "根簇"
		"water_reservoir":
			return "水库"
		"unstable_pocket":
			return "不稳定土层"
		"rock_mass":
			return "岩层"
		"foundation":
			return "地基遗迹"
		_:
			return type_id.capitalize()


func _need_percent(value: float) -> float:
	return clampf(value * 100.0 if value <= 1.0 else value, 0.0, 100.0)


func _update_inspector() -> void:
	var cell = world_grid.get_cell(_selected_cell)
	if cell == null:
		inspector_label.text = "移动鼠标检查任意格子。" if not AppConfig.debug_tools_enabled() else "Move over the world to inspect a cell."
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
	var anchor := Vector2i(-1, -1)
	var feature = worldgen_result.feature_registry.get_feature(_feature_id)
	if feature != null:
		anchor = feature.anchor
	_push_notification("discovery_root", "发现根簇！%d 份食物涌出——规划食物/觅食区可以稳定产出。" % produced, anchor, 25.0)
	_last_feedback = "根簇暴露！涌出 %d 份食物；附近的觅食区可以让它稳定产出。" % produced
	_feedback_seconds_remaining = 5.0


func _on_reservoir_breached(_feature_id: int, cell: Vector2i, _danger_cells: Array, released_units: int) -> void:
	_tutorial_flags["breach"] = true
	_push_notification("breach", "水库破裂！%d 单位水涌出，鼠鼠们正在自动撤离。" % released_units, cell, 25.0)
	_last_feedback = "水库破裂：泄出 %d 单位水。鼠鼠们正在撤离；挖排水道或使用封堵。" % released_units
	_feedback_seconds_remaining = 6.0


func _on_region_collapsed(cells: Array, absorbed_water_units: int) -> void:
	var water_note := "" if int(absorbed_water_units) <= 0 else " %d water sank into the rubble." % int(absorbed_water_units)
	_last_feedback = "局部坍塌！%d 格被碎石填满。%s加固天花板，或下次挖窄一点。" % [cells.size(), water_note]
	_feedback_seconds_remaining = 6.0
	if not cells.is_empty():
		_push_notification("collapse", "局部坍塌！%d 格被碎石填满，路线被阻断。" % cells.size(), cells[0] as Vector2i)


func _on_critical_warning(cells: Array) -> void:
	_tutorial_flags["stability_warning"] = true
	if _feedback_seconds_remaining > 0.0:
		return
	if not cells.is_empty():
		_push_notification("stability_critical", "危急警告：附近天花板即将坍塌，鼠鼠们正在撤离。", cells[0] as Vector2i, 20.0)
	_last_feedback = "危急警告：(%d, %d) 附近的天花板即将坍塌。鼠鼠们正在撤离；加固它，或任其坍塌。" % [
		(cells[0] as Vector2i).x,
		(cells[0] as Vector2i).y,
	]
	_feedback_seconds_remaining = 5.0


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


func _setup_qa_stability_demo(requested_mode: String) -> void:
	var mode := requested_mode.strip_edges().to_lower()
	var home: Vector2i = world_grid.metadata.start_cell
	var seam := _find_qa_soft_soil_seam(home)
	if seam.row < 0:
		GameLog.failure("QA", "Phase 8 Stability demo found no soft-soil seam")
		return
	var span_count: int
	match mode:
		"clue":
			span_count = mini(int(seam.length), 4)
		"collapse":
			span_count = mini(int(seam.length), 14)
		_:
			span_count = mini(int(seam.length), 9)
	var goals: Array[Vector2i] = []
	for index: int in range(span_count):
		goals.append(Vector2i(int(seam.start) + index, int(seam.row)))
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
		tunnel_cells.append(Vector2i(x, int(seam.row)))
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
			_last_feedback = "Reinforcement complete: %d supports stabilized the span." % request_cells.size()
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


func _find_qa_soft_soil_seam(home: Vector2i) -> Dictionary:
	var best := {"row": -1, "start": -1, "length": 0}
	for candidate_row: int in range(home.y + 4, mini(world_grid.height - 4, home.y + 16)):
		var length := 0
		var start := -1
		for x: int in range(4, world_grid.width - 4):
			var cell := Vector2i(x, candidate_row)
			var usable: bool = (
				world_grid.is_solid(cell)
				and not world_grid.is_exterior(cell)
				and not world_grid.is_protected(cell)
				and world_grid.get_feature_id(cell) < 0
				and world_grid.get_material(cell) != CellDataScript.TerrainMaterial.STONE
			)
			if usable:
				if start < 0:
					start = x
				length += 1
				if length > int(best.length):
					best = {"row": candidate_row, "start": start, "length": length}
			else:
				length = 0
				start = -1
	return best


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
			return "世界边界之外。"
		"NOT_EXCAVATABLE":
			return "这里已经挖开，或无法挖掘。"
		"PROTECTED_FEATURE":
			return "受保护的边界或结构。"
		"NOT_CONTIGUOUS":
			return "请从当前规划路径继续。"
		"NOT_CONNECTED_TO_EXCAVATED":
			return "请从与巢穴连通的已挖掘边界开始。"
		"NOT_DESIGNATED":
			return "这里没有待取消的挖掘计划。"
		"NOT_OPEN":
			return "封堵需要内部的洞穴格。"
		"EXTERIOR":
			return "地表竖井无法被封堵。"
		"ALREADY_SEALED":
			return "这里已经是封堵状态；用挖掘可以拆除。"
		"ALREADY_REQUESTED":
			return "这里已规划了一个封堵。"
		"REQUEST_NOT_FOUND":
			return "这里没有待取消的封堵。"
		"WATER_DISPLACEMENT_BLOCKED":
			return "相邻格子需要空间，湿封堵才能完成。"
		"NO_ROOF":
			return "加固需要正上方有实心天花板。"
		"ALREADY_REINFORCED":
			return "这个天花板已经加固过了。"
		"NOT_EXCAVATED":
			return "区划只能使用已挖掘的空间。"
		"NOT_CONNECTED":
			return "这个洞穴未与巢穴连通。"
		"FLOODED":
			return "积水让这里不再适用。"
		"WET":
			return "趁水变深之前把物资转移走。"
		"ALREADY_ASSIGNED":
			return "这里已经有该类型的区划。"
		"NOT_ASSIGNED":
			return "这里没有可擦除的区划。"
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
			return "睡眠区"
		Tool.STORAGE:
			return "存储区"
		Tool.FOOD_FORAGE:
			return "食物/觅食区"
		Tool.SEAL:
			return "封堵"
		Tool.REINFORCE:
			return "加固"
		_:
			return "挖掘"
