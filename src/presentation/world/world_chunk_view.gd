class_name WorldChunkView
extends Node2D

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const WorldChunkScript = preload("res://src/domain/world/world_chunk.gd")
const DigOverlayChunkViewScript = preload("res://src/presentation/world/dig_overlay_chunk_view.gd")
const TerrainAtlasViewScript = preload("res://src/presentation/world/terrain_atlas.gd")
const TerrainEdgeRulesScript = preload("res://src/presentation/world/terrain_edge_rules.gd")

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
var stability_system
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


func configure_environment(water, seals, stability = null) -> void:
	water_system = water
	seal_system = seals
	stability_system = stability
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
	# Terrain-transition pass (docs/art/12 §5): edge bands + notch silhouettes
	# hide the straight tile grid at material boundaries and excavated lips.
	_draw_terrain_edges()
	for local_y: int in range(world_chunk.size.y):
		for local_x: int in range(world_chunk.size.x):
			var cell_coord: Vector2i = world_chunk.origin + Vector2i(local_x, local_y)
			var rect := Rect2(Vector2(local_x, local_y) * cell_size, Vector2.ONE * cell_size)
			if world_grid.is_excavated(cell_coord):
				_draw_excavated_shading(cell_coord, rect)
				_draw_landmark_dressing(cell_coord, rect)
			_draw_root_information(cell_coord, rect)
			_draw_water_information(cell_coord, rect)
			_draw_seal_information(cell_coord, rect)
			_draw_stability_information(cell_coord, rect)
			if world_grid.is_protected(cell_coord):
				draw_rect(rect.grow(-1.0), Color(0.68, 0.66, 0.61, 0.48), false, 1.0)
			if show_cell_grid:
				draw_rect(rect, Color(0.9, 0.82, 0.68, 0.12), false, 1.0)
	world_chunk.consume_dirty(WorldChunkScript.DIRTY_TERRAIN | WorldChunkScript.DIRTY_SIGNALS | WorldChunkScript.DIRTY_WATER | WorldChunkScript.DIRTY_STABILITY)


## Phase 15 spatial storytelling: revealed old-burrow cells carry faint
## nest-trace relics, and warm-chamber cells carry a soft warm tint (art
## bible §4 — decoration must never compete with signal cues).
func _draw_landmark_dressing(cell_coord: Vector2i, rect: Rect2) -> void:
	var feature = _feature_at(cell_coord)
	if feature == null or bool(feature.hidden):
		return
	var cell_hash := absi(cell_coord.x * 15487 + cell_coord.y * 3313)
	match String(feature.type_id):
		"old_burrow":
			var relic := cell_hash % 3
			var center := rect.get_center()
			if relic == 0:
				# Old nest: faded bedding ring.
				draw_arc(center + Vector2(0.0, 2.0), 3.4, 0.0, TAU, 12, Color("a08b6a", 0.3), 1.2)
				draw_circle(center + Vector2(0.0, 2.0), 2.0, Color("6b5a42", 0.28))
			elif relic == 1:
				# Scattered hoard debris.
				for index: int in range(3):
					var offset := Vector2(float((cell_hash >> (index * 3)) % 9) - 4.0, float((cell_hash >> (index * 4 + 2)) % 7) - 3.0)
					draw_circle(center + offset, 0.9, Color("8f7a58", 0.34))
			else:
				# Twig remains from the old structure.
				var flip := -1.0 if (cell_hash & 1) == 0 else 1.0
				draw_line(center + Vector2(-3.5, 2.5), center + Vector2(2.5 * flip, -1.5), Color("7a674c", 0.32), 0.9)
				draw_line(center + Vector2(0.5, 3.5), center + Vector2(4.0 * flip, 1.0), Color("7a674c", 0.26), 0.8)
		"warm_chamber":
			draw_rect(rect.grow(-0.5), Color(0.86, 0.62, 0.36, 0.10), true)
			if cell_hash % 4 == 0:
				draw_circle(rect.get_center(), 1.2, Color(0.94, 0.72, 0.42, 0.16))


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


## Edge-band pass. Only boundary cells draw anything, so the cost stays
## proportional to the terrain perimeter rather than the cell count.
func _draw_terrain_edges() -> void:
	var atlas := TerrainAtlasViewScript.get_shared()
	for local_y: int in range(world_chunk.size.y):
		for local_x: int in range(world_chunk.size.x):
			var cell_coord: Vector2i = world_chunk.origin + Vector2i(local_x, local_y)
			if world_grid.is_exterior(cell_coord) or world_grid.is_excavated(cell_coord):
				continue
			var rect := Rect2(Vector2(local_x, local_y) * cell_size, Vector2.ONE * cell_size)
			var display_material := get_display_material(cell_coord)
			var faces := TerrainEdgeRulesScript.classify_faces(
				cell_coord,
				true,
				get_display_material,
				world_grid.is_excavated,
				world_grid.is_exterior
			)
			if faces.is_empty():
				continue
			var tile: Dictionary = atlas.get_tile_for_material(display_material, TerrainAtlasViewScript.cell_variant_hash(cell_coord))
			var edge_base: Color = tile.get("base_color", _legacy_material_color(display_material, cell_coord))
			for band: Dictionary in TerrainEdgeRulesScript.edge_bands(rect, faces, cell_size):
				if bool(band.gradient):
					var band_rect: Rect2 = band.rect
					var rim := edge_base.darkened(0.45)
					var inner := edge_base.darkened(0.12)
					var points: PackedVector2Array
					var colors: PackedColorArray
					match String(band.face):
						"top":
							points = PackedVector2Array([band_rect.position, Vector2(band_rect.end.x, band_rect.position.y), Vector2(band_rect.end.x, band_rect.end.y), Vector2(band_rect.position.x, band_rect.end.y)])
							colors = PackedColorArray([rim, rim, inner, inner])
						"bottom":
							points = PackedVector2Array([Vector2(band_rect.position.x, band_rect.end.y), band_rect.end, Vector2(band_rect.end.x, band_rect.position.y), Vector2(band_rect.position.x, band_rect.position.y)])
							colors = PackedColorArray([rim, rim, inner, inner])
						"left":
							points = PackedVector2Array([band_rect.position, Vector2(band_rect.position.x, band_rect.end.y), Vector2(band_rect.end.x, band_rect.end.y), Vector2(band_rect.end.x, band_rect.position.y)])
							colors = PackedColorArray([rim, rim, inner, inner])
						"right":
							points = PackedVector2Array([Vector2(band_rect.end.x, band_rect.position.y), Vector2(band_rect.end.x, band_rect.end.y), Vector2(band_rect.position.x, band_rect.end.y), band_rect.position])
							colors = PackedColorArray([rim, rim, inner, inner])
					draw_polygon(points, colors)
				else:
					draw_rect(band.rect, Color(edge_base.darkened(0.22), 0.42), true)
			var cell_hash := TerrainAtlasViewScript.cell_variant_hash(cell_coord)
			for face_name: String in faces:
				if String(faces[face_name]) != "exposed":
					continue
				for notch: PackedVector2Array in TerrainEdgeRulesScript.exposed_face_notches(rect, face_name, cell_hash):
					draw_colored_polygon(notch, Color(edge_base.darkened(0.3), 0.85))


## Excavated interior ambient shading: soft ceiling shadow under solid rock and
## faint side-wall falloff, so tunnels read as carved voids (art bible §5).
func _draw_excavated_shading(cell_coord: Vector2i, rect: Rect2) -> void:
	var above := cell_coord + Vector2i.UP
	if not world_grid.is_exterior(above) and not world_grid.is_excavated(above):
		var shadow := Rect2(rect.position, Vector2(rect.size.x, 5.0))
		draw_polygon(
			PackedVector2Array([shadow.position, Vector2(shadow.end.x, shadow.position.y), Vector2(shadow.end.x, shadow.end.y), Vector2(shadow.position.x, shadow.end.y)]),
			PackedColorArray([Color(0.0, 0.0, 0.0, 0.38), Color(0.0, 0.0, 0.0, 0.38), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)])
		)
	for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor := cell_coord + side
		if not world_grid.is_exterior(neighbor) and not world_grid.is_excavated(neighbor):
			var wall_rect := Rect2(rect.position, Vector2(3.0, rect.size.y)) if side == Vector2i.LEFT else Rect2(Vector2(rect.end.x - 3.0, rect.position.y), Vector2(3.0, rect.size.y))
			draw_rect(wall_rect, Color(0.0, 0.0, 0.0, 0.14), true)


func _draw_root_information(cell_coord: Vector2i, rect: Rect2) -> void:
	if world_grid.is_exterior(cell_coord):
		return
	var feature = _feature_at(cell_coord)
	if feature != null and feature.type_id == "root_cluster":
		if feature.hidden:
			# Hidden feature cells deliberately share their stratum color and draw no
			# cell-perfect mark. Clues live in the surrounding field instead.
			return
		_draw_revealed_root(rect, cell_coord, int(world_grid.get_feature_id(cell_coord)))
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
	# Fine curved threads at weak signal; denser thicker strands near the
	# feature, with small nutrient nodules at band 3 (art bible §9 Root).
	_draw_strand(center + Vector2(-5.0, 4.0 * flip), center + Vector2(4.0, -3.0 * flip), cue_color, 0.9 + band * 0.25, 1.2)
	if band >= 2:
		_draw_strand(center + Vector2(-1.0, 0.0), center + Vector2(5.0, 4.0 * flip), cue_color, 0.9 + band * 0.25, -1.0)
	if band >= 3:
		var nodule := center + Vector2(-4.0, -3.0 * flip)
		draw_circle(nodule, 1.6, Color("b7a06a", 0.72))
		draw_circle(nodule, 0.8, Color("8a7443", 0.8))


## Tapered organic strand: three segments with shrinking width and a
## perpendicular sway so lines read as living roots rather than UI strokes.
func _draw_strand(from: Vector2, to: Vector2, color: Color, width: float, sway: float) -> void:
	var mid_a := from.lerp(to, 0.33) + Vector2(-sway, sway * 0.4)
	var mid_b := from.lerp(to, 0.66) + Vector2(sway * 0.6, -sway * 0.3)
	draw_line(from, mid_a, color, width)
	draw_line(mid_a, mid_b, color, width * 0.72)
	draw_line(mid_b, to, color, width * 0.45)


func _draw_revealed_root(rect: Rect2, cell_coord: Vector2i, feature_id: int) -> void:
	var center := rect.get_center()
	var half := float(cell_size) * 0.5
	var feature_hash := absi(cell_coord.x * 92821 + cell_coord.y * 68917)
	# Major root network: strands connect across the whole cluster so the
	# revealed feature reads as one organism instead of per-cell decorations.
	var connected_any := false
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor := cell_coord + direction
		if world_grid.is_exterior(neighbor) or int(world_grid.get_feature_id(neighbor)) != feature_id:
			continue
		connected_any = true
		var tip := center + Vector2(direction) * half
		var sway := 1.6 if (feature_hash & 1) == 0 else -1.6
		_draw_strand(center, tip, Color("5d452e", 0.65), 5.0, sway)
		_draw_strand(center, tip, Color("a47a45", 0.95), 3.2, sway)
		_draw_strand(center, tip, Color("c49a5d", 0.7), 1.1, sway * 0.5)
	if not connected_any:
		draw_circle(center, 2.4, Color("a47a45", 0.95))
	# One short feeder rootlet per cell keeps texture without competing with
	# gameplay overlays above.
	if (feature_hash % 3) != 0:
		var branch_angle := float(feature_hash % 4) * (PI * 0.5) + 0.6
		var branch_tip := center + Vector2(cos(branch_angle), sin(branch_angle)) * 5.0
		_draw_strand(center, branch_tip, Color("8f6c3f", 0.6), 1.0, 0.8)


func _draw_water_information(cell_coord: Vector2i, rect: Rect2) -> void:
	if world_grid.is_exterior(cell_coord):
		return
	var units: int = int(world_grid.get_water_units(cell_coord))
	if units > 0:
		_draw_water_body(cell_coord, rect, units)
		return
	var feature = _feature_at(cell_coord)
	if feature != null and feature.type_id == "water_reservoir" and not feature.hidden:
		_draw_reservoir_pool(cell_coord, rect)
		return
	if world_grid.is_excavated(cell_coord):
		return
	# Wet-soil halo: solid cells touching standing water or a revealed
	# reservoir read darker/damp (art bible §9 moisture, §12 water halo).
	if _touches_visible_water(cell_coord):
		draw_rect(rect.grow(-0.5), Color(0.13, 0.16, 0.15, 0.3), true)
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
	# Darker/smoother damp patch + tiny specular droplets at strong levels;
	# deliberately not a neon glow (art bible §9).
	draw_circle(center + Vector2(float((cue_hash % 5) - 2), 4.0), 1.6 + band * 0.7, Color("4c443c", 0.30 + band * 0.08))
	draw_circle(center + Vector2(float((cue_hash % 5) - 2), 4.0), 1.0 + band * 0.45, Color("73a6a5", 0.34 + band * 0.12))
	if band >= 3:
		draw_line(center + Vector2(-5.0, 5.0), center + Vector2(5.0, 4.0), Color("7bb1ad", 0.62), 1.0)


func _draw_water_body(cell_coord: Vector2i, rect: Rect2, units: int) -> void:
	var capacity := 4 if water_system == null else maxi(1, int(water_system.get_cell_capacity()))
	var ratio := clampf(float(units) / float(capacity), 0.0, 1.0)
	var height := maxf(3.0, rect.size.y * ratio)
	var water_rect := Rect2(Vector2(rect.position.x, rect.end.y - height), Vector2(rect.size.x, height)).grow(-1.0)
	# Depth gradient: lighter surface, darker pool bottom.
	draw_polygon(
		PackedVector2Array([water_rect.position, Vector2(water_rect.end.x, water_rect.position.y), water_rect.end, Vector2(water_rect.position.x, water_rect.end.y)]),
		PackedColorArray([Color("5fa9bd", 0.72), Color("5fa9bd", 0.72), Color("2e6473", 0.82), Color("2e6473", 0.82)])
	)
	# Meniscus highlight along the surface; the animated shimmer lives in
	# WaterFxView so the static pass stays dirty-driven.
	draw_line(Vector2(water_rect.position.x, water_rect.position.y + 0.5), Vector2(water_rect.end.x, water_rect.position.y + 0.5), Color("9fdde0", 0.85), 1.0)


## Revealed reservoir interior: one continuous contained pool across the whole
## cluster (art bible §12 "calm pool"). Cells fill edge-to-edge so neighbors
## merge; rims and the bright surface line appear only on boundary faces.
func _draw_reservoir_pool(cell_coord: Vector2i, rect: Rect2) -> void:
	# Full-cell flat fill: per-cell gradients would band across multi-row
	# pools, so the calm pool reads as one flat body; structure comes from the
	# boundary rims and the top meniscus line.
	draw_rect(rect, Color("4d9cb2", 0.8), true)
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor := cell_coord + direction
		var neighbor_feature = _feature_at(neighbor)
		var same_pool: bool = neighbor_feature != null and neighbor_feature.type_id == "water_reservoir" and not neighbor_feature.hidden
		if same_pool:
			continue
		# Boundary face: bright meniscus where the pool meets air above, dark
		# basin rim against soil on the other three faces.
		var rim_color := Color("9fdde0", 0.85) if direction == Vector2i.UP else Color("27505c", 0.8)
		var half := rect.size.x * 0.5
		var center := rect.get_center()
		match direction:
			Vector2i.UP:
				draw_line(Vector2(center.x - half + 1.5, rect.position.y + 2.0), Vector2(center.x + half - 1.5, rect.position.y + 2.0), rim_color, 1.2)
			Vector2i.DOWN:
				draw_line(Vector2(center.x - half + 1.5, rect.end.y - 2.0), Vector2(center.x + half - 1.5, rect.end.y - 2.0), rim_color, 1.2)
			Vector2i.LEFT:
				draw_line(Vector2(rect.position.x + 2.0, center.y - half + 1.5), Vector2(rect.position.x + 2.0, center.y + half - 1.5), rim_color, 1.2)
			Vector2i.RIGHT:
				draw_line(Vector2(rect.end.x - 2.0, center.y - half + 1.5), Vector2(rect.end.x - 2.0, center.y + half - 1.5), rim_color, 1.2)


func _touches_visible_water(cell_coord: Vector2i) -> bool:
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor := cell_coord + direction
		if int(world_grid.get_water_units(neighbor)) > 0:
			return true
		var feature = _feature_at(neighbor)
		if feature != null and feature.type_id == "water_reservoir" and not feature.hidden:
			return true
	return false


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


func _draw_stability_information(cell_coord: Vector2i, rect: Rect2) -> void:
	if world_grid.is_exterior(cell_coord):
		return
	# Collapsed rubble keeps the resolved area legible (docs/systems/09 spec §8):
	# rough speckle plus a few angular chunks over the refilled solid cells,
	# distinct from natural terrain and from live warning states.
	if world_grid.is_rubble(cell_coord) and not world_grid.is_traversable(cell_coord):
		var rubble_hash := absi(cell_coord.x * 2246822519 + cell_coord.y * 3266489917)
		for speck: int in range(6):
			var sx := float((rubble_hash >> (speck * 4)) % 12) + 2.0
			var sy := float((rubble_hash >> (speck * 5 + 3)) % 11) + 2.0
			var radius := 0.8 + float((rubble_hash >> (speck * 2)) % 3) * 0.3
			var tone := Color("9c8568", 0.72) if (rubble_hash >> speck) & 1 == 0 else Color("453424", 0.72)
			draw_circle(rect.position + Vector2(sx, sy), radius, tone)
		for chunk: int in range(2):
			var cx := float((rubble_hash >> (chunk * 7)) % 10) + 3.0
			var cy := float((rubble_hash >> (chunk * 6 + 2)) % 9) + 4.0
			var half_w := 1.6 + float((rubble_hash >> (chunk + 3)) % 3) * 0.5
			var chunk_tone := Color("7a674c", 0.85) if chunk == 0 else Color("584734", 0.85)
			draw_colored_polygon(PackedVector2Array([
				rect.position + Vector2(cx - half_w, cy + 0.8),
				rect.position + Vector2(cx, cy - 1.2),
				rect.position + Vector2(cx + half_w, cy + 0.4),
				rect.position + Vector2(cx - 0.4, cy + 1.4),
			]), chunk_tone)
		draw_rect(rect.grow(-1.0), Color("5d4934", 0.5), false, 1.0)
	# Reinforced roof support: timber frame prop (beam + posts) with shadow,
	# replacing the Phase 8 placeholder lines.
	if world_grid.is_reinforced(cell_coord):
		var beam := Rect2(rect.position + Vector2(1.0, 2.0), Vector2(rect.size.x - 2.0, 3.0))
		draw_rect(beam.grow(0.5), Color(0.0, 0.0, 0.0, 0.25), true)
		draw_rect(beam, Color("c9a86a"), true)
		draw_rect(beam, Color("6d5433"), false, 1.0)
		draw_line(beam.position + Vector2(1.0, 1.5), Vector2(beam.end.x - 1.0, beam.position.y + 1.5), Color("e0c28d", 0.7), 0.8)
		for post_x: float in [3.0, rect.size.x - 5.0]:
			var post := Rect2(rect.position + Vector2(post_x, beam.end.y), Vector2(2.0, rect.size.y - beam.end.y - 2.0))
			draw_rect(post, Color("b08e56"), true)
			draw_rect(post, Color("6d5433"), false, 0.8)
		draw_circle(beam.position + Vector2(2.5, 1.5), 0.6, Color("4a352b"))
		draw_circle(Vector2(beam.end.x - 2.5, beam.position.y + 1.5), 0.6, Color("4a352b"))
	# Reinforce request outline on open cells.
	if stability_system != null and stability_system.has_request(cell_coord):
		draw_rect(rect.grow(-2.0), Color("e5c06a", 0.22), true)
		draw_rect(rect.grow(-2.0), Color("f2d488", 0.9), false, 1.5)
	var value: int = int(world_grid.get_stability_base(cell_coord))
	if value > 0 and world_grid.is_traversable(cell_coord):
		var thresholds: Array = world_grid.metadata.get("signal_thresholds", {}).get("instability", [35, 60, 80])
		if value >= int(thresholds[2]):
			var center := rect.get_center()
			draw_colored_polygon(PackedVector2Array([
				Vector2(center.x, center.y - 5.0),
				Vector2(center.x + 5.0, center.y + 4.0),
				Vector2(center.x - 5.0, center.y + 4.0),
			]), Color("ef7c54", 0.92))
			draw_rect(Rect2(center + Vector2(-0.75, -2.0), Vector2(1.5, 3.5)), Color("2b1d16"), true)
			draw_rect(Rect2(center + Vector2(-0.75, 2.2), Vector2(1.5, 1.5)), Color("2b1d16"), true)
		elif value >= int(thresholds[1]):
			# Branching cracks: a main fissure plus one hash-derived offshoot,
			# wide enough to read at far zoom but still terrain-colored.
			var crack_hash := absi(cell_coord.x * 37039 + cell_coord.y * 65537)
			var crack_origin := rect.position + Vector2(float(crack_hash % 7) + 4.0, 2.0)
			var sway := float((crack_hash >> 3) % 5) - 2.0
			var mid := crack_origin + Vector2(sway, 5.5)
			var tip := mid + Vector2(-sway * 0.6, 5.5)
			draw_line(crack_origin, mid, Color("d8c49a", 0.72), 1.6)
			draw_line(mid, tip, Color("d8c49a", 0.6), 1.0)
			draw_line(mid, mid + Vector2(2.5 + sway, 2.5), Color("d8c49a", 0.5), 0.8)
		elif value >= int(thresholds[0]):
			var crumb_hash := absi(cell_coord.x * 15487 + cell_coord.y * 3313)
			for crumb: int in range(3):
				draw_circle(
					rect.position + Vector2(float((crumb_hash >> (crumb * 2)) % 12) + 2.0, float((crumb_hash >> (crumb * 3)) % 10) + 3.0),
					0.9,
					Color("c9b28a", 0.42)
				)


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
