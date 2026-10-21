class_name DiscoverySystem
extends RefCounted

signal discovered(event: Dictionary)

const FeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")
const DEFINITIONS := {
	"seed_cache": {"en": "Seed pantry", "zh": "種子小糧倉", "item": "FOOD", "amount": 5, "kind": "food"},
	"fiber_cache": {"en": "Soft nesting fibres", "zh": "柔軟築巢纖維", "item": "GENERAL_MATERIAL", "amount": 6, "kind": "material"},
	"stone_seam": {"en": "Smooth stone seam", "zh": "圓潤石材層", "item": "STONE", "amount": 6, "kind": "stone"},
	"ore_seam": {"en": "Copper-coloured ore", "zh": "銅色礦脈", "item": "ORE", "amount": 4, "kind": "ore"},
}
const COLLECTIBLES: Array[String] = [
	"amber_drop", "striped_pebble", "tiny_fossil", "blue_seed", "glass_bead", "moss_star",
	"old_button", "shell_fragment", "mica_leaf", "silver_root", "glowcap", "crystal_tear",
	"clay_mouse", "lost_bell", "ancient_acorn", "warm_stone", "burrow_token", "moon_geode",
]

const COLLECTION_TITLES := {
	"amber_drop": {"zh": "琥珀淚滴", "en": "Amber drop", "hint_zh": "淺土中的小驚喜", "hint_en": "A little surprise in shallow soil"},
	"striped_pebble": {"zh": "條紋小卵石", "en": "Striped pebble", "hint_zh": "淺土中的小驚喜", "hint_en": "A little surprise in shallow soil"},
	"tiny_fossil": {"zh": "迷你化石", "en": "Tiny fossil", "hint_zh": "淺土中的小驚喜", "hint_en": "A little surprise in shallow soil"},
	"blue_seed": {"zh": "藍色種子", "en": "Blue seed", "hint_zh": "淺土中的小驚喜", "hint_en": "A little surprise in shallow soil"},
	"glass_bead": {"zh": "玻璃珠", "en": "Glass bead", "hint_zh": "淺土中的小驚喜", "hint_en": "A little surprise in shallow soil"},
	"moss_star": {"zh": "苔蘚小星", "en": "Moss star", "hint_zh": "根系深處的痕跡", "hint_en": "A trace among the roots"},
	"old_button": {"zh": "舊鈕扣", "en": "Old button", "hint_zh": "根系深處的痕跡", "hint_en": "A trace among the roots"},
	"shell_fragment": {"zh": "貝殼碎片", "en": "Shell fragment", "hint_zh": "根系深處的痕跡", "hint_en": "A trace among the roots"},
	"mica_leaf": {"zh": "雲母薄葉", "en": "Mica leaf", "hint_zh": "根系深處的痕跡", "hint_en": "A trace among the roots"},
	"silver_root": {"zh": "銀色根鬚", "en": "Silver root", "hint_zh": "根系深處的痕跡", "hint_en": "A trace among the roots"},
	"glowcap": {"zh": "微光菇", "en": "Glowcap", "hint_zh": "潮濕地層的閃光", "hint_en": "A glimmer in damp strata"},
	"crystal_tear": {"zh": "水晶淚", "en": "Crystal tear", "hint_zh": "潮濕地層的閃光", "hint_en": "A glimmer in damp strata"},
	"clay_mouse": {"zh": "陶土鼠像", "en": "Clay mouse", "hint_zh": "潮濕地層的閃光", "hint_en": "A glimmer in damp strata"},
	"lost_bell": {"zh": "遺落小鈴", "en": "Lost bell", "hint_zh": "潮濕地層的閃光", "hint_en": "A glimmer in damp strata"},
	"ancient_acorn": {"zh": "古老橡實", "en": "Ancient acorn", "hint_zh": "潮濕地層的閃光", "hint_en": "A glimmer in damp strata"},
	"warm_stone": {"zh": "暖暖石", "en": "Warm stone", "hint_zh": "舊巢穴附近的往事", "hint_en": "A memory near the old burrow"},
	"burrow_token": {"zh": "舊巢徽記", "en": "Burrow token", "hint_zh": "舊巢穴附近的往事", "hint_en": "A memory near the old burrow"},
	"moon_geode": {"zh": "月色晶洞", "en": "Moon geode", "hint_zh": "舊巢穴附近的往事", "hint_en": "A memory near the old burrow"},
}

var _world
var _registry
var _items
var _elapsed := 0.0
var _retry_elapsed := 0.0


func configure(world, registry, items, digs) -> void:
	_world = world
	_registry = registry
	_items = items
	_elapsed = 0.0
	if digs != null:
		digs.cell_excavated.connect(_on_excavated)


func fixed_tick(delta: float) -> void:
	_elapsed += delta
	_retry_elapsed += delta
	if _retry_elapsed < 0.5:
		return
	_retry_elapsed = 0.0
	# Pending exposure lives in persisted feature metadata, not a volatile queue.
	for feature in _registry.get_features("discovery"):
		if feature.metadata.has("exposure") and not bool(feature.metadata.get("claimed", false)):
			claim(feature.id, feature.metadata.exposure)


func claim(feature_id: int, exposure: Vector2i) -> Dictionary:
	var feature = _registry.get_feature(feature_id)
	if feature == null or feature.type_id != "discovery":
		return {"ok": false, "reason": "UNKNOWN_DISCOVERY"}
	if bool(feature.metadata.get("claimed", false)):
		return {"ok": false, "reason": "ALREADY_CLAIMED"}
	if not _world.is_traversable(exposure) or (feature.anchor - exposure).abs().x + (feature.anchor - exposure).abs().y > 1:
		return {"ok": false, "reason": "NOT_EXPOSED"}
	var definition_id: String = str(feature.metadata.get("definition_id", ""))
	var definition: Dictionary = definition_for(definition_id)
	if definition.is_empty():
		return {"ok": false, "reason": "UNKNOWN_DEFINITION"}
	feature.metadata.exposure = exposure
	var item: String = str(definition.get("item", ""))
	var amount: int = int(feature.metadata.get("amount", definition.get("amount", 1)))
	if not item.is_empty() and _items.add_pile(item, exposure, amount) < 0:
		return {"ok": false, "reason": "OUTPUT_BLOCKED"}
	feature.hidden = false
	feature.metadata.claimed = true
	feature.metadata.claimed_at = _elapsed
	_world.mark_region_dirty(feature.get_bounds().grow(4), _world.CHANGE_SIGNALS | _world.CHANGE_TERRAIN)
	var event := {"ok": true, "id": feature.id, "definition_id": definition_id, "item": item, "amount": amount, "cell": exposure, "time": _elapsed}
	discovered.emit(event)
	return event


func _on_excavated(cell: Vector2i) -> void:
	for candidate: Vector2i in [cell, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]:
		var feature_id: int = _world.get_feature_id(candidate)
		if feature_id >= 0:
			var feature = _registry.get_feature(feature_id)
			if feature != null and feature.type_id == "discovery":
				claim(feature_id, cell)


static func definition_for(id: String) -> Dictionary:
	if DEFINITIONS.has(id):
		return DEFINITIONS[id]
	if COLLECTIBLES.has(id):
		var definition: Dictionary = COLLECTION_TITLES[id].duplicate(true)
		definition["kind"] = "collectible"
		definition["amount"] = 1
		return definition
	return {}


static func populate(context) -> void:
	var world = context.world
	var registry = context.feature_registry
	var rng = context.stage_rng("discoveries_v7")
	var start: Vector2i = world.metadata.start_cell
	# Two different, shallow promises near the initial burrow; all choices remain legal.
	for side: int in [-1, 1]:
		for offset: int in range(6, 13):
			var cell := start + Vector2i(side * offset, 0)
			if _can_place(world, cell):
				_add(registry, world, cell, "seed_cache" if side < 0 else "fiber_cache", "small")
				break
	# Bootstrap resources must precede the capability barriers they unlock.
	for side: int in [-1, 1]:
		for offset: int in range(6, 12):
			var cell := start + Vector2i(side * offset, 3)
			if _can_place(world, cell) and world.get_hardness(cell) < 3.0:
				_add(registry, world, cell, "stone_seam" if side < 0 else "ore_seam", "medium")
				break
	# Stratified jittered placement avoids one roll per dug tile and stays deterministic.
	for y: int in range(start.y + 4, world.height - 3, 6):
		for x: int in range(4, world.width - 4, 7):
			var cell := Vector2i(x + rng.next_int(-2, 2), y + rng.next_int(-1, 1))
			if not _can_place(world, cell):
				continue
			var stratum: int = world.get_stratum_id(cell)
			var ids: Array = ["seed_cache", "fiber_cache", "stone_seam"]
			if stratum >= 1:
				ids.append("ore_seam")
			var id: String = str(ids[rng.next_int(0, ids.size() - 1)])
			if rng.next_int(0, 3) == 0:
				var first := mini(stratum * 5, 15)
				id = COLLECTIBLES[rng.next_int(first, mini(first + 4, COLLECTIBLES.size() - 1))]
			_add(registry, world, cell, id, "medium" if id.ends_with("seam") else "small")

	ensure_collectibles(context)


static func _can_place(world, cell: Vector2i) -> bool:
	return world.is_in_bounds(cell) and world.is_solid(cell) and not world.is_protected(cell) and not world.is_exterior(cell) and world.get_feature_id(cell) < 0


static func _add(registry, world, cell: Vector2i, definition_id: String, size: String) -> void:
	var feature = FeatureScript.new("discovery", cell, [cell], false)
	feature.metadata = {"definition_id": definition_id, "size": size, "claimed": false, "definition_version": 1}
	feature.metadata["tier"] = world.get_stratum_id(cell)
	var definition: Dictionary = definition_for(definition_id)
	feature.metadata["amount"] = mini(12, int(definition.get("amount", 1)) + (world.get_stratum_id(cell) * 2 if str(definition.get("kind", "")) != "collectible" else 0))
	var id: int = registry.add_feature(feature)
	world.set_feature_id(cell, id)


static func ensure_collectibles(context) -> void:
	var present: Dictionary = {}
	for feature in context.feature_registry.get_features("discovery"):
		present[str(feature.metadata.get("definition_id", ""))] = true
	var by_tier: Array = [[], [], [], []]
	for y: int in range(int(context.world.metadata.start_cell.y) + 2, context.world.height - 2):
		for x: int in range(2, context.world.width - 2):
			var cell := Vector2i(x, y)
			if _can_place(context.world, cell):
				by_tier[clampi(context.world.get_stratum_id(cell), 0, 3)].append(cell)
	var rng = context.stage_rng("collection_completion_v7")
	for index: int in range(COLLECTIBLES.size()):
		var id := COLLECTIBLES[index]
		if present.has(id):
			continue
		var tier := mini(index / 5, 3)
		if by_tier[tier].is_empty():
			continue
		var choice: int = rng.next_int(0, by_tier[tier].size() - 1)
		var cell: Vector2i = by_tier[tier][choice]
		by_tier[tier].remove_at(choice)
		_add(context.feature_registry, context.world, cell, id, "small")


func claimed_count() -> int:
	var total := 0
	for feature in _registry.get_features("discovery"):
		if bool(feature.metadata.get("claimed", false)):
			total += 1
	return total
