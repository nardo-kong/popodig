class_name HomeProgress
extends RefCounted

signal changed()
const TITLES := {
	"keepsake": {"zh": "第一件小珍藏", "en": "Our first keepsake"},
	"shelter": {"zh": "有床有糧的家", "en": "A place to live"},
	"workshop": {"zh": "自己造出好東西", "en": "Made by our mice"},
	"tools": {"zh": "一起學會新本領", "en": "Better tools together"},
	"family": {"zh": "越來越熱鬧的小窩", "en": "A growing family"},
	"deep_home": {"zh": "終於安頓的暖巢", "en": "Our warm deep home"},
}
var unlocked: Dictionary = {}


func evaluate(context: Dictionary, time: float) -> Array[String]:
	var conditions := {
		"keepsake": int(context.get("collection_count", 0)) > 0,
		"shelter": bool(context.get("sleeping_ready", false)) and bool(context.get("storage_ready", false)) and int(context.get("food_total", 0)) > 0,
		"workshop": int(context.get("production_batches", 0)) > 0,
		"tools": int(context.get("capability_level", 0)) > 0,
		"family": int(context.get("mouse_count", 0)) >= 3,
		"deep_home": bool(context.get("campaign_complete", false)),
	}
	var fresh: Array[String] = []
	for id: String in conditions:
		if bool(conditions[id]) and not unlocked.has(id):
			unlocked[id] = maxf(0.0, time)
			fresh.append(id)
	if not fresh.is_empty():
		changed.emit()
	return fresh


func to_save_data() -> Dictionary:
	return {"unlocked": unlocked.duplicate()}


func apply_save_data(data: Dictionary) -> Dictionary:
	var source: Variant = data.get("unlocked", {})
	if not source is Dictionary:
		return {"ok": false, "error": "invalid home progress"}
	for id: String in source:
		if not TITLES.has(id) or float(source[id]) < 0:
			return {"ok": false, "error": "unknown home milestone"}
	unlocked = source.duplicate()
	changed.emit()
	return {"ok": true, "error": ""}
