class_name WorldChunkView
extends Node2D

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const WorldChunkScript = preload("res://src/domain/world/world_chunk.gd")
const DigOverlayChunkViewScript = preload("res://src/presentation/world/dig_overlay_chunk_view.gd")
const TerrainAtlasViewScript = preload("res://src/presentation/world/terrain_atlas.gd")

# Overlap that hides filtering seams between adjacent organic tile silhouettes.
const TILE_OVERSHOOT_UNITS := 0.5
# Pass 01 keeps the legacy flat colors as underlay/fallback so presentation
# degrades gracefully if production assets are absent.
const EXTERIOR_BASE_COLOR := Color("302822")
const EXCAVATED_BASE_COLOR := Color("171413")

var world_grid
var world_chunk
var feature_registry
var water_system
var seal_system
var cell_size := 16
var show_cell_grid := false
var redraw_request_count := 0
var draw_count := 0
var dig_overlay_view: DigOverlayChunkView


func configure(
	grid,
	chunk,
	logical_cell_size: int,
	registry = null,
	_signal_config: Dictionary = {}
) -> void:
	world_grid = grid
	world_chunk = chunk
	feature_registry = registry
	cell_size = logical_cell_size
	position = Vector2(world_chunk.origin * cell_size)
	dig_overlay_view = DigOverlayChunkViewScript.new()
	dig_overlay_view.name = "DigOverlay"
	dig_overlay_view.z_index = 5
	add_child(dig_overlay_view)
	dig_overlay_view.configure(world_grid, world_chunk, cell_size)
	queue_redraw()


func set_grid_visible(value: bool) -> void:
	if show_cell_grid == value:
		return
	show_cell_grid = value
	request_terrain_redraw()


func configure_environment(water, seals) -> void:
	water_system = water
	seal_system = seals
	request_terrain_redraw()


func request_terrain_redraw() -> void:
	redraw_request_count += 1
	queue_redraw()


func request_dig_redraw() -> void:
	if dig_overlay_view != null:
		dig_overlay_view.request_overlay_redraw()


func _draw() -> void:
	if world_grid == null or world_chunk == null:
		return
	var atlas := TerrainAtlasViewScript.get_shared()
	draw_count += 1
	# Terrain rendering runs in grouped passes so the canvas batcher can merge
	# consecutive flat rects and consecutive textured quads instead of flushing
	# a state change per cell. Overlay pass restores per-cell visual layering
	# above terrain.
	var texture_cells: Array[Vector2] = []
	var texture_tiles: Array[Dictionary] = []
	for local_y: int in range(world_chunk.size.y):
		for local_x: int in range(world_chunk.size.x):
			var cell_coord: Vector2i = world_chunk.origin + Vector2i(local_x, local_y)
			var rect := Rect2(Vector2(local_x, local_y) * cell_size, Vector2.ONE * cell_size)
			var material: int = get_display_material(cell_coord)
			if material == CellDataScript.TerrainMaterial.EMPTY:
				draw_rect(rect, EXTERIOR_BASE_COLOR)
			elif world_grid.is_excavated(cell_coord):
				draw_rect(rect, EXCAVATED_BASE_COLOR)
				var burrow_tile: Dictionary = atlas.get_burrow_interior_tile(TerrainAtlasViewScript.cell_variant_hash(cell_coord))
				if not burrow_tile.is_empty():
					texture_cells.append(rect.position)
					texture_tiles.append(burrow_tile)
			else:
				var tile: Dictionary = atlas.get_tile_for_material(material, TerrainAtlasViewScript.cell_variant_hash(cell_coord))
				if not tile.is_empty():
					draw_rect(rect, tile.base_color)
					texture_cells.append(rect.position)
					texture_tiles.append(tile)
				else:
					draw_rect(rect, _legacy_material_color(material, cell_coord))
	for quad_index: int in range(texture_cells.size()):
		var tile: Dictionary = texture_tiles[quad_index]
		draw_texture_rect_region(
			tile.texture,
			Rect2(texture_cells[quad_index], Vector2.ONE * cell_size).grow(TILE_OVERSHOOT_UNITS),
			tile.source_rect
		)
	for local_y: int in range(world_chunk.size.y):
		for local_x: int in range(world_chunk.size.x):
			var cell_coord: Vector2i = world_chunk.origin + Vector2i(local_x, local_y)
			var rect := Rect2(Vector2(local_x, local_y) * cell_size, Vector2.ONE * cell_size)
			_draw_root_information(cell_coord, rect)
			_draw_water_information(cell_coord, rect)
			_draw_seal_information(cell_coord, rect)
			if world_grid.is_protected(cell_coord):
				draw_rect(rect.grow(-1.0), Color(0.68, 0.66, 0.61, 0.48), false, 1.0)
			if show_cell_grid:
				draw_rect(rect, Color(0.9, 0.82, 0.68, 0.12), false, 1.0)
	world_chunk.consume_dirty(WorldChunkScript.DIRTY_TERRAIN | WorldChunkScript.DIRTY_SIGNALS | WorldChunkScript.DIRTY_WATER)


func _legacy_material_color(material: int, cell_coord: Vector2i) -> Color:
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


func get_display_material(cell_coord: Vector2i) -> int:
	var material: int = int(world_grid.get_material(cell_coord))
	var feature = _feature_at(cell_coord)
	if feature != null and feature.hidden and feature.type_id in ["root_cluster", "water_reservoir"]:
		return _material_for_stratum(world_grid.get_stratum_id(cell_coord))
	return material


func _draw_root_information(cell_coord: Vector2i, rect: Rect2) -> void:
	if world_grid.is_exterior(cell_coord):
		return
	var feature = _feature_at(cell_coord)
	if feature != null and feature.type_id == "root_cluster":
		if feature.hidden:
			# Hidden feature cells deliberately share their stratum color and draw no
			# cell-perfect mark. Clues live in the surrounding field instead.
			return
		_draw_revealed_root(rect, cell_coord)
		return
	if world_grid.is_traversable(cell_coord):
		return
	var value: int = int(world_grid.get_root_signal(cell_coord))
	var thresholds: Array = world_grid.metadata.get("signal_thresholds", {}).get("root_density", [1, 3, 5])
	if value < int(thresholds[0]):
		return
	var band := 1
	if value >= int(thresholds[2]):
		band = 3
	elif value >= int(thresholds[1]):
		band = 2
	var cue_hash := absi(cell_coord.x * 92821 + cell_coord.y * 68917)
	if (band == 1 and cue_hash % 4 != 0) or (band == 2 and cue_hash % 2 != 0):
		return
	var center := rect.get_center()
	var flip := -1.0 if ((cell_coord.x * 13 + cell_coord.y * 7) & 1) == 0 else 1.0
	var cue_color := Color("a99362", 0.38 + band * 0.10)
	draw_line(center + Vector2(-5.0, 4.0 * flip), center + Vector2(4.0, -3.0 * flip), cue_color, 1.0)
	if band >= 2:
		draw_line(center + Vector2(-1.0, 0.0), center + Vector2(5.0, 4.0 * flip), cue_color, 1.0)
	if band >= 3:
		draw_circle(center + Vector2(-4.0, -3.0 * flip), 1.2, cue_color)


func _draw_revealed_root(rect: Rect2, cell_coord: Vector2i) -> void:
	var center := rect.get_center()
	var bend := 3.0 if ((cell_coord.x + cell_coord.y) & 1) == 0 else -3.0
	var root_color := Color("a47a45", 0.92)
	draw_line(center + Vector2(-7.0, bend), center + Vector2(7.0, -bend), root_color, 3.0)
	draw_line(center, center + Vector2(5.0, bend), Color("c49a5d", 0.88), 1.5)


func _draw_water_information(cell_coord: Vector2i, rect: Rect2) -> void:
	if world_grid.is_exterior(cell_coord):
		return
	var units: int = int(world_grid.get_water_units(cell_coord))
	if units > 0:
		var capacity := 4 if water_system == null else maxi(1, int(water_system.get_cell_capacity()))
		var ratio := clampf(float(units) / float(capacity), 0.0, 1.0)
		var height := maxf(3.0, rect.size.y * ratio)
		var water_rect := Rect2(Vector2(rect.position.x, rect.end.y - height), Vector2(rect.size.x, height))
		draw_rect(water_rect.grow(-1.0), Color("3e91ad", 0.62 + ratio * 0.22), true)
		draw_line(Vector2(rect.position.x + 2.0, water_rect.position.y + 1.0), Vector2(rect.end.x - 2.0, water_rect.position.y + 1.0), Color("8ed2d6", 0.78), 1.0)
		return
	var feature = _feature_at(cell_coord)
	if feature != null and feature.type_id == "water_reservoir" and not feature.hidden:
		var center := rect.get_center()
		draw_circle(center, 3.0, Color("5195a5", 0.72))
		draw_line(center + Vector2(-5.0, 3.0), center + Vector2(5.0, -2.0), Color("77bdc3", 0.72), 1.5)
		return
	if world_grid.is_excavated(cell_coord):
		return
	var value: int = int(world_grid.get_moisture_signal(cell_coord))
	var thresholds: Array = world_grid.metadata.get("signal_thresholds", {}).get("moisture", [1, 3, 5])
	if value < int(thresholds[0]):
		return
	var band := 1
	if value >= int(thresholds[2]):
		band = 3
	elif value >= int(thresholds[1]):
		band = 2
	var cue_hash := absi(cell_coord.x * 51787 + cell_coord.y * 93139)
	if (band == 1 and cue_hash % 4 != 0) or (band == 2 and cue_hash % 2 != 0):
		return
	var center := rect.get_center()
	draw_circle(center + Vector2(float((cue_hash % 5) - 2), 4.0), 1.0 + band * 0.45, Color("73a6a5", 0.34 + band * 0.12))
	if band >= 3:
		draw_line(center + Vector2(-5.0, 5.0), center + Vector2(5.0, 4.0), Color("7bb1ad", 0.62), 1.0)


func _draw_seal_information(cell_coord: Vector2i, rect: Rect2) -> void:
	if world_grid.is_sealed(cell_coord):
		draw_rect(rect.grow(-1.0), Color("44545a", 0.96), true)
		draw_line(rect.position + Vector2(2.0, 5.0), Vector2(rect.end.x - 2.0, rect.position.y + 5.0), Color("83949a"), 1.0)
		draw_line(rect.position + Vector2(2.0, 10.0), Vector2(rect.end.x - 2.0, rect.position.y + 10.0), Color("83949a"), 1.0)
		draw_line(rect.position + Vector2(6.0, 1.0), rect.position + Vector2(6.0, 15.0), Color("687a80"), 1.0)
		return
	if seal_system != null and seal_system.has_request(cell_coord):
		draw_rect(rect.grow(-2.0), Color("70c5cf", 0.24), true)
		draw_rect(rect.grow(-2.0), Color("87d9dd", 0.88), false, 1.5)


func _feature_at(cell_coord: Vector2i):
	if feature_registry == null:
		return null
	var feature_id: int = int(world_grid.get_feature_id(cell_coord))
	return null if feature_id < 0 else feature_registry.get_feature(feature_id)


func _material_for_stratum(stratum_id: int) -> int:
	match stratum_id:
		0:
			return CellDataScript.TerrainMaterial.SOFT_SOIL
		1:
			return CellDataScript.TerrainMaterial.DAMP_CLAY
		2, 3:
			return CellDataScript.TerrainMaterial.STONE
		_:
			return CellDataScript.TerrainMaterial.SOFT_SOIL
