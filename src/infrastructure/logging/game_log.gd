class_name GameLogger
extends Node

const CATEGORIES: PackedStringArray = [
	"WORLDGEN",
	"DIG",
	"WATER",
	"STABILITY",
	"JOB",
	"MOUSE",
	"SAVE",
	"QA",
]


func debug(category: String, message: String) -> void:
	if AppConfig.verbose_logging_enabled():
		print(_format(category, "DEBUG", message))


func info(category: String, message: String) -> void:
	print(_format(category, "INFO", message))


func warning(category: String, message: String) -> void:
	push_warning(_format(category, "WARN", message))


func failure(category: String, message: String) -> void:
	push_error(_format(category, "ERROR", message))


func is_known_category(category: String) -> bool:
	return CATEGORIES.has(category.to_upper())


func _format(category: String, level: String, message: String) -> String:
	var normalized := category.to_upper()
	if not is_known_category(normalized):
		normalized = "QA"
	return "[%s][%s] %s" % [normalized, level, message]
