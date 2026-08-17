class_name DigOverlayChunkView
extends Node2D

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const WorldChunkScript = preload("res://src/domain/world/world_chunk.gd")

var world_grid
var world_chunk
var cell_size := 16
var redraw_request_count := 0
var draw_count := 0


func configure(grid, chunk, logical_cell_size: int) -> void:
	world_grid = grid
	world_chunk = chunk
	cell_size = logical_cell_size
	queue_redraw()


func request_overlay_redraw() -> void:
	redraw_request_count += 1
	queue_redraw()


func _draw() -> void:
	if world_grid == null or world_chunk == null:
		return
	draw_count += 1
	for local_y: int in range(world_chunk.size.y):
		for local_x: int in range(world_chunk.size.x):
			var cell_coord: Vector2i = world_chunk.origin + Vector2i(local_x, local_y)
			var dig_state: int = world_grid.get_dig_state(cell_coord)
			if dig_state == CellDataScript.DigState.NONE:
				continue
			_draw_designation(cell_coord, Vector2(local_x, local_y) * cell_size, dig_state)
	world_chunk.consume_dirty(WorldChunkScript.DIRTY_JOBS)


func _draw_designation(cell_coord: Vector2i, local_position: Vector2, dig_state: int) -> void:
	var inset := Rect2(local_position + Vector2.ONE * 2.0, Vector2.ONE * (cell_size - 4))
	if dig_state == CellDataScript.DigState.QUEUED:
		var queued_color := Color("e5bd5f")
		draw_rect(inset, Color(queued_color, 0.16), true)
		draw_rect(inset, queued_color, false, 1.5)
		return
	var progress: float = world_grid.get_dig_progress(cell_coord)
	var active_color := Color("f19152")
	draw_rect(inset, Color(active_color, 0.18), true)
	draw_rect(inset, active_color, false, 2.0)
	var fill_height := maxf(1.0, inset.size.y * progress)
	draw_rect(Rect2(inset.position + Vector2(0.0, inset.size.y - fill_height), Vector2(inset.size.x, fill_height)), Color(active_color, 0.38), true)
	if progress > 0.2:
		var center := inset.get_center()
		draw_line(center, inset.position + Vector2(inset.size.x, 2.0), Color("ffe0a3"), 1.0)
	if progress > 0.55:
		draw_line(inset.get_center(), inset.position + Vector2(2.0, inset.size.y), Color("ffe0a3"), 1.0)
