extends RefCounted

const GeneratorScript = preload("res://src/domain/world/simple_world_generator.gd")
const AppConfigScript = preload("res://src/infrastructure/config/app_config.gd")
const StructuredGeneratorScript = preload("res://src/domain/worldgen/structured_world_generator.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")
const ZoneSystemScript = preload("res://src/domain/zones/zone_system.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")

const BALANCE := {
	"zones": {"setup_material_per_zone": 1},
	"pathfinding": {"max_walkable_water_units": 1},
}

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_generated_exterior_is_not_colony_space()
	_test_structured_surface_cannot_bypass_underground()
	return results


func _test_structured_surface_cannot_bypass_underground() -> void:
	var loaded: Dictionary = AppConfigScript.load_json_document("res://config/worldgen/default.json")
	var generated = StructuredGeneratorScript.new().generate_result(loaded.data, 63051)
	_assert_true(generated.success, "Structured v3 EXTERIOR fixture validates")
	var world = generated.world
	var paths := PathServiceScript.new()
	paths.configure(world, BALANCE)
	var start: Vector2i = world.metadata.start_cell
	var exterior_reachable := false
	for x: int in range(world.width):
		var sky := Vector2i(x, maxi(0, int(world.metadata.surface_heights[x]) - 1))
		exterior_reachable = exterior_reachable or paths.is_reachable(start, sky)
	_assert_true(not exterior_reachable, "Structured v3 world cannot route through sky and re-enter underground from an edge")


func _test_generated_exterior_is_not_colony_space() -> void:
	var world = GeneratorScript.new().generate(
		{"world_size": [48, 36], "chunk_size": 16, "worldgen_version": 1},
		63051
	)
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var zones := ZoneSystemScript.new()
	zones.configure(world, path_service, BALANCE)
	var items := ItemSystemScript.new()
	items.configure(world, path_service)

	var center_x: int = world.width / 2
	var surface_y: int = world.metadata.surface_heights[center_x]
	var exterior_cell := Vector2i(center_x, surface_y - 1)
	var entrance_cell := Vector2i(center_x, surface_y)
	var burrow_cell: Vector2i = world.metadata.start_cell

	_assert_true(world.is_excavated(exterior_cell) and world.is_exterior(exterior_cell), "Generated sky remains explicit excavated exterior air")
	_assert_true(not world.is_traversable(exterior_cell) and not path_service.is_walkable(exterior_cell), "Generated sky is excluded from colony pathing")
	_assert_true(path_service.find_path(burrow_cell, exterior_cell).is_empty(), "Surface opening does not make the exterior sky reachable")
	_assert_true(world.set_exterior(exterior_cell, false) and path_service.is_walkable(exterior_cell), "Path cache observes an exterior-to-interior topology change immediately")
	_assert_true(world.set_exterior(exterior_cell, true) and not path_service.is_walkable(exterior_cell), "Path cache immediately excludes a cell restored to exterior")
	_assert_equal(
		zones.inspect_cell(ZoneScript.Type.STORAGE, exterior_cell).reason_code,
		ZoneSystemScript.REASON_NOT_EXCAVATED,
		"Generated sky cannot be assigned to a colony zone"
	)
	_assert_equal(items.add_pile(ItemSystemScript.FOOD, exterior_cell, 1), -1, "Generated sky cannot hold a colony item pile")

	_assert_true(world.is_traversable(entrance_cell) and not world.is_exterior(entrance_cell), "Carved surface entrance remains interior and traversable")
	_assert_true(path_service.is_reachable(burrow_cell, entrance_cell), "Carved entrance remains connected to the underground burrow")
	_assert_true(zones.paint_zone(ZoneScript.Type.SLEEPING, [burrow_cell]).ok, "Underground cavity remains valid colony zone space")
	_assert_true(items.add_pile(ItemSystemScript.FOOD, burrow_cell, 1) > 0, "Underground cavity remains valid item storage space")


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
