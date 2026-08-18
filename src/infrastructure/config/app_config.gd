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
	if _documents.has("app") and _documents.has("worldgen"):
		var app_worldgen_version := int((_documents.app as Dictionary).get("worldgen_version", 0))
		var generator_worldgen_version := int((_documents.worldgen as Dictionary).get("worldgen_version", 0))
		if app_worldgen_version != generator_worldgen_version:
			_load_errors.append("app/worldgen version mismatch: %d != %d" % [app_worldgen_version, generator_worldgen_version])
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
	requested = profile_for_build(requested, OS.is_debug_build())
	var profiles: Dictionary = profiles_document.get("profiles", {})
	if not profiles.has(requested):
		_load_errors.append("Unknown build profile: %s" % requested)
		requested = "development"
	_profile_name = requested
	_profile = profiles.get(requested, {}).duplicate(true)


static func profile_for_build(requested: String, debug_build: bool) -> String:
	return requested if debug_build else "release"


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
			if int(data.get("initial_mouse_count", 0)) <= 0:
				return "initial_mouse_count must be positive"
			var digging: Dictionary = data.get("digging", {})
			if float(digging.get("base_dig_seconds", 0.0)) <= 0.0:
				return "digging.base_dig_seconds must be positive"
			if float(digging.get("simulation_step_seconds", 0.0)) <= 0.0:
				return "digging.simulation_step_seconds must be positive"
			var mouse: Dictionary = data.get("mouse", {})
			if float(mouse.get("move_cells_per_second", 0.0)) <= 0.0:
				return "mouse.move_cells_per_second must be positive"
			if float(mouse.get("dig_work_per_second", 0.0)) <= 0.0:
				return "mouse.dig_work_per_second must be positive"
			for unit_value: String in [
				"initial_hunger",
				"food_restore",
				"hunger_seek_threshold",
				"hunger_critical_threshold",
				"initial_rest",
				"rest_seek_threshold",
				"rest_critical_threshold",
				"rest_resume_threshold",
			]:
				var normalized := float(mouse.get(unit_value, -1.0))
				if normalized < 0.0 or normalized > 1.0:
					return "mouse.%s must be between zero and one" % unit_value
			if float(mouse.get("hunger_per_second", -1.0)) < 0.0:
				return "mouse.hunger_per_second must not be negative"
			if float(mouse.get("rest_drain_per_second", -1.0)) < 0.0:
				return "mouse.rest_drain_per_second must not be negative"
			if float(mouse.get("rest_recover_per_second", 0.0)) <= 0.0:
				return "mouse.rest_recover_per_second must be positive"
			if float(mouse.get("hunger_critical_threshold", 0.0)) < float(mouse.get("hunger_seek_threshold", 0.0)):
				return "mouse hunger thresholds are inverted"
			if float(mouse.get("rest_critical_threshold", 1.0)) > float(mouse.get("rest_seek_threshold", 0.0)):
				return "mouse rest thresholds are inverted"
			if float(mouse.get("rest_resume_threshold", 0.0)) < float(mouse.get("rest_seek_threshold", 0.0)):
				return "mouse rest resume threshold is too low"
			var jobs: Dictionary = data.get("jobs", {})
			if float(jobs.get("unreachable_retry_seconds", 0.0)) <= 0.0:
				return "jobs.unreachable_retry_seconds must be positive"
			if float(jobs.get("emergency_priority", 0.0)) <= float(jobs.get("haul_priority", 0.0)):
				return "jobs.emergency_priority must exceed haul_priority"
			if float(jobs.get("haul_priority", 0.0)) <= float(jobs.get("dig_priority", 0.0)):
				return "jobs.haul_priority must exceed dig_priority"
			if float(jobs.get("zone_setup_priority", 0.0)) <= float(jobs.get("dig_priority", 0.0)):
				return "jobs.zone_setup_priority must exceed dig_priority"
			if float(jobs.get("zone_setup_priority", 0.0)) >= float(jobs.get("haul_priority", 0.0)):
				return "jobs.zone_setup_priority must remain below haul_priority"
			if float(jobs.get("seal_priority", 0.0)) <= float(jobs.get("haul_priority", 0.0)):
				return "jobs.seal_priority must exceed haul_priority"
			if float(jobs.get("seal_priority", 0.0)) >= float(jobs.get("emergency_priority", 0.0)):
				return "jobs.seal_priority must remain below emergency_priority"
			var pathfinding: Dictionary = data.get("pathfinding", {})
			if int(pathfinding.get("max_walkable_water_units", -1)) < 0:
				return "pathfinding.max_walkable_water_units must not be negative"
			var zones: Dictionary = data.get("zones", {})
			if int(zones.get("setup_material_per_zone", 0)) <= 0:
				return "zones.setup_material_per_zone must be positive"
			if int(zones.get("storage_capacity_per_cell", 0)) <= 0:
				return "zones.storage_capacity_per_cell must be positive"
			if int(zones.get("sleeping_capacity_per_cell", 0)) <= 0:
				return "zones.sleeping_capacity_per_cell must be positive"
			if int(zones.get("dry_water_max_units", -1)) < 0:
				return "zones.dry_water_max_units must not be negative"
			if int(zones.get("dry_water_max_units", -1)) > int(pathfinding.get("max_walkable_water_units", -1)):
				return "zones.dry_water_max_units must not exceed pathfinding.max_walkable_water_units"
			var water: Dictionary = data.get("water", {})
			for positive_name: String in ["cell_capacity_units", "max_transfers_per_step", "source_release_per_step", "stable_quiet_steps", "danger_radius", "danger_water_units"]:
				if int(water.get(positive_name, 0)) <= 0:
					return "water.%s must be positive" % positive_name
			if float(water.get("simulation_step_seconds", 0.0)) <= 0.0:
				return "water.simulation_step_seconds must be positive"
			if int(water.get("breach_initial_units", -1)) < 0:
				return "water.breach_initial_units must not be negative"
			if int(water.get("breach_initial_units", 0)) > int(water.get("cell_capacity_units", 0)):
				return "water.breach_initial_units must not exceed cell capacity"
			if int(pathfinding.get("max_walkable_water_units", 0)) >= int(water.get("cell_capacity_units", 0)):
				return "walkable water threshold must remain below cell capacity"
			if int(water.get("danger_water_units", 0)) > int(water.get("cell_capacity_units", 0)):
				return "water.danger_water_units must not exceed cell capacity"
		"worldgen":
			var size_value: Variant = data.get("world_size")
			if not size_value is Array or size_value.size() != 2:
				return "world_size must contain exactly two values"
			if int(size_value[0]) < 32 or int(size_value[1]) < 24:
				return "world_size is below the Phase 1 safe minimum"
			if int(data.get("chunk_size", 0)) <= 0:
				return "chunk_size must be positive"
			if int(data.get("worldgen_version", 0)) < 2:
				return "worldgen_version must be at least 2 for structured generation"
			if int(data.get("protected_margin", 0)) <= 0:
				return "protected_margin must be positive"
			if int(data.get("max_repair_passes", -1)) < 0 or int(data.get("max_repair_passes", 0)) > 8:
				return "max_repair_passes must be between zero and eight"
			if int(data.get("max_generation_attempts", 0)) <= 0 or int(data.get("max_generation_attempts", 0)) > 5:
				return "max_generation_attempts must be between one and five"
			var surface: Dictionary = data.get("surface", {})
			var surface_minimum := float(surface.get("minimum_ratio", 0.0))
			var surface_maximum := float(surface.get("maximum_ratio", 0.0))
			if surface_minimum <= 0.0 or surface_maximum <= surface_minimum or surface_maximum >= 0.25:
				return "surface ratios must be ordered within the upper quarter of the world"
			var strata: Array = data.get("strata", [])
			if strata.size() != 4:
				return "structured worldgen requires exactly four V1 strata"
			var previous_ratio := 0.0
			for index: int in range(strata.size()):
				if not strata[index] is Dictionary:
					return "strata entries must be objects"
				var stratum: Dictionary = strata[index]
				var end_ratio := float(stratum.get("end_ratio", 0.0))
				if int(stratum.get("id", -1)) != index or end_ratio <= previous_ratio or end_ratio > 1.0:
					return "strata IDs and end ratios must be ordered"
				previous_ratio = end_ratio
			if not is_equal_approx(previous_ratio, 1.0):
				return "final stratum must end at 1.0"
			var batch_gate: Dictionary = data.get("batch_gate", {})
			if int(batch_gate.get("curated_seed_count", 0)) != 32 or int(batch_gate.get("random_seed_count", 0)) != 256:
				return "authoritative worldgen batch must remain 32 curated plus 256 random seeds"
			for rate_name: String in ["required_final_valid_rate", "minimum_raw_valid_rate", "maximum_retry_rate", "maximum_repair_rate"]:
				var rate := float(batch_gate.get(rate_name, -1.0))
				if rate < 0.0 or rate > 1.0:
					return "batch_gate.%s must be between zero and one" % rate_name
			var feature_counts: Dictionary = data.get("feature_counts", {})
			for count_name: String in ["additional_root_clusters", "additional_reservoirs", "rock_masses", "natural_cavities", "unstable_pockets"]:
				if int(feature_counts.get(count_name, -1)) < 0:
					return "feature_counts.%s must not be negative" % count_name
			var validation: Dictionary = data.get("validation", {})
			for threshold_name: String in ["minimum_start_open_cells", "early_food_max_dig_cost", "first_hazard_min_dig_cost", "decision_knot_max_dig_cost", "minimum_decision_knots"]:
				if int(validation.get(threshold_name, 0)) <= 0:
					return "validation.%s must be positive" % threshold_name
			var signal_fields: Dictionary = data.get("signal_fields", {})
			for channel_name: String in ["root_density", "moisture", "instability"]:
				var channel: Dictionary = signal_fields.get(channel_name, {})
				var thresholds: Array = channel.get("thresholds", [])
				if thresholds.size() != 3 or int(thresholds[0]) <= 0 or int(thresholds[1]) <= int(thresholds[0]) or int(thresholds[2]) <= int(thresholds[1]):
					return "signal_fields.%s thresholds must contain three increasing positive values" % channel_name
			var root_feature: Dictionary = data.get("root_feature", {})
			for count_name: String in ["required_food_reserve", "optional_food_reserve", "initial_food_yield", "forage_radius"]:
				if int(root_feature.get(count_name, 0)) <= 0:
					return "root_feature.%s must be positive" % count_name
			if float(root_feature.get("forage_interval_seconds", 0.0)) <= 0.0:
				return "root_feature.forage_interval_seconds must be positive"
	return ""
