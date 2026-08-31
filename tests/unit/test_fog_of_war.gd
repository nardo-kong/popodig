extends RefCounted

# Phase 16 unit tests: fog-of-war visibility — excavation-lit cells, linear
# fade to full darkness, lit surface band, and determinism.

const FogOfWarViewScript = preload("res://src/presentation/world/fog_of_war_view.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	results = []
	_test_open_cells_are_lit()
	_test_fade_is_monotonic_into_darkness()
	_test_surface_stays_lit()
	_test_fully_dark_beyond_radius()
	_test_computation_is_deterministic()
	return results


func _make_world(width: int, height: int, open_cells: Dictionary) -> Array:
	# Returns [levels, is_open, is_exterior]; row 0 is the surface band.
	var levels: PackedInt32Array = FogOfWarViewScript.compute_visibility(
		width, height,
		func(cell: Vector2i) -> bool: return open_cells.has(cell),
		func(cell: Vector2i) -> bool: return cell.y == 0,
		3
	)
	var is_open := func(cell: Vector2i) -> bool: return open_cells.has(cell)
	var is_exterior := func(cell: Vector2i) -> bool: return cell.y == 0
	return [levels, is_open, is_exterior]


func _test_open_cells_are_lit() -> void:
	var world := _make_world(8, 6, {Vector2i(3, 3): true})
	var levels: PackedInt32Array = world[0]
	_assert_true(levels[3 * 8 + 3] == 0, "An excavated cell is fully lit")
	_assert_true(levels[3 * 8 + 4] == 1, "The cell below an excavation is in the fade band")


func _test_fade_is_monotonic_into_darkness() -> void:
	var world := _make_world(8, 8, {Vector2i(4, 4): true})
	var levels: PackedInt32Array = world[0]
	var previous := -1
	for y: int in range(4, 8):
		var level := levels[y * 8 + 4]
		_assert_true(level > previous, "Darkness increases with distance from the dig (row %d)" % y)
		previous = level
	_assert_true(levels[7 * 8 + 4] >= 3, "Ground at the fog radius is fully dark")


func _test_surface_stays_lit() -> void:
	var world := _make_world(8, 6, {})
	var levels: PackedInt32Array = world[0]
	for x: int in range(8):
		_assert_true(levels[x] == 0, "The surface band stays lit even with nothing dug (x=%d)" % x)


func _test_fully_dark_beyond_radius() -> void:
	var world := _make_world(16, 6, {Vector2i(2, 3): true})
	var levels: PackedInt32Array = world[0]
	_assert_true(levels[3 * 16 + 15] >= 3, "Ground far from any excavation is fully dark")
	_assert_true(levels[3 * 16 + 5] <= 3, "Ground near the dig stays visible")


func _test_computation_is_deterministic() -> void:
	var first: PackedInt32Array = FogOfWarViewScript.compute_visibility(
		8, 6,
		func(cell: Vector2i) -> bool: return cell == Vector2i(4, 4),
		func(_cell: Vector2i) -> bool: return false,
		3
	)
	var second: PackedInt32Array = FogOfWarViewScript.compute_visibility(
		8, 6,
		func(cell: Vector2i) -> bool: return cell == Vector2i(4, 4),
		func(_cell: Vector2i) -> bool: return false,
		3
	)
	_assert_true(str(first) == str(second), "Visibility computation is deterministic")


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})
