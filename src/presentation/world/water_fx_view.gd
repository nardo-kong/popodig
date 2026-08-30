class_name WaterFxView
extends Node2D

# Animated water layer (docs/art/13_AUDIO_VFX_SPEC.md §7): surface ripple and
# drifting shimmer over standing water, plus flow accents for recent transfer
# moves. The static depth body lives in WorldChunkView (dirty-driven); this
# view only animates, redraws at ~8 Hz, and culls to the camera-visible cells.

const REDRAW_INTERVAL := 0.12

var world_grid
var water_system
var cell_size := 16
var _accumulator := 0.0
var _time := 0.0


func configure(grid, water, logical_cell_size: int) -> void:
	world_grid = grid
	water_system = water
	cell_size = logical_cell_size


func _process(delta: float) -> void:
	if world_grid == null:
		visible = false
		return
	visible = true
	_time += delta
	_accumulator += delta
	if _accumulator >= REDRAW_INTERVAL:
		_accumulator = 0.0
		queue_redraw()


func _draw() -> void:
	if world_grid == null:
		return
	var visible_rect := _visible_world_rect()
	if visible_rect.size == Vector2.ZERO:
		return
	var from_cell := Vector2i(floori(visible_rect.position.x / cell_size), floori(visible_rect.position.y / cell_size))
	var to_cell := Vector2i(floori(visible_rect.end.x / cell_size), floori(visible_rect.end.y / cell_size))
	for y: int in range(from_cell.y, to_cell.y + 1):
		for x: int in range(from_cell.x, to_cell.x + 1):
			var cell := Vector2i(x, y)
			if int(world_grid.get_water_units(cell)) <= 0:
				continue
			_draw_animated_surface(cell)
	_draw_flow_accents()


func _visible_world_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var canvas_transform := get_viewport_transform()
	var inv := canvas_transform.affine_inverse()
	var corners := [
		inv * Vector2.ZERO,
		inv * Vector2(viewport.get_visible_rect().size.x, 0.0),
		inv * Vector2(0.0, viewport.get_visible_rect().size.y),
		inv * viewport.get_visible_rect().size,
	]
	var rect := Rect2(corners[0], Vector2.ZERO)
	for point: Vector2 in corners:
		rect = rect.expand(point)
	return rect


func _draw_animated_surface(cell: Vector2i) -> void:
	var rect := Rect2(Vector2(cell * cell_size), Vector2.ONE * cell_size)
	var capacity := 4 if water_system == null else maxi(1, int(water_system.get_cell_capacity()))
	var ratio := clampf(float(int(world_grid.get_water_units(cell))) / float(capacity), 0.0, 1.0)
	var surface_y := rect.end.y - maxf(3.0, rect.size.y * ratio)
	var cell_hash := absi(cell.x * 73856093 ^ cell.y * 19349663)
	# Two-phase ripple: surface line undulates and a shimmer speck drifts.
	var ripple_phase := _time * 2.4 + float(cell_hash % 7)
	var ripple_a := sin(ripple_phase) * 0.7
	var ripple_b := sin(ripple_phase + 2.1) * 0.7
	draw_line(
		Vector2(rect.position.x + 1.0, surface_y + 1.0 + ripple_a * 0.4),
		Vector2(rect.end.x - 1.0, surface_y + 1.0 + ripple_b * 0.4),
		Color("b8e8ea", 0.28 + 0.1 * sin(_time * 1.7 + float(cell_hash % 5))),
		0.8
	)
	var drift := fmod(_time * 3.0 + float(cell_hash % 11), float(cell_size - 4.0))
	draw_circle(
		Vector2(rect.position.x + 2.0 + drift, surface_y + 2.2 + sin(_time * 3.0 + float(cell_hash % 3)) * 0.5),
		0.7,
		Color("d6f4f4", 0.35)
	)


## Recent transfer flows get a fading chevron pointing downstream so gravity
## drainage direction is visible while it happens.
func _draw_flow_accents() -> void:
	if water_system == null:
		return
	var flows: Array = water_system.get_last_flows()
	if flows.is_empty():
		return
	var phase := sin(_time * 6.0)
	for flow: Dictionary in flows:
		var from_cell: Vector2i = flow.get("from", Vector2i(-1, -1))
		var to_cell: Vector2i = flow.get("to", Vector2i(-1, -1))
		if from_cell.x < 0 or to_cell.x < 0:
			continue
		var from_center := (Vector2(from_cell) + Vector2(0.5, 0.5)) * cell_size
		var to_center := (Vector2(to_cell) + Vector2(0.5, 0.5)) * cell_size
		var direction := (to_center - from_center).normalized()
		if direction == Vector2.ZERO:
			continue
		var arrow_tip := to_center.lerp(from_center, 0.25)
		var side := direction.orthogonal() * 2.2
		var alpha := 0.35 + 0.25 * phase
		draw_colored_polygon(
			PackedVector2Array([arrow_tip + direction * 2.5, arrow_tip - direction * 1.5 + side, arrow_tip - direction * 1.5 - side]),
			Color("b8e8ea", alpha)
		)
