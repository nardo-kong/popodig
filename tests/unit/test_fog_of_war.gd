extends RefCounted

# Phase 16 unit tests: fog-of-war visibility — excavation-lit cells, linear
# fade to full darkness, lit surface band, determinism. PM feedback round 1
# follow-up: undiscovered (hidden) feature cells must not act as light
# sources — they would leak spoiler halos through solid rock — and light up
# once their feature is discovered.

const FogOfWarViewScript = preload("res://src/presentation/world/fog_of_war_view.gd")

var results: Array[Dictionary] = []


class FakeGrid:
	var width := 16
	var height := 12
	var open := {}

	func is_traversable(cell: Vector2i) -> bool:
		return open.has(cell)

	func is_exterior(cell: Vector2i) -> bool:
		return cell.y == 0


class FakeFeature:
	var hidden := true
	var cells: Array[Vector2i] = []


class FakeRegistry:
	var features: Array = []

	func get_features() -> Array:
		return features


func run() -> Array[Dictionary]:
	results = []
	_test_open_cells_are_lit()
	_test_fade_is_monotonic_into_darkness()
	_test_surface_stays_lit()
	_test_fully_dark_beyond_radius()
	_test_computation_is_deterministic()
	_test_hidden_feature_cells_stay_dark()
	_test_discovered_feature_becomes_light_source()
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


func _test_hidden_feature_cells_stay_dark() -> void:
	var grid := FakeGrid.new()
	var start := Vector2i(4, 6)
	grid.open[start] = true
	var cavity_cells: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, -1)]:
		var cell := start + Vector2i(7, 0) + offset
		grid.open[cell] = true
		cavity_cells.append(cell)
	var registry := FakeRegistry.new()
	var cavity := FakeFeature.new()
	cavity.cells = cavity_cells
	registry.features = [cavity]
	var fog := FogOfWarViewScript.new()
	fog.configure(grid, 16, 4, registry)
	fog._recompute()
	var center_cell := start + Vector2i(8, 0)
	var level_center := fog._visibility[center_cell.y * grid.width + center_cell.x]
	_assert_true(level_center >= 5, "An undiscovered feature's open cells stay fully dark (%d)" % level_center)
	var level_start := fog._visibility[start.y * grid.width + start.x]
	_assert_true(level_start == 0, "Player-seen cells stay lit")
	fog.configure(grid, 16, 4, null)
	fog._recompute()
	var level_without_registry := fog._visibility[center_cell.y * grid.width + center_cell.x]
	_assert_true(level_without_registry == 0, "Without registry knowledge the hidden cavity leaks light (old broken behavior, level %d)" % level_without_registry)


func _test_discovered_feature_becomes_light_source() -> void:
	var grid := FakeGrid.new()
	var start := Vector2i(4, 6)
	grid.open[start] = true
	var cavity_cells: Array[Vector2i] = [start + Vector2i(2, 0), start + Vector2i(3, 0)]
	grid.open[cavity_cells[0]] = true
	grid.open[cavity_cells[1]] = true
	var registry := FakeRegistry.new()
	var cavity := FakeFeature.new()
	cavity.cells = cavity_cells
	registry.features = [cavity]
	var fog := FogOfWarViewScript.new()
	fog.configure(grid, 16, 4, registry)
	fog._recompute()
	var far_level := fog._visibility[cavity_cells[1].y * grid.width + cavity_cells[1].x]
	_assert_true(far_level >= 2, "Hidden cavity interior beyond the dug frontier stays dark (level %d)" % far_level)
	cavity.hidden = false
	fog._recompute()
	var revealed_level := fog._visibility[cavity_cells[1].y * grid.width + cavity_cells[1].x]
	_assert_true(revealed_level == 0, "Discovering the feature lights its cells (level %d)" % revealed_level)


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})
