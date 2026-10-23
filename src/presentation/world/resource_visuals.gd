class_name ResourceVisuals
extends RefCounted

const SOURCES := {
	"FOOD": "res://assets/art/production/resources/food_berries_01.png",
	"GENERAL_MATERIAL": "res://assets/art/production/resources/building_bundle_01.png",
	"STONE": "res://assets/art/production/resources/stone_pile_01.png",
	"ORE": "res://assets/art/production/resources/copper_ore_01.png",
	"METAL": "res://assets/art/production/resources/metal_ingots_01.png",
	"ROOT": "res://assets/art/production/resources/root_cluster_01.png",
}
const PURPOSES := {
	"FOOD": ["鼠鼠餓了會自己取食，維持日常生活。", "Mice take food themselves when hungry."],
	"GENERAL_MATERIAL": ["佈置睡眠區、倉儲與工坊，也用於加固和升級。", "Used to set up beds, stores and workshops, and for supports and upgrades."],
	"STONE": ["原料：在工坊加工成建材，也用於深掘工具升級。", "Raw stone: craft building material in a workshop, or improve deep-digging tools."],
	"ORE": ["原料：在工坊選「礦石 → 金屬」加工。", "Raw ore: choose Ore → metal in a workshop."],
	"METAL": ["加工好的金屬，用來升級整個鼠群的工具。", "Refined metal improves tools for the whole colony."],
	"ROOT": ["仍長在土裡的活樹根；部分根系提供有限的食物。", "Living roots in the soil; some clusters offer a finite food source."],
}
static var _textures: Dictionary = {}


static func texture(id: String) -> Texture2D:
	if not SOURCES.has(id):
		return null
	if not _textures.has(id):
		var source: Texture2D = load(SOURCES[id])
		# Keep the generated PNG intact. A texture region removes transparent
		# padding consistently at every world/UI scale without editing the asset.
		var region := AtlasTexture.new()
		region.atlas = source
		region.region = source.get_image().get_used_rect()
		_textures[id] = region
	return _textures[id]


static func purpose(id: String, locale: String) -> String:
	var text: Array = PURPOSES.get(id, ["", ""])
	return str(text[0 if locale.begins_with("zh") else 1])


static func title(id: String, locale: String) -> String:
	if id == "ROOT":
		return "樹根" if locale.begins_with("zh") else "Tree roots"
	return ResourceCatalog.display_name(id, locale)


static func fitted_rect(id: String, center: Vector2, extent: float) -> Rect2:
	var icon := texture(id)
	if icon == null:
		return Rect2()
	var dimensions := icon.get_size()
	var scale_value := extent / maxf(dimensions.x, dimensions.y)
	var size := dimensions * scale_value
	return Rect2(center - size * 0.5, size)
