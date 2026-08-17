class_name WorldChunkView
extends Node2D

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const WorldChunkScript = preload("res://src/domain/world/world_chunk.gd")

var world_grid
var world_chunk
var cell_size := 16
var show_cell_grid := false
var redraw_request_count := 0
var draw_count := 0


func configure(grid, chunk, logical_cell_size: int) -> void:
	world_grid = grid
	world_chunk = chunk
	cell_size = logical_cell_size
	position = Vector2(world_chunk.origin * cell_size)
	queue_redraw()


func set_grid_visible(value: bool) -> void:
	if show_cell_grid == value:
		return
	show_cell_grid = value
	request_terrain_redraw()


func request_terrain_redraw() -> void:
	redraw_request_count += 1
	queue_redraw()


func _draw() -> void:
	if world_grid == null or world_chunk == null:
		return
	draw_count += 1
	for local_y: int in range(world_chunk.size.y):
		for local_x: int in range(world_chunk.size.x):
			var cell_coord: Vector2i = world_chunk.origin + Vector2i(local_x, local_y)
			var rect := Rect2(Vector2(local_x, local_y) * cell_size, Vector2.ONE * cell_size)
			var color := _cell_color(cell_coord)
			draw_rect(rect, color)
			if world_grid.is_protected(cell_coord):
				draw_rect(rect.grow(-1.0), Color(0.68, 0.66, 0.61, 0.48), false, 1.0)
			if show_cell_grid:
				draw_rect(rect, Color(0.9, 0.82, 0.68, 0.12), false, 1.0)
	world_chunk.consume_dirty(WorldChunkScript.DIRTY_TERRAIN)


func _cell_color(cell_coord: Vector2i) -> Color:
	var material: int = world_grid.get_material(cell_coord)
	if material == CellDataScript.TerrainMaterial.EMPTY:
		return Color("302822")
	if world_grid.is_excavated(cell_coord):
		return Color("171413")
	var base: Color
	match material:
		CellDataScript.TerrainMaterial.SOFT_SOIL:
			base = Color("76543c")
		CellDataScript.TerrainMaterial.DAMP_CLAY:
			base = Color("574a42")
		CellDataScript.TerrainMaterial.LOOSE_SOIL:
			base = Color("907158")
		CellDataScript.TerrainMaterial.STONE:
			base = Color("555351")
		CellDataScript.TerrainMaterial.FOUNDATION:
			base = Color("66615b")
		CellDataScript.TerrainMaterial.ROOT_SOIL:
			base = Color("6d5238")
		_:
			base = Color.MAGENTA
	var variation := float((cell_coord.x * 17 + cell_coord.y * 31) % 5 - 2) * 0.012
	return base.lightened(variation) if variation >= 0.0 else base.darkened(-variation)
