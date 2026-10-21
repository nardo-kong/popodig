extends "res://tests/test_case.gd"

const World = preload("res://src/domain/world/world_grid.gd")
const Cell = preload("res://src/domain/world/cell_data.gd")
const Paths = preload("res://src/application/services/grid_path_service.gd")
const Digs = preload("res://src/domain/jobs/dig_system.gd")
const Colony = preload("res://src/domain/colony/colony_simulation.gd")
const Zones = preload("res://src/domain/zones/zone.gd")


func _fixture(source_x: int = 22) -> Dictionary:
	var world := World.new(28, 10, 7)
	for y: int in range(10):
		for x: int in range(28):
			world.initialize_cell(Vector2i(x, y), Cell.TerrainMaterial.STONE, false, false, false)
	for x: int in range(1, 27):
		world.set_excavated(Vector2i(x, 4), true, true)
		if x % 4 == 0:
			world.set_reinforced(Vector2i(x, 3), true)
	world.metadata.start_cell = Vector2i(2, 4)
	var balance := {"initial_mouse_count": 1, "capabilities_enabled": true, "mouse": {"hunger_per_second": 0.0, "rest_drain_per_second": 0.0}}
	var paths := Paths.new()
	paths.configure(world, balance)
	var digs := Digs.new()
	digs.configure(world, paths, balance)
	var colony := Colony.new()
	colony.configure(world, paths, digs, balance)
	colony.add_item_pile("GENERAL_MATERIAL", Vector2i(2, 4), 8)
	colony.add_item_pile("STONE", Vector2i(source_x, 4), 4)
	colony.add_item_pile("ORE", Vector2i(source_x, 4), 4)
	colony.get_zone_system().paint_zone(Zones.Type.PRODUCTION, [Vector2i(8, 4)])
	return {"world": world, "paths": paths, "digs": digs, "colony": colony}


func _until_batches(colony, count: int) -> bool:
	for tick: int in range(4000):
		colony.fixed_tick(0.05)
		if colony.get_production_system().completed_batches >= count:
			return true
	return false


func run() -> Array[Dictionary]:
	var fixture := _fixture()
	var colony = fixture.colony
	var items = colony.get_item_system()
	var production = colony.get_production_system()
	var zone = colony.get_zone_system().get_zone_at(Vector2i(8, 4))
	assert_true(_until_batches(colony, 1), "Mouse supplies and crafts a real building-material batch")
	production.set_enabled(zone.zone_id, false)
	assert_equal(items.get_total_count("STONE"), 2, "Production consumes exactly two stone")
	assert_equal(items.get_total_count("GENERAL_MATERIAL"), 10, "Eight initial minus setup plus three new building materials")
	var far_supply_steps: int = colony.loaded_travel_steps
	assert_true(colony.loaded_travel_steps >= 14, "Supply travel is measured from actual loaded mouse movement")
	assert_true(production.set_recipe(zone.zone_id, "metal").ok, "Idle workshop can select metal recipe")
	assert_true(_until_batches(colony, 3), "Mouse completes two metal batches through ordinary work arbitration")
	production.set_enabled(zone.zone_id, false)
	assert_equal(items.get_total_count("ORE"), 0, "Metal batches consume four ore")
	assert_equal(items.get_total_count("METAL"), 2, "Metal exists as physical output")
	var capabilities = colony.get_capabilities()
	assert_true(not capabilities.can_dig(Vector2i(4, 5)), "Basic capability cannot excavate stone")
	assert_true(capabilities.upgrade().ok, "Reachable produced metal unlocks colony capability")
	assert_true(capabilities.can_dig(Vector2i(4, 5)), "Shared upgrade opens previously inaccessible stone")
	var snapshot: Dictionary = items.to_save_data()
	assert_true(not capabilities.upgrade().ok, "Unaffordable deeper upgrade fails")
	assert_equal(items.to_save_data(), snapshot, "Failed upgrade does not consume a partial bundle")
	colony.add_item_pile("ORE", Vector2i(21, 4), 2)
	production.set_enabled(zone.zone_id, true)
	for tick: int in range(2000):
		colony.fixed_tick(0.05)
		if float(production.status(zone.zone_id).progress) >= 2.0:
			break
	assert_true(float(production.status(zone.zone_id).progress) >= 2.0, "A batch reaches a partially worked state")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(colony.to_save_data()))
	assert_true(colony.apply_save_data(saved).ok, "Colony restores a production batch with carried inputs")
	assert_equal(capabilities.level, 1, "Colony capability persists through reload")
	assert_true(_until_batches(colony, 4), "Interrupted production resumes after reload")
	production.set_enabled(zone.zone_id, false)
	assert_equal(items.get_total_count("METAL"), 1, "Resumed batch produces once after earlier upgrade spent metal")
	assert_equal(items.get_total_count("ORE"), 0, "Carried input is not duplicated by reload")
	fixture.world.initialize_cell(Vector2i(6, 5), Cell.TerrainMaterial.DAMP_CLAY, false, false, false)
	fixture.world.set_stratum_id(Vector2i(6, 5), 2)
	assert_equal(fixture.digs.inspect_designation(Vector2i(6, 5)).reason_code, "ABILITY_REQUIRED", "Reinforced tools still respect deep-clay capability gate")
	colony.add_item_pile("METAL", Vector2i(2, 4), 4)
	colony.add_item_pile("STONE", Vector2i(2, 4), 8)
	assert_true(capabilities.upgrade().ok, "Deep tools unlock using the complete resource bundle")
	assert_true(fixture.digs.designate_path([Vector2i(6, 5)]).ok, "Deep tools permit actual designation of deep clay")
	for tick: int in range(1000):
		colony.fixed_tick(0.05)
		if fixture.world.is_traversable(Vector2i(6, 5)):
			break
	assert_true(fixture.world.is_traversable(Vector2i(6, 5)), "Mouse can actually excavate newly unlocked deep clay")
	var near = _fixture(10)
	assert_true(_until_batches(near.colony, 1), "Near-source comparison completes same production work")
	assert_true(near.colony.loaded_travel_steps < far_supply_steps, "Closer supply reduces actual loaded travel")
	return results
