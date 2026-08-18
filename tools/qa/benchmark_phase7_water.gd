extends SceneTree

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const RegistryScript = preload("res://src/domain/worldgen/feature_registry.gd")
const WaterSystemScript = preload("res://src/domain/features/water_system.gd")

const STEP_COUNT := 240
const MAXIMUM_P95_STEP_MS := 8.0
const MAXIMUM_SINGLE_STEP_MS := 25.0


func _initialize() -> void:
	call_deferred("_benchmark")


func _benchmark() -> void:
	var world := GridScript.new(96, 72, 16)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var open := x > 0 and x < world.width - 1 and y > 0 and y < world.height - 1
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, open, not open, false)
	for x: int in range(1, world.width - 1):
		world.set_water_units(Vector2i(x, 1), 4)
	var water := WaterSystemScript.new()
	water.configure(world, RegistryScript.new(), null, null, {
		"water": {
			"cell_capacity_units": 4,
			"simulation_step_seconds": 0.2,
			"max_transfers_per_step": 256,
			"source_release_per_step": 2,
			"breach_initial_units": 1,
			"stable_quiet_steps": 3,
			"danger_radius": 3,
			"danger_water_units": 2,
		}
	})
	var inventory_before: int = water.get_conserved_inventory()
	var samples: Array[float] = []
	var max_transfers := 0
	for _step: int in range(STEP_COUNT):
		var started := Time.get_ticks_usec()
		var result: Dictionary = water.fixed_tick(0.2)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
		max_transfers = maxi(max_transfers, int(result.transfers))
	samples.sort()
	var p95_index := clampi(ceili(samples.size() * 0.95) - 1, 0, samples.size() - 1)
	var p95_ms: float = samples[p95_index]
	var max_ms: float = samples[-1]
	var average_ms := 0.0
	for sample: float in samples:
		average_ms += sample
	average_ms /= samples.size()
	print("PHASE7_WATER_BENCHMARK average_step_ms=%.3f p95_step_ms=%.3f max_step_ms=%.3f steps=%d max_transfers=%d active_cells=%d inventory=%d" % [
		average_ms,
		p95_ms,
		max_ms,
		STEP_COUNT,
		max_transfers,
		water.get_active_cell_count(),
		water.get_conserved_inventory(),
	])
	if water.get_conserved_inventory() != inventory_before:
		_fail("simulation violated water conservation")
		return
	if max_transfers > 256:
		_fail("simulation exceeded bounded transfer work")
		return
	if p95_ms > MAXIMUM_P95_STEP_MS or max_ms > MAXIMUM_SINGLE_STEP_MS:
		_fail("simulation exceeded step-time budget")
		return
	quit(0)


func _fail(message: String) -> void:
	push_error("PHASE7_WATER_BENCHMARK_FAIL %s" % message)
	quit(1)
