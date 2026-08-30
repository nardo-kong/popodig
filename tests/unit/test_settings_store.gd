extends RefCounted

# Phase 12 unit tests: player settings persistence — defaults, clamping,
# save/load round trip, and stale-entry tolerance (docs/ux/11; deferred
# quick-load/settings decision from the Phase 10 acceptance).

const SettingsStoreScript = preload("res://src/infrastructure/config/settings_store.gd")

var results: Array[Dictionary] = []
var _backup_path := ""


func run() -> Array[Dictionary]:
	results = []
	_backup_existing_file()
	_test_defaults_are_sane()
	_test_volume_clamping()
	_test_unknown_keys_rejected()
	_test_save_load_round_trip()
	_test_stale_entries_ignored()
	_restore_backup()
	return results


func _backup_existing_file() -> void:
	_backup_path = SettingsStoreScript.SETTINGS_PATH + ".test_backup"
	if FileAccess.file_exists(SettingsStoreScript.SETTINGS_PATH):
		DirAccess.copy_absolute(SettingsStoreScript.SETTINGS_PATH, _backup_path)
		DirAccess.remove_absolute(SettingsStoreScript.SETTINGS_PATH)


func _restore_backup() -> void:
	DirAccess.remove_absolute(SettingsStoreScript.SETTINGS_PATH)
	if FileAccess.file_exists(_backup_path):
		DirAccess.copy_absolute(_backup_path, SettingsStoreScript.SETTINGS_PATH)
		DirAccess.remove_absolute(_backup_path)


func _test_defaults_are_sane() -> void:
	var store: SettingsStore = SettingsStoreScript.new()
	var view := store.as_audio_accessibility()
	_assert(view.master_volume > 0.0 and view.master_volume <= 1.0, "Default master volume is normalized")
	_assert(view.sfx_volume > 0.0 and view.sfx_volume <= 1.0, "Default SFX volume is normalized")
	_assert(view.ambience_volume > 0.0 and view.ambience_volume <= 1.0, "Default ambience volume is normalized")
	_assert(not view.reduced_particles and not view.reduced_shake, "Accessibility flags default to off")


func _test_volume_clamping() -> void:
	var store: SettingsStore = SettingsStoreScript.new()
	_assert(store.set_value("audio/master_volume", 2.5), "Setting a volume returns success")
	_assert(float(store.get_value("audio/master_volume")) == 1.0, "Volumes clamp to the 0..1 range")
	store.set_value("audio/sfx_volume", -3.0)
	_assert(float(store.get_value("audio/sfx_volume")) == 0.0, "Negative volumes clamp to zero")
	_assert(not store.set_value("audio/master_volume", "loud"), "Non-numeric volumes are rejected")


func _test_unknown_keys_rejected() -> void:
	var store: SettingsStoreScript = SettingsStoreScript.new()
	_assert(not store.set_value("cheats/god_mode", true), "Unknown keys are rejected — the store only holds player options")


func _test_save_load_round_trip() -> void:
	var store: SettingsStore = SettingsStoreScript.new()
	store.set_value("audio/master_volume", 0.35)
	store.set_value("accessibility/reduced_shake", true)
	_assert(store.save_settings(), "Settings save to user://settings.cfg")
	var reloaded: SettingsStore = SettingsStoreScript.new()
	_assert(reloaded.load_settings(), "Saved settings load back")
	_assert(float(reloaded.get_value("audio/master_volume")) == 0.35, "Master volume survives the round trip")
	_assert(bool(reloaded.get_value("accessibility/reduced_shake")), "Accessibility flag survives the round trip")


func _test_stale_entries_ignored() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", 0.9)
	config.set_value("legacy", "unknown_key", 42)
	config.save(SettingsStoreScript.SETTINGS_PATH)
	var store: SettingsStore = SettingsStoreScript.new()
	_assert(store.load_settings(), "A file with unknown sections still loads")
	_assert(float(store.get_value("audio/master_volume")) == 0.9, "Known keys are applied from the file")


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
