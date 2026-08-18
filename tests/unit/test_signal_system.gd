extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const FeatureRegistryScript = preload("res://src/domain/worldgen/feature_registry.gd")
const GeneratedFeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")
const SignalSystemScript = preload("res://src/domain/features/signal_system.gd")
const WorldChunkViewScript = preload("res://src/presentation/world/world_chunk_view.gd")
const WorldGridScript = preload("res://src/domain/world/world_grid.gd")

const SIGNAL_CONFIG := {
	"root_density": {"thresholds": [1, 3, 5]},
	"moisture": {"thresholds": [1, 3, 5]},
	"instability": {"thresholds": [35, 60, 80]},
}

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_geometry_driven_falloff_and_bands()
	_test_runtime_dirty_region_and_recognition()
	_test_normal_presentation_hides_exact_geometry()
	return results


func _test_geometry_driven_falloff_and_bands() -> void:
	var context: Dictionary = _fixture(false)
	var world = context.world
	var signals = context.signals
	_assert_equal(world.get_root_signal(Vector2i(7, 4)), 5, "Root signal reaches configured strength on final feature geometry")
	_assert_equal(world.get_root_signal(Vector2i(6, 4)), 4, "Root signal uses deterministic Manhattan falloff")
	_assert_equal(world.get_root_signal(Vector2i(4, 4)), 2, "Root signal preserves a weak information gradient away from the feature")
	_assert_equal(world.get_root_signal(Vector2i(2, 4)), 0, "Root signal ends at its finite configured radius")
	_assert_equal(signals.get_band("root_density", Vector2i(2, 4)), SignalSystemScript.Band.NONE, "Zero signal maps to NONE")
	_assert_equal(signals.get_band("root_density", Vector2i(4, 4)), SignalSystemScript.Band.WEAK, "Low signal maps to WEAK")
	_assert_equal(signals.get_band("root_density", Vector2i(5, 4)), SignalSystemScript.Band.NOTICEABLE, "Mid signal maps to NOTICEABLE")
	_assert_equal(signals.get_band("root_density", Vector2i(7, 4)), SignalSystemScript.Band.STRONG, "Source signal maps to STRONG")
	var first_values: Array[int] = []
	for index: int in range(world.width * world.height):
		first_values.append(int(world.get_root_signal(world.index_to_cell(index))))
		signals.rebuild_all()
	var deterministic := true
	var exterior_clear := true
	for index: int in range(world.width * world.height):
		var cell: Vector2i = world.index_to_cell(index)
		deterministic = deterministic and first_values[index] == int(world.get_root_signal(cell))
		if world.is_exterior(cell):
			exterior_clear = exterior_clear and world.get_root_signal(cell) == 0
	_assert_true(deterministic, "Signal field rebuild is deterministic")
	_assert_true(exterior_clear, "Signal field never leaks into EXTERIOR")


func _test_runtime_dirty_region_and_recognition() -> void:
	var context: Dictionary = _fixture(true)
	var world = context.world
	var signals = context.signals
	_assert_equal(signals.get_recognition_level("root_cluster"), SignalSystemScript.RecognitionLevel.UNKNOWN, "Distant unopened Root begins UNKNOWN")
	world.set_excavated(Vector2i(2, 4), true)
	_assert_equal(signals.get_recognition_level("root_cluster"), SignalSystemScript.RecognitionLevel.ENCOUNTERED, "Advancing the frontier into a clue changes recognition to ENCOUNTERED")
	_assert_equal(signals.get_runtime_update_count(), 1, "One terrain mutation performs one bounded signal refresh")
	var dirty: Array[Dictionary] = signals.get_dirty_regions()
	_assert_equal(dirty.size(), 2, "Runtime terrain change refreshes the two implemented static signal channels")
	var bounded := true
	for entry: Dictionary in dirty:
		var region: Rect2i = entry.region
		bounded = bounded and region.size.x <= 11 and region.size.y <= 9
	_assert_true(bounded, "Runtime signal refresh records bounded dirty regions")
	_assert_true(signals.set_recognition_level("root_cluster", SignalSystemScript.RecognitionLevel.UNDERSTOOD), "Recognition can advance to UNDERSTOOD")
	_assert_true(not signals.set_recognition_level("root_cluster", SignalSystemScript.RecognitionLevel.UNKNOWN), "Recognition cannot regress after understanding")
	var clue: String = signals.get_qualitative_clue("root_density", Vector2i(4, 4))
	_assert_true(not clue.is_empty() and not clue.contains("2"), "Player clue text is qualitative and does not expose raw field values")


func _test_normal_presentation_hides_exact_geometry() -> void:
	var context: Dictionary = _fixture(false)
	var view = WorldChunkViewScript.new()
	view.world_grid = context.world
	view.feature_registry = context.registry
	_assert_equal(
		view.get_display_material(Vector2i(7, 4)),
		CellDataScript.TerrainMaterial.SOFT_SOIL,
		"Hidden Root geometry renders as its ordinary stratum material"
	)
	context.feature.hidden = false
	_assert_equal(
		view.get_display_material(Vector2i(7, 4)),
		CellDataScript.TerrainMaterial.ROOT_SOIL,
		"Revealed Root geometry renders as persistent Root structure"
	)
	view.free()


func _fixture(runtime_tracking: bool) -> Dictionary:
	var world := WorldGridScript.new(15, 9, 5)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var exterior := x == 0 or y == 0 or x == world.width - 1 or y == world.height - 1
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false, exterior, exterior)
	world.metadata = {"start_cell": Vector2i(1, 4), "seed": 606}
	var registry := FeatureRegistryScript.new()
	var feature := GeneratedFeatureScript.new(
		"root_cluster",
		Vector2i(7, 4),
		[Vector2i(7, 4), Vector2i(8, 4)],
		true
	)
	registry.add_feature(feature)
	for cell: Vector2i in feature.cells:
		world.set_feature_id(cell, feature.id)
		world.set_material(cell, CellDataScript.TerrainMaterial.ROOT_SOIL)
	var emitters: Array = [{
		"feature_id": feature.id,
		"channel": "root_density",
		"anchor": feature.anchor,
		"strength": 5,
		"falloff": 1,
	}]
	var signals := SignalSystemScript.new()
	signals.configure(world, registry, emitters, SIGNAL_CONFIG, true, runtime_tracking)
	return {"world": world, "registry": registry, "feature": feature, "signals": signals}


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	results.append({"passed": actual == expected, "description": description, "details": "Expected %s, got %s" % [expected, actual]})
