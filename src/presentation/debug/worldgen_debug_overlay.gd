class_name WorldgenDebugOverlay
extends Node2D

enum Mode {
	NONE,
	STRATA,
	FEATURES,
	LANDMARKS,
	VALIDATION,
}

var world_grid
var feature_registry: FeatureRegistry
var cell_size := 16
var mode := Mode.NONE


func configure(world, registry: FeatureRegistry, logical_cell_size: int) -> void:
	world_grid = world
	feature_registry = registry
	cell_size = logical_cell_size
	queue_redraw()


func cycle_mode() -> String:
	mode = (mode + 1) % (Mode.VALIDATION + 1)
	queue_redraw()
	return get_mode_name()


func set_mode_by_name(mode_name: String) -> bool:
	var requested := mode_name.strip_edges().to_lower()
	match requested:
		"off", "none":
			mode = Mode.NONE
		"strata":
			mode = Mode.STRATA
		"features":
			mode = Mode.FEATURES
		"landmarks":
			mode = Mode.LANDMARKS
		"validation", "repair":
			mode = Mode.VALIDATION
		_:
			return false
	queue_redraw()
	return true


func get_mode_name() -> String:
	match mode:
		Mode.STRATA:
			return "STRATA"
		Mode.FEATURES:
			return "FEATURE IDS"
		Mode.LANDMARKS:
			return "LANDMARKS"
		Mode.VALIDATION:
			return "VALIDATION / REPAIR"
		_:
			return "OFF"


func _draw() -> void:
	if world_grid == null or mode == Mode.NONE:
		return
	match mode:
		Mode.STRATA:
			_draw_strata()
		Mode.FEATURES:
			_draw_features()
		Mode.LANDMARKS:
			_draw_landmarks()
		Mode.VALIDATION:
			_draw_validation()


func _draw_strata() -> void:
	var colors: Array[Color] = [Color("8abf72", 0.20), Color("c69962", 0.22), Color("6299ad", 0.22), Color("a8789b", 0.24)]
	for index: int in range(world_grid.width * world_grid.height):
		var cell: Vector2i = world_grid.index_to_cell(index)
		if world_grid.is_exterior(cell):
			continue
		var stratum_id: int = clampi(world_grid.get_stratum_id(cell), 0, colors.size() - 1)
		draw_rect(_cell_rect(cell), colors[stratum_id], true)


func _draw_features() -> void:
	for index: int in range(world_grid.width * world_grid.height):
		var cell: Vector2i = world_grid.index_to_cell(index)
		var feature_id: int = world_grid.get_feature_id(cell)
		if feature_id < 0:
			continue
		var color := _feature_color(feature_id)
		draw_rect(_cell_rect(cell).grow(-1.0), Color(color, 0.34), true)
		draw_rect(_cell_rect(cell).grow(-1.0), Color(color, 0.68), false, 1.0)


func _draw_landmarks() -> void:
	if feature_registry == null:
		return
	for landmark: GeneratedFeature in feature_registry.get_features_by_role("landmark"):
		var center := _cell_center(landmark.anchor)
		var color := Color("f2c86f") if landmark.required else Color("d5b4e8")
		draw_circle(center, cell_size * 0.65, Color(color, 0.18))
		draw_arc(center, cell_size * 0.65, 0.0, TAU, 24, color, 2.0)
		draw_line(center - Vector2(cell_size * 0.4, 0), center + Vector2(cell_size * 0.4, 0), color, 1.0)
		draw_line(center - Vector2(0, cell_size * 0.4), center + Vector2(0, cell_size * 0.4), color, 1.0)


func _draw_validation() -> void:
	for knot_value: Variant in world_grid.metadata.get("decision_knots", []):
		if not knot_value is Vector2i:
			continue
		var center := _cell_center(knot_value)
		draw_circle(center, cell_size * 1.2, Color("f0c35d", 0.12))
		draw_arc(center, cell_size * 1.2, 0.0, TAU, 28, Color("f0c35d", 0.9), 2.0)
	for repair_value: Variant in world_grid.metadata.get("repairs", []):
		if not repair_value is Dictionary:
			continue
		var target: Variant = repair_value.get("target", Vector2i(-1, -1))
		if not target is Vector2i or target.x < 0:
			continue
		var rect := _cell_rect(target).grow(3.0)
		draw_line(rect.position, rect.end, Color("ed665c"), 2.0)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color("ed665c"), 2.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * cell_size), Vector2.ONE * cell_size)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _feature_color(feature_id: int) -> Color:
	var palette: Array[Color] = [Color("77b86d"), Color("5ba8c8"), Color("d48c5e"), Color("c86f86"), Color("9b82d1"), Color("d1bc68")]
	return palette[absi(feature_id) % palette.size()]
