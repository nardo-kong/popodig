extends Node

const SimpleWorldGeneratorScript = preload("res://src/domain/world/simple_world_generator.gd")

@onready var world_view: WorldView = %WorldView
@onready var world_camera: WorldCamera = %WorldCamera
@onready var seed_label: Label = %SeedLabel
@onready var stats_label: Label = %StatsLabel
@onready var inspector_label: Label = %InspectorLabel
@onready var fps_label: Label = %FpsLabel
@onready var debug_help: Label = %DebugHelp
@onready var debug_top_bar: Control = %TopBar
@onready var debug_inspector: Control = %Inspector
@onready var debug_footer: Control = %Footer

var world_grid
var _selected_cell := Vector2i(-1, -1)


func _ready() -> void:
	if not AppConfig.get_load_errors().is_empty():
		GameLog.failure("QA", "Configuration errors: %s" % "; ".join(AppConfig.get_load_errors()))
		return
	var worldgen_config := AppConfig.get_document("worldgen")
	var seed_value := int(worldgen_config.get("default_seed", 137042))
	world_grid = SimpleWorldGeneratorScript.new().generate(worldgen_config, seed_value)
	var logical_cell_size := int(AppConfig.get_value("balance", "logical_cell_size", 16))
	world_view.configure(world_grid, logical_cell_size)
	world_camera.configure_world_bounds(world_view.get_world_rect())
	world_camera.focus_cell(world_grid.metadata.start_cell, logical_cell_size)
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
	GameLog.info("WORLDGEN", "Phase 1 simple world generated seed=%d checksum=%d" % [seed_value, world_grid.checksum()])


func _process(_delta: float) -> void:
	if not AppConfig.debug_tools_enabled() or world_grid == null:
		return
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_refresh_hovered_cell()


func _unhandled_input(event: InputEvent) -> void:
	if not AppConfig.debug_tools_enabled() or world_grid == null:
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		_refresh_hovered_cell()
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_F2:
		world_view.set_grid_visible(not world_view.is_grid_visible())
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_E and world_grid.is_in_bounds(_selected_cell):
		_refresh_hovered_cell()
		world_grid.set_excavated(_selected_cell, not world_grid.is_excavated(_selected_cell))
		_update_inspector()
		get_viewport().set_input_as_handled()


func _refresh_hovered_cell() -> void:
	var candidate := world_view.local_position_to_cell(world_view.get_local_mouse_position())
	if world_grid.is_in_bounds(candidate) and candidate != _selected_cell:
		_selected_cell = candidate
		_update_inspector()


func _update_inspector() -> void:
	var cell = world_grid.get_cell(_selected_cell)
	if cell == null:
		inspector_label.text = "Move over the world to inspect a cell."
		return
	inspector_label.text = "Cell (%d, %d)\n%s · hardness %.2f\n%s · chunk (%d, %d)%s" % [
		cell.coord.x,
		cell.coord.y,
		cell.material_name(cell.terrain_material),
		cell.hardness,
		"Excavated" if cell.excavated else "Solid",
		world_grid.cell_to_chunk(cell.coord).x,
		world_grid.cell_to_chunk(cell.coord).y,
		" · PROTECTED" if cell.protected_cell else "",
	]
