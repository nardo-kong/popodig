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
	var amount: int = int(definition.get("amount", 1))
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
		return {"en": id.replace("_", " ").capitalize(), "zh": "地下珍藏 · " + str(COLLECTIBLES.find(id) + 1), "kind": "collectible", "amount": 1}
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
				var first := mini(stratum * 4, 12)
				id = COLLECTIBLES[rng.next_int(first, mini(first + 5, COLLECTIBLES.size() - 1))]
			_add(registry, world, cell, id, "medium" if id.ends_with("seam") else "small")


static func _can_place(world, cell: Vector2i) -> bool:
	return world.is_in_bounds(cell) and world.is_solid(cell) and not world.is_protected(cell) and not world.is_exterior(cell) and world.get_feature_id(cell) < 0


static func _add(registry, world, cell: Vector2i, definition_id: String, size: String) -> void:
	var feature = FeatureScript.new("discovery", cell, [cell], false)
	feature.metadata = {"definition_id": definition_id, "size": size, "claimed": false, "definition_version": 1}
	var id: int = registry.add_feature(feature)
	world.set_feature_id(cell, id)
