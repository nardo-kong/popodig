extends RefCounted

# Phase 11 unit tests: the synthesized audio bank is complete and loadable,
# and the AudioDirector's bus/volume logic behaves (docs/art/13_AUDIO_VFX_SPEC.md).

const AudioDirectorScript = preload("res://src/presentation/audio/audio_director.gd")
const AppConfigServiceScript = preload("res://src/infrastructure/config/app_config.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	results = []
	_test_bank_files_exist_and_load()
	_test_dig_material_map_covers_terrain_materials()
	_test_volume_config_defaults()
	_test_bus_indices_stable()
	return results


func _test_bank_files_exist_and_load() -> void:
	for stream_key: String in AudioDirectorScript.STREAMS:
		var stream: AudioStream = AudioDirectorScript.STREAMS[stream_key]
		_assert(stream != null, "Stream '%s' preloads" % stream_key)
		_assert(stream is AudioStreamWAV, "Stream '%s' is a WAV resource" % stream_key)
		var ambience: AudioStream = AudioDirectorScript.AMBIENCE_STREAM
		_assert(ambience != null, "Ambience loop preloads")


func _test_dig_material_map_covers_terrain_materials() -> void:
	# Terrain materials 1-6 (SOFT_SOIL..ROOT_SOIL) must all have a dig impact.
	for material: int in range(1, 7):
		_assert(AudioDirectorScript.MATERIAL_DIG_KEYS.has(material), "Material %d has a dig impact" % material)


func _test_volume_config_defaults() -> void:
	var config_service := AppConfigServiceScript.new()
	config_service.reload_all()
	var config: Dictionary = config_service.get_document("app").get("audio", {})
	var accessibility: Dictionary = config_service.get_document("app").get("accessibility", {})
	config_service.free()
	_assert(not config.is_empty(), "app.json exposes an audio section")
	_assert(config.has("master_volume") and config.has("sfx_volume") and config.has("ambience_volume"), "Audio section carries the three volume controls")
	for key: String in ["master_volume", "sfx_volume", "ambience_volume"]:
		var value := float(config.get(key, -1.0))
		_assert(value >= 0.0 and value <= 1.0, "%s is a normalized volume" % key)
	_assert(accessibility.has("reduced_particles") and accessibility.has("reduced_shake"), "Accessibility section carries reduced-particles and reduced-shake flags")


func _test_bus_indices_stable() -> void:
	var before_count := AudioServer.bus_count
	var director := AudioDirectorScript.new()
	director._ensure_buses()
	director.apply_volumes({"master_volume": 0.8, "sfx_volume": 0.9, "ambience_volume": 0.7})
	director.free()
	_assert(AudioServer.get_bus_index("SFX") >= 0, "SFX bus exists after director setup")
	_assert(AudioServer.get_bus_index("Ambience") >= 0, "Ambience bus exists after director setup")
	_assert(AudioServer.bus_count <= before_count + 2, "Director creates at most its two buses")


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
