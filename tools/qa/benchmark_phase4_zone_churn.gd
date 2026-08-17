extends SceneTree

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")
const ZoneSystemScript = preload("res://src/domain/zones/zone_system.gd")

const BALANCE := {
	"pathfinding": {"max_walkable_water_units": 1},
	"zones": {"setup_material_per_zone": 1, "dry_water_max_units": 0},
}
const MAX_EVENT_BURST_MS := 250.0
const MAX_FLUSH_MS := 500.0


func _initialize() -> void:
	call_deferred("_benchmark")


func _benchmark() -> void:
	var world := GridScript.new(96, 72, 16)
	for y: int in range(world.height):
		for x: int in range(world.width):
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, true)
	world.metadata = {"start_cell": Vector2i(1, 1), "seed": 40404}
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var zones := ZoneSystemScript.new()
	zones.configure(world, path_service, BALANCE)
	var zone_cells: Array[Vector2i] = []
	for y: int in range(8, 40):
		for x: int in range(8, 72):
			zone_cells.append(Vector2i(x, y))
	var painted: Dictionary = zones.paint_zone(ZoneScript.Type.SLEEPING, zone_cells)
	if not painted.ok:
		_fail("large zone paint failed: %s" % painted.reason_code)
		return
	var batches_before := zones.get_debug_refresh_batch_count()
	var changed_cells := 0
	var event_started := Time.get_ticks_usec()
	for index: int in range(0, zone_cells.size(), 4):
		world.set_water_units(zone_cells[index], 1)
		changed_cells += 1
	var event_burst_ms := (Time.get_ticks_usec() - event_started) / 1000.0
	var flush_started := Time.get_ticks_usec()
	zones.flush_world_changes()
	var flush_ms := (Time.get_ticks_usec() - flush_started) / 1000.0
	var zone: Zone = zones.get_zone_at(zone_cells[0])
	var refresh_batches := zones.get_debug_refresh_batch_count() - batches_before
	print("PHASE4_ZONE_CHURN_BENCHMARK zone_cells=%d changed_cells=%d refresh_batches=%d event_burst_ms=%.2f flush_ms=%.2f" % [
		zone_cells.size(),
		changed_cells,
		refresh_batches,
		event_burst_ms,
		flush_ms,
	])
	if zone == null or not zone.valid or zone.suitability >= 1.0:
		_fail("batched water changes did not re-evaluate the large Sleeping zone")
		return
	if refresh_batches != 1:
		_fail("water churn was not coalesced into exactly one zone refresh batch")
		return
	if event_burst_ms > MAX_EVENT_BURST_MS or flush_ms > MAX_FLUSH_MS:
		_fail("large-zone churn exceeded the provisional Phase 4 budget")
		return
	quit(0)


func _fail(message: String) -> void:
	push_error("PHASE4_ZONE_CHURN_BENCHMARK_FAIL %s" % message)
	quit(1)
