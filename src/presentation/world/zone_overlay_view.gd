class_name ZoneOverlayView
extends Node2D

const ZoneScript = preload("res://src/domain/zones/zone.gd")

var zone_system
var cell_size := 16
var editing := false
var selected_zone_type := ZoneScript.Type.SLEEPING


func configure(system, logical_cell_size: int) -> void:
	zone_system = system
	cell_size = logical_cell_size
	if not zone_system.zones_changed.is_connected(_on_zones_changed):
		zone_system.zones_changed.connect(_on_zones_changed)
	if not zone_system.zone_validity_changed.is_connected(_on_zone_validity_changed):
		zone_system.zone_validity_changed.connect(_on_zone_validity_changed)
	if not zone_system.setup_state_changed.is_connected(_on_setup_state_changed):
		zone_system.setup_state_changed.connect(_on_setup_state_changed)
	queue_redraw()


func set_editing(value: bool, zone_type: int = ZoneScript.Type.SLEEPING) -> void:
	if editing == value and selected_zone_type == zone_type:
		return
	editing = value
	selected_zone_type = zone_type
	queue_redraw()


func _draw() -> void:
	if zone_system == null:
		return
	for zone: Zone in zone_system.get_zones():
		var color := _zone_color(zone.zone_type)
		var is_selected := editing and zone.zone_type == selected_zone_type
		var fill_alpha := 0.28 if is_selected else 0.09
		if not zone.valid:
			color = Color("db665e")
			fill_alpha = 0.34 if editing else 0.17
		for cell: Vector2i in zone.cells:
			var rect := Rect2(Vector2(cell * cell_size) + Vector2.ONE, Vector2.ONE * (cell_size - 2))
			draw_rect(rect, Color(color, fill_alpha), true)
			if editing:
				draw_rect(rect, Color(color, 0.76 if is_selected else 0.34), false, 1.0)
				if not zone.valid:
					draw_line(rect.position + Vector2(3, 3), rect.end - Vector2(3, 3), color, 1.2)
					draw_line(Vector2(rect.end.x - 3, rect.position.y + 3), Vector2(rect.position.x + 3, rect.end.y - 3), color, 1.2)
		if zone.valid and zone.setup_state == ZoneScript.SetupState.SET_UP:
			_draw_dressing(zone)
		else:
			_draw_setup_marker(zone.identity_anchor, color)


func _draw_dressing(zone: Zone) -> void:
	var color := _zone_color(zone.zone_type)
	for anchor: Vector2i in zone.dressing_anchors:
		var center := (Vector2(anchor) + Vector2(0.5, 0.5)) * cell_size
		match zone.zone_type:
			ZoneScript.Type.SLEEPING:
				draw_circle(center, 5.0, Color("352c28"))
				draw_arc(center, 5.0, 0.0, TAU, 16, color.lightened(0.18), 1.5)
				draw_line(center + Vector2(-3, 1), center + Vector2(3, -1), color, 1.0)
			ZoneScript.Type.STORAGE:
				var basket := Rect2(center - Vector2(5, 3), Vector2(10, 7))
				draw_rect(basket, Color("3a3028"), true)
				draw_rect(basket, color.lightened(0.15), false, 1.3)
				draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), color, 1.0)
			ZoneScript.Type.FOOD_FORAGE:
				draw_circle(center + Vector2(-2, 1), 3.0, color)
				draw_circle(center + Vector2(2, -1), 2.5, color.lightened(0.2))
				draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color("4a3928"), 1.2)


func _draw_setup_marker(cell: Vector2i, color: Color) -> void:
	if cell.x < 0:
		return
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
	var points := PackedVector2Array([
		center + Vector2(0, -4),
		center + Vector2(4, 0),
		center + Vector2(0, 4),
		center + Vector2(-4, 0),
	])
	draw_colored_polygon(points, Color(color, 0.7))


func _zone_color(zone_type: int) -> Color:
	match zone_type:
		ZoneScript.Type.SLEEPING:
			return Color("9e88c9")
		ZoneScript.Type.STORAGE:
			return Color("d1a85c")
		ZoneScript.Type.FOOD_FORAGE:
			return Color("70ad72")
		_:
			return Color.MAGENTA


func _on_zones_changed(_change: Dictionary) -> void:
	queue_redraw()


func _on_zone_validity_changed(_zone_id: int, _valid: bool, _reasons: PackedStringArray) -> void:
	queue_redraw()


func _on_setup_state_changed(_zone_id: int, _setup_state: int) -> void:
	queue_redraw()
