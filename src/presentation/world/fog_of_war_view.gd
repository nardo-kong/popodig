class_name FogOfWarView
extends Node2D

# Phase 16 player feedback (PM direction): unexplored ground is dark — the
# world reads as excavation, not as an already-drawn map. Visibility is a
# multi-source BFS from every open/surface cell: distance 0 is fully lit,
# `radius` and beyond is full darkness, with a linear fade between. Pure
# computation lives in the static `compute_visibility` so tests can drive it
# without a scene. Presentation only — never mutates simulation state.

const DARK_COLOR := Color(0.03, 0.02, 0.02, 1.0)
const REDRAW_INTERVAL := 0.25

var world_grid
var feature_registry = null
var cell_size := 16
var radius := 4
var debug_disabled := false

var _visibility: PackedInt32Array = []
var _grid_width := 0
var _grid_height := 0
var _accumulator := REDRAW_INTERVAL
var _stale := true
var _last_visible_rect := Rect2()


func configure(grid, logical_cell_size: int, fog_radius: int, registry = null) -> void:
	world_grid = grid
	cell_size = logical_cell_size
	radius = maxi(1, fog_radius)
	feature_registry = registry


func mark_stale() -> void:
	_stale = true


func distance_to_frontier(cell: Vector2i) -> int:
	if world_grid == null or _visibility.is_empty() or not world_grid.is_in_bounds(cell):
		return radius + 1
	return _visibility[world_grid.cell_to_index(cell)]


func is_cell_visible(cell: Vector2i) -> bool:
	if world_grid == null or _visibility.is_empty():
		return true
	if cell.x < 0 or cell.y < 0 or cell.x >= _grid_width or cell.y >= _grid_height:
		return true
	return _visibility[cell.y * _grid_width + cell.x] <= 1


func _process(delta: float) -> void:
	if world_grid == null or debug_disabled:
		visible = false
		return
	visible = true
	_accumulator += delta
	# Panning/zooming changes which cells need darkness even with no dig
	# events, so a moved viewport counts as stale (throttled below).
	var visible_rect := _visible_world_rect()
	if visible_rect != _last_visible_rect:
		_last_visible_rect = visible_rect
		_stale = true
	if _stale and _accumulator >= REDRAW_INTERVAL:
		_accumulator = 0.0
		_stale = false
		_recompute()
		queue_redraw()


## Multi-source BFS over the whole grid. Sources: every traversable cell plus
## every surface (exterior) cell — the garden stays lit, the underground
## darkens away from the digging. Returns distance levels (0 = lit … radius =
## fully dark) as width×height row-major levels.
static func compute_visibility(width: int, height: int, is_open: Callable, is_exterior: Callable, fog_radius: int) -> PackedInt32Array:
	var levels := PackedInt32Array()
	levels.resize(width * height)
	levels.fill(fog_radius + 1)
	var queue: Array[Vector2i] = []
	for y: int in range(height):
		for x: int in range(width):
			var cell := Vector2i(x, y)
			var source := bool(is_exterior.call(cell)) or bool(is_open.call(cell))
			if source:
				levels[y * width + x] = 0
				queue.append(cell)
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_level: int = levels[current.y * width + current.x]
		if current_level >= fog_radius:
			continue
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor := current + direction
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
				continue
			var index := neighbor.y * width + neighbor.x
			if levels[index] > current_level + 1:
				levels[index] = current_level + 1
				queue.append(neighbor)
	return levels


func _recompute() -> void:
	_grid_width = world_grid.width
	_grid_height = world_grid.height
	# Undiscovered features keep their open cells dark: they must not act as
	# light sources or they leak halo spoilers through solid rock. Once
	# `feature.hidden` flips on discovery, their cells light up like any dug
	# space. Natural BFS propagation still bleeds partial light into a hidden
	# cavity as the player tunnels next to it — that is the intended
	# Signal → Reveal leak, bounded by the fade.
	var hidden_open := {}
	if feature_registry != null:
		for feature in feature_registry.get_features():
			if not bool(feature.hidden):
				continue
			for cell: Vector2i in feature.cells:
				if world_grid.is_traversable(cell):
					hidden_open[cell] = true
	_visibility = compute_visibility(
		world_grid.width,
		world_grid.height,
		func(cell: Vector2i) -> bool: return world_grid.is_traversable(cell) and not hidden_open.has(cell),
		world_grid.is_exterior,
		radius
	)


func _draw() -> void:
	if world_grid == null or _visibility.is_empty():
		return
	var visible_rect := _visible_world_rect()
	if visible_rect.size == Vector2.ZERO:
		return
	var from_cell := Vector2i(maxi(0, floori(visible_rect.position.x / cell_size)), maxi(0, floori(visible_rect.position.y / cell_size)))
	var to_cell := Vector2i(mini(_grid_width - 1, floori(visible_rect.end.x / cell_size)), mini(_grid_height - 1, floori(visible_rect.end.y / cell_size)))
	for y: int in range(from_cell.y, to_cell.y + 1):
		for x: int in range(from_cell.x, to_cell.x + 1):
			var level := _visibility[y * _grid_width + x]
			if level <= 1:
				continue
			var fade := clampf(float(level - 1) / float(maxi(1, radius)), 0.0, 1.0)
			var color := DARK_COLOR
			color.a = 0.35 + 0.65 * fade
			draw_rect(Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size), color, true)


func _visible_world_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	# get_canvas_transform maps world-canvas coordinates into the same
	# base-viewport units as get_visible_rect().size. The stretch
	# final_transform must stay OUT of the pair — CanvasItem
	# get_viewport_transform() includes it, and mixing the two spaces made the
	# fog only cover the window's top-left corner at window sizes above the
	# 1280×720 base (PM bug report, maximized window).
	var canvas_inv := viewport.get_canvas_transform().affine_inverse()
	var size := viewport.get_visible_rect().size
	var rect := Rect2(canvas_inv * Vector2.ZERO, Vector2.ZERO)
	for corner: Vector2 in [canvas_inv * Vector2(size.x, 0.0), canvas_inv * Vector2(0.0, size.y), canvas_inv * size]:
		rect = rect.expand(corner)
	return get_global_transform().affine_inverse() * rect
