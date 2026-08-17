class_name CellData
extends RefCounted

enum TerrainMaterial {
	EMPTY,
	SOFT_SOIL,
	DAMP_CLAY,
	LOOSE_SOIL,
	STONE,
	FOUNDATION,
	ROOT_SOIL,
}

enum DigState {
	NONE,
	QUEUED,
	ACTIVE,
}

var coord := Vector2i.ZERO
var terrain_material: int = TerrainMaterial.EMPTY
var excavated := true
var hardness := 0.0
var dig_state: int = DigState.NONE
var dig_progress := 0.0
var feature_id := -1
var stability_base := 0
var water_units := 0
var moisture_signal := 0
var root_signal := 0
var zone_id := -1
var protected_cell := false


func is_solid() -> bool:
	return terrain_material != TerrainMaterial.EMPTY and not excavated


static func material_name(material: int) -> String:
	match material:
		TerrainMaterial.EMPTY:
			return "Air"
		TerrainMaterial.SOFT_SOIL:
			return "Soft Soil"
		TerrainMaterial.DAMP_CLAY:
			return "Damp Clay"
		TerrainMaterial.LOOSE_SOIL:
			return "Loose Soil"
		TerrainMaterial.STONE:
			return "Stone"
		TerrainMaterial.FOUNDATION:
			return "Foundation"
		TerrainMaterial.ROOT_SOIL:
			return "Root Soil"
		_:
			return "Unknown"


static func default_hardness(material: int) -> float:
	match material:
		TerrainMaterial.EMPTY:
			return 0.0
		TerrainMaterial.SOFT_SOIL:
			return 1.0
		TerrainMaterial.DAMP_CLAY:
			return 1.45
		TerrainMaterial.LOOSE_SOIL:
			return 0.85
		TerrainMaterial.STONE:
			return 3.0
		TerrainMaterial.FOUNDATION:
			return 5.0
		TerrainMaterial.ROOT_SOIL:
			return 1.6
		_:
			return 1.0
