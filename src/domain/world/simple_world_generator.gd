class_name SimpleWorldGenerator
extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const DeterministicRngScript = preload("res://src/domain/common/deterministic_rng.gd")
const WorldGridScript = preload("res://src/domain/world/world_grid.gd")


func generate(config: Dictionary, seed_value: int):
	var requested_size := _validated_world_size(config.get("world_size", [96, 72]))
	var width := maxi(32, int(requested_size[0]))
	var height := maxi(24, int(requested_size[1]))
	var chunk_size := maxi(4, int(config.get("chunk_size", 16)))
	var rng := DeterministicRngScript.new(seed_value)
	var world := WorldGridScript.new(width, height, chunk_size)
	var surface_heights := _build_surface(width, height, rng)
	_fill_terrain(world, surface_heights, rng)
	var start_cell := _carve_start_burrow(world, surface_heights)
	world.metadata = {
		"seed": seed_value,
		"generator": "phase_1_simple",
		"worldgen_version": int(config.get("worldgen_version", 1)),
		"surface_heights": surface_heights,
		"start_cell": start_cell,
	}
	world.mark_all_chunks_dirty()
	return world


func _validated_world_size(value: Variant) -> Array[int]:
	if value is Array and value.size() == 2 and int(value[0]) >= 32 and int(value[1]) >= 24:
		return [int(value[0]), int(value[1])]
	return [96, 72]


func _build_surface(width: int, height: int, rng) -> PackedInt32Array:
	var surface := PackedInt32Array()
	surface.resize(width)
	var current := maxi(3, int(height * 0.08))
	for x: int in range(width):
		if x % 3 == 0:
			current = clampi(current + rng.next_int(-1, 1), 3, maxi(4, int(height * 0.14)))
		surface[x] = current
	return surface


func _fill_terrain(world, surface: PackedInt32Array, rng) -> void:
	for y: int in range(world.height):
		for x: int in range(world.width):
			var cell := Vector2i(x, y)
			var protected_cell: bool = x == 0 or x == world.width - 1 or y == world.height - 1
			if y < surface[x]:
				world.initialize_cell(cell, CellDataScript.TerrainMaterial.EMPTY, true, protected_cell)
				continue
			var depth_ratio := float(y - surface[x]) / maxi(1, world.height - surface[x])
			var material := CellDataScript.TerrainMaterial.SOFT_SOIL
			if depth_ratio > 0.72:
				material = CellDataScript.TerrainMaterial.STONE if rng.next_int(0, 99) < 46 else CellDataScript.TerrainMaterial.DAMP_CLAY
			elif depth_ratio > 0.42:
				material = CellDataScript.TerrainMaterial.DAMP_CLAY if rng.next_int(0, 99) < 42 else CellDataScript.TerrainMaterial.SOFT_SOIL
			elif rng.next_int(0, 99) < 13:
				material = CellDataScript.TerrainMaterial.LOOSE_SOIL
			world.initialize_cell(cell, material, false, protected_cell)


func _carve_start_burrow(world, surface: PackedInt32Array) -> Vector2i:
	var center_x: int = world.width / 2
	var start_y: int = mini(world.height - 9, surface[center_x] + 6)
	var start_cell := Vector2i(center_x, start_y + 2)
	for y: int in range(start_y, start_y + 5):
		for x: int in range(center_x - 5, center_x + 6):
			var relative := Vector2(float(x - center_x) / 5.5, float(y - start_cell.y) / 2.6)
			if relative.length_squared() <= 1.0:
				world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, true, false)
	for y: int in range(surface[center_x], start_y + 2):
		world.initialize_cell(Vector2i(center_x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, true, false)
	return start_cell
