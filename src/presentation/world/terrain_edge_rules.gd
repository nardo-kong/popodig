class_name TerrainEdgeRules
extends RefCounted

# Phase 11 terrain-transition rules (docs/art/12_ART_BIBLE.md §5): pure face
# classification + band geometry for the chunk-view edge pass, kept free of any
# Node2D state so tests can drive them with stub lookups.
#
# Face kinds:
#   "exposed"  — solid cell faces open space (tunnel/surface); gets a darkened
#                rim band plus a light lip so cut edges read as excavated.
#   "material" — solid cell meets a different terrain material; gets a soft
#                blend band that hides the straight tile seam.
#   ""         — same material continuing; no treatment.

const FACE_DIRECTIONS: Dictionary = {
	"top": Vector2i.UP,
	"bottom": Vector2i.DOWN,
	"left": Vector2i.LEFT,
	"right": Vector2i.RIGHT,
}


## material_at/excavated_at/exterior_at take a Vector2i and answer for it; the
## probed cell itself is described by is_solid_here (already display-resolved).
static func classify_faces(
	cell: Vector2i,
	is_solid_here: bool,
	material_at: Callable,
	excavated_at: Callable,
	exterior_at: Callable
) -> Dictionary:
	var faces: Dictionary = {}
	if not is_solid_here:
		return faces
	var here_material: int = int(material_at.call(cell))
	for face_name: String in FACE_DIRECTIONS:
		var neighbor: Vector2i = cell + FACE_DIRECTIONS[face_name]
		if bool(exterior_at.call(neighbor)):
			faces[face_name] = "exposed"
			continue
		if bool(excavated_at.call(neighbor)):
			faces[face_name] = "exposed"
			continue
		if int(material_at.call(neighbor)) != here_material:
			faces[face_name] = "material"
	return faces


## Band geometry in local chunk pixels. rect is the solid cell's rect; bands sit
## inside the cell so they never overlap the neighbor's own treatment.
## exposed → 3px gradient band (dark rim toward the opening);
## material → 2px flat band at the shared seam, slightly darkened.
static func edge_bands(rect: Rect2, faces: Dictionary, cell_size: int) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	var unit := float(cell_size)
	for face_name: String in ["top", "bottom", "left", "right"]:
		var kind: String = String(faces.get(face_name, ""))
		if kind.is_empty():
			continue
		var depth := 3.0 if kind == "exposed" else 2.0
		var band_rect: Rect2
		match face_name:
			"top":
				band_rect = Rect2(rect.position, Vector2(rect.size.x, depth))
			"bottom":
				band_rect = Rect2(Vector2(rect.position.x, rect.end.y - depth), Vector2(rect.size.x, depth))
			"left":
				band_rect = Rect2(rect.position, Vector2(depth, rect.size.y))
			"right":
				band_rect = Rect2(Vector2(rect.end.x - depth, rect.position.y), Vector2(depth, rect.size.y))
		bands.append({
			"face": face_name,
			"kind": kind,
			"rect": band_rect,
			"gradient": kind == "exposed",
			"unit": unit,
		})
	return bands


## Deterministic notch mask for exposed faces: which irregular dirt nubs to draw
## so straight excavated lips break the grid without reaching into neighbors.
## Returns local polygon point lists (relative to the cell rect) per face.
static func exposed_face_notches(rect: Rect2, face: String, cell_hash: int) -> Array[PackedVector2Array]:
	var notches: Array[PackedVector2Array] = []
	var count := int(cell_hash % 3) # 0..2 nubs per face
	for index: int in range(count):
		var lane := float((cell_hash >> (index * 3 + 1)) % 12) + 2.0
		var reach := 1.5 + float((cell_hash >> (index * 2)) % 3) * 0.6
		var width := 1.6 + float((cell_hash >> (index + 5)) % 3) * 0.5
		var points := PackedVector2Array()
		match face:
			"top":
				var x := rect.position.x + lane
				points.push_back(Vector2(x - width, rect.position.y))
				points.push_back(Vector2(x, rect.position.y + reach))
				points.push_back(Vector2(x + width, rect.position.y))
			"bottom":
				var x := rect.position.x + lane
				points.push_back(Vector2(x - width, rect.end.y))
				points.push_back(Vector2(x, rect.end.y - reach))
				points.push_back(Vector2(x + width, rect.end.y))
			"left":
				var y := rect.position.y + lane
				points.push_back(Vector2(rect.position.x, y - width))
				points.push_back(Vector2(rect.position.x + reach, y))
				points.push_back(Vector2(rect.position.x, y + width))
			"right":
				var y := rect.position.y + lane
				points.push_back(Vector2(rect.end.x, y - width))
				points.push_back(Vector2(rect.end.x - reach, y))
				points.push_back(Vector2(rect.end.x, y + width))
		notches.push_back(points)
	return notches


## Vertex color pair for an exposed gradient band: darkest at the opening lip.
static func exposed_band_colors(edge_base: Color) -> Array[Color]:
	var rim := edge_base.darkened(0.45)
	var inner := edge_base.darkened(0.12)
	return [rim, inner]
