extends RefCounted

const AppConfigScript = preload("res://src/infrastructure/config/app_config.gd")
const RngScript = preload("res://src/domain/common/deterministic_rng.gd")
const LoggerScript = preload("res://src/infrastructure/logging/game_log.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_required_config_documents()
	_test_invalid_configuration_rejection()
	_test_build_profiles()
	_test_deterministic_rng()
	_test_logging_contract()
	_test_main_scene_contract()
	return results


func _test_required_config_documents() -> void:
	for path: String in AppConfigScript.CONFIG_PATHS.values():
		var result := AppConfigScript.load_json_document(path)
		assert_true(result.ok, "Config parses: %s" % path)
		if result.ok:
			assert_equal(result.data.get("schema_version"), 1, "Config schema is v1: %s" % path)
			assert_equal(AppConfigScript.validate_document(document_name_for_path(path), result.data), "", "Config contract validates: %s" % path)


func _test_invalid_configuration_rejection() -> void:
	var malformed := AppConfigScript.load_json_document("res://tests/fixtures/invalid_json.json")
	assert_true(not malformed.ok, "Malformed JSON is rejected")
	var missing := AppConfigScript.load_json_document("res://tests/fixtures/does_not_exist.json")
	assert_true(not missing.ok, "Missing config is rejected")
	assert_true(not AppConfigScript.validate_document("worldgen", {"schema_version": 1, "world_size": [96]}).is_empty(), "Invalid world size contract is rejected")
	assert_true(not AppConfigScript.validate_document("worldgen", {"schema_version": 1, "world_size": [96, 72], "chunk_size": 0}).is_empty(), "Invalid chunk size contract is rejected")


func document_name_for_path(path: String) -> String:
	for document_name: String in AppConfigScript.CONFIG_PATHS:
		if AppConfigScript.CONFIG_PATHS[document_name] == path:
			return document_name
	return ""


func _test_build_profiles() -> void:
	var result := AppConfigScript.load_json_document("res://config/build_profiles.json")
	if not result.ok:
		assert_true(false, "Build profiles are available")
		return
	var profiles: Dictionary = result.data.get("profiles", {})
	for profile_name: String in ["development", "qa", "release"]:
		assert_true(profiles.has(profile_name), "Build profile exists: %s" % profile_name)
	assert_equal(profiles.get("release", {}).get("debug_tools"), false, "Release hides debug tools")
	assert_equal(profiles.get("release", {}).get("allow_cheats"), false, "Release disables cheats")


func _test_deterministic_rng() -> void:
	var first := RngScript.new(98421)
	var second := RngScript.new(98421)
	var first_sequence: Array[int] = []
	var second_sequence: Array[int] = []
	for index: int in range(12):
		first_sequence.append(first.next_int(-1000, 1000))
		second_sequence.append(second.next_int(-1000, 1000))
	assert_equal(first_sequence, second_sequence, "Equal seeds produce equal sequences")
	assert_equal(first.get_seed(), 98421, "Seed remains inspectable")
	assert_true(first.fork(1).next_int(0, 100000) != first.fork(2).next_int(0, 100000), "Forked streams differ")


func _test_logging_contract() -> void:
	var logger := LoggerScript.new()
	for category: String in ["WORLDGEN", "DIG", "WATER", "STABILITY", "JOB", "MOUSE", "SAVE", "QA"]:
		assert_true(logger.is_known_category(category), "Logging category exists: %s" % category)
	logger.free()


func _test_main_scene_contract() -> void:
	var main_scene_path := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	assert_equal(main_scene_path, "res://scenes/app/game_app.tscn", "Main scene is configured")
	var packed := load(main_scene_path) as PackedScene
	assert_true(packed != null, "Main scene resource loads")
	if packed == null:
		return
	var instance := packed.instantiate()
	assert_true(instance != null, "Main scene instantiates")
	assert_equal(instance.name, "GameApp", "Main scene root contract")
	instance.free()


func assert_true(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})


func assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
