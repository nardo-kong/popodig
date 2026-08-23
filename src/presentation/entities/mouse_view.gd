class_name MouseView
extends Node2D

const MouseMasterTexture := preload("res://assets/art/production/entities/mouse_master_idle_01.png")
const MASTER_HEIGHT_UNITS := 18.0

# Temporary hybrid presentation switch: static master idle art replaces the
# procedural placeholder body; every state badge below stays procedural until
# a real animation set arrives. Cosmetic only — press M in game to compare.
static var master_default := false

var mouse_agent
var cell_size := 16
var _work_phase := 0.0
var _palette_index := 0
var _use_master := master_default
var _facing := -1.0


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
	var previous_x := position.x
	_work_phase = fmod(_work_phase + delta * 9.0, TAU)
	position = position.lerp(_target_position(), minf(1.0, delta * 14.0))
	if absf(position.x - previous_x) > 0.25:
		_facing = signf(position.x - previous_x)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_use_master = not _use_master
		MouseView.master_default = _use_master
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
	if _use_master and MouseMasterTexture != null:
		_draw_master_body(bob)
	else:
		_draw_placeholder_body(bob)
	_draw_state_badges(working, resting, fleeing, carrying, bob)


func _draw_master_body(bob: float) -> void:
	var tex_size := MouseMasterTexture.get_size()
	var scale_factor := MASTER_HEIGHT_UNITS / tex_size.y
	var size := tex_size * scale_factor
	# Feet anchored near the cell floor like the placeholder body.
	var origin := Vector2(-size.x * 0.5, 7.0 - size.y + bob)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1.0))
	draw_texture_rect(MouseMasterTexture, Rect2(origin, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_placeholder_body(bob: float) -> void:
	var body_color := _body_color()
	var ear_color := Color("d9aa9a")
	var outline := Color("4a352b")
	# Engineering placeholder silhouette; production mouse art is intentionally deferred.
	draw_circle(Vector2(-4.0, -5.0 + bob), 3.5, ear_color)
	draw_circle(Vector2(4.0, -5.0 + bob), 3.5, ear_color)
	draw_circle(Vector2(0.0, bob), 7.0, outline)
	draw_circle(Vector2(0.0, -0.5 + bob), 5.8, body_color)
	draw_circle(Vector2(2.2, -1.5 + bob), 0.9, Color("1e1714"))


func _draw_state_badges(working: bool, resting: bool, fleeing: bool, carrying: bool, bob: float) -> void:
	if working:
		var flip := _facing
		var tool_tip := Vector2(10.0 * flip + sin(_work_phase) * 2.0 * flip, -6.0 + cos(_work_phase) * 3.0)
		draw_line(Vector2(4.0 * flip, 2.0 + bob), tool_tip, Color("e0c28d"), 2.0)
	if carrying:
		var carry_color := Color("d76d52") if String(mouse_agent.carried_item_type) == "FOOD" else Color("d1b26f")
		draw_rect(Rect2(Vector2(-3.0, -15.0 + bob), Vector2(6.0, 5.0)), carry_color, true)
		draw_rect(Rect2(Vector2(-3.0, -15.0 + bob), Vector2(6.0, 5.0)), Color("4a352b"), false, 1.0)
	if resting:
		draw_arc(Vector2(0.0, -12.0), 3.0, 0.0, PI, 8, Color("a8c6d8"), 1.5)
	if fleeing:
		var warning := PackedVector2Array([Vector2(-3.5, -16.0), Vector2(3.5, -16.0), Vector2(0.0, -22.0)])
		draw_colored_polygon(warning, Color("ef7c54"))


func _body_color() -> Color:
	var palette: Array[Color] = [Color("c7a27c"), Color("b88f78"), Color("d1b189")]
	return palette[posmod(_palette_index, palette.size())]


func _target_position() -> Vector2:
	if mouse_agent == null:
		return position
	return (Vector2(mouse_agent.current_cell) + Vector2(0.5, 0.5)) * cell_size
