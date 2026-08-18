class_name DigCursorView
extends Node2D

var cell_size := 16
var cell_coord := Vector2i(-1, -1)
var valid := false
var cancel_mode := false
var tool_style := "DIG"


func configure(logical_cell_size: int) -> void:
	cell_size = logical_cell_size


func set_cursor(coord: Vector2i, is_visible: bool, is_valid: bool, is_cancel: bool) -> void:
	cell_coord = coord
	visible = is_visible
	valid = is_valid
	cancel_mode = is_cancel
	position = Vector2(cell_coord * cell_size)
	queue_redraw()


func set_tool_style(value: String) -> void:
	tool_style = value
	queue_redraw()


func _draw() -> void:
	var color := _tool_color() if valid else Color("d96b62")
	if cancel_mode:
		color = Color("ef8b71")
	var rect := Rect2(Vector2.ONE, Vector2.ONE * (cell_size - 2))
	draw_rect(rect, Color(color, 0.14), true)
	draw_rect(rect, color, false, 2.0)
	if not valid or cancel_mode:
		draw_line(Vector2(4.0, 4.0), Vector2(cell_size - 4.0, cell_size - 4.0), color, 1.5)
		draw_line(Vector2(cell_size - 4.0, 4.0), Vector2(4.0, cell_size - 4.0), color, 1.5)


func _tool_color() -> Color:
	if tool_style.begins_with("SLEEPING"):
		return Color("a997d4")
	if tool_style.begins_with("STORAGE"):
		return Color("e0b765")
	if tool_style.begins_with("FOOD"):
		return Color("7dc681")
	if tool_style.begins_with("SEAL"):
		return Color("70c5cf")
	return Color("eac56b")
