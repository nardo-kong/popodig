extends Node

const SimpleWorldGeneratorScript = preload("res://src/domain/world/simple_world_generator.gd")
const GridPathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const MouseAgentScript = preload("res://src/domain/colony/mouse_agent.gd")
const DesignateDigCommandScript = preload("res://src/application/commands/designate_dig_command.gd")
const CancelDigCommandScript = preload("res://src/application/commands/cancel_dig_command.gd")
const CellDataScript = preload("res://src/domain/world/cell_data.gd")

enum PaintAction {
	NONE,
	DESIGNATE,
	CANCEL,
}

@onready var world_view: WorldView = %WorldView
@onready var world_camera: WorldCamera = %WorldCamera
@onready var mouse_view: MouseView = %MouseView
@onready var dig_cursor_view: DigCursorView = %DigCursorView
@onready var seed_label: Label = %SeedLabel
@onready var stats_label: Label = %StatsLabel
@onready var inspector_label: Label = %InspectorLabel
@onready var dig_status_label: Label = %DigStatusLabel
@onready var dig_feedback_label: Label = %DigFeedbackLabel
@onready var fps_label: Label = %FpsLabel
@onready var debug_top_bar: Control = %TopBar
@onready var debug_inspector: Control = %Inspector
@onready var debug_footer: Control = %Footer

var world_grid
var path_service
var dig_system
var mouse_agent
var _logical_cell_size := 16
var _simulation_step := 0.05
var _simulation_accumulator := 0.0
var _selected_cell := Vector2i(-1, -1)
var _paint_action := PaintAction.NONE
var _last_painted_cell := Vector2i(-1, -1)
var _last_feedback := "Choose any legal frontier cell."
var _hover_feedback := "Choose any legal frontier cell."
var _feedback_seconds_remaining := 0.0


func _ready() -> void:
	if not AppConfig.get_load_errors().is_empty():
		GameLog.failure("QA", "Configuration errors: %s" % "; ".join(AppConfig.get_load_errors()))
		return
	var worldgen_config := AppConfig.get_document("worldgen")
	var balance_config := AppConfig.get_document("balance")
	var digging_balance: Dictionary = balance_config.get("digging", {})
	var seed_value := int(worldgen_config.get("default_seed", 137042))
	world_grid = SimpleWorldGeneratorScript.new().generate(worldgen_config, seed_value)
	_logical_cell_size = int(balance_config.get("logical_cell_size", 16))
	_simulation_step = float(digging_balance.get("simulation_step_seconds", 0.05))
	world_view.configure(world_grid, _logical_cell_size)
	world_camera.configure_world_bounds(world_view.get_world_rect())
	world_camera.focus_cell(world_grid.metadata.start_cell, _logical_cell_size)
	path_service = GridPathServiceScript.new()
	path_service.configure(world_grid, balance_config)
	dig_system = DigSystemScript.new()
	dig_system.configure(world_grid, path_service, balance_config)
	mouse_agent = MouseAgentScript.new(1, world_grid.metadata.start_cell)
	mouse_agent.configure(world_grid, path_service, dig_system, balance_config)
	mouse_view.configure(mouse_agent, _logical_cell_size)
	dig_cursor_view.configure(_logical_cell_size)
	seed_label.text = "Seed %d · worldgen v%d" % [seed_value, world_grid.metadata.worldgen_version]
	stats_label.text = "%d×%d cells · %d chunks · %.1f KiB logical grid" % [
		world_grid.width,
		world_grid.height,
		world_grid.get_chunk_count(),
		world_grid.estimate_storage_bytes() / 1024.0,
	]
	var debug_visible := AppConfig.debug_tools_enabled()
	debug_top_bar.visible = debug_visible
	debug_inspector.visible = debug_visible
	debug_footer.visible = debug_visible
	if _has_user_argument("--qa-phase2-demo") and AppConfig.cheats_enabled():
		_designate_qa_demo_path()
	_update_hud()
	GameLog.info("WORLDGEN", "Phase 2 world generated seed=%d checksum=%d" % [seed_value, world_grid.checksum()])


func _process(delta: float) -> void:
	if world_grid == null or mouse_agent == null:
		return
	_simulation_accumulator = minf(_simulation_accumulator + delta, 0.4)
	var ticks := 0
	while _simulation_accumulator >= _simulation_step and ticks < 8:
		mouse_agent.fixed_tick(_simulation_step)
		_simulation_accumulator -= _simulation_step
		ticks += 1
	_feedback_seconds_remaining = maxf(0.0, _feedback_seconds_remaining - delta)
	_refresh_hovered_cell()
	_update_cursor()
	_update_hud()
	if AppConfig.debug_tools_enabled():
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if world_grid == null:
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
	if _paint_action == PaintAction.CANCEL:
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
		var changed: Array = result.get("accepted_cells", result.get("cancelled_cells", []))
		var changed_count: int = changed.size() + (result.get("removed_downstream", []) as Array).size()
		_last_feedback = "%d cell%s updated." % [changed_count, "" if changed_count == 1 else "s"]
		return
	var rejected: Array = result.get("rejected", [])
	var reason := String(result.get("reason_code", "NOT_EXCAVATABLE"))
	if not rejected.is_empty():
		reason = String(rejected[0].get("reason_code", reason))
	_last_feedback = _reason_text(reason)


func _refresh_hovered_cell() -> void:
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
	var inspection: Dictionary = dig_system.inspect_designation(cell_coord)
	var valid: bool = world_grid.get_dig_state(cell_coord) != CellDataScript.DigState.NONE if cancel_mode else bool(inspection.get("ok", false))
	if cancel_mode:
		_hover_feedback = "Release this planned dig." if valid else _reason_text("NOT_DESIGNATED")
	else:
		_hover_feedback = "Legal frontier — paint freely from here." if valid else _reason_text(String(inspection.get("reason_code", "NOT_EXCAVATABLE")))
	dig_cursor_view.set_cursor(cell_coord, true, valid, cancel_mode)


func _update_hud() -> void:
	dig_status_label.text = "DIG · LMB paint path · RMB cancel  |  queued %d  |  mouse %s" % [
		dig_system.get_designated_count(),
		mouse_agent.get_state_name(),
	]
	dig_feedback_label.text = _last_feedback if _feedback_seconds_remaining > 0.0 else _hover_feedback


func _update_inspector() -> void:
	var cell = world_grid.get_cell(_selected_cell)
	if cell == null:
		inspector_label.text = "Move over the world to inspect a cell."
		return
	inspector_label.text = "Cell (%d, %d)\n%s · hardness %.2f\n%s · dig %s %.0f%%%s" % [
		cell.coord.x,
		cell.coord.y,
		cell.material_name(cell.terrain_material),
		cell.hardness,
		"Excavated" if cell.excavated else "Solid",
		_dig_state_name(cell.dig_state),
		cell.dig_progress * 100.0,
		" · PROTECTED" if cell.protected_cell else "",
	]


func _mouse_cell() -> Vector2i:
	return world_view.local_position_to_cell(world_view.get_local_mouse_position())


func _viewport_position_to_cell(viewport_position: Vector2) -> Vector2i:
	var world_local := world_view.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return world_view.local_position_to_cell(world_local)


func _designate_qa_demo_path() -> void:
	var cursor: Vector2i = world_grid.metadata.start_cell
	while world_grid.is_in_bounds(cursor + Vector2i.DOWN) and world_grid.is_excavated(cursor + Vector2i.DOWN):
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
		_:
			return reason_code.replace("_", " ").capitalize()


func _has_user_argument(argument_name: String) -> bool:
	return OS.get_cmdline_user_args().has(argument_name)
