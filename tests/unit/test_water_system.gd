extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const RegistryScript = preload("res://src/domain/worldgen/feature_registry.gd")
const FeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")
const WaterSystemScript = preload("res://src/domain/features/water_system.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_gravity_and_conservation()
	_test_horizontal_basin_equalization()
	_test_seal_blocks_water()
	_test_topology_change_redirects_stable_pool()
	_test_finite_reservoir_lifecycle()
	return results


func _test_gravity_and_conservation() -> void:
	var grid = _solid_grid(7, 7)
	for y: int in range(1, 6):
		_open(grid, Vector2i(3, y))
	grid.set_water_units(Vector2i(3, 1), 4)
	var water = _configured_water(grid, RegistryScript.new())
	var before: int = water.get_conserved_inventory()
	_tick_steps(water, 8)
	_assert_equal(grid.get_water_units(Vector2i(3, 5)), 4, "Discrete water falls to the lowest connected cell")
	_assert_equal(water.get_conserved_inventory(), before, "Gravity flow conserves water units")
	_assert_true(water.is_sleeping(), "Settled vertical water leaves the active simulation set")


func _test_horizontal_basin_equalization() -> void:
	var grid = _solid_grid(7, 5)
	for x: int in range(1, 6):
		_open(grid, Vector2i(x, 2))
	grid.set_water_units(Vector2i(3, 2), 4)
	var water = _configured_water(grid, RegistryScript.new())
	_tick_steps(water, 16)
	var minimum := 99
	var maximum := 0
	var total := 0
	for x: int in range(1, 6):
		var units: int = grid.get_water_units(Vector2i(x, 2))
		minimum = mini(minimum, units)
		maximum = maxi(maximum, units)
		total += units
	_assert_equal(total, 4, "Basin equalization preserves finite volume")
	_assert_true(maximum - minimum <= 1, "A level basin settles with at most one discrete unit difference")


func _test_seal_blocks_water() -> void:
	var grid = _solid_grid(7, 5)
	for x: int in range(1, 6):
		_open(grid, Vector2i(x, 2))
	grid.set_sealed(Vector2i(3, 2), true)
	grid.set_water_units(Vector2i(1, 2), 4)
	var water = _configured_water(grid, RegistryScript.new())
	_tick_steps(water, 16)
	_assert_equal(grid.get_water_units(Vector2i(4, 2)) + grid.get_water_units(Vector2i(5, 2)), 0, "Constructed seal blocks horizontal water connectivity")
	_assert_equal(water.get_total_water_units(), 4, "Seal containment does not delete water")


func _test_topology_change_redirects_stable_pool() -> void:
	var grid = _solid_grid(7, 7)
	_open(grid, Vector2i(3, 2))
	grid.set_water_units(Vector2i(3, 2), 3)
	var water = _configured_water(grid, RegistryScript.new())
	_tick_steps(water, 4)
	_assert_true(water.is_sleeping(), "Closed pool reaches stable sleep state")
	_assert_true(water.get_active_cell_count() > 0, "Sleeping pool retains wet candidates; chapter stability must use sleep state")
	_open(grid, Vector2i(3, 3))
	_open(grid, Vector2i(3, 4))
	_assert_true(not water.is_sleeping(), "Newly excavated lower route wakes nearby stable water")
	_tick_steps(water, 8)
	_assert_equal(grid.get_water_units(Vector2i(3, 4)), 3, "Player-created lower topology predictably redirects water")


func _test_finite_reservoir_lifecycle() -> void:
	var grid = _solid_grid(7, 8)
	for y: int in range(1, 7):
		_open(grid, Vector2i(3, y))
	var registry := RegistryScript.new()
	var feature := FeatureScript.new("water_reservoir", Vector2i(3, 1), [Vector2i(3, 1)], true)
	feature.metadata = {"reserve_units": 6}
	registry.add_feature(feature)
	grid.set_feature_id(Vector2i(3, 1), feature.id)
	var water = _configured_water(grid, registry)
	var inventory_before: int = int(water.get_conserved_inventory())
	var reveal: Dictionary = water.reveal_reservoir(feature.id, Vector2i(3, 1))
	_assert_true(reveal.ok and int(reveal.released_units) == 1, "Reservoir breach releases the configured one-shot reaction")
	_assert_true(not feature.hidden and bool(feature.metadata.reaction_fired), "Reservoir breach persists reveal and reaction state")
	_tick_steps(water, 30)
	_assert_equal(int(feature.metadata.reserve_units), 0, "Finite reservoir source reaches explicit exhaustion")
	_assert_equal(water.get_total_water_units(), 6, "Every exhausted reservoir unit remains in world cells")
	_assert_equal(water.get_conserved_inventory(), inventory_before, "Reservoir discharge conserves reserve plus world water")
	_assert_equal(String(feature.metadata.lifecycle_state), WaterSystemScript.STATE_STABLE, "Settled breached reservoir reaches Stable State")


func _solid_grid(width: int, height: int):
	var grid := GridScript.new(width, height, 4)
	for y: int in range(height):
		for x: int in range(width):
			grid.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false, false, false)
	return grid


func _open(grid, cell: Vector2i) -> void:
	grid.set_excavated(cell, true, true)


func _configured_water(grid, registry):
	var water := WaterSystemScript.new()
	water.configure(grid, registry, null, null, {
		"water": {
			"cell_capacity_units": 4,
			"simulation_step_seconds": 0.2,
			"max_transfers_per_step": 64,
			"source_release_per_step": 2,
			"breach_initial_units": 1,
			"stable_quiet_steps": 3,
			"danger_radius": 2,
			"danger_water_units": 2,
		}
	})
	return water


func _tick_steps(water, count: int) -> void:
	for _index: int in range(count):
		water.fixed_tick(0.2)


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
