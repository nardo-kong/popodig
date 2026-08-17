class_name WorldCamera
extends Camera2D

@export var min_zoom := 0.55
@export var max_zoom := 2.2
@export var zoom_step := 0.12
@export var keyboard_pan_speed := 620.0

var _dragging := false
var _drag_button := MOUSE_BUTTON_NONE
var _last_mouse_position := Vector2.ZERO
var _world_rect := Rect2()


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 9.0


func configure_world_bounds(world_rect: Rect2) -> void:
	_world_rect = world_rect


func focus_cell(cell_coord: Vector2i, cell_size: int) -> void:
	position = (Vector2(cell_coord) + Vector2(0.5, 0.5)) * cell_size
	_clamp_to_world()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction != Vector2.ZERO:
		position += direction.normalized() * keyboard_pan_speed * delta / zoom.x
		_clamp_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_set_zoom(zoom.x + zoom_step)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_set_zoom(zoom.x - zoom_step)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_set_dragging(mouse_event.pressed, MOUSE_BUTTON_MIDDLE, mouse_event.position)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed and Input.is_key_pressed(KEY_SPACE):
				_set_dragging(true, MOUSE_BUTTON_LEFT, mouse_event.position)
				get_viewport().set_input_as_handled()
			elif not mouse_event.pressed and _drag_button == MOUSE_BUTTON_LEFT:
				_set_dragging(false, MOUSE_BUTTON_LEFT, mouse_event.position)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		position -= (motion.position - _last_mouse_position) / zoom.x
		_last_mouse_position = motion.position
		_clamp_to_world()
		get_viewport().set_input_as_handled()


func _set_zoom(value: float) -> void:
	var clamped := clampf(value, min_zoom, max_zoom)
	zoom = Vector2.ONE * clamped
	_clamp_to_world()


func force_clamp_to_world() -> void:
	_clamp_to_world()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_dragging = false
		_drag_button = MOUSE_BUTTON_NONE


func _set_dragging(value: bool, button: MouseButton, mouse_position: Vector2) -> void:
	_dragging = value
	_drag_button = button if value else MOUSE_BUTTON_NONE
	_last_mouse_position = mouse_position


func _clamp_to_world() -> void:
	if _world_rect.size == Vector2.ZERO:
		return
	var half_view := get_viewport_rect().size * 0.5 / zoom
	if _world_rect.size.x <= half_view.x * 2.0:
		position.x = _world_rect.get_center().x
	else:
		position.x = clampf(position.x, _world_rect.position.x + half_view.x, _world_rect.end.x - half_view.x)
	if _world_rect.size.y <= half_view.y * 2.0:
		position.y = _world_rect.get_center().y
	else:
		position.y = clampf(position.y, _world_rect.position.y + half_view.y, _world_rect.end.y - half_view.y)
