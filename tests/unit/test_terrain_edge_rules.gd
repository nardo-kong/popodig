extends RefCounted

# Phase 11 unit tests for the pure terrain-transition rules that drive the
# chunk-view edge pass (docs/art/12_ART_BIBLE.md §5).

const TerrainEdgeRulesScript = preload("res://src/presentation/world/terrain_edge_rules.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	results = []
	_test_exposed_face_classification()
	_test_material_boundary_classification()
	_test_solid_cell_without_edges()
	_test_band_geometry_exposed()
	_test_band_geometry_material()
	_test_notches_are_deterministic_and_local()
	_test_band_colors_darken_toward_the_rim()
	return results


func _test_exposed_face_classification() -> void:
	# Center solid cell surrounded by excavated cells on all sides.
	var faces := _classify_with_grid(func(_cell: Vector2i) -> int: return 1, Vector2i(5, 5), {
		Vector2i(5, 4): "excavated",
		Vector2i(5, 6): "excavated",
		Vector2i(4, 5): "excavated",
		Vector2i(6, 5): "excavated",
	})
	_assert(faces.get("top") == "exposed" and faces.get("bottom") == "exposed", "Excavated neighbors classify as exposed faces")
	_assert(faces.get("left") == "exposed" and faces.get("right") == "exposed", "All four excavated neighbors classify as exposed")
	var exterior_faces := _classify_with_grid(func(_cell: Vector2i) -> int: return 1, Vector2i(5, 5), {
		Vector2i(5, 4): "exterior",
		Vector2i(5, 6): "solid_same",
		Vector2i(4, 5): "solid_same",
		Vector2i(6, 5): "solid_same",
	})
	_assert(exterior_faces.get("top") == "exposed", "Exterior neighbor classifies as exposed")
	_assert(exterior_faces.size() == 1, "Same-material solid neighbors get no treatment")


func _test_material_boundary_classification() -> void:
	var faces := _classify_with_grid(func(cell: Vector2i) -> int: return 1 if cell == Vector2i(5, 5) else 4, Vector2i(5, 5), {
		Vector2i(5, 4): "solid",
		Vector2i(5, 6): "solid",
		Vector2i(4, 5): "solid",
		Vector2i(6, 5): "solid",
	})
	_assert(faces.size() == 4, "Different-material neighbors all classify as material boundaries")
	for face_name: String in ["top", "bottom", "left", "right"]:
		_assert(String(faces.get(face_name)) == "material", "Face %s is a material boundary" % face_name)


func _test_solid_cell_without_edges() -> void:
	var faces := _classify_with_grid(func(_cell: Vector2i) -> int: return 1, Vector2i(5, 5), {
		Vector2i(5, 4): "solid_same",
		Vector2i(5, 6): "solid_same",
		Vector2i(4, 5): "solid_same",
		Vector2i(6, 5): "solid_same",
	})
	_assert(faces.is_empty(), "Uniform solid surroundings produce no edge bands")


func _test_band_geometry_exposed() -> void:
	var rect := Rect2(Vector2(0, 0), Vector2(16, 16))
	var bands := TerrainEdgeRulesScript.edge_bands(rect, {"top": "exposed"}, 16)
	_assert(bands.size() == 1, "One band per declared face")
	var band: Dictionary = bands[0]
	_assert(bool(band.gradient), "Exposed bands render as gradients")
	_assert(Rect2(band.rect).size.y == 3.0, "Exposed top band is 3px deep")
	var bottom := TerrainEdgeRulesScript.edge_bands(rect, {"bottom": "exposed"}, 16)[0]
	_assert(absf(Rect2(bottom.rect).end.y - 16.0) < 0.01, "Bottom band hugs the cell bottom edge")


func _test_band_geometry_material() -> void:
	var rect := Rect2(Vector2(0, 0), Vector2(16, 16))
	var bands := TerrainEdgeRulesScript.edge_bands(rect, {"left": "material", "right": "material"}, 16)
	_assert(bands.size() == 2, "Both declared faces get bands")
	for band: Dictionary in bands:
		_assert(not bool(band.gradient), "Material seams render flat")
		_assert(Rect2(band.rect).size.x == 2.0, "Material seam bands are 2px wide")


func _test_notches_are_deterministic_and_local() -> void:
	var rect := Rect2(Vector2(0, 0), Vector2(16, 16))
	var first := TerrainEdgeRulesScript.exposed_face_notches(rect, "top", 12345)
	var second := TerrainEdgeRulesScript.exposed_face_notches(rect, "top", 12345)
	_assert(first.size() == second.size(), "Same cell hash produces the same notch count")
	_assert(str(first) == str(second), "Notch layout is deterministic")
	for polygon: PackedVector2Array in first:
		for point: Vector2 in polygon:
			_assert(rect.grow(0.1).has_point(point), "Notch points stay inside the cell (no neighbor bleed)")
	# 9998 yields a different notch count than 12345 (which yields none).
	var varied := TerrainEdgeRulesScript.exposed_face_notches(rect, "top", 9998)
	_assert(first.size() != varied.size(), "Different hashes vary the notch layout")


func _test_band_colors_darken_toward_the_rim() -> void:
	var colors := TerrainEdgeRulesScript.exposed_band_colors(Color("835830"))
	_assert(colors.size() == 2, "Exposed bands get a rim/inner color pair")
	_assert(colors[0].v < colors[1].v, "The rim color is darker than the inner color")


## Builds classifier calls against a tiny virtual grid described by a
## neighborhood dictionary: "excavated", "exterior", "solid", "solid_same".
func _classify_with_grid(material_fn: Callable, center: Vector2i, neighborhood: Dictionary) -> Dictionary:
	var excavated_at := func(cell: Vector2i) -> bool: return String(neighborhood.get(cell, "")) == "excavated"
	var exterior_at := func(cell: Vector2i) -> bool: return String(neighborhood.get(cell, "")) == "exterior"
	var material_at := func(cell: Vector2i) -> int:
		if cell == center:
			return material_fn.call(cell)
		var kind := String(neighborhood.get(cell, "solid_same"))
		if kind == "solid_same":
			return material_fn.call(center)
		if kind == "solid":
			return (material_fn.call(center) + 3) % 6
		return material_fn.call(center)
	return TerrainEdgeRulesScript.classify_faces(center, true, material_at, excavated_at, exterior_at)


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
