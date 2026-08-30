class_name SettingsStore
extends RefCounted

# Phase 12 player settings persistence (docs/ux/11 player-facing UX; the
# deferred quick-load/settings decision from Phase 10). Keeps player options
# in user://settings.cfg so they survive across sessions; game balance and
# defaults still live in config/app.json — this store only overrides the
# player-facing subset. Pure logic over a ConfigFile, unit-testable headless.

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULTS := {
	"audio/master_volume": 0.8,
	"audio/sfx_volume": 0.9,
	"audio/ambience_volume": 0.7,
	"audio/music_volume": 0.5,
	"accessibility/reduced_particles": false,
	"accessibility/reduced_shake": false,
}

const VALID_RANGES := {
	"audio/master_volume": Vector2(0.0, 1.0),
	"audio/sfx_volume": Vector2(0.0, 1.0),
	"audio/ambience_volume": Vector2(0.0, 1.0),
	"audio/music_volume": Vector2(0.0, 1.0),
}

var _values: Dictionary = {}


func _init() -> void:
	reset_to_defaults()


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()


func get_value(key: String) -> Variant:
	return _values.get(key)


func set_value(key: String, value: Variant) -> bool:
	if not _values.has(key):
		return false
	if VALID_RANGES.has(key):
		if not (value is float or value is int):
			return false
		var range_value: Vector2 = VALID_RANGES[key]
		var numeric := float(value)
		if is_nan(numeric) or is_inf(numeric):
			return false
		_values[key] = clampf(numeric, range_value.x, range_value.y)
		return true
	if value is bool:
		_values[key] = value
		return true
	return false


## Reads user://settings.cfg; unknown/invalid entries are ignored so a
## hand-edited or stale file can never poison the session.
func load_settings() -> bool:
	reset_to_defaults()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return false
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		return false
	var loaded_any := false
	for key: String in DEFAULTS:
		var section := key.get_slice("/", 0)
		var entry := key.get_slice("/", 1)
		if config.has_section_key(section, entry):
			set_value(key, config.get_value(section, entry))
			loaded_any = true
	return loaded_any


func save_settings() -> bool:
	var config := ConfigFile.new()
	for key: String in _values:
		config.set_value(key.get_slice("/", 0), key.get_slice("/", 1), _values[key])
	return config.save(SETTINGS_PATH) == OK


## Convenience view for consumers: {"master_volume": .., "sfx_volume": ..,
## "ambience_volume": .., "reduced_particles": .., "reduced_shake": ..}.
func as_audio_accessibility() -> Dictionary:
	return {
		"master_volume": float(_values["audio/master_volume"]),
		"sfx_volume": float(_values["audio/sfx_volume"]),
		"ambience_volume": float(_values["audio/ambience_volume"]),
		"music_volume": float(_values["audio/music_volume"]),
		"reduced_particles": bool(_values["accessibility/reduced_particles"]),
		"reduced_shake": bool(_values["accessibility/reduced_shake"]),
	}
