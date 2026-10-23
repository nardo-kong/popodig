class_name ResourceCatalog
extends RefCounted

# GENERAL_MATERIAL remains the stable legacy ID for usable building material.
const DEFINITIONS := {
	"FOOD": {"en": "Food", "zh": "食物", "category": "food"},
	"GENERAL_MATERIAL": {"en": "Building material", "zh": "建材", "category": "building"},
	"STONE": {"en": "Stone", "zh": "石材", "category": "raw"},
	"ORE": {"en": "Ore", "zh": "礦石", "category": "raw"},
	"METAL": {"en": "Metal", "zh": "金屬", "category": "processed"},
}


static func is_known(item_type: String) -> bool:
	return DEFINITIONS.has(item_type)


static func display_name(item_type: String, language: String = "en") -> String:
	return str(DEFINITIONS.get(item_type, {}).get("zh" if language.begins_with("zh") else "en", item_type))
