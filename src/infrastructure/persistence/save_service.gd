class_name SaveService
extends RefCounted

# Phase 10 persistence (docs/tech/15_DATA_SAVE_SPEC.md):
# - JSON save documents with a versioned header;
# - sequential migration chain (v1 -> v2 -> ...), never scattered checks;
# - atomic writes (temporary file + rename) so an interrupted write cannot
#   destroy the only save;
# - corruption recovery: failed loads preserve the file with a .corrupt suffix
#   and report a user-readable error instead of silently regenerating.

const SAVE_SCHEMA_VERSION := 2
const MIGRATIONS: Array[Dictionary] = [
	{"from": 1, "to": 2, "note": "v2 adds the progression section (tutorial step/flags, language)."},
]

const HEADER_KEY := "header"
const REQUIRED_HEADER_FIELDS: Array[String] = [
	"save_schema_version",
	"game_version",
	"worldgen_version",
	"seed",
]


static func build_header(worldgen_version: int, seed: int) -> Dictionary:
	var now := Time.get_datetime_string_from_system(true)
	return {
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"worldgen_version": worldgen_version,
		"seed": seed,
		"created_at": now,
		"last_saved_at": now,
	}


static func save_game(path: String, document: Dictionary) -> Dictionary:
	var directory := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		return {"ok": false, "error": "cannot create save directory: %s" % error_string(directory_error)}
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "cannot open temporary save: %s" % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(document, "  ", false))
	file.flush()
	if file.get_error() != OK:
		file.close()
		DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "temporary save write failed"}
	file.close()
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "atomic rename failed: %s" % error_string(rename_error)}
	return {"ok": true, "error": ""}


static func load_game(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "save file not found", "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "cannot open save file", "data": {}}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		_preserve_corrupted_copy(path)
		return {"ok": false, "error": "save file is corrupted (not valid JSON)", "data": {}}
	var document: Dictionary = parsed
	var migration_result := migrate(document)
	if not migration_result.get("ok", false):
		_preserve_corrupted_copy(path)
		return {"ok": false, "error": String(migration_result.get("error", "migration failed")), "data": {}}
	return {"ok": true, "error": "", "data": document}


## Sequential migration chain: v1 -> v2 -> ... Applied in order; a document
## newer than the supported schema is rejected instead of guessed at.
static func migrate(document: Dictionary) -> Dictionary:
	if not document.has(HEADER_KEY):
		return {"ok": false, "error": "save has no header"}
	var header: Dictionary = document[HEADER_KEY]
	for field: String in REQUIRED_HEADER_FIELDS:
		if not header.has(field):
			return {"ok": false, "error": "save header missing field: %s" % field}
	var version := int(header.save_schema_version)
	if version > SAVE_SCHEMA_VERSION:
		return {"ok": false, "error": "save is from a newer game version (%d > %d)" % [version, SAVE_SCHEMA_VERSION]}
	while version < SAVE_SCHEMA_VERSION:
		var step := _find_migration(version)
		if step.is_empty():
			return {"ok": false, "error": "no migration registered for schema v%d" % version}
		var migration_error := _apply_migration(document, int(step.from), int(step.to))
		if not migration_error.is_empty():
			return {"ok": false, "error": migration_error}
		version = int(step.to)
		document[HEADER_KEY].save_schema_version = version
	return {"ok": true, "error": ""}


static func _find_migration(from_version: int) -> Dictionary:
	for step: Dictionary in MIGRATIONS:
		if int(step.from) == from_version:
			return step
	return {}


static func _apply_migration(document: Dictionary, _from_version: int, to_version: int) -> String:
	match to_version:
		2:
			# v2 introduced the progression section (tutorial step/flags, language).
			if not document.has("progression"):
				document["progression"] = {"tutorial_step": 0, "tutorial_flags": {}, "language": "zh"}
			return ""
	return "no migration implementation for schema v%d" % to_version


static func _preserve_corrupted_copy(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var backup_path := path + ".corrupt"
	DirAccess.remove_absolute(backup_path)
	DirAccess.rename_absolute(path, backup_path)


static func get_save_directory() -> String:
	return OS.get_user_data_dir().path_join("saves")
