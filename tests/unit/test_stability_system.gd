extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const RegistryScript = preload("res://src/domain/worldgen/feature_registry.gd")
const FeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const StabilitySystemScript = preload("res://src/domain/features/stability_system.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_safe_start()
	_test_stable_span_remains_stable()
	_test_weak_over_span_warns_then_collapses()
	_test_reinforcement_prevents_collapse()
	_test_root_support_applies_locally()
	_test_stone_self_supports()
	_test_collapse_updates_pathfinding()
	_test_collapse_radius_is_bounded()
	_test_protected_cells_never_collapse()
	_test_support_only_improves_local_score()
	_test_reinforce_request_rules()
	_test_collapse_absorbs_trapped_water()
	_test_water_weakened_ceiling()
	return results


func _test_stable_span_remains_stable() -> void:
	var context := _tunnel(11, 7, 4, 4, 6)
	var stability: StabilitySystem = context.stability
	for x: int in range(4, 7):
		var level := stability.get_warning_level(Vector2i(x, 4))
		_assert_equal(level, StabilitySystemScript.LEVEL_STABLE, "A three-cell soft-soil span stays stable (x=%d)" % x)
	_tick_seconds(stability, 12.0)
	_assert_equal(int(context.grid.get_stability_base(Vector2i(5, 4))), 0, "Stable span writes no instability signal")


func _test_weak_over_span_warns_then_collapses() -> void:
	var context := _tunnel(13, 7, 4, 3, 10)
	var stability: StabilitySystem = context.stability
	var collapsed_cells: Array = []
	stability.region_collapsed.connect(func(cells: Array, _absorbed: int) -> void:
		collapsed_cells.append_array(cells)
	)
	var mid_level := stability.get_warning_level(Vector2i(6, 4))
	_assert_true(mid_level >= StabilitySystemScript.LEVEL_CRACKING, "An over-wide soft span escalates past cracking")
	_tick_seconds(stability, 1.0)
	_assert_true(stability.is_danger_active(), "Critical span exposes an active danger region for mice")
	_tick_seconds(stability, 9.0)
	_assert_true(not collapsed_cells.is_empty(), "A deliberately ignored critical span collapses after the grace period")
	for x: int in range(3, 11):
		_assert_true(not context.grid.is_excavated(Vector2i(x, 4)), "Collapsed rubble refills the excavated span (x=%d)" % x)
		_assert_true(context.grid.is_rubble(Vector2i(x, 4)), "Collapsed cells keep a legible rubble marker (x=%d)" % x)
	_assert_true(not context.grid.is_rubble(Vector2i(3, 6)), "Never-excavated terrain carries no rubble marker")
	var reopened: bool = context.grid.set_excavated(Vector2i(5, 4), true, true)
	_assert_true(reopened, "Ordinary dig can reopen a collapsed rubble cell")
	_assert_true(context.grid.is_traversable(Vector2i(5, 4)), "Reopened rubble cell is traversable")
	_assert_true(not context.grid.is_rubble(Vector2i(5, 4)), "Reopening a rubble cell clears the rubble marker")


func _test_reinforcement_prevents_collapse() -> void:
	var context := _tunnel(13, 7, 4, 3, 10)
	var stability: StabilitySystem = context.stability
	var request: Dictionary = stability.request_reinforce(Vector2i(6, 4))
	_assert_true(request.ok, "Player can request reinforcement under a stressed ceiling")
	var completion: Dictionary = stability.complete_reinforcement(Vector2i(6, 4), 1)
	_assert_true(completion.ok, "Delivered General Material completes the reinforcement")
	_assert_true(context.grid.is_reinforced(Vector2i(6, 3)), "Reinforcement marks the roof cell as a visible support")
	_tick_seconds(stability, 14.0)
	_assert_true(context.grid.is_excavated(Vector2i(8, 4)), "Reinforcement prevents the delayed collapse")
	var right_level := stability.get_warning_level(Vector2i(8, 4))
	_assert_true(right_level < StabilitySystemScript.LEVEL_CRITICAL, "Splitting the span de-escalates the warning level")


func _test_root_support_applies_locally() -> void:
	var grid = GridScript.new(15, 7, 4)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			grid.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false, false, false)
	var registry := RegistryScript.new()
	var roots := FeatureScript.new("root_cluster", Vector2i(7, 3), [Vector2i(7, 3), Vector2i(8, 3)], true)
	registry.add_feature(roots)
	grid.set_feature_id(Vector2i(7, 3), roots.id)
	grid.set_feature_id(Vector2i(8, 3), roots.id)
	for x: int in range(3, 12):
		grid.set_excavated(Vector2i(x, 4), true, true)
	var stability := StabilitySystemScript.new()
	stability.configure(grid, registry, null, null, {}, [])
	var worst_with_roots := _worst_level(stability, 3, 12, 4)
	_assert_true(worst_with_roots < StabilitySystemScript.LEVEL_CRITICAL, "Major root cells support the local span")
	grid.set_feature_id(Vector2i(7, 3), -1)
	grid.set_feature_id(Vector2i(8, 3), -1)
	_tick_seconds(stability, 0.05)
	var worst_after_cut := _worst_level(stability, 3, 12, 4)
	_assert_true(worst_after_cut > worst_with_roots, "Cutting the supporting root re-escalates the same span")


func _test_stone_self_supports() -> void:
	var grid = GridScript.new(20, 7, 4)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			grid.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.STONE, false, false, false)
	for x: int in range(3, 17):
		grid.set_excavated(Vector2i(x, 4), true, true)
	var stability := StabilitySystemScript.new()
	stability.configure(grid, null, null, null, {}, [])
	_tick_seconds(stability, 12.0)
	_assert_equal(_worst_level(stability, 3, 17, 4), StabilitySystemScript.LEVEL_STABLE, "Stone ceilings self-support a wide gallery")


func _test_collapse_updates_pathfinding() -> void:
	var context := _tunnel(13, 7, 4, 3, 10)
	var revision_before: int = context.path_service.get_topology_revision()
	_tick_seconds(context.stability, 12.0)
	_assert_true(context.path_service.get_topology_revision() > revision_before, "Collapse bumps the path topology revision")
	_assert_true(not context.path_service.is_walkable(Vector2i(5, 4)), "Rubble cells are removed from walkable topology")


func _test_collapse_radius_is_bounded() -> void:
	var context := _tunnel(13, 13, 4, 3, 10)
	var grid = context.grid
	for y: int in range(5, 11):
		grid.set_excavated(Vector2i(9, y), true, true)
	var seeds: Array[Vector2i] = []
	for x: int in range(3, 11):
		seeds.append(Vector2i(x, 4))
	_tick_seconds(context.stability, 12.0)
	var radius := 3
	for index: int in range(grid.width * grid.height):
		var cell: Vector2i = grid.index_to_cell(index)
		if grid.is_excavated(cell) or not _was_open_before(cell, seeds):
			continue
		var nearest := 1 << 20
		for seed_cell: Vector2i in seeds:
			nearest = mini(nearest, maxi(absi(cell.x - seed_cell.x), absi(cell.y - seed_cell.y)))
		_assert_true(nearest <= radius, "Collapse never escapes the configured max radius (cell %s)" % str(cell))
	for y: int in range(8, 11):
		_assert_true(grid.is_excavated(Vector2i(9, y)), "Pocket cells beyond the collapse radius survive (y=%d)" % y)


func _was_open_before(cell: Vector2i, seeds: Array[Vector2i]) -> bool:
	if cell in seeds:
		return true
	return cell.x == 9 and cell.y >= 5 and cell.y <= 10


func _test_protected_cells_never_collapse() -> void:
	var context := _tunnel(13, 7, 4, 3, 10)
	var grid = context.grid
	grid.set_protected(Vector2i(6, 4), true)
	_tick_seconds(context.stability, 12.0)
	_assert_true(grid.is_excavated(Vector2i(6, 4)) and grid.is_traversable(Vector2i(6, 4)), "Protected open cells are never filled by collapse")
	_assert_true(not grid.is_excavated(Vector2i(4, 4)), "Unprotected neighbours of the protected cell still collapse")


func _test_support_only_improves_local_score() -> void:
	var plain_context := _tunnel(13, 7, 4, 3, 10)
	var worst_plain: int = _worst_level(plain_context.stability, 3, 11, 4)
	var reinforced_context := _tunnel(13, 7, 4, 3, 10)
	reinforced_context.stability.request_reinforce(Vector2i(6, 4))
	reinforced_context.stability.complete_reinforcement(Vector2i(6, 4), 1)
	var worst_reinforced: int = _worst_level(reinforced_context.stability, 3, 11, 4)
	_assert_true(worst_reinforced <= worst_plain, "Support can only improve or maintain the local warning score")


func _test_reinforce_request_rules() -> void:
	var context := _tunnel(13, 7, 4, 3, 10)
	var stability: StabilitySystem = context.stability
	_assert_equal(stability.inspect_request(Vector2i(5, 1)), "NOT_OPEN", "Reinforcement requires an excavated interior cell")
	_assert_true(stability.request_reinforce(Vector2i(6, 4)).ok, "A ceiling-backed request is accepted")
	_assert_equal(stability.inspect_request(Vector2i(6, 4)), "ALREADY_REQUESTED", "Duplicate requests are rejected deterministically")
	_assert_equal(
		String(stability.complete_reinforcement(Vector2i(6, 4), 0).reason_code),
		"INSUFFICIENT_MATERIAL",
		"Reinforcement without the required material is refused"
	)
	_assert_true(stability.cancel_request(Vector2i(6, 4)).ok, "The player may cancel a pending reinforcement")
	_assert_true(stability.request_reinforce(Vector2i(6, 4)).ok, "A cancelled cell can be requested again")
	_assert_true(stability.complete_reinforcement(Vector2i(6, 4), 1).ok, "A fresh request can be completed after cancellation")
	_assert_equal(stability.inspect_request(Vector2i(6, 4)), "ALREADY_REINFORCED", "A reinforced roof refuses duplicate work")


func _test_collapse_absorbs_trapped_water() -> void:
	var context := _tunnel(13, 7, 4, 3, 10)
	var grid = context.grid
	for x: int in range(4, 10):
		grid.set_water_units(Vector2i(x, 4), 1)
	_tick_seconds(context.stability, 12.0)
	var total_water := 0
	for index: int in range(grid.width * grid.height):
		total_water += grid.get_water_units(grid.index_to_cell(index))
	_assert_equal(total_water + context.stability.get_absorbed_water_units(), 6, "Trapped water is either displaced or documented as a rubble sink")


func _worst_level(stability: StabilitySystem, from_x: int, to_x: int, row: int) -> int:
	var worst := StabilitySystemScript.LEVEL_STABLE
	for x: int in range(from_x, to_x):
		worst = maxi(worst, stability.get_warning_level(Vector2i(x, row)))
	return worst


## Phase 14 (spec 09 §10): standing water against a ceiling halves its
## allowed span — a dry-stable 3-wide soft span turns critical when flooded,
## and recovers once drained.
func _test_water_weakened_ceiling() -> void:
	var context := _tunnel(11, 7, 4, 4, 6)
	var stability: StabilitySystem = context.stability
	for x: int in range(4, 7):
		_assert_equal(stability.get_warning_level(Vector2i(x, 4)), StabilitySystemScript.LEVEL_STABLE, "Dry 3-wide soft span starts stable (x=%d)" % x)
		context.grid.set_water_units(Vector2i(x, 4), 2)
	_tick_seconds(stability, 0.2)
	var flooded_level := stability.get_warning_level(Vector2i(5, 4))
	_assert_true(flooded_level >= StabilitySystemScript.LEVEL_CRACKING, "Flooding the ceiling escalates the warning (%d)" % flooded_level)
	for x: int in range(4, 7):
		context.grid.set_water_units(Vector2i(x, 4), 0)
	_tick_seconds(stability, 0.5)
	_assert_true(stability.get_warning_level(Vector2i(5, 4)) == StabilitySystemScript.LEVEL_STABLE, "Draining the water recovers the span to stable")


func _tunnel(width: int, height: int, row: int, from_x: int, to_x: int) -> Dictionary:
	var balance := {
		"stability": {
			"span_short": 3,
			"span_moderate": 6,
			"span_high": 12,
			"crumbs_ratio": 0.6,
			"cracking_ratio": 0.85,
			"critical_grace_seconds": 8.0,
			"max_collapse_radius": 3,
			"reinforce_material_per_cell": 1,
		}
	}
	var grid := GridScript.new(width, height, 4)
	for y: int in range(height):
		for x: int in range(width):
			grid.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false, false, false)
	for x: int in range(from_x, to_x + 1):
		grid.set_excavated(Vector2i(x, row), true, true)
	var path_service := PathServiceScript.new()
	path_service.configure(grid, balance)
	var stability := StabilitySystemScript.new()
	stability.configure(grid, RegistryScript.new(), null, null, balance, [])
	return {"grid": grid, "path_service": path_service, "stability": stability}


func _tick_seconds(stability: StabilitySystem, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(0.05, remaining)
		stability.fixed_tick(step)
		remaining -= step


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({"passed": passed, "description": description, "details": "" if passed else "Expected %s, got %s" % [expected, actual]})


func _test_safe_start() -> void:
	var context := _tunnel(19, 7, 4, 2, 17)
	context.grid.metadata["start_cell"] = Vector2i(6, 4)
	context.stability.configure(context.grid, null, null, null, {"stability": {"safe_start_radius": 4}}, [])
	_tick_seconds(context.stability, 12.0)
	_assert_true(context.grid.is_traversable(Vector2i(6, 4)), "Starter safety area survives adjacent collapse")
	_assert_equal(context.stability.get_warning_level(Vector2i(6, 4)), 0, "Starter radius teaches rewards before collapse pressure")
	_assert_true(context.grid.is_rubble(Vector2i(15, 4)), "Safety radius leaves distant hazard active")
