extends Node2D

# Visual Test Room — Pass 01 art integration comparison sheet.
# Development/QA aid only; never shipped as gameplay content.
# Renders every accepted production material next to the current engineering
# placeholders (mouse + water) so palette/density coherence can be judged.

const CELL := 16
const COLUMN_PITCH := 44
const VIEW_SCALE := 2.0
const TerrainAtlasViewScript = preload("res://src/presentation/world/terrain_atlas.gd")

const LABEL_COLOR := Color("e8dcc8")
const BACKGROUND := Color("241c16")


func _draw() -> void:
	draw_rect(Rect2(Vector2(-40, -60), Vector2(620, 330)), BACKGROUND)
	draw_set_transform(Vector2(30, 90), 0.0, Vector2.ONE * VIEW_SCALE)
	var font := ThemeDB.fallback_font
	var atlas := TerrainAtlasViewScript.get_shared()
	if not atlas.is_available():
		draw_string(font, Vector2.ZERO, "TERRAIN ATLAS UNAVAILABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.RED)
		return
	var families: Array = [
		["soft_soil", "SOFT"],
		["damp_clay", "CLAY"],
		["loose_soil", "LOOSE"],
		["stone", "STONE"],
		["burrow_interior", "BURROW"],
	]
	for index: int in range(families.size()):
		var tile := atlas.get_tile_for_key(families[index][0], index * 7)
		var origin := Vector2(index * COLUMN_PITCH, 0)
		if index == 4:
			draw_rect(Rect2(origin, Vector2.ONE * CELL), EXCAVATED_BACKGROUND)
		if not tile.is_empty():
			draw_texture_rect_region(tile.texture, Rect2(origin, Vector2.ONE * CELL), tile.source_rect)
		else:
			draw_rect(Rect2(origin, Vector2.ONE * CELL), Color.MAGENTA)
		draw_string(font, origin + Vector2(-6.0, CELL + 14.0), families[index][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LABEL_COLOR)

	# Root signal placeholder cue ladder (current procedural cues).
	draw_string(font, Vector2(0, 64.0), "ROOT CUES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL_COLOR)
	for band: int in range(1, 4):
		var center := Vector2((band - 1) * (CELL + 22.0) + CELL * 0.5, 92.0)
		_draw_root_cue(center, band)

	# Current mouse placeholder at world scale.
	draw_string(font, Vector2(140.0, 64.0), "MOUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL_COLOR)
	_draw_mouse_placeholder(Vector2(152.0, 92.0))

	# Current water placeholder swatch on top of damp clay for contrast judgement.
	var water_tile := atlas.get_tile_for_key("damp_clay", 3)
	draw_string(font, Vector2(260.0, 64.0), "WATER ON CLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL_COLOR)
	var water_origin := Vector2(260.0, 76.0)
	if not water_tile.is_empty():
		draw_texture_rect_region(water_tile.texture, Rect2(water_origin, Vector2(96.0, 32.0)), water_tile.source_rect)
	_draw_water_placeholder(Rect2(water_origin + Vector2(2.0, 18.0), Vector2(92.0, 12.0)))

	draw_string(font, Vector2(0, 150.0), "PASS 01 · TERRAIN ONLY — Root / water / stability / mouse production art pending.", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("b8a488"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


const EXCAVATED_BACKGROUND := Color("171413")


func _draw_root_cue(center: Vector2, band: int) -> void:
	var flip := 1.0 if band % 2 == 0 else -1.0
	var cue_color := Color("a99362", 0.38 + band * 0.10)
	draw_line(center + Vector2(-5.0, 4.0 * flip), center + Vector2(4.0, -3.0 * flip), cue_color, 1.0)
	if band >= 2:
		draw_line(center + Vector2(-1.0, 0.0), center + Vector2(5.0, 4.0 * flip), cue_color, 1.0)
	if band >= 3:
		draw_circle(center + Vector2(-4.0, -3.0 * flip), 1.2, cue_color)


func _draw_mouse_placeholder(at: Vector2) -> void:
	draw_circle(at + Vector2(-4.0, -5.0), 3.5, Color("d9aa9a"))
	draw_circle(at + Vector2(4.0, -5.0), 3.5, Color("d9aa9a"))
	draw_circle(at, 7.0, Color("4a352b"))
	draw_circle(at + Vector2(0.0, -0.5), 5.8, Color("c7a27c"))
	draw_circle(at + Vector2(2.2, -1.5), 0.9, Color("1e1714"))


func _draw_water_placeholder(rect: Rect2) -> void:
	draw_rect(rect, Color("3e91ad", 0.72), true)
	draw_line(Vector2(rect.position.x + 2.0, rect.position.y + 1.0), Vector2(rect.end.x - 2.0, rect.position.y + 1.0), Color("8ed2d6", 0.78), 1.0)
