class_name Localization
extends RefCounted

# Bilingual zh/en support for the vertical slice (user decision: follow the OS
# language by default, L toggles in game, --language= overrides for QA).
# Debug-only chrome intentionally stays outside i18n.

const SUPPORTED: Array[String] = ["zh", "en"]
const LANGUAGE_ARGUMENT := "--language="


static func resolve_default() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(LANGUAGE_ARGUMENT):
			var requested := argument.trim_prefix(LANGUAGE_ARGUMENT).to_lower()
			if requested in SUPPORTED:
				return requested
	var system_language := OS.get_locale_language()
	return system_language if system_language in SUPPORTED else "en"


static func apply() -> void:
	TranslationServer.set_locale(resolve_default())


static func current() -> String:
	return TranslationServer.get_locale()


static func cycle() -> String:
	var next_language := "en" if current().begins_with("zh") else "zh"
	TranslationServer.set_locale(next_language)
	return next_language


## Translate with a graceful fallback so missing keys never render as raw keys
## in gameplay surfaces that must stay readable.
static func text(key: String) -> String:
	var translated: String = TranslationServer.translate(key)
	return key if translated.is_empty() else translated
