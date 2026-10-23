extends RefCounted

const SaveServiceScript = preload("res://src/infrastructure/persistence/save_service.gd")

var results: Array[Dictionary] = []
var _temp_dir := ""


func run() -> Array[Dictionary]:
	_temp_dir = ProjectSettings.globalize_path("user://").path_join("save_service_tests")
	DirAccess.make_dir_recursive_absolute(_temp_dir)
	_test_header_contract()
	_test_atomic_save_round_trip()
	_test_corruption_recovery_preserves_file()
	_test_v1_migration_adds_progression()
	_test_committed_fixtures_load()
	_test_future_version_rejected()
	_cleanup()
	return results


func _test_header_contract() -> void:
	var header: Dictionary = SaveServiceScript.build_header(3, 137042)
	for field: String in SaveServiceScript.REQUIRED_HEADER_FIELDS:
		_assert(header.has(field), "Header contains %s" % field)
	_assert(int(header.save_schema_version) == SaveServiceScript.SAVE_SCHEMA_VERSION, "Header carries the current schema version")
	_assert(int(header.seed) == 137042, "Header preserves the seed")


func _test_atomic_save_round_trip() -> void:
	var path := _temp_dir.path_join("atomic.json")
	var document := {"header": {"save_schema_version": 2, "game_version": "test", "worldgen_version": 3, "seed": 7}, "payload": {"value": 42}}
	var save_result: Dictionary = SaveServiceScript.save_game(path, document)
	_assert(bool(save_result.ok), "Atomic save succeeds: %s" % String(save_result.error))
	_assert(FileAccess.file_exists(path), "Saved file exists at the target path")
	_assert(not FileAccess.file_exists(path + ".tmp"), "No temporary file remains after an atomic save")
	var load_result: Dictionary = SaveServiceScript.load_game(path)
	_assert(bool(load_result.ok), "Load succeeds: %s" % String(load_result.error))
	if bool(load_result.ok):
		_assert(int(load_result.data.payload.value) == 42, "Payload round-trips through save/load")


func _test_corruption_recovery_preserves_file() -> void:
	var path := _temp_dir.path_join("corrupt.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"header\": {\"save_schema")
	file.close()
	var load_result: Dictionary = SaveServiceScript.load_game(path)
	_assert(not bool(load_result.ok), "Corrupted save fails to load")
	_assert(not String(load_result.error).is_empty(), "Corrupted save reports a readable error")
	_assert(FileAccess.file_exists(path + ".corrupt"), "Corrupted file is preserved with a .corrupt suffix")
	_assert(not FileAccess.file_exists(path), "The corrupted file no longer occupies the live slot")


func _test_v1_migration_adds_progression() -> void:
	var path := _temp_dir.path_join("v1.json")
	var v1_document := {
		"header": {"save_schema_version": 1, "game_version": "0.1.0-dev", "worldgen_version": 3, "seed": 11},
		"world": {"width": 8},
	}
	SaveServiceScript.save_game(path, v1_document)
	var load_result: Dictionary = SaveServiceScript.load_game(path)
	_assert(bool(load_result.ok), "v1 save migrates successfully: %s" % String(load_result.error))
	if bool(load_result.ok):
		var header: Dictionary = load_result.data.header
		_assert(int(header.save_schema_version) == SaveServiceScript.SAVE_SCHEMA_VERSION, "Migration reaches current schema through the v1-v2-v3 chain")
		_assert(load_result.data.has("progression"), "v1->v2 migration adds the progression section")


func _test_committed_fixtures_load() -> void:
	# Spec §15: committed save fixtures must stay loadable as the schema and
	# migration chain evolve, including the hand-derived v1 fixture.
	var fixture_dir := "res://tests/fixtures/saves"
	var dir := DirAccess.open(fixture_dir)
	if dir == null:
		_assert(false, "Save fixture directory exists at %s" % fixture_dir)
		return
	var fixture_names: Array[String] = []
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			fixture_names.append(file_name)
	_assert(fixture_names.size() >= 6, "All documented save fixtures are committed (found %d)" % fixture_names.size())
	for file_name: String in fixture_names:
		var load_result: Dictionary = SaveServiceScript.load_game(fixture_dir.path_join(file_name))
		_assert(bool(load_result.ok), "Fixture %s loads: %s" % [file_name, String(load_result.error)])
		if bool(load_result.ok):
			_assert(int(load_result.data.header.save_schema_version) == SaveServiceScript.SAVE_SCHEMA_VERSION, "Fixture %s reaches the current schema" % file_name)
			_assert(load_result.data.has("world"), "Fixture %s carries world state" % file_name)


func _test_future_version_rejected() -> void:
	var path := _temp_dir.path_join("future.json")
	var future_document := {
		"header": {"save_schema_version": SaveServiceScript.SAVE_SCHEMA_VERSION + 5, "game_version": "future", "worldgen_version": 3, "seed": 3},
	}
	SaveServiceScript.save_game(path, future_document)
	var load_result: Dictionary = SaveServiceScript.load_game(path)
	_assert(not bool(load_result.ok), "Saves from newer game versions are rejected")
	_assert(String(load_result.error).contains("newer"), "Rejection explains the version gap")


func _cleanup() -> void:
	DirAccess.remove_absolute(_temp_dir.path_join("atomic.json"))
	DirAccess.remove_absolute(_temp_dir.path_join("v1.json"))
	DirAccess.remove_absolute(_temp_dir.path_join("future.json"))
	DirAccess.remove_absolute(_temp_dir.path_join("corrupt.json.corrupt"))
	DirAccess.remove_absolute(_temp_dir)


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
