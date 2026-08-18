class_name WorldValidator
extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GeneratedFeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")

const IMPASSABLE := 0x3fffffff
const HEAP_INDEX_MASK := 0xffffffff
const REQUIRED_LANDMARK_CONTENT_TYPES := {
	"major_root_anchor": "root_cluster",
	"first_reservoir_region": "water_reservoir",
	"foundation_segment": "foundation",
	"old_burrow_entrance": "old_burrow",
	"final_warm_chamber": "warm_chamber",
}
const REQUIRED_LANDMARK_TYPES: PackedStringArray = [
	"start_burrow",
	"major_root_anchor",
	"first_reservoir_region",
	"foundation_segment",
	"old_burrow_entrance",
	"final_warm_chamber",
]

var _cached_world
var _cached_start := Vector2i(-1, -1)
var _cached_distances := PackedInt32Array()
var _cached_previous := PackedInt32Array()
var _cached_reachable_cells := 0


func validate(context: WorldGenContext) -> Dictionary:
	_clear_planner_cache()
	var failures: Array[Dictionary] = []
	var metrics: Dictionary = {
		"feature_count": context.feature_registry.count(),
		"landmark_count": context.feature_registry.get_features_by_role("landmark").size(),
		"decision_knot_count": 0,
		"start_open_cells": 0,
		"early_food_cost": -1,
		"required_depth_cost": -1,
		"max_landmark_cost": -1,
		"reservoir_count": context.feature_registry.count("water_reservoir"),
		"first_reservoir_cost": -1,
		"witness_paths": {},
	}
	if context.world == null:
		_fail(failures, "WORLD_MISSING", "Terrain stage did not produce a world.")
		return _report(failures, metrics)
	_validate_start(context, failures, metrics)
	_validate_feature_bounds(context, failures)
	_validate_feature_ownership(context, failures)
	_validate_required_landmark_set(context, failures)
	_validate_food(context, failures, metrics)
	_validate_required_depth(context, failures, metrics)
	_validate_landmarks(context, failures, metrics)
	_validate_reservoirs(context, failures, metrics)
	_validate_signal_hooks(context, failures)
	_validate_signal_fields(context, failures, metrics)
	_validate_decision_knots(context, failures, metrics)
	_validate_required_approaches(context, failures)
	return _report(failures, metrics)


func minimum_potential_dig_cost(world, start: Vector2i, goals: Array[Vector2i], maximum_cost: int = -1) -> Dictionary:
	var result := {"cost": -1, "goal": Vector2i(-1, -1), "reachable_cells": 0, "witness_path": []}
	if world == null or goals.is_empty() or not world.is_traversable(start):
		return result
	_ensure_potential_field(world, start)
	var best_index := -1
	var best_cost := IMPASSABLE
	for goal: Vector2i in goals:
		var goal_index: int = world.cell_to_index(goal)
		if goal_index < 0:
			continue
		var cost: int = _cached_distances[goal_index]
		if cost < best_cost or (cost == best_cost and (best_index < 0 or goal_index < best_index)):
			best_index = goal_index
			best_cost = cost
	result.reachable_cells = _cached_reachable_cells
	if best_index < 0 or best_cost >= IMPASSABLE or (maximum_cost >= 0 and best_cost > maximum_cost):
		return result
	result.cost = best_cost
	result.goal = world.index_to_cell(best_index)
	result.witness_path = _reconstruct_witness(world, best_index)
	return result


func _ensure_potential_field(world, start: Vector2i) -> void:
	if _cached_world == world and _cached_start == start and not _cached_distances.is_empty():
		return
	_clear_planner_cache()
	_cached_world = world
	_cached_start = start
	var cell_count: int = world.width * world.height
	_cached_distances.resize(cell_count)
	_cached_distances.fill(IMPASSABLE)
	_cached_previous.resize(cell_count)
	_cached_previous.fill(-2)
	var start_index: int = world.cell_to_index(start)
	_cached_distances[start_index] = 0
	_cached_previous[start_index] = -1
	var heap: Array[int] = []
	_heap_push(heap, start_index, 0)
	while not heap.is_empty():
		var entry: int = _heap_pop(heap)
		var current_index := entry & HEAP_INDEX_MASK
		var current_cost := entry >> 32
		if current_cost != _cached_distances[current_index]:
			continue
		_cached_reachable_cells += 1
		var current: Vector2i = world.index_to_cell(current_index)
		for neighbor: Vector2i in world.get_cardinal_neighbors(current):
			var step_cost := _potential_step_cost(world, neighbor)
			if step_cost >= IMPASSABLE:
				continue
			var neighbor_index: int = world.cell_to_index(neighbor)
			if neighbor_index == start_index:
				continue
			var next_cost := current_cost + step_cost
			if next_cost >= _cached_distances[neighbor_index]:
				continue
			_cached_distances[neighbor_index] = next_cost
			_cached_previous[neighbor_index] = current_index
			_heap_push(heap, neighbor_index, next_cost)


func _reconstruct_witness(world, goal_index: int) -> Array[Vector2i]:
	var reversed: Array[Vector2i] = []
	var cursor := goal_index
	var guard := 0
	while cursor >= 0 and guard <= _cached_previous.size():
		reversed.append(world.index_to_cell(cursor))
		cursor = _cached_previous[cursor]
		guard += 1
	reversed.reverse()
	return reversed


func _clear_planner_cache() -> void:
	_cached_world = null
	_cached_start = Vector2i(-1, -1)
	_cached_distances.clear()
	_cached_previous.clear()
	_cached_reachable_cells = 0


func _validate_start(context: WorldGenContext, failures: Array[Dictionary], metrics: Dictionary) -> void:
	var world = context.world
	var start: Vector2i = world.metadata.get("start_cell", Vector2i(-1, -1))
	if not world.is_in_bounds(start) or not world.is_traversable(start):
		_fail(failures, "START_NOT_TRAVERSABLE", "The starting cell is not an interior traversable cell.", [start])
		return
	var open_count := _connected_open_count(world, start, 64)
	metrics.start_open_cells = open_count
	var minimum_open := int(_validation_config(context).get("minimum_start_open_cells", 18))
	if open_count < minimum_open:
		_fail(failures, "START_SPACE_TOO_SMALL", "The starting burrow lacks usable Sleeping/Storage space.", [start])
	var flooded: Array[Vector2i] = []
	for y: int in range(maxi(0, start.y - 4), mini(world.height, start.y + 5)):
		for x: int in range(maxi(0, start.x - 6), mini(world.width, start.x + 7)):
			var cell := Vector2i(x, y)
			if world.is_traversable(cell) and world.get_water_units(cell) > 0:
				flooded.append(cell)
	if not flooded.is_empty():
		_fail(failures, "START_HAS_ACTIVE_WATER", "Active water enters the starting burrow at generation time.", flooded)


func _validate_feature_bounds(context: WorldGenContext, failures: Array[Dictionary]) -> void:
	var world = context.world
	for feature: GeneratedFeature in context.feature_registry.get_features():
		if not world.is_in_bounds(feature.anchor):
			_fail(failures, "FEATURE_OUT_OF_BOUNDS", "Feature anchor is outside the finite world.", [feature.anchor], feature.id)
			continue
		for cell: Vector2i in feature.cells:
			if not world.is_in_bounds(cell) or world.is_exterior(cell):
				_fail(failures, "FEATURE_OUT_OF_BOUNDS", "Feature geometry leaves the underground world.", [cell], feature.id)
				break


func _validate_feature_ownership(context: WorldGenContext, failures: Array[Dictionary]) -> void:
	var world = context.world
	for feature: GeneratedFeature in context.feature_registry.get_features_by_role("feature"):
		if feature.cells.is_empty():
			_fail(failures, "FEATURE_GEOMETRY_EMPTY", "A registered feature has no owned geometry.", [feature.anchor], feature.id)
			continue
		for cell: Vector2i in feature.cells:
			if world.get_feature_id(cell) != feature.id:
				_fail(failures, "FEATURE_OWNER_MISMATCH", "Registry geometry and the cell owner layer disagree.", [cell], feature.id)
				break
	for index: int in range(world.width * world.height):
		var cell: Vector2i = world.index_to_cell(index)
		var owner_id: int = world.get_feature_id(cell)
		if owner_id < 0:
			continue
		var owner: GeneratedFeature = context.feature_registry.get_feature(owner_id)
		if owner == null or owner.role != "feature" or not owner.cells.has(cell):
			_fail(failures, "ORPHAN_FEATURE_OWNER", "A cell references missing or stale feature geometry.", [cell], owner_id)
			break
	for landmark: GeneratedFeature in context.feature_registry.get_features_by_role("landmark"):
		if not world.is_landmark(landmark.anchor):
			_fail(failures, "LANDMARK_MASK_MISSING", "A landmark registry entry is absent from the canonical landmark mask.", [landmark.anchor], landmark.id)


func _validate_food(context: WorldGenContext, failures: Array[Dictionary], metrics: Dictionary) -> void:
	var goals: Array[Vector2i] = []
	var food_features: Array[GeneratedFeature] = []
	for feature: GeneratedFeature in context.feature_registry.get_features("root_cluster"):
		if bool(feature.metadata.get("food_opportunity", false)):
			food_features.append(feature)
			goals.append_array(_derived_feature_boundary(context, feature))
	if food_features.is_empty():
		_fail(failures, "EARLY_FOOD_MISSING", "No Root food opportunity was generated.")
		return
	if goals.is_empty():
		var blocked_cells: Array[Vector2i] = []
		for feature: GeneratedFeature in food_features:
			blocked_cells.append(feature.anchor)
		_fail(failures, "EARLY_FOOD_UNREACHABLE", "Root food opportunities have no legal boundary approach.", blocked_cells)
		return
	var start: Vector2i = context.world.metadata.start_cell
	var maximum_cost := int(_validation_config(context).get("early_food_max_dig_cost", 34))
	var path: Dictionary = minimum_potential_dig_cost(context.world, start, goals, maximum_cost)
	metrics.early_food_cost = int(path.cost)
	(metrics.witness_paths as Dictionary).early_food = (path.witness_path as Array).duplicate()
	if int(path.cost) < 0:
		_fail(failures, "EARLY_FOOD_UNREACHABLE", "The first food opportunity exceeds the early dig-cost envelope.", goals)


func _validate_required_depth(context: WorldGenContext, failures: Array[Dictionary], metrics: Dictionary) -> void:
	var world = context.world
	var target_y := int(context.depth_targets.get("campaign_progress", int(world.height * 0.86)))
	var goals: Array[Vector2i] = []
	var margin := int(context.config.get("protected_margin", 1)) + 1
	for x: int in range(margin, world.width - margin):
		goals.append(Vector2i(x, target_y))
	var path: Dictionary = minimum_potential_dig_cost(world, world.metadata.start_cell, goals)
	metrics.required_depth_cost = int(path.cost)
	(metrics.witness_paths as Dictionary).campaign_progress = (path.witness_path as Array).duplicate()
	if int(path.cost) < 0:
		_fail(failures, "REQUIRED_DEPTH_SEALED", "The campaign depth band is sealed by non-excavatable cells.", goals)


func _validate_landmarks(context: WorldGenContext, failures: Array[Dictionary], metrics: Dictionary) -> void:
	var maximum_landmark_cost := -1
	var landmark_witnesses: Dictionary = {}
	for landmark: GeneratedFeature in context.feature_registry.get_features_by_role("landmark"):
		if not landmark.required or landmark.type_id == "start_burrow":
			continue
		var derived_goals: Array[Vector2i] = _derived_landmark_boundary(context, landmark)
		var path: Dictionary = minimum_potential_dig_cost(context.world, context.world.metadata.start_cell, derived_goals)
		var cost := int(path.cost)
		if cost < 0:
			_fail(failures, "REQUIRED_LANDMARK_UNREACHABLE", "A required landmark has no potential excavation route to its final-geometry boundary.", derived_goals, landmark.id)
		else:
			maximum_landmark_cost = maxi(maximum_landmark_cost, cost)
			landmark_witnesses[landmark.type_id] = (path.witness_path as Array).duplicate()
	metrics.max_landmark_cost = maximum_landmark_cost
	(metrics.witness_paths as Dictionary).landmarks = landmark_witnesses


func _validate_reservoirs(context: WorldGenContext, failures: Array[Dictionary], metrics: Dictionary) -> void:
	var reservoirs := context.feature_registry.get_features("water_reservoir")
	if reservoirs.is_empty():
		_fail(failures, "RESERVOIR_MISSING", "No finite water reservoir feature was generated.")
		return
	var minimum_start_cost := int(_validation_config(context).get("first_hazard_min_dig_cost", 9))
	var first_cost := IMPASSABLE
	var first_feature_id := -1
	var all_reservoir_boundaries: Array[Vector2i] = []
	for reservoir: GeneratedFeature in reservoirs:
		if int(reservoir.metadata.get("reserve_units", 0)) <= 0:
			_fail(failures, "RESERVOIR_EMPTY", "A reservoir has no finite reserve.", reservoir.cells, reservoir.id)
		var reservoir_boundary: Array[Vector2i] = _derived_feature_boundary(context, reservoir)
		all_reservoir_boundaries.append_array(reservoir_boundary)
		var path: Dictionary = minimum_potential_dig_cost(context.world, context.world.metadata.start_cell, reservoir_boundary)
		if int(path.cost) >= 0 and int(path.cost) < first_cost:
			first_cost = int(path.cost)
			first_feature_id = reservoir.id
	metrics.first_reservoir_cost = -1 if first_cost >= IMPASSABLE else first_cost
	metrics.first_reservoir_feature_id = first_feature_id
	if first_cost >= IMPASSABLE:
		_fail(failures, "RESERVOIR_UNREACHABLE", "No finite reservoir has a potential route to its final-geometry boundary.", all_reservoir_boundaries)
	for reservoir: GeneratedFeature in reservoirs:
		if not reservoir.required:
			continue
		var hard_shoulder: Dictionary = {}
		for reservoir_cell: Vector2i in reservoir.cells:
			for neighbor: Vector2i in context.world.get_cardinal_neighbors(reservoir_cell):
				if (
					context.world.get_feature_id(neighbor) != reservoir.id
					and context.world.get_material(neighbor) in [CellDataScript.TerrainMaterial.STONE, CellDataScript.TerrainMaterial.FOUNDATION]
					and _potential_step_cost(context.world, neighbor) < IMPASSABLE
				):
					hard_shoulder[neighbor] = true
		if _derived_feature_boundary(context, reservoir).size() < 2 or hard_shoulder.size() < 3:
			_fail(failures, "RESERVOIR_MITIGATION_MISSING", "Required reservoir lacks multiple legal approaches and a diggable containment shoulder.", reservoir.cells, reservoir.id)
	if first_cost < minimum_start_cost:
		var first_feature: GeneratedFeature = context.feature_registry.get_feature(first_feature_id)
		_fail(
			failures,
			"FIRST_HAZARD_TOO_CLOSE",
			"The first reservoir can be breached before adequate warning distance.",
			all_reservoir_boundaries if first_feature == null else _derived_feature_boundary(context, first_feature),
			first_feature_id
		)


func _validate_signal_hooks(context: WorldGenContext, failures: Array[Dictionary]) -> void:
	var expected_channels := {
		"root_cluster": "root_density",
		"water_reservoir": "moisture",
		"unstable_pocket": "instability",
	}
	var emitter_owner_ids: Dictionary = {}
	for emitter: Dictionary in context.signal_emitters:
		var feature_id := int(emitter.get("feature_id", -1))
		var feature: GeneratedFeature = context.feature_registry.get_feature(feature_id)
		var valid: bool = (
			feature != null
			and expected_channels.has(feature.type_id)
			and not emitter_owner_ids.has(feature_id)
			and String(emitter.get("channel", "")) == String(expected_channels.get(feature.type_id, ""))
			and emitter.get("anchor", Vector2i(-1, -1)) == feature.anchor
			and int(emitter.get("strength", 0)) > 0
			and int(emitter.get("falloff", -1)) >= 0
		)
		if not valid:
			var failure_cells: Array[Vector2i] = []
			if feature != null:
				failure_cells.append(feature.anchor)
			_fail(failures, "SIGNAL_HOOK_INVALID", "Signal emitter contract has an orphan, duplicate, or invalid channel/state.", failure_cells, feature_id)
			continue
		emitter_owner_ids[feature_id] = true
	for feature_type: String in expected_channels:
		for feature: GeneratedFeature in context.feature_registry.get_features(feature_type):
			if not emitter_owner_ids.has(feature.id):
				_fail(failures, "SIGNAL_HOOK_MISSING", "A major feature lacks its Phase 6+ signal emitter hook.", [feature.anchor], feature.id)


func _validate_signal_fields(context: WorldGenContext, failures: Array[Dictionary], metrics: Dictionary) -> void:
	var root_cells_with_signal := 0
	var exterior_signal_cells := 0
	for index: int in range(context.world.width * context.world.height):
		var cell: Vector2i = context.world.index_to_cell(index)
		var value: int = int(context.world.get_root_signal(cell))
		if value > 0:
			root_cells_with_signal += 1
			if context.world.is_exterior(cell):
				exterior_signal_cells += 1
	metrics.root_signal_cell_count = root_cells_with_signal
	metrics.exterior_signal_cell_count = exterior_signal_cells
	if exterior_signal_cells > 0:
		_fail(failures, "SIGNAL_FIELD_EXTERIOR_LEAK", "Root signal values leak into EXTERIOR cells.")
	for feature: GeneratedFeature in context.feature_registry.get_features("root_cluster"):
		if not feature.required:
			continue
		var boundary := _derived_feature_boundary(context, feature)
		var has_clue := false
		var strongest := 0
		for cell: Vector2i in boundary:
			var value: int = int(context.world.get_root_signal(cell))
			strongest = maxi(strongest, value)
			has_clue = has_clue or value > 0
		if not has_clue or strongest < 3:
			_fail(failures, "SIGNAL_FIELD_MISSING", "A required Root Cluster lacks a noticeable clue on its final-geometry boundary.", boundary, feature.id)


func _validate_decision_knots(context: WorldGenContext, failures: Array[Dictionary], metrics: Dictionary) -> void:
	var valid_count := 0
	var decision_witnesses: Array = []
	var decision_diagnostics: Array[Dictionary] = []
	var max_cost := int(_validation_config(context).get("decision_knot_max_dig_cost", 30))
	var minimum_count := int(_validation_config(context).get("minimum_decision_knots", 1))
	var validated_cells: Array[Vector2i] = []
	for knot: Vector2i in _decision_frontier_candidates(context, max_cost):
		var path: Dictionary = minimum_potential_dig_cost(context.world, context.world.metadata.start_cell, [knot], max_cost)
		if int(path.cost) < 0:
			continue
		var approach_direction := ""
		var global_witness: Array = path.witness_path
		if global_witness.size() >= 2:
			approach_direction = _direction_from_cells(knot, global_witness[-2])
		var segments: Array[Dictionary] = _analyze_frontier_segments(context, knot, approach_direction)
		var signatures: Dictionary = {}
		var has_root_value := false
		var has_water_risk := false
		var has_hard_cost := false
		var has_safe_route := false
		var minimum_branch_cost := IMPASSABLE
		var maximum_branch_cost := -1
		var minimum_open_cells := IMPASSABLE
		var maximum_open_cells := -1
		for segment: Dictionary in segments:
			signatures[String(segment.signature)] = true
			has_root_value = has_root_value or bool(segment.root_value)
			has_water_risk = has_water_risk or bool(segment.water_risk)
			has_hard_cost = has_hard_cost or bool(segment.hard_cost)
			has_safe_route = has_safe_route or bool(segment.safe_soft_route)
			minimum_branch_cost = mini(minimum_branch_cost, int(segment.ray_dig_cost))
			maximum_branch_cost = maxi(maximum_branch_cost, int(segment.ray_dig_cost))
			minimum_open_cells = mini(minimum_open_cells, int(segment.open_cells))
			maximum_open_cells = maxi(maximum_open_cells, int(segment.open_cells))
		var cost_or_topology_varies := (
			maximum_branch_cost - minimum_branch_cost >= 2
			or maximum_open_cells - minimum_open_cells >= 3
		)
		var topology_diverse := (
			segments.size() >= 3
			and signatures.size() >= 3
			and has_root_value
			and has_water_risk
			and has_hard_cost
			and has_safe_route
			and cost_or_topology_varies
		)
		if decision_diagnostics.size() < 24:
			decision_diagnostics.append({
			"cell": knot,
			"cost": int(path.cost),
			"approach_direction": approach_direction,
			"frontier_segment_count": segments.size(),
			"distinct_signature_count": signatures.size(),
			"has_root_value": has_root_value,
			"has_water_risk": has_water_risk,
			"has_hard_cost": has_hard_cost,
			"has_safe_route": has_safe_route,
			"cost_or_topology_varies": cost_or_topology_varies,
			"segments": segments,
			"topology_diverse": topology_diverse,
			})
		if topology_diverse:
			valid_count += 1
			validated_cells.append(knot)
			decision_witnesses.append((path.witness_path as Array).duplicate())
			if valid_count >= minimum_count:
				break
	metrics.decision_knot_count = valid_count
	metrics.decision_knot_diagnostics = decision_diagnostics
	metrics.validated_decision_knots = validated_cells
	(metrics.witness_paths as Dictionary).decision_knots = decision_witnesses
	if valid_count < minimum_count:
		_fail(failures, "DECISION_KNOT_MISSING", "The early world lacks three real frontier segments with unequal downstream value, water risk, dig cost, and topology.", context.decision_knots)


func _decision_frontier_candidates(context: WorldGenContext, maximum_cost: int) -> Array[Vector2i]:
	var world = context.world
	var start: Vector2i = world.metadata.start_cell
	_ensure_potential_field(world, start)
	var unique: Dictionary = {}
	var nominated_cells: Dictionary = {}
	for y: int in range(start.y + 6, mini(world.height - 2, start.y + 19), 2):
		for x: int in range(maxi(2, start.x - 18), mini(world.width - 2, start.x + 19), 2):
			var cell := Vector2i(x, y)
			var distance: int = _cached_distances[world.cell_to_index(cell)]
			if distance <= maximum_cost:
				unique[cell] = true
	for nominated: Vector2i in context.decision_knots:
		var index: int = world.cell_to_index(nominated)
		if index >= 0 and _cached_distances[index] <= maximum_cost:
			unique[nominated] = true
			nominated_cells[nominated] = true
	var candidates: Array[Vector2i] = []
	for cell_value: Variant in unique:
		candidates.append(cell_value)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_nominated := nominated_cells.has(a)
		var b_nominated := nominated_cells.has(b)
		if a_nominated != b_nominated:
			return a_nominated
		var a_cost: int = _cached_distances[world.cell_to_index(a)]
		var b_cost: int = _cached_distances[world.cell_to_index(b)]
		if a_cost != b_cost:
			return a_cost < b_cost
		return world.cell_to_index(a) < world.cell_to_index(b)
	)
	return candidates


func _analyze_frontier_segments(context: WorldGenContext, origin: Vector2i, approach_direction: String) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var direction_name := _direction_name(direction)
		if direction_name == approach_direction:
			continue
		var branch: Dictionary = _explore_branch_sector(context, origin, direction)
		if not bool(branch.get("valid", false)):
			continue
		var root_value := bool(branch.root_value)
		var water_risk := bool(branch.water_risk)
		var unstable_risk := bool(branch.unstable_risk)
		var hard_cost := int(branch.hard_cells) >= 2
		var safe_soft_route := bool(branch.safe_soft_route)
		var open_cells := int(branch.open_cells)
		var signature := "root=%d|water=%d|unstable=%d|hard=%d|safe=%d|open=%d" % [
			1 if root_value else 0,
			1 if water_risk else 0,
			1 if unstable_risk else 0,
			1 if hard_cost else 0,
			1 if safe_soft_route else 0,
			mini(2, open_cells / 3),
		]
		segments.append({
			"direction": direction_name,
			"continuous_cells": 6,
			"ray_dig_cost": int(branch.ray_dig_cost),
			"root_value": root_value,
			"water_risk": water_risk,
			"unstable_risk": unstable_risk,
			"hard_cost": hard_cost,
			"safe_soft_route": safe_soft_route,
			"open_cells": open_cells,
			"downstream_witnesses": branch.downstream_witnesses,
			"signature": signature,
		})
	return segments


func _explore_branch_sector(context: WorldGenContext, origin: Vector2i, direction: Vector2i) -> Dictionary:
	var world = context.world
	var origin_index: int = world.cell_to_index(origin)
	var costs: Dictionary = {origin_index: 0}
	var previous: Dictionary = {origin_index: -1}
	var cursor := origin
	var ray_dig_cost := 0
	var safe_soft_route := true
	for distance: int in range(1, 7):
		var ray_cell := origin + direction * distance
		var step_cost := _potential_step_cost(world, ray_cell)
		if step_cost >= IMPASSABLE:
			return {"valid": false}
		ray_dig_cost += step_cost
		if distance <= 3 and (
			world.get_material(ray_cell) not in [CellDataScript.TerrainMaterial.SOFT_SOIL, CellDataScript.TerrainMaterial.LOOSE_SOIL]
			or world.get_feature_id(ray_cell) >= 0
			or world.get_water_units(ray_cell) > 0
		):
			safe_soft_route = false
		var ray_index: int = world.cell_to_index(ray_cell)
		previous[ray_index] = world.cell_to_index(cursor)
		costs[ray_index] = ray_dig_cost
		cursor = ray_cell
	var heap: Array[int] = []
	_heap_push(heap, world.cell_to_index(cursor), ray_dig_cost)
	var root_value := false
	var water_risk := false
	var unstable_risk := false
	var hard_cells := 0
	var open_cells := 0
	var witness_goal_indices: Dictionary = {}
	while not heap.is_empty():
		var entry: int = _heap_pop(heap)
		var current_index := entry & HEAP_INDEX_MASK
		var current_cost := entry >> 32
		if current_cost != int(costs.get(current_index, IMPASSABLE)):
			continue
		var current: Vector2i = world.index_to_cell(current_index)
		if world.is_traversable(current):
			open_cells += 1
		if world.get_material(current) in [CellDataScript.TerrainMaterial.STONE, CellDataScript.TerrainMaterial.FOUNDATION]:
			hard_cells += 1
			if not witness_goal_indices.has("hard"):
				witness_goal_indices.hard = current_index
		var owner_id: int = world.get_feature_id(current)
		var owner: GeneratedFeature = context.feature_registry.get_feature(owner_id) if owner_id >= 0 else null
		if owner != null:
			if owner.type_id == "root_cluster" and bool(owner.metadata.get("food_opportunity", false)):
				root_value = true
				if not witness_goal_indices.has("root"):
					witness_goal_indices.root = current_index
			elif owner.type_id == "water_reservoir":
				water_risk = true
				if not witness_goal_indices.has("water"):
					witness_goal_indices.water = current_index
			elif owner.type_id == "unstable_pocket":
				unstable_risk = true
				if not witness_goal_indices.has("unstable"):
					witness_goal_indices.unstable = current_index
		for neighbor: Vector2i in world.get_cardinal_neighbors(current):
			var offset := neighbor - origin
			if absi(offset.x) + absi(offset.y) > 12 or not _offset_in_direction_sector(offset, direction):
				continue
			var step_cost := _potential_step_cost(world, neighbor)
			if step_cost >= IMPASSABLE:
				continue
			var neighbor_index: int = world.cell_to_index(neighbor)
			var next_cost := current_cost + step_cost
			if next_cost >= int(costs.get(neighbor_index, IMPASSABLE)):
				continue
			costs[neighbor_index] = next_cost
			previous[neighbor_index] = current_index
			_heap_push(heap, neighbor_index, next_cost)
	var downstream_witnesses: Dictionary = {}
	for witness_name: String in witness_goal_indices:
		downstream_witnesses[witness_name] = _reconstruct_branch_witness(world, previous, int(witness_goal_indices[witness_name]))
	return {
		"valid": true,
		"ray_dig_cost": ray_dig_cost,
		"safe_soft_route": safe_soft_route,
		"root_value": root_value,
		"water_risk": water_risk,
		"unstable_risk": unstable_risk,
		"hard_cells": hard_cells,
		"open_cells": open_cells,
		"downstream_witnesses": downstream_witnesses,
	}


func _reconstruct_branch_witness(world, previous: Dictionary, goal_index: int) -> Array[Vector2i]:
	var reversed: Array[Vector2i] = []
	var cursor := goal_index
	var guard := 0
	while cursor >= 0 and previous.has(cursor) and guard <= previous.size():
		reversed.append(world.index_to_cell(cursor))
		cursor = int(previous[cursor])
		guard += 1
	reversed.reverse()
	return reversed


func _offset_in_direction_sector(offset: Vector2i, direction: Vector2i) -> bool:
	var axial := offset.x * direction.x + offset.y * direction.y
	var perpendicular := absi(offset.x * direction.y - offset.y * direction.x)
	return axial > 0 and axial > perpendicular


func _validate_required_approaches(context: WorldGenContext, failures: Array[Dictionary]) -> void:
	for feature: GeneratedFeature in context.feature_registry.get_features():
		if not feature.required:
			continue
		var has_usable_approach := false
		var derived_approaches: Array[Vector2i] = _derived_landmark_boundary(context, feature) if feature.role == "landmark" else _derived_feature_boundary(context, feature)
		for approach: Vector2i in derived_approaches:
			if _potential_step_cost(context.world, approach) < IMPASSABLE:
				for neighbor: Vector2i in context.world.get_cardinal_neighbors(approach):
					if _potential_step_cost(context.world, neighbor) < IMPASSABLE:
						has_usable_approach = true
						break
			if has_usable_approach:
				break
		if not has_usable_approach:
			_fail(failures, "IMPOSSIBLE_APPROACH", "A required feature has no mouse-sized legal final-geometry boundary.", derived_approaches, feature.id)


func _validate_required_landmark_set(context: WorldGenContext, failures: Array[Dictionary]) -> void:
	for type_id: String in REQUIRED_LANDMARK_TYPES:
		var count := 0
		for feature: GeneratedFeature in context.feature_registry.get_features(type_id):
			if feature.role == "landmark" and feature.required:
				count += 1
		if count != 1:
			_fail(failures, "REQUIRED_LANDMARK_MISSING", "Required landmark type must exist exactly once: %s" % type_id)


func _derived_landmark_boundary(context: WorldGenContext, landmark: GeneratedFeature) -> Array[Vector2i]:
	if landmark.type_id == "start_burrow":
		var start_result: Array[Vector2i] = [context.world.metadata.start_cell]
		return start_result
	var content_type := String(REQUIRED_LANDMARK_CONTENT_TYPES.get(landmark.type_id, ""))
	if content_type.is_empty():
		return _derived_feature_boundary(context, landmark)
	var nearest: GeneratedFeature = null
	var nearest_distance := IMPASSABLE
	for feature: GeneratedFeature in context.feature_registry.get_features(content_type):
		var distance := absi(feature.anchor.x - landmark.anchor.x) + absi(feature.anchor.y - landmark.anchor.y)
		if distance < nearest_distance or (distance == nearest_distance and (nearest == null or feature.id < nearest.id)):
			nearest = feature
			nearest_distance = distance
	if nearest == null:
		var empty: Array[Vector2i] = []
		return empty
	return _derived_feature_boundary(context, nearest)


func _derived_feature_boundary(context: WorldGenContext, feature: GeneratedFeature) -> Array[Vector2i]:
	var unique: Dictionary = {}
	for feature_cell: Vector2i in feature.cells:
		for neighbor: Vector2i in context.world.get_cardinal_neighbors(feature_cell):
			if feature.cells.has(neighbor) or context.world.is_exterior(neighbor):
				continue
			if _potential_step_cost(context.world, neighbor) < IMPASSABLE:
				unique[neighbor] = true
	var result: Array[Vector2i] = []
	for value: Variant in unique:
		result.append(value)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return context.world.cell_to_index(a) < context.world.cell_to_index(b)
	)
	return result


func _connected_open_count(world, start: Vector2i, limit: int) -> int:
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size() and visited.size() < limit:
		var current := queue[head]
		head += 1
		for neighbor: Vector2i in world.get_cardinal_neighbors(current):
			if visited.has(neighbor) or not world.is_traversable(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return visited.size()


func _potential_step_cost(world, cell: Vector2i) -> int:
	if not world.is_in_bounds(cell) or world.is_exterior(cell):
		return IMPASSABLE
	if world.is_traversable(cell):
		return 0
	if world.is_protected(cell) or not world.is_solid(cell):
		return IMPASSABLE
	match world.get_material(cell):
		CellDataScript.TerrainMaterial.LOOSE_SOIL, CellDataScript.TerrainMaterial.SOFT_SOIL:
			return 1
		CellDataScript.TerrainMaterial.DAMP_CLAY, CellDataScript.TerrainMaterial.ROOT_SOIL:
			return 2
		CellDataScript.TerrainMaterial.STONE:
			return 4
		CellDataScript.TerrainMaterial.FOUNDATION:
			return 8
		_:
			return IMPASSABLE


func _nearest_feature_distance(context: WorldGenContext, type_id: String, origin: Vector2i) -> int:
	var nearest := IMPASSABLE
	for feature: GeneratedFeature in context.feature_registry.get_features(type_id):
		for cell: Vector2i in feature.cells:
			nearest = mini(nearest, absi(cell.x - origin.x) + absi(cell.y - origin.y))
	return nearest


func _has_material_within(world, origin: Vector2i, materials: Array, radius: int) -> bool:
	for y: int in range(maxi(0, origin.y - radius), mini(world.height, origin.y + radius + 1)):
		for x: int in range(maxi(0, origin.x - radius), mini(world.width, origin.x + radius + 1)):
			if absi(x - origin.x) + absi(y - origin.y) > radius:
				continue
			if materials.has(world.get_material(Vector2i(x, y))):
				return true
	return false


func _safe_soft_directions(world, origin: Vector2i) -> Array[String]:
	var result: Array[String] = []
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var safe_cells := 0
		for distance: int in range(1, 5):
			var cell := origin + direction * distance
			if not world.is_in_bounds(cell) or world.is_exterior(cell) or world.is_protected(cell):
				break
			if world.get_material(cell) not in [CellDataScript.TerrainMaterial.SOFT_SOIL, CellDataScript.TerrainMaterial.LOOSE_SOIL] or world.get_feature_id(cell) >= 0 or world.get_water_units(cell) > 0:
				break
			safe_cells += 1
		if safe_cells >= 3:
			result.append(_direction_name(direction))
	return result


func _potential_frontier_directions(world, origin: Vector2i) -> Array[String]:
	var result: Array[String] = []
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var legal_cells := 0
		for distance: int in range(1, 4):
			if _potential_step_cost(world, origin + direction * distance) >= IMPASSABLE:
				break
			legal_cells += 1
		if legal_cells == 3:
			result.append(_direction_name(direction))
	return result


func _nearest_feature_direction(context: WorldGenContext, type_id: String, origin: Vector2i) -> String:
	var nearest := IMPASSABLE
	var nearest_cell := Vector2i(-1, -1)
	for feature: GeneratedFeature in context.feature_registry.get_features(type_id):
		for cell: Vector2i in feature.cells:
			var distance := absi(cell.x - origin.x) + absi(cell.y - origin.y)
			if distance < nearest or (distance == nearest and context.world.cell_to_index(cell) < context.world.cell_to_index(nearest_cell)):
				nearest = distance
				nearest_cell = cell
	return _direction_from_cells(origin, nearest_cell) if nearest_cell.x >= 0 else ""


func _nearest_material_direction(world, origin: Vector2i, materials: Array, radius: int) -> String:
	var nearest := IMPASSABLE
	var nearest_cell := Vector2i(-1, -1)
	for y: int in range(origin.y - radius, origin.y + radius + 1):
		for x: int in range(origin.x - radius, origin.x + radius + 1):
			var cell := Vector2i(x, y)
			if not world.is_in_bounds(cell) or world.get_material(cell) not in materials:
				continue
			var distance := absi(x - origin.x) + absi(y - origin.y)
			if distance > radius:
				continue
			if distance < nearest or (distance == nearest and world.cell_to_index(cell) < world.cell_to_index(nearest_cell)):
				nearest = distance
				nearest_cell = cell
	return _direction_from_cells(origin, nearest_cell) if nearest_cell.x >= 0 else ""


func _direction_from_cells(origin: Vector2i, target: Vector2i) -> String:
	var delta := target - origin
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		return "RIGHT" if delta.x > 0 else "LEFT"
	if delta.y != 0:
		return "DOWN" if delta.y > 0 else "UP"
	return ""


func _direction_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "UP"
	if direction == Vector2i.LEFT:
		return "LEFT"
	if direction == Vector2i.RIGHT:
		return "RIGHT"
	return "DOWN"


func _validation_config(context: WorldGenContext) -> Dictionary:
	return context.config.get("validation", {})


func _fail(
	failures: Array[Dictionary],
	code: String,
	message: String,
	cells: Array[Vector2i] = [],
	feature_id: int = -1
) -> void:
	failures.append({"code": code, "message": message, "cells": cells.duplicate(), "feature_id": feature_id})


func _report(failures: Array[Dictionary], metrics: Dictionary) -> Dictionary:
	var codes := PackedStringArray()
	for failure: Dictionary in failures:
		codes.append(String(failure.code))
	return {
		"valid": failures.is_empty(),
		"failures": failures,
		"failure_codes": codes,
		"metrics": metrics,
	}


func _heap_push(heap: Array[int], index: int, cost: int) -> void:
	var encoded := (cost << 32) | index
	heap.append(encoded)
	var cursor := heap.size() - 1
	while cursor > 0:
		var parent := (cursor - 1) / 2
		if heap[parent] <= encoded:
			break
		heap[cursor] = heap[parent]
		cursor = parent
	heap[cursor] = encoded


func _heap_pop(heap: Array[int]) -> int:
	var result: int = heap[0]
	var tail: int = heap.pop_back()
	if heap.is_empty():
		return result
	var cursor := 0
	while true:
		var left := cursor * 2 + 1
		if left >= heap.size():
			break
		var right := left + 1
		var child := left
		if right < heap.size() and heap[right] < heap[left]:
			child = right
		if heap[child] >= tail:
			break
		heap[cursor] = heap[child]
		cursor = child
	heap[cursor] = tail
	return result
