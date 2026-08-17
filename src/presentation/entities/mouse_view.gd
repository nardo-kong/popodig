class_name MouseView
extends Node2D

var mouse_agent
var cell_size := 16
var _work_phase := 0.0


func configure(agent, logical_cell_size: int) -> void:
	mouse_agent = agent
	cell_size = logical_cell_size
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
	var working := String(mouse_agent.get_state_name()) == "DIGGING"
	var bob := sin(_work_phase) * 1.2 if working else sin(_work_phase * 0.25) * 0.35
	var body_color := Color("c7a27c")
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


func _target_position() -> Vector2:
	if mouse_agent == null:
		return position
	return (Vector2(mouse_agent.current_cell) + Vector2(0.5, 0.5)) * cell_size
