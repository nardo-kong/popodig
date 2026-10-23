extends "res://tests/test_case.gd"

const World = preload("res://src/domain/world/world_grid.gd")
const Cell = preload("res://src/domain/world/cell_data.gd")
const Fog = preload("res://src/presentation/world/fog_of_war_view.gd")
const View = preload("res://src/presentation/world/discovery_view.gd")
const Registry = preload("res://src/domain/worldgen/feature_registry.gd")
const Feature = preload("res://src/domain/worldgen/generated_feature.gd")


func run() -> Array[Dictionary]:
	var world := World.new(15, 9, 4)
	for y: int in range(9):
		for x: int in range(15):
			world.initialize_cell(Vector2i(x, y), Cell.TerrainMaterial.SOFT_SOIL, false, false, false)
	world.set_excavated(Vector2i(3, 4), true, true)
	world.set_excavated(Vector2i(12, 4), true, true)
	var registry := Registry.new()
	var hidden := Feature.new("natural_cavity", Vector2i(12, 4), [Vector2i(12, 4)])
	registry.add_feature(hidden)
	world.set_feature_id(hidden.anchor, hidden.id)
	var fog := Fog.new()
	fog.configure(world, 16, 4, registry)
	fog._recompute()
	var view := View.new()
	view.configure(world, registry, fog, 16)
	assert_equal(view.signal_band(Vector2i(4, 4)), 3, "Strong promise exists immediately outside explored space")
	assert_equal(view.signal_band(Vector2i(5, 4)), 2, "Promise weakens with distance")
	assert_equal(view.signal_band(Vector2i(6, 4)), 1, "Faint promise exists at fringe")
	assert_equal(view.signal_band(Vector2i(7, 4)), 0, "Full darkness never reveals a discovery promise")
	assert_equal(view.signal_band(Vector2i(11, 4)), 0, "Undiscovered open cavity cannot reveal nearby promises")
	assert_equal(view.signal_band(Vector2i(-1, 4)), 0, "Out of bounds promise is suppressed")
	view.free()
	fog.free()
	return results
