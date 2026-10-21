class_name ColonyCapabilities
extends RefCounted

signal upgraded(level: int)

const Cell = preload("res://src/domain/world/cell_data.gd")
const COSTS: Array[Dictionary] = [{"GENERAL_MATERIAL": 4, "METAL": 2}, {"STONE": 8, "METAL": 4}]
const NAMES: Array[String] = ["Basic", "Reinforced", "Deep"]
var level := 0
var _items
var _world


func configure(items, world) -> void:
	_items = items
	_world = world


func can_dig(cell: Vector2i) -> bool:
	var material: int = _world.get_material(cell)
	if material == Cell.TerrainMaterial.FOUNDATION:
		return level >= 2
	if material == Cell.TerrainMaterial.DAMP_CLAY and _world.get_stratum_id(cell) >= 2:
		return level >= 2
	if material == Cell.TerrainMaterial.STONE:
		return level >= 1
	return true


func upgrade() -> Dictionary:
	if level >= COSTS.size():
		return {"ok": false, "reason": "MAX_LEVEL"}
	var result: Dictionary = _items.consume_reachable_bundle(COSTS[level], _world.metadata.get("start_cell", Vector2i.ZERO))
	if not result.ok:
		return result
	level += 1
	upgraded.emit(level)
	return {"ok": true, "level": level}


func requirements() -> Dictionary:
	if level >= COSTS.size():
		return {"ready": false, "costs": {}, "missing": {}}
	var missing: Dictionary = {}
	var origin: Vector2i = _world.metadata.get("start_cell", Vector2i.ZERO)
	for item_type: String in COSTS[level]:
		var remaining: int = int(COSTS[level][item_type]) - _items.reachable_available_count(item_type, origin)
		if remaining > 0:
			missing[item_type] = remaining
	return {"ready": missing.is_empty(), "costs": COSTS[level].duplicate(), "missing": missing}


func to_save_data() -> Dictionary:
	return {"level": level}


func apply_save_data(data: Dictionary) -> Dictionary:
	var restored := int(data.get("level", 0))
	if restored < 0 or restored > 2:
		return {"ok": false, "error": "invalid colony capability"}
	level = restored
	return {"ok": true, "error": ""}
