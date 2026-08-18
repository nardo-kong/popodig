class_name WorldView
extends Node2D

const WorldChunkViewScript = preload("res://src/presentation/world/world_chunk_view.gd")
const WorldChunkScript = preload("res://src/domain/world/world_chunk.gd")

var world_grid
var cell_size := 16
var _chunk_views: Dictionary = {}
var _show_grid := false


func configure(
	grid,
	logical_cell_size: int,
	feature_registry = null,
	signal_config: Dictionary = {}
) -> void:
	_clear_chunk_views()
	world_grid = grid
	cell_size = logical_cell_size
	for chunk in world_grid.get_chunks():
		var chunk_view := WorldChunkViewScript.new()
		chunk_view.name = "Chunk_%d_%d" % [chunk.coord.x, chunk.coord.y]
		add_child(chunk_view)
		chunk_view.configure(world_grid, chunk, cell_size, feature_registry, signal_config)
		_chunk_views[chunk.coord] = chunk_view
	world_grid.chunk_dirtied.connect(_on_chunk_dirtied)


func set_grid_visible(value: bool) -> void:
	_show_grid = value
	for chunk_view: WorldChunkView in _chunk_views.values():
		chunk_view.set_grid_visible(value)


func configure_environment(water_system, seal_system) -> void:
	for chunk_view: WorldChunkView in _chunk_views.values():
		chunk_view.configure_environment(water_system, seal_system)


func is_grid_visible() -> bool:
	return _show_grid


func local_position_to_cell(local_position: Vector2) -> Vector2i:
	return Vector2i(floori(local_position.x / cell_size), floori(local_position.y / cell_size))


func cell_to_world_center(cell_coord: Vector2i) -> Vector2:
	return to_global((Vector2(cell_coord) + Vector2(0.5, 0.5)) * cell_size)


func get_world_rect() -> Rect2:
	if world_grid == null:
		return Rect2()
	return Rect2(global_position, Vector2(world_grid.width, world_grid.height) * cell_size)


func get_chunk_view_count() -> int:
	return _chunk_views.size()


func get_chunk_view(chunk_coord: Vector2i) -> WorldChunkView:
	return _chunk_views.get(chunk_coord)


func _clear_chunk_views() -> void:
	if world_grid != null and world_grid.chunk_dirtied.is_connected(_on_chunk_dirtied):
		world_grid.chunk_dirtied.disconnect(_on_chunk_dirtied)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_chunk_views.clear()


func _on_chunk_dirtied(chunk_coord: Vector2i, dirty_flags: int) -> void:
	var chunk_view: WorldChunkView = _chunk_views.get(chunk_coord)
	if chunk_view == null:
		return
	if (dirty_flags & (WorldChunkScript.DIRTY_TERRAIN | WorldChunkScript.DIRTY_SIGNALS | WorldChunkScript.DIRTY_WATER)) != 0:
		chunk_view.request_terrain_redraw()
	if (dirty_flags & WorldChunkScript.DIRTY_JOBS) != 0:
		chunk_view.request_dig_redraw()
