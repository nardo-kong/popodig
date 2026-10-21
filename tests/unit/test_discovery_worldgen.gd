extends "res://tests/test_case.gd"

const Generator = preload("res://src/domain/worldgen/structured_world_generator.gd")
const Context = preload("res://src/domain/worldgen/world_gen_context.gd")
const Validator = preload("res://src/domain/worldgen/world_validator.gd")
const Discovery = preload("res://src/domain/features/discovery_system.gd")


func run() -> Array[Dictionary]:
	var config: Dictionary = AppConfig.get_document("worldgen")
	var generated = Generator.new().generate_result(config, 137042)
	assert_true(generated.success, "v7 canonical world passes discovery validators")
	var context := Context.new(config, 137042)
	context.world = generated.world
	context.feature_registry = generated.feature_registry
	var failures: Array[Dictionary] = []
	var metrics: Dictionary = {}
	Validator.new()._validate_discovery_economy(context, failures, metrics)
	assert_true(failures.is_empty(), "Valid discovery economy has no false failures")
	assert_equal(metrics.discovery_economy.unique_collection_definitions, 18, "Every collection entry is attainable in one generated world")
	assert_true(metrics.discovery_economy.initial_visible_promise_categories.size() >= 2, "Starting fringe offers unequal promises")
	for feature in context.feature_registry.get_features("discovery"):
		if str(feature.metadata.definition_id) == "amber_drop":
			context.world.set_feature_id(feature.anchor, -1)
			context.feature_registry.remove_feature(feature.id)
	failures.clear()
	Validator.new()._validate_discovery_economy(context, failures, {})
	assert_true(failures.any(func(failure: Dictionary) -> bool: return failure.code == "COLLECTION_INCOMPLETE"), "Validator detects an impossible collection completion")
	Discovery.ensure_collectibles(context)
	failures.clear()
	Validator.new()._validate_discovery_economy(context, failures, {})
	assert_true(failures.is_empty(), "Collection repair restores missing content without invalidating the economy")
	return results
