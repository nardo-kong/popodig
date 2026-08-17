extends RefCounted

const AppConfigScript = preload("res://src/infrastructure/config/app_config.gd")
const DigSystemScript = preload("res://src/domain/jobs/dig_system.gd")
const GeneratorScript = preload("res://src/domain/worldgen/structured_world_generator.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const WorldGenContextScript = preload("res://src/domain/worldgen/world_gen_context.gd")
const WorldRepairerScript = preload("res://src/domain/worldgen/world_repairer.gd")
const WorldValidatorScript = preload("res://src/domain/worldgen/world_validator.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	var loaded: Dictionary = AppConfigScript.load_json_document("res://config/worldgen/default.json")
	_assert_true(bool(loaded.ok), "Structured worldgen fixture config loads")
	if not bool(loaded.ok):
		return results
	var config: Dictionary = loaded.data
	_test_pipeline_and_contract(config)
	_test_determinism(config)
	_test_hash_covers_feature_and_signal_state(config)
	_test_registry_integrity(config)
	_test_potential_witness_executes_through_runtime_dig(config)
	_test_repair_revalidates(config)
	_test_repair_adversarial_fixtures(config)
	_test_seed_boundaries(config)
	return results


func _test_pipeline_and_contract(config: Dictionary) -> void:
	var result = GeneratorScript.new().generate_result(config, 137042)
	if not result.success:
		print("WORLDGEN_TEST_FAILURES %s" % result.report.get("validation", {}).get("failure_codes", []))
	_assert_true(result.success, "Structured pipeline produces a validator-approved default world")
	_assert_equal(result.report.stage_order, GeneratorScript.STAGE_ORDER, "Worldgen executes the locked eight-stage order")
	_assert_equal(result.world.metadata.worldgen_version, 2, "Structured topology records worldgen version 2")
	_assert_true(result.world.metadata.generation_valid, "Final world metadata records validation success")
	_assert_equal(result.world.metadata.content_hash, result.get_content_hash(), "Generation result and world share the canonical content hash")
	_assert_true(result.world.is_traversable(result.world.metadata.start_cell), "Structured start burrow is traversable interior")
	_assert_true(not result.world.is_exterior(result.world.metadata.start_cell), "Structured start burrow is never EXTERIOR")
	_assert_true(result.report.feature_count >= 20, "Structured world contains guaranteed landmarks and varied feature geometry")
	_assert_equal(result.feature_registry.get_features_by_role("landmark").size(), 6, "All six V1 macro landmarks are guaranteed")
	_assert_true(result.feature_registry.count("root_cluster") >= 1, "At least one Root Cluster is guaranteed")
	_assert_true(result.feature_registry.count("water_reservoir") >= 1, "At least one finite Water Reservoir is guaranteed")
	_assert_true(result.feature_registry.count("unstable_pocket") >= 1, "At least one Unstable Pocket is generated")
	_assert_true(result.world.metadata.signal_emitters.size() >= 3, "Major features expose stable SignalSystem emitter hooks")
	_assert_true((result.world.metadata.validation_metrics as Dictionary).decision_knot_count >= 1, "Default world contains a validated early Decision Knot")
	var independent_context = _context_from_result(config, result, int(result.report.seed))
	independent_context.decision_knots.clear()
	_assert_true(bool(WorldValidatorScript.new().validate(independent_context).valid), "Validator can derive a real Decision Knot without trusting generator nominations")
	_assert_equal(result.world.metadata.stage_order, GeneratorScript.STAGE_ORDER, "World metadata records the actual executed stage trace")
	for stage_name: String in GeneratorScript.STAGE_ORDER:
		_assert_true(result.report.stage_timings_ms.has(stage_name), "Worldgen report records %s timing" % stage_name)


func _test_determinism(config: Dictionary) -> void:
	var generator := GeneratorScript.new()
	var first = generator.generate_result(config, 424242)
	var second = generator.generate_result(config, 424242)
	var different = generator.generate_result(config, 424243)
	_assert_true(first.success and second.success and different.success, "Determinism fixture seeds all validate")
	_assert_equal(first.get_content_hash(), second.get_content_hash(), "Same seed/config reproduces the full canonical world hash")
	_assert_true(first.get_content_hash() != different.get_content_hash(), "Different seeds change structured world content")
	_assert_equal(first.world.metadata.landmark_anchors, second.world.metadata.landmark_anchors, "Landmark placement is stable for a seed")
	_assert_equal(first.feature_registry.checksum(), second.feature_registry.checksum(), "Feature IDs, geometry, state, and reserves are deterministic")
	_assert_true(first.report.get("stage_timings_ms", {}) != second.report.get("stage_timings_ms", {}) or first.get_content_hash() == second.get_content_hash(), "Non-content stage timings cannot alter canonical determinism")


func _test_registry_integrity(config: Dictionary) -> void:
	var result = GeneratorScript.new().generate_result(config, 80808)
	_assert_true(result.success, "Registry integrity fixture validates")
	var owned_cells := 0
	var all_geometry_nonempty := true
	var all_in_bounds := true
	var all_interior := true
	var all_registry_owners_match := true
	for feature in result.feature_registry.get_features_by_role("feature"):
		all_geometry_nonempty = all_geometry_nonempty and not feature.cells.is_empty()
		for cell: Vector2i in feature.cells:
			owned_cells += 1
			all_in_bounds = all_in_bounds and result.world.is_in_bounds(cell)
			all_interior = all_interior and not result.world.is_exterior(cell)
			all_registry_owners_match = all_registry_owners_match and result.world.get_feature_id(cell) == feature.id
	var world_owned_cells := 0
	var no_orphan_owner := true
	for index: int in range(result.world.width * result.world.height):
		var cell: Vector2i = result.world.index_to_cell(index)
		var owner_id: int = result.world.get_feature_id(cell)
		if owner_id < 0:
			continue
		world_owned_cells += 1
		var owner = result.feature_registry.get_feature(owner_id)
		no_orphan_owner = no_orphan_owner and owner != null and owner.cells.has(cell)
	_assert_true(all_geometry_nonempty, "Every registered feature owns non-empty geometry")
	_assert_true(all_in_bounds, "All feature geometry remains inside finite bounds")
	_assert_true(all_interior, "No feature geometry leaks into EXTERIOR")
	_assert_true(all_registry_owners_match, "Every registry cell agrees with the canonical owner layer")
	_assert_true(no_orphan_owner, "Owner layer has no orphan feature reference")
	_assert_equal(world_owned_cells, owned_cells, "FeatureRegistry and owner grid are exactly bidirectional")
	var all_landmark_masks := true
	for landmark in result.feature_registry.get_features_by_role("landmark"):
		all_landmark_masks = all_landmark_masks and result.world.is_landmark(landmark.anchor)
	_assert_true(all_landmark_masks, "Canonical landmark mask contains every registered landmark")
	var all_reserves_positive := true
	for reservoir in result.feature_registry.get_features("water_reservoir"):
		all_reserves_positive = all_reserves_positive and int(reservoir.metadata.get("reserve_units", 0)) > 0
	_assert_true(all_reserves_positive, "Every reservoir has finite positive reserve")


func _test_hash_covers_feature_and_signal_state(config: Dictionary) -> void:
	var generated = GeneratorScript.new().generate_result(config, 515151)
	_assert_true(generated.success, "Canonical-hash fixture validates")
	var feature = generated.feature_registry.get_features_by_role("feature")[0]
	var registry_before: int = generated.feature_registry.checksum()
	feature.hidden = not feature.hidden
	_assert_true(generated.feature_registry.checksum() != registry_before, "FeatureRegistry checksum covers hidden/revealed feature state")
	feature.hidden = not feature.hidden
	var context = _context_from_result(config, generated, 515151)
	var generator := GeneratorScript.new()
	var content_before: int = generator._content_hash(context)
	context.signal_emitters[0].strength = int(context.signal_emitters[0].get("strength", 0)) + 1
	_assert_true(generator._content_hash(context) != content_before, "Canonical content hash covers signal emitter state")
	var grid_hash_before: int = generated.world.content_checksum()
	generated.world.metadata.start_cell += Vector2i.RIGHT
	_assert_true(generated.world.content_checksum() != grid_hash_before, "Canonical WorldGrid hash covers the authoritative start cell")


func _test_potential_witness_executes_through_runtime_dig(config: Dictionary) -> void:
	var generated = GeneratorScript.new().generate_result(config, 137042)
	var metrics: Dictionary = generated.report.get("validation", {}).get("metrics", {})
	var witness: Array = (metrics.get("witness_paths", {}) as Dictionary).get("early_food", [])
	_assert_true(generated.success and witness.size() > 1, "Validator publishes a concrete early-food excavation witness")
	if not generated.success or witness.size() <= 1:
		return
	var balance := {
		"digging": {"base_dig_seconds": 0.8},
		"pathfinding": {"max_walkable_water_units": 1},
	}
	var path_service := PathServiceScript.new()
	path_service.configure(generated.world, balance)
	var dig_system := DigSystemScript.new()
	dig_system.configure(generated.world, path_service, balance)
	var start: Vector2i = generated.world.metadata.start_cell
	var replay_legal := true
	var excavated_count := 0
	for cell_value: Variant in witness:
		var cell: Vector2i = cell_value
		if generated.world.is_traversable(cell):
			replay_legal = replay_legal and path_service.is_reachable(start, cell)
			if not replay_legal:
				break
			continue
		var designation: Dictionary = dig_system.designate_path([cell])
		if not bool(designation.get("ok", false)):
			replay_legal = false
			break
		var job = dig_system.claim_next("witness_mouse", start)
		if job == null or job.cell != cell:
			replay_legal = false
			break
		var completion: Dictionary = dig_system.advance_job("witness_mouse", job.job_id, 1000.0)
		if not bool(completion.get("ok", false)) or not bool(completion.get("completed", false)):
			replay_legal = false
			break
		excavated_count += 1
	_assert_true(replay_legal, "Potential Excavation Planner witness is executable by the authoritative DigSystem")
	_assert_true(excavated_count > 0, "Witness replay performs real atomic excavation work")
	_assert_true(path_service.is_reachable(start, witness[-1]), "Witness replay connects the colony to its planned goal")
	var reaches_real_root := false
	for neighbor: Vector2i in generated.world.get_cardinal_neighbors(witness[-1]):
		var owner = generated.feature_registry.get_feature(generated.world.get_feature_id(neighbor))
		if owner != null and owner.type_id == "root_cluster" and bool(owner.metadata.get("food_opportunity", false)):
			reaches_real_root = true
	_assert_true(reaches_real_root, "Early-food witness ends at a boundary derived from actual Root geometry")


func _test_repair_revalidates(config: Dictionary) -> void:
	var generated = GeneratorScript.new().generate_result(config, 19191)
	_assert_true(generated.success, "Repair fixture starts from a valid canonical world")
	var context = _context_from_result(config, generated, 19191)
	var start: Vector2i = context.world.metadata.start_cell
	context.world.set_water_units(start, 2)
	var validator := WorldValidatorScript.new()
	var before: Dictionary = validator.validate(context)
	var hash_before: int = context.world.content_checksum()
	_assert_true(not bool(before.valid) and before.failure_codes.has("START_HAS_ACTIVE_WATER"), "Adversarial fixture proves Validator fails before Repair")
	var actions: Array[Dictionary] = WorldRepairerScript.new().repair(context, before, 0)
	var after: Dictionary = validator.validate(context)
	_assert_true(not actions.is_empty(), "Repair records a concrete deterministic action")
	_assert_true(context.world.content_checksum() != hash_before, "Repair changes canonical world content")
	_assert_true(bool(after.valid), "Repair reruns against real world state and converges to PASS")
	_assert_equal(context.world.get_water_units(start), 0, "Start-water Repair changes the authoritative cell layer")


func _test_repair_adversarial_fixtures(config: Dictionary) -> void:
	var validator := WorldValidatorScript.new()
	var repairer := WorldRepairerScript.new()

	var signal_generated = GeneratorScript.new().generate_result(config, 616161)
	var signal_context = _context_from_result(config, signal_generated, 616161)
	var removed_emitter: Dictionary = signal_context.signal_emitters.pop_front()
	var missing_signal: Dictionary = validator.validate(signal_context)
	_assert_true(missing_signal.failure_codes.has("SIGNAL_HOOK_MISSING"), "Adversarial fixture detects a missing major-feature signal hook")
	var signal_actions: Array[Dictionary] = repairer.repair(signal_context, missing_signal, 0)
	_assert_true(not signal_actions.is_empty() and bool(validator.validate(signal_context).valid), "Signal-hook Repair restores real emitter state and revalidates")
	_assert_true(signal_context.signal_emitters.any(func(emitter: Dictionary) -> bool: return int(emitter.feature_id) == int(removed_emitter.feature_id)), "Signal-hook Repair restores the missing feature owner")
	signal_context.signal_emitters[0].channel = "wrong_channel"
	var invalid_signal: Dictionary = validator.validate(signal_context)
	_assert_true(invalid_signal.failure_codes.has("SIGNAL_HOOK_INVALID"), "Adversarial fixture rejects malformed signal channel ownership")
	var invalid_signal_actions: Array[Dictionary] = repairer.repair(signal_context, invalid_signal, 1)
	_assert_true(not invalid_signal_actions.is_empty() and bool(validator.validate(signal_context).valid), "Signal-hook Repair canonically rebuilds malformed emitter contracts")
	signal_context.signal_emitters[0].strength = 0
	var zero_strength: Dictionary = validator.validate(signal_context)
	var strength_actions: Array[Dictionary] = repairer.repair(signal_context, zero_strength, 2)
	_assert_true(zero_strength.failure_codes.has("SIGNAL_HOOK_INVALID") and not strength_actions.is_empty(), "Repair state hashing detects and records non-channel signal corrections")
	_assert_true(bool(validator.validate(signal_context).valid), "Zero-strength signal Repair revalidates after canonical rebuild")

	var bounds_generated = GeneratorScript.new().generate_result(config, 717171)
	var bounds_context = _context_from_result(config, bounds_generated, 717171)
	var optional_rock = bounds_context.feature_registry.get_features("rock_mass").filter(func(feature) -> bool: return not feature.required)[0]
	var optional_rock_id: int = optional_rock.id
	optional_rock.cells.append(Vector2i(-1, -1))
	var invalid_bounds: Dictionary = validator.validate(bounds_context)
	_assert_true(invalid_bounds.failure_codes.has("FEATURE_OUT_OF_BOUNDS"), "Adversarial fixture detects optional Feature geometry outside the finite world")
	var bounds_actions: Array[Dictionary] = repairer.repair(bounds_context, invalid_bounds, 0)
	_assert_true(not bounds_actions.is_empty() and bounds_context.feature_registry.get_feature(optional_rock_id) == null, "Repair removes only the invalid optional Feature")
	_assert_true(bool(validator.validate(bounds_context).valid), "Optional Feature removal clears owner state and revalidates without orphans")

	var reservoir_generated = GeneratorScript.new().generate_result(config, 818181)
	var reservoir_context = _context_from_result(config, reservoir_generated, 818181)
	var reservoir = reservoir_context.feature_registry.get_features("water_reservoir")[0]
	var reservoir_id: int = reservoir.id
	reservoir.metadata.reserve_units = 0
	var empty_reserve: Dictionary = validator.validate(reservoir_context)
	_assert_true(empty_reserve.failure_codes.has("RESERVOIR_EMPTY"), "Adversarial fixture detects a non-finite reservoir contract")
	var reserve_actions: Array[Dictionary] = repairer.repair(reservoir_context, empty_reserve, 0)
	_assert_true(not reserve_actions.is_empty() and int(reservoir.metadata.reserve_units) > 0, "Reservoir Repair restores finite reserve on the existing Feature")
	_assert_true(reservoir_context.feature_registry.get_feature(reservoir_id) == reservoir and bool(validator.validate(reservoir_context).valid), "Reservoir Repair preserves identity and revalidates")

	var knot_generated = GeneratorScript.new().generate_result(config, 919191)
	var knot_context = _context_from_result(config, knot_generated, 919191)
	for root_feature in knot_context.feature_registry.get_features("root_cluster"):
		root_feature.metadata.food_opportunity = false
	var missing_knot: Dictionary = validator.validate(knot_context)
	_assert_true(missing_knot.failure_codes.has("DECISION_KNOT_MISSING"), "Adversarial fixture detects a missing Decision Knot")
	var knot_actions: Array[Dictionary] = repairer.repair(knot_context, missing_knot, 0)
	var repaired_knot: Dictionary = validator.validate(knot_context)
	_assert_true(not knot_actions.is_empty() and bool(repaired_knot.valid), "Decision Knot Repair creates real value/risk/cost/topology signatures and revalidates")
	_assert_true(repairer.repair(knot_context, repaired_knot, 1).is_empty(), "Repair is idempotent after the world reaches PASS")

	var required_generated = GeneratorScript.new().generate_result(config, 102030)
	var required_context = _context_from_result(config, required_generated, 102030)
	var required_root = required_context.feature_registry.get_features("root_cluster").filter(func(feature) -> bool: return feature.required)[0]
	required_root.cells.append(Vector2i(-1, -1))
	var invalid_required: Dictionary = validator.validate(required_context)
	var required_actions: Array[Dictionary] = repairer.repair(required_context, invalid_required, 0)
	_assert_true(required_actions.is_empty(), "Repair refuses to delete or tunnel through an invalid required Feature")
	_assert_true(required_context.feature_registry.get_feature(required_root.id) == required_root, "Failed required-Feature repair preserves the authored objective for deterministic retry")

	var food_generated = GeneratorScript.new().generate_result(config, 112233)
	var food_context = _context_from_result(config, food_generated, 112233)
	for food_feature in food_context.feature_registry.get_features("root_cluster"):
		if not bool(food_feature.metadata.get("food_opportunity", false)):
			continue
		for feature_cell: Vector2i in food_feature.cells:
			for neighbor: Vector2i in food_context.world.get_cardinal_neighbors(feature_cell):
				if not food_feature.cells.has(neighbor):
					food_context.world.set_protected(neighbor, true)
	var food_count_before: int = food_context.feature_registry.count("root_cluster")
	var persistent_food: Dictionary = validator.validate(food_context)
	_assert_true(persistent_food.failure_codes.has("EARLY_FOOD_UNREACHABLE"), "Persistent-food fixture seals every real Root boundary")
	repairer.repair(food_context, persistent_food, 0)
	var persistent_food_again: Dictionary = validator.validate(food_context)
	repairer.repair(food_context, persistent_food_again, 1)
	_assert_equal(food_context.feature_registry.count("root_cluster"), food_count_before, "Repeated unreachable-food Repair never inserts duplicate required Roots")
	_assert_true(food_context.feature_registry.get_features("root_cluster").all(func(feature) -> bool: return not feature.cells.is_empty()), "Repeated unreachable-food Repair preserves non-empty ownership geometry")

	var landmark_generated = GeneratorScript.new().generate_result(config, 445566)
	var landmark_context = _context_from_result(config, landmark_generated, 445566)
	var removed_landmark = landmark_context.feature_registry.get_features("final_warm_chamber").filter(func(feature) -> bool: return feature.role == "landmark")[0]
	landmark_context.feature_registry.remove_feature(removed_landmark.id)
	_assert_true(validator.validate(landmark_context).failure_codes.has("REQUIRED_LANDMARK_MISSING"), "Validator independently enforces the complete required-landmark type set")


func _test_seed_boundaries(config: Dictionary) -> void:
	for seed_value: int in [0, -1, 2147483647]:
		var result = GeneratorScript.new().generate_result(config, seed_value)
		_assert_true(result.success, "Boundary seed %d produces a valid finite world" % seed_value)
		_assert_equal(result.report.seed, seed_value, "Boundary seed %d remains replayable" % seed_value)
	var positive = GeneratorScript.new().generate_result(config, 2026)
	var negative = GeneratorScript.new().generate_result(config, -2026)
	_assert_true(positive.get_content_hash() != negative.get_content_hash(), "Signed seeds do not alias to the same structured world")


func _context_from_result(config: Dictionary, generated, seed_value: int):
	var context = WorldGenContextScript.new(config, seed_value, int(generated.report.attempt))
	context.world = generated.world
	context.width = generated.world.width
	context.height = generated.world.height
	context.chunk_size = generated.world.chunk_size
	context.surface_heights = generated.world.metadata.surface_heights.duplicate()
	context.depth_targets = generated.world.metadata.depth_targets.duplicate(true)
	context.feature_registry = generated.feature_registry
	context.decision_knots.assign(generated.world.metadata.decision_knots)
	context.signal_emitters.assign(generated.world.metadata.signal_emitters)
	return context


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
