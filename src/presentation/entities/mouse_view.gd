class_name MouseView
extends Node2D

const MouseMasterTexture := preload("res://assets/art/production/entities/mouse_master_idle_01.png")
const MASTER_HEIGHT_UNITS := 18.0

# Phase 11 mouse animation set (docs/art/12_ART_BIBLE.md §10): the production
# master sprite is the body; every state animates it code-side (bob, squash,
# lean, stepping feet) plus small procedural accents, keeping the silhouette
# and carried-item readability while avoiding a full frame-set dependency.
# Cosmetic only — press M in game to compare against the flat placeholder.

const OUTLINE := Color("4a352b")
const EAR_COLOR := Color("d9aa9a")
const EYE_COLOR := Color("1e1714")
const TOOL_COLOR := Color("e0c28d")

static var master_default := true
static var animations_enabled := true

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
	var state_name := String(mouse_agent.get_state_name())
	# Fleeing breathes faster; resting breathes slower; working paces the tool.
	var pace := 14.0 if state_name == "FLEEING" else 9.0 if state_name == "DIGGING" else 3.5 if state_name == "RESTING" else 6.0
	_work_phase = fmod(_work_phase + delta * pace, TAU)
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
	var fleeing := state_name == "FLEEING"
	var moving := state_name == "MOVING" or state_name == "HAULING"
	var eating := state_name == "EATING"
	var idle := state_name == "IDLE"
	var carrying: bool = int(mouse_agent.carried_item_count) > 0
	var bob: float
	if animations_enabled:
		if working:
			bob = sin(_work_phase) * 1.2
		elif fleeing:
			bob = absf(sin(_work_phase * 1.5)) * -1.6
		elif moving:
			bob = absf(sin(_work_phase)) * -0.9
		elif eating:
			bob = sin(_work_phase * 2.0) * 0.5
		elif resting:
			bob = sin(_work_phase) * 0.5
		else:
			bob = sin(_work_phase * 0.25) * 0.35
	var lean := 0.0
	if animations_enabled and working:
		lean = 0.12 * _facing
	if _use_master and MouseMasterTexture != null:
		_draw_master_body(bob, lean, resting)
	else:
		_draw_placeholder_body(bob, lean)
	if animations_enabled:
		_draw_state_accents(state_name, working, resting, fleeing, moving, eating, idle, carrying, bob)


func _draw_master_body(bob: float, lean: float, resting: bool) -> void:
	var tex_size := MouseMasterTexture.get_size()
	var scale_factor := MASTER_HEIGHT_UNITS / tex_size.y
	var size := tex_size * scale_factor
	# Sleeping mice curl: squash vertically, widen slightly, sink to the floor.
	var body_scale := Vector2(1.12, 0.82) if (resting and animations_enabled) else Vector2.ONE
	size = Vector2(size.x * body_scale.x, size.y * body_scale.y)
	# Feet anchored near the cell floor like the placeholder body.
	var origin := Vector2(-size.x * 0.5, 7.0 - size.y + bob)
	draw_set_transform(Vector2.ZERO, lean, Vector2(_facing, 1.0))
	draw_texture_rect(MouseMasterTexture, Rect2(origin, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_placeholder_body(bob: float, lean: float) -> void:
	var body_color := _body_color()
	draw_set_transform(Vector2.ZERO, lean, Vector2.ONE)
	draw_circle(Vector2(-4.0, -5.0 + bob), 3.5, EAR_COLOR)
	draw_circle(Vector2(4.0, -5.0 + bob), 3.5, EAR_COLOR)
	draw_circle(Vector2(0.0, bob), 7.0, OUTLINE)
	draw_circle(Vector2(0.0, -0.5 + bob), 5.8, body_color)
	draw_circle(Vector2(2.2, -1.5 + bob), 0.9, EYE_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_state_accents(state_name: String, working: bool, resting: bool, fleeing: bool, moving: bool, eating: bool, idle: bool, carrying: bool, bob: float) -> void:
	if working:
		var flip := _facing
		var tool_tip := Vector2(10.0 * flip + sin(_work_phase) * 2.0 * flip, -6.0 + cos(_work_phase) * 3.0)
		draw_line(Vector2(4.0 * flip, 2.0 + bob), tool_tip, TOOL_COLOR, 2.0)
		# Dig dust puffs at the tool tip, phased so they puff on the downswing.
		var puff := fmod(_work_phase, TAU) / TAU
		if puff < 0.55:
			var puff_alpha := 0.5 * (1.0 - puff / 0.55)
			draw_circle(tool_tip + Vector2(2.0 * flip, 1.0), 1.2 + puff * 2.4, Color("c9b28a", puff_alpha))
			draw_circle(tool_tip + Vector2(3.5 * flip, 2.2), 0.9 + puff * 1.6, Color("b09a76", puff_alpha * 0.8))
	elif moving:
		# Alternating step pads under the body, phase-driven, flipped by facing.
		var step := sin(_work_phase)
		var foot_color := Color("3a2b22", 0.85)
		draw_circle(Vector2(-2.5 * _facing + step * 1.8 * _facing, 6.5), 1.1, foot_color)
		draw_circle(Vector2(2.5 * _facing - step * 1.8 * _facing, 6.8), 1.1, foot_color)
	elif eating:
		# Nibble: small crumb pulses in front of the mouth.
		var crumb_pulse := 0.5 + 0.5 * sin(_work_phase * 2.0)
		draw_circle(Vector2(5.0 * _facing, -1.0 + bob), 1.0 + crumb_pulse * 0.8, Color("d76d52", 0.9))
		draw_circle(Vector2(6.5 * _facing, -0.2 + bob), 0.7 + crumb_pulse * 0.5, Color("b85c42", 0.8))
	elif resting:
		# Closed eye line + floating sleep wisps rising with the breath cycle.
		draw_line(Vector2(1.2 * _facing, -1.5 + bob), Vector2(3.2 * _facing, -1.5 + bob), EYE_COLOR, 1.0)
		var wisp_phase := fmod(_work_phase / TAU, 1.0)
		var wisp_y := -8.0 - wisp_phase * 9.0
		var wisp_alpha := 0.6 * (1.0 - wisp_phase)
		_draw_wisp(Vector2(4.0 * _facing, wisp_y), wisp_alpha)
		if wisp_phase > 0.45:
			_draw_wisp(Vector2(6.0 * _facing, wisp_y + 5.0), wisp_alpha * 0.7)
	elif fleeing:
		# Panic streaks trailing behind the body + warning badge.
		for streak: int in range(2):
			var streak_y := -3.0 + float(streak) * 4.0
			var streak_alpha := 0.35 - 0.12 * float(streak) + 0.1 * sin(_work_phase * 2.0 + float(streak))
			draw_line(Vector2(-6.0 * _facing, streak_y), Vector2(-12.0 * _facing, streak_y + 0.8), Color("ef7c54", streak_alpha), 1.0)
	elif idle:
		# Idle blink: eye closes for a moment every few breath cycles.
		if fmod(_work_phase, TAU * 3.0) < TAU * 0.12:
			draw_line(Vector2(1.2 * _facing, -1.5), Vector2(3.2 * _facing, -1.5), EYE_COLOR, 1.0)
	if carrying:
		# Carried item rides on the back, clear of the head silhouette.
		var id := String(mouse_agent.carried_item_type)
		var icon := ResourceVisuals.texture(id)
		if icon != null:
			var center := Vector2(0.0, -11.5 + bob) if not resting else Vector2(0.0, -9.0 + bob)
			draw_texture_rect(icon, ResourceVisuals.fitted_rect(id, center, 10.0), false)
	if fleeing:
		var warning := PackedVector2Array([Vector2(-3.5, -16.0), Vector2(3.5, -16.0), Vector2(0.0, -22.0)])
		draw_colored_polygon(warning, Color("ef7c54"))


func _draw_wisp(origin: Vector2, alpha: float) -> void:
	draw_arc(origin, 1.8, PI * 0.2, PI * 1.3, 8, Color("a8c6d8", alpha), 1.1)


func _body_color() -> Color:
	var palette: Array[Color] = [Color("c7a27c"), Color("b88f78"), Color("d1b189")]
	return palette[posmod(_palette_index, palette.size())]


func _target_position() -> Vector2:
	if mouse_agent == null:
		return position
	return (Vector2(mouse_agent.current_cell) + Vector2(0.5, 0.5)) * cell_size
