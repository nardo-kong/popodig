extends Node

@onready var version_label: Label = %VersionLabel
@onready var profile_label: Label = %ProfileLabel
@onready var debug_badge: Label = %DebugBadge


func _ready() -> void:
	version_label.text = "工程基线 %s" % AppConfig.get_value("app", "game_version", "unknown")
	profile_label.text = "Build profile: %s" % AppConfig.get_profile_name()
	debug_badge.visible = AppConfig.debug_tools_enabled()
	if AppConfig.get_load_errors().is_empty():
		GameLog.info("QA", "Application booted with profile %s" % AppConfig.get_profile_name())
	else:
		GameLog.failure("QA", "Configuration errors: %s" % "; ".join(AppConfig.get_load_errors()))
