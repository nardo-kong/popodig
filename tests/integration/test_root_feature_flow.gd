extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const ColonySimulationScript = preload("res://src/domain/colony/colony_simulation.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const FeatureRegistryScript = preload("res://src/domain/worldgen/feature_registry.gd")
const GeneratedFeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const SignalSystemScript = preload("res://src/domain/features/signal_system.gd")
const WorldGridScript = preload("res://src/domain/world/world_grid.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")

const BALANCE := {
	"initial_mouse_count": 1,
	"digging": {"base_dig_seconds": 0.1},
	"pathfinding": {"max_walkable_water_units": 1},
	"zones": {"setup_material_per_zone": 1, "dry_water_max_units": 0},
}
const WORLDGEN_CONFIG := {
	"signal_fields": {
		"root_density": {"thresholds": [1, 3, 5]},
		"moisture": {"thresholds": [1, 3, 5]},
		"instability": {"thresholds": [35, 60, 80]},
	},
	"root_feature": {
		"required_food_reserve": 7,
		"optional_food_reserve": 5,
		"initial_food_yield": 4,
		"forage_interval_seconds": 0.5,
		"forage_radius": 2,
	},
}

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_signal_reveal_reaction_adaptation_stable_state()
	return results


func _test_signal_reveal_reaction_adaptation_stable_state() -> void:
	var context: Dictionary = _fixture()
	var world = context.world
	var dig = context.dig
	var colony = context.colony
	var feature = context.feature
	var signals = colony.get_signal_system()
	var roots = colony.get_root_feature_system()
	var reactions: Array[Dictionary] = []
	var states: Array[String] = []
	roots.feature_reacted.connect(func(_feature_id: int, reaction: Dictionary) -> void: reactions.append(reaction.duplicate(true)))
	roots.feature_state_changed.connect(func(_feature_id: int, state: String) -> void: states.append(state))
	_assert_equal(signals.get_recognition_level("root_cluster"), SignalSystemScript.RecognitionLevel.UNKNOWN, "Root lifecycle begins with UNKNOWN recognition before a clue reaches open space")
	var replay_ok := true
	var work_cell := Vector2i(1, 3)
	for x: int in range(2, 8):
		var target := Vector2i(x, 3)
		var designation: Dictionary = dig.designate_path([target])
		var job = dig.claim_next("integration_digger", work_cell)
		if not bool(designation.get("ok", false)) or job == null:
			replay_ok = false
			break
		var completion: Dictionary = dig.advance_job("integration_digger", job.job_id, 100.0)
		if not bool(completion.get("ok", false)) or not bool(completion.get("completed", false)):
			replay_ok = false
			break
		work_cell = target
		if x == 2:
			_assert_equal(signals.get_recognition_level("root_cluster"), SignalSystemScript.RecognitionLevel.ENCOUNTERED, "A real excavation frontier crossing the weak field advances recognition")
	_assert_true(replay_ok, "Authoritative DigSystem reaches and exposes final Root geometry")
	_assert_true(not feature.hidden, "Excavating a Root boundary reveals the persistent feature")
	_assert_equal(int(feature.metadata.get("reveal_count", 0)), 1, "Root reveal fires exactly once")
	_assert_equal(reactions.size(), 1, "Root short-term reaction fires exactly once")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.FOOD), 4, "Root exposure releases the configured initial Food yield")
	_assert_equal(signals.get_recognition_level("root_cluster"), SignalSystemScript.RecognitionLevel.UNDERSTOOD, "Root reveal advances recognition to UNDERSTOOD")
	_assert_true(states.has("REACTION") and states.has("ADAPTATION"), "Reveal executes Reaction then Adaptation lifecycle states")
	var duplicate: Dictionary = roots.reveal_feature(feature.id, Vector2i(7, 3))
	_assert_equal(String(duplicate.reason_code), "ALREADY_REVEALED", "Repeated exposure cannot duplicate the discovery reaction")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.FOOD), 4, "Repeated exposure cannot duplicate Food")
	roots.fixed_tick(3.0)
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.FOOD), 4, "Revealed Root does not produce without player-assigned Food/Forage space")
	var zones = colony.get_zone_system()
	var zone_cell := Vector2i(6, 3)
	var paint: Dictionary = zones.paint_zone(ZoneScript.Type.FOOD_FORAGE, [zone_cell])
	_assert_true(bool(paint.ok), "Player can adapt adjacent excavated space as Food/Forage")
	roots.fixed_tick(3.0)
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.FOOD), 4, "Painted but unfinished Food/Forage space does not produce")
	var zone: Zone = zones.get_zone_at(zone_cell)
	_assert_true(zone != null and zones.begin_setup(zone.zone_id).ok and zones.apply_setup_material(zone.zone_id, 1).ok, "Completing zone setup enables Root adaptation")
	for _tick: int in range(20):
		roots.fixed_tick(0.5)
	_assert_equal(roots.get_feature_state(feature.id), "STABLE_STATE", "Nearby set-up Food/Forage space advances Root to Stable State")
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.FOOD), 7, "Stable Root produces only its remaining finite reserve")
	_assert_equal(int(feature.metadata.get("food_reserve_units", -1)), 0, "Root reserve reaches explicit depletion")
	_assert_equal(int(feature.metadata.get("food_produced_total", -1)), 7, "Initial and sustained Root yields conserve the configured reserve")
	_assert_true(bool(feature.metadata.get("food_depleted", false)), "Depleted Root remains as an explicit stable landmark state")
	roots.fixed_tick(20.0)
	_assert_equal(colony.get_item_system().get_total_count(ItemSystemScript.FOOD), 7, "Depleted Root cannot create infinite Food")
	_assert_true(world.is_traversable(Vector2i(7, 3)), "Discovery changes the continuous world instead of resolving as a detached event")


func _fixture() -> Dictionary:
	var world := WorldGridScript.new(14, 7, 7)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var exterior := x == 0 or y == 0 or x == world.width - 1 or y == world.height - 1
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, false, exterior, exterior)
	world.initialize_cell(Vector2i(1, 3), CellDataScript.TerrainMaterial.SOFT_SOIL, true)
	world.metadata = {"start_cell": Vector2i(1, 3), "seed": 6613}
	var registry := FeatureRegistryScript.new()
	var feature := GeneratedFeatureScript.new(
		"root_cluster",
		Vector2i(7, 3),
		[Vector2i(7, 3), Vector2i(8, 3)],
		true
	)
	feature.metadata = {"food_opportunity": true}
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
	world.metadata.signal_emitters = emitters.duplicate(true)
	var static_signals := SignalSystemScript.new()
	static_signals.configure(world, registry, emitters, WORLDGEN_CONFIG.signal_fields, true, false)
	var path := PathServiceScript.new()
	path.configure(world, BALANCE)
	var dig := DigSystemScript.new()
	dig.configure(world, path, BALANCE)
	var colony := ColonySimulationScript.new()
	colony.configure(world, path, dig, BALANCE, registry, WORLDGEN_CONFIG)
	return {"world": world, "registry": registry, "feature": feature, "dig": dig, "colony": colony}


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	results.append({"passed": actual == expected, "description": description, "details": "Expected %s, got %s" % [expected, actual]})
