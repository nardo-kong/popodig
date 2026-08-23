class_name WorldgenDebugOverlay
extends Node2D

enum Mode {
	NONE,
	STRATA,
	FEATURES,
	LANDMARKS,
	VALIDATION,
	SIGNAL_BANDS,
	SIGNAL_RAW,
	SIGNAL_SYSTEM,
	MOISTURE_RAW,
	WATER_STATE,
	STABILITY_STATE,
}

var world_grid
var feature_registry: FeatureRegistry
var signal_system
var water_system
var stability_system
var cell_size := 16
var mode := Mode.NONE


func configure(world, registry: FeatureRegistry, logical_cell_size: int, signals = null, water = null, stability = null) -> void:
	world_grid = world
	feature_registry = registry
	signal_system = signals
	water_system = water
	stability_system = stability
	cell_size = logical_cell_size
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and (mode == Mode.WATER_STATE or mode == Mode.STABILITY_STATE):
		queue_redraw()


func cycle_mode() -> String:
	mode = (mode + 1) % (Mode.STABILITY_STATE + 1)
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
		"signals", "signal_bands", "root", "root_bands":
			mode = Mode.SIGNAL_BANDS
		"signal_raw", "root_raw", "raw":
			mode = Mode.SIGNAL_RAW
		"signal_system", "emitters", "dirty", "recognition":
			mode = Mode.SIGNAL_SYSTEM
		"moisture", "moisture_raw":
			mode = Mode.MOISTURE_RAW
		"water", "water_state", "flow":
			mode = Mode.WATER_STATE
		"stability", "stability_state", "collapse", "reinforce":
			mode = Mode.STABILITY_STATE
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
		Mode.SIGNAL_BANDS:
			return "ROOT SIGNAL BANDS"
		Mode.SIGNAL_RAW:
			return "ROOT SIGNAL RAW"
		Mode.SIGNAL_SYSTEM:
			var recognition: String = "UNKNOWN" if signal_system == null else String(signal_system.get_recognition_name("root_cluster"))
			return "SIGNAL SYSTEM / %s" % recognition
		Mode.MOISTURE_RAW:
			return "MOISTURE SIGNAL RAW"
		Mode.WATER_STATE:
			return "WATER ACTIVE / FLOW"
		Mode.STABILITY_STATE:
			return "STABILITY WARNINGS"
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
		Mode.SIGNAL_BANDS:
			_draw_signal_bands()
		Mode.SIGNAL_RAW:
			_draw_signal_raw()
		Mode.SIGNAL_SYSTEM:
			_draw_signal_system()
		Mode.MOISTURE_RAW:
			_draw_moisture_raw()
		Mode.WATER_STATE:
			_draw_water_state()
		Mode.STABILITY_STATE:
			_draw_stability_state()


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


func _draw_signal_bands() -> void:
	var thresholds: Array = world_grid.metadata.get("signal_thresholds", {}).get("root_density", [1, 3, 5])
	var colors: Array[Color] = [Color.TRANSPARENT, Color("dfc56c", 0.18), Color("e79b50", 0.30), Color("e95f55", 0.44)]
	for index: int in range(world_grid.width * world_grid.height):
		var cell: Vector2i = world_grid.index_to_cell(index)
		if world_grid.is_exterior(cell):
			continue
		var value: int = int(world_grid.get_root_signal(cell))
		var band := 0
		if value >= int(thresholds[2]):
			band = 3
		elif value >= int(thresholds[1]):
			band = 2
		elif value >= int(thresholds[0]):
			band = 1
		if band > 0:
			draw_rect(_cell_rect(cell), colors[band], true)


func _draw_signal_raw() -> void:
	for index: int in range(world_grid.width * world_grid.height):
		var cell: Vector2i = world_grid.index_to_cell(index)
		var value: int = int(world_grid.get_root_signal(cell))
		if value <= 0 or world_grid.is_exterior(cell):
			continue
		var intensity := clampf(float(value) / 8.0, 0.08, 0.75)
		draw_rect(_cell_rect(cell).grow(-1.0), Color(0.95, 0.18, 0.35, intensity), true)


func _draw_signal_system() -> void:
	if signal_system == null:
		return
	for emitter: Dictionary in signal_system.get_emitters():
		var anchor: Variant = emitter.get("anchor", Vector2i(-1, -1))
		if not anchor is Vector2i:
			continue
		var center := _cell_center(anchor)
		draw_circle(center, cell_size * 0.72, Color("f25768", 0.20))
		draw_arc(center, cell_size * 0.72, 0.0, TAU, 20, Color("f25768"), 2.0)
	for dirty: Dictionary in signal_system.get_dirty_regions():
		var region: Variant = dirty.get("region", Rect2i())
		if region is Rect2i:
			var rect := Rect2(Vector2(region.position * cell_size), Vector2(region.size * cell_size))
			draw_rect(rect, Color("6ee7db", 0.55), false, 2.0)


func _draw_moisture_raw() -> void:
	for index: int in range(world_grid.width * world_grid.height):
		var cell: Vector2i = world_grid.index_to_cell(index)
		var value: int = int(world_grid.get_moisture_signal(cell))
		if value <= 0 or world_grid.is_exterior(cell):
			continue
		var intensity := clampf(float(value) / 8.0, 0.08, 0.75)
		draw_rect(_cell_rect(cell).grow(-1.0), Color(0.12, 0.68, 0.82, intensity), true)


func _draw_water_state() -> void:
	for index: int in range(world_grid.width * world_grid.height):
		var cell: Vector2i = world_grid.index_to_cell(index)
		var units: int = int(world_grid.get_water_units(cell))
		if units <= 0:
			continue
		var intensity := clampf(float(units) / 4.0, 0.18, 0.82)
		draw_rect(_cell_rect(cell).grow(-1.0), Color(0.10, 0.58, 0.90, intensity), true)
	if water_system == null:
		return
	for flow: Dictionary in water_system.get_last_flows():
		var from_cell: Vector2i = flow.get("from", Vector2i(-1, -1))
		var to_cell: Vector2i = flow.get("to", Vector2i(-1, -1))
		if from_cell.x < 0 or to_cell.x < 0:
			continue
		var from_center := _cell_center(from_cell)
		var to_center := _cell_center(to_cell)
		draw_line(from_center, to_center, Color("9cecff"), 2.0)
		draw_circle(to_center, 2.0, Color("d6f8ff"))


func _draw_stability_state() -> void:
	var thresholds: Array = world_grid.metadata.get("signal_thresholds", {}).get("instability", [35, 60, 80])
	var colors: Array[Color] = [
		Color.TRANSPARENT,
		Color("dfc56c", 0.30),
		Color("e79b50", 0.42),
		Color("e95f55", 0.55),
	]
	for index: int in range(world_grid.width * world_grid.height):
		var cell: Vector2i = world_grid.index_to_cell(index)
		if not world_grid.is_traversable(cell) or world_grid.is_exterior(cell):
			continue
		var value: int = int(world_grid.get_stability_base(cell))
		if value <= 0:
			continue
		var band := 1
		if value >= int(thresholds[2]):
			band = 3
		elif value >= int(thresholds[1]):
			band = 2
		draw_rect(_cell_rect(cell), colors[band], true)
	for index: int in range(world_grid.width * world_grid.height):
		var cell: Vector2i = world_grid.index_to_cell(index)
		if world_grid.is_reinforced(cell):
			draw_rect(_cell_rect(cell).grow(-1.0), Color("c9a86a", 0.9), false, 2.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * cell_size), Vector2.ONE * cell_size)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _feature_color(feature_id: int) -> Color:
	var palette: Array[Color] = [Color("77b86d"), Color("5ba8c8"), Color("d48c5e"), Color("c86f86"), Color("9b82d1"), Color("d1bc68")]
	return palette[absi(feature_id) % palette.size()]
