extends RefCounted

const CLUE_KEYS: Array[String] = [
	"clue.crumbs_drift",
	"clue.cracks_creep",
	"clue.damp",
	"clue.seep_marks",
	"clue.saturated",
	"clue.seep_reservoir",
	"clue.fibers",
	"clue.root_fine",
	"clue.root_dense",
	"clue.root_thick",
	"clue.root_fine_food",
	"clue.root_dense_food",
]

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_default_locale_is_supported()
	_test_all_keys_resolve_in_both_languages()
	_test_cycle_switches_language()
	_test_missing_key_falls_back_to_key()
	return results


func _test_default_locale_is_supported() -> void:
	Localization.apply()
	_assert(Localization.current() in Localization.SUPPORTED, "Resolved default locale is a supported language")


func _test_all_keys_resolve_in_both_languages() -> void:
	var sample_keys: Array[String] = [
		"hud.food", "hud.objective", "tool.dig", "reason.NOT_EXCAVATABLE",
		"notify.breach", "tutorial.done", "inspector.signs", "feature.root_cluster",
	]
	for key: String in sample_keys + CLUE_KEYS:
		TranslationServer.set_locale("zh")
		var zh_text: String = Localization.text(key)
		TranslationServer.set_locale("en")
		var en_text: String = Localization.text(key)
		_assert(not zh_text.is_empty() and zh_text != key, "Key resolves in zh: %s" % key)
		_assert(not en_text.is_empty() and en_text != key, "Key resolves in en: %s" % key)
		_assert(zh_text != en_text, "Translations differ between languages: %s" % key)
	Localization.apply()


func _test_cycle_switches_language() -> void:
	Localization.apply()
	var before: String = Localization.current()
	var after: String = Localization.cycle()
	_assert(after != before, "Cycling switches the language")
	_assert(Localization.current() == after, "Current reflects the cycled language")
	Localization.apply()


func _test_missing_key_falls_back_to_key() -> void:
	_assert(Localization.text("nonexistent.key.for.test") == "nonexistent.key.for.test", "Missing keys fall back to the raw key")


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
