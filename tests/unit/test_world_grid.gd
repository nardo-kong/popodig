extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GeneratorScript = preload("res://src/domain/world/simple_world_generator.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const ChunkScript = preload("res://src/domain/world/world_chunk.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_coordinates_and_chunks()
	_test_compact_cell_state()
	_test_dirty_chunk_updates()
	_test_seeded_generation()
	_test_large_grid_budget()
	return results


func _test_coordinates_and_chunks() -> void:
	var grid := GridScript.new(33, 17, 16)
	_assert_equal(grid.width, 33, "Grid preserves width")
	_assert_equal(grid.height, 17, "Grid preserves height")
	_assert_equal(grid.get_chunk_count(), 6, "Partial edges create the expected chunks")
	_assert_equal(grid.cell_to_index(Vector2i(0, 0)), 0, "Origin index")
	_assert_equal(grid.cell_to_index(Vector2i(32, 16)), 560, "Last valid index")
	_assert_equal(grid.index_to_cell(560), Vector2i(32, 16), "Index roundtrip")
	_assert_equal(grid.cell_to_index(Vector2i(33, 0)), -1, "Out-of-bounds coordinate is rejected")
	_assert_equal(grid.index_to_cell(561), Vector2i(-1, -1), "Out-of-bounds index is rejected")
	_assert_equal(grid.cell_to_chunk(Vector2i(32, 16)), Vector2i(2, 1), "Cell maps to edge chunk")


func _test_compact_cell_state() -> void:
	var grid := GridScript.new(8, 8, 4)
	var coord := Vector2i(3, 4)
	grid.initialize_cell(coord, CellDataScript.TerrainMaterial.DAMP_CLAY, false, false)
	var cell = grid.get_cell(coord)
	_assert_equal(cell.coord, coord, "Cell snapshot preserves coordinate")
	_assert_equal(cell.terrain_material, CellDataScript.TerrainMaterial.DAMP_CLAY, "Cell snapshot preserves material")
	_assert_true(is_equal_approx(cell.hardness, 1.45), "Material applies provisional hardness")
	_assert_true(cell.is_solid(), "Unexcavated terrain is solid")
	_assert_true(grid.set_excavated(coord, true), "Cell excavation mutation succeeds")
	_assert_true(grid.is_excavated(coord), "Excavated state updates")
	_assert_equal(grid.get_zone_id(coord), -1, "Excavated cell starts without a zone")
	_assert_true(grid.set_zone_id(coord, 7), "Cell accepts a compact zone reference")
	_assert_equal(grid.get_zone_id(coord), 7, "Zone reference roundtrips through compact storage")
	_assert_equal(grid.get_cell(coord).zone_id, 7, "Cell snapshot exposes its zone reference")
	_assert_true(grid.set_zone_id(coord, -1), "Zone reference can be cleared")
	_assert_true(not grid.set_zone_id(coord, -2), "Invalid negative zone reference is rejected")
	_assert_true(grid.set_sealed(coord, true), "Excavated interior cell accepts a constructed seal")
	_assert_true(grid.is_sealed(coord) and grid.is_solid(coord), "Seal becomes solid without reverting excavation history")
	_assert_true(not grid.is_traversable(coord), "Seal blocks path traversal")
	_assert_true(grid.get_cell(coord).sealed, "Cell snapshot exposes seal state")
	_assert_true(grid.set_dig_state(coord, CellDataScript.DigState.ACTIVE), "Seal can enter the ordinary dig workflow")
	_assert_true(grid.complete_excavation_atomic(coord), "Completing a dig atomically removes a seal")
	_assert_true(not grid.is_sealed(coord) and grid.is_traversable(coord), "Removed seal restores the excavated passage")
	var signal_field := PackedByteArray()
	signal_field.resize(grid.width * grid.height)
	signal_field.fill(0)
	signal_field[grid.cell_to_index(coord)] = 4
	_assert_true(grid.replace_signal_field("root_density", signal_field), "Equal-size signal field can be replaced atomically")
	_assert_equal(grid.get_root_signal(coord), 4, "Atomic signal field replacement updates compact storage")
	_assert_true(not grid.replace_signal_field("unknown", signal_field), "Unknown signal field channel is rejected")
	_assert_true(not grid.replace_signal_field("root_density", PackedByteArray([1])), "Wrong-size signal field replacement is rejected")
	grid.initialize_cell(Vector2i(0, 0), CellDataScript.TerrainMaterial.STONE, false, true)
	_assert_true(not grid.set_excavated(Vector2i(0, 0), true), "Protected cell rejects normal mutation")
	_assert_true(grid.set_excavated(Vector2i(0, 0), true, true), "Explicit generator/debug override can mutate protected cell")
	var exterior_coord := Vector2i(1, 0)
	grid.initialize_cell(exterior_coord, CellDataScript.TerrainMaterial.EMPTY, true, true, true)
	var exterior_cell = grid.get_cell(exterior_coord)
	_assert_true(exterior_cell.is_exterior() and grid.is_exterior(exterior_coord), "Exterior flag roundtrips through compact cell storage")
	_assert_true(exterior_cell.protected_cell and grid.is_protected(exterior_coord), "Packed exterior and protected flags coexist")
	_assert_true(not exterior_cell.is_traversable() and not grid.is_traversable(exterior_coord), "Excavated exterior air is not underground-traversable")
	_assert_true(grid.set_exterior(exterior_coord, false), "Exterior classification can be cleared through the grid API")
	_assert_true(grid.is_protected(exterior_coord), "Changing exterior classification preserves the packed protected flag")
	_assert_true(grid.is_traversable(exterior_coord), "Clearing exterior exposes the already-excavated interior cavity")
	var interior_checksum := grid.checksum()
	_assert_true(grid.set_exterior(exterior_coord, true), "Exterior classification can be restored")
	_assert_true(grid.checksum() != interior_checksum, "World checksum includes exterior classification")


func _test_dirty_chunk_updates() -> void:
	var grid := GridScript.new(32, 32, 16)
	var chunk = grid.get_chunk(Vector2i.ZERO)
	for existing_chunk in grid.get_chunks():
		existing_chunk.consume_dirty()
	_assert_true(not chunk.is_dirty(), "Chunk dirty flags can be consumed")
	grid.initialize_cell(Vector2i(2, 2), CellDataScript.TerrainMaterial.SOFT_SOIL, false)
	_assert_true(grid.set_excavated(Vector2i(2, 2), true), "Dirty test mutation succeeds")
	_assert_true(chunk.is_dirty(ChunkScript.DIRTY_TERRAIN), "Terrain mutation dirties terrain presentation")
	_assert_true(chunk.is_dirty(ChunkScript.DIRTY_PATHING), "Terrain mutation dirties path topology")
	_assert_true(chunk.is_dirty(ChunkScript.DIRTY_STABILITY), "Excavation dirties local stability")
	chunk.consume_dirty()
	_assert_true(grid.set_zone_id(Vector2i(2, 2), 1), "Zone dirty test mutation succeeds")
	_assert_true(chunk.is_dirty(ChunkScript.DIRTY_ZONES), "Zone mutation dirties zone presentation")
	_assert_true(not chunk.is_dirty(ChunkScript.DIRTY_TERRAIN), "Zone mutation does not redraw terrain")
	_assert_true(not grid.get_chunk(Vector2i(1, 1)).is_dirty(ChunkScript.DIRTY_TERRAIN), "Unrelated chunk remains clean after local edit")


func _test_seeded_generation() -> void:
	var config := {"world_size": [96, 72], "chunk_size": 16, "worldgen_version": 1}
	var first = GeneratorScript.new().generate(config, 424242)
	var second = GeneratorScript.new().generate(config, 424242)
	var different = GeneratorScript.new().generate(config, 424243)
	_assert_equal(first.checksum(), second.checksum(), "Same seed generates identical Phase 1 topology")
	_assert_true(first.checksum() != different.checksum(), "Different seed changes simple terrain")
	_assert_equal(first.metadata.seed, 424242, "World records seed")
	_assert_equal(first.metadata.worldgen_version, 1, "World records worldgen version")
	_assert_true(first.is_excavated(first.metadata.start_cell), "Starting burrow contains a traversable start cell")
	_assert_true(first.is_protected(Vector2i(0, first.height - 1)), "World boundary is protected")
	_assert_equal(first.get_chunk_count(), 30, "Vertical Slice size uses 30 chunk records")


func _test_large_grid_budget() -> void:
	var started := Time.get_ticks_usec()
	var world = GeneratorScript.new().generate({"world_size": [240, 260], "chunk_size": 16}, 9001)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	var cell_count: int = world.width * world.height
	var bytes_per_cell := float(world.estimate_storage_bytes()) / cell_count
	_assert_equal(cell_count, 62400, "Full-size stress grid contains expected cells")
	_assert_true(bytes_per_cell <= 24.0, "Bit-packed cell flags keep exterior-aware logical storage at or below 24 bytes per cell")
	_assert_true(world.get_chunk_count() == 255, "Full-size stress grid uses bounded chunk records")
	_assert_true(elapsed_ms < 3000.0, "Full-size simple generation stays below 3 seconds")
	print("PERF_PHASE1 generation_ms=%.2f bytes_per_cell=%.2f cells=%d chunks=%d" % [elapsed_ms, bytes_per_cell, cell_count, world.get_chunk_count()])


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
