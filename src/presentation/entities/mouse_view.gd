class_name MouseView
extends Node2D

var mouse_agent
var cell_size := 16
var _work_phase := 0.0
var _palette_index := 0


func configure(agent, logical_cell_size: int, palette_index: int = 0) -> void:
	mouse_agent = agent
	cell_size = logical_cell_size
	_palette_index = palette_index
	position = _target_position()
	queue_redraw()


func _process(delta: float) -> void:
	if mouse_agent == null:
		visible = false
		return
	visible = true
	_work_phase = fmod(_work_phase + delta * 9.0, TAU)
	position = position.lerp(_target_position(), minf(1.0, delta * 14.0))
	queue_redraw()


func _draw() -> void:
	if mouse_agent == null:
		return
	var state_name := String(mouse_agent.get_state_name())
	var working := state_name == "DIGGING"
	var resting := state_name == "RESTING"
	var fleeing: bool = bool(mouse_agent.danger_state)
	var carrying: bool = int(mouse_agent.carried_item_count) > 0
	var bob := sin(_work_phase) * 1.2 if working else sin(_work_phase * 0.25) * 0.35
	var body_color := _body_color()
	var ear_color := Color("d9aa9a")
	var outline := Color("4a352b")
	# Engineering placeholder silhouette; production mouse art is intentionally deferred.
	draw_circle(Vector2(-4.0, -5.0 + bob), 3.5, ear_color)
	draw_circle(Vector2(4.0, -5.0 + bob), 3.5, ear_color)
	draw_circle(Vector2(0.0, bob), 7.0, outline)
	draw_circle(Vector2(0.0, -0.5 + bob), 5.8, body_color)
	draw_circle(Vector2(2.2, -1.5 + bob), 0.9, Color("1e1714"))
	if working:
		var tool_tip := Vector2(10.0 + sin(_work_phase) * 2.0, -6.0 + cos(_work_phase) * 3.0)
		draw_line(Vector2(4.0, 2.0 + bob), tool_tip, Color("e0c28d"), 2.0)
	if carrying:
		var carry_color := Color("d76d52") if String(mouse_agent.carried_item_type) == "FOOD" else Color("d1b26f")
		draw_rect(Rect2(Vector2(-3.0, -13.0 + bob), Vector2(6.0, 5.0)), carry_color, true)
		draw_rect(Rect2(Vector2(-3.0, -13.0 + bob), Vector2(6.0, 5.0)), outline, false, 1.0)
	if resting:
		draw_arc(Vector2(0.0, -10.0), 3.0, 0.0, PI, 8, Color("a8c6d8"), 1.5)
	if fleeing:
		var warning := PackedVector2Array([Vector2(-3.5, -14.0), Vector2(3.5, -14.0), Vector2(0.0, -20.0)])
		draw_colored_polygon(warning, Color("ef7c54"))


func _body_color() -> Color:
	var palette: Array[Color] = [Color("c7a27c"), Color("b88f78"), Color("d1b189")]
	return palette[posmod(_palette_index, palette.size())]


func _target_position() -> Vector2:
	if mouse_agent == null:
		return position
	return (Vector2(mouse_agent.current_cell) + Vector2(0.5, 0.5)) * cell_size
