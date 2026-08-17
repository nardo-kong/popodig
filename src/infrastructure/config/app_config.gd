class_name AppConfigService
extends Node

const CONFIG_PATHS: Dictionary = {
	"app": "res://config/app.json",
	"build_profiles": "res://config/build_profiles.json",
	"balance": "res://config/balance/core.json",
	"worldgen": "res://config/worldgen/default.json",
}

var _documents: Dictionary = {}
var _profile_name: String = "development"
var _profile: Dictionary = {}
var _load_errors: PackedStringArray = []


func _ready() -> void:
	reload_all()


func reload_all() -> bool:
	_documents.clear()
	_load_errors.clear()
	for document_name: String in CONFIG_PATHS:
		var result := load_json_document(CONFIG_PATHS[document_name])
		if not result.ok:
			_load_errors.append("%s: %s" % [document_name, result.error])
			continue
		var validation_error := validate_document(document_name, result.data)
		if not validation_error.is_empty():
			_load_errors.append("%s: %s" % [document_name, validation_error])
			continue
		_documents[document_name] = result.data
	_resolve_profile()
	return _load_errors.is_empty()


func get_document(document_name: String) -> Dictionary:
	return _documents.get(document_name, {}).duplicate(true)


func get_value(document_name: String, key: String, fallback: Variant = null) -> Variant:
	var document: Dictionary = _documents.get(document_name, {})
	return document.get(key, fallback)


func get_profile_name() -> String:
	return _profile_name


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


func debug_tools_enabled() -> bool:
	return bool(_profile.get("debug_tools", false))


func verbose_logging_enabled() -> bool:
	return bool(_profile.get("verbose_logging", false))


func cheats_enabled() -> bool:
	return bool(_profile.get("allow_cheats", false))


func get_load_errors() -> PackedStringArray:
	return _load_errors.duplicate()


func _resolve_profile() -> void:
	var profiles_document: Dictionary = _documents.get("build_profiles", {})
	var requested := _command_line_profile()
	if requested.is_empty():
		requested = String(profiles_document.get("default_profile", "development"))
	if not OS.is_debug_build() and requested == "development":
		requested = "release"
	var profiles: Dictionary = profiles_document.get("profiles", {})
	if not profiles.has(requested):
		_load_errors.append("Unknown build profile: %s" % requested)
		requested = "development"
	_profile_name = requested
	_profile = profiles.get(requested, {}).duplicate(true)


func _command_line_profile() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--profile="):
			return argument.trim_prefix("--profile=").strip_edges().to_lower()
	return ""


static func load_json_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "File not found: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}, "error": "Unable to open: %s" % path}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		return {
			"ok": false,
			"data": {},
			"error": "JSON line %d: %s" % [json.get_error_line(), json.get_error_message()],
		}
	if not json.data is Dictionary:
		return {"ok": false, "data": {}, "error": "Root value must be an object: %s" % path}
	return {"ok": true, "data": json.data, "error": ""}


static func validate_document(document_name: String, data: Dictionary) -> String:
	if int(data.get("schema_version", 0)) < 1:
		return "schema_version must be a positive integer"
	match document_name:
		"app":
			if String(data.get("game_version", "")).is_empty():
				return "game_version is required"
		"build_profiles":
			var profiles: Dictionary = data.get("profiles", {})
			for required_profile: String in ["development", "qa", "release"]:
				if not profiles.has(required_profile):
					return "missing build profile: %s" % required_profile
		"balance":
			if int(data.get("logical_cell_size", 0)) <= 0:
				return "logical_cell_size must be positive"
		"worldgen":
			var size_value: Variant = data.get("world_size")
			if not size_value is Array or size_value.size() != 2:
				return "world_size must contain exactly two values"
			if int(size_value[0]) < 32 or int(size_value[1]) < 24:
				return "world_size is below the Phase 1 safe minimum"
			if int(data.get("chunk_size", 0)) <= 0:
				return "chunk_size must be positive"
	return ""
