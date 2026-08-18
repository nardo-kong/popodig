class_name WorldRepairer
extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GeneratedFeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")
const SignalSystemScript = preload("res://src/domain/features/signal_system.gd")


func repair(context: WorldGenContext, validation_report: Dictionary, repair_pass: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var before_hash := _repair_state_hash(context)
	var handled_codes: Dictionary = {}
	for failure: Dictionary in validation_report.get("failures", []):
		var code := String(failure.get("code", ""))
		if handled_codes.has(code):
			continue
		handled_codes[code] = true
		match code:
			"START_NOT_TRAVERSABLE", "START_SPACE_TOO_SMALL":
				_repair_start_space(context)
				actions.append(_action(repair_pass, code, "recarve_start_burrow", context.world.metadata.start_cell))
			"START_HAS_ACTIVE_WATER":
				for cell: Vector2i in failure.get("cells", []):
					context.world.set_water_units(cell, 0)
				actions.append(_action(repair_pass, code, "remove_start_water", context.world.metadata.start_cell))
			"EARLY_FOOD_MISSING", "EARLY_FOOD_UNREACHABLE":
				var food_root: GeneratedFeature = _find_food_root(context)
				if food_root == null:
					var roots := context.feature_registry.get_features("root_cluster")
					if not roots.is_empty():
						food_root = roots[0]
						food_root.metadata.food_opportunity = true
						_ensure_root_lifecycle_metadata(context, food_root)
					else:
						var root_anchor: Vector2i = context.world.metadata.start_cell + Vector2i(-7, 10)
						food_root = _add_repair_root(context, root_anchor)
				if food_root != null:
					var approaches: Array[Vector2i] = food_root.get_approach_cells()
					var failed_food_cells: Array = failure.get("cells", [])
					var food_approach: Vector2i = failed_food_cells[0] if not failed_food_cells.is_empty() else (approaches[0] if not approaches.is_empty() else food_root.anchor)
					_soften_corridor(context, context.world.metadata.start_cell, food_approach)
					actions.append(_action(repair_pass, code, "restore_reachable_food_root", food_root.anchor))
			"REQUIRED_DEPTH_SEALED":
				var depth_goal := Vector2i(context.world.metadata.start_cell.x, int(context.depth_targets.get("campaign_progress", context.world.height - 10)))
				_soften_corridor(context, context.world.metadata.start_cell, depth_goal)
				actions.append(_action(repair_pass, code, "soften_progress_corridor", depth_goal))
			"REQUIRED_LANDMARK_UNREACHABLE", "IMPOSSIBLE_APPROACH":
				var feature = context.feature_registry.get_feature(int(failure.get("feature_id", -1)))
				if feature != null:
					var approaches: Array[Vector2i] = []
					for cell_value: Variant in failure.get("cells", []):
						if cell_value is Vector2i:
							approaches.append(cell_value)
					if approaches.is_empty():
						approaches = feature.get_approach_cells()
					var approach: Vector2i = approaches[0] if not approaches.is_empty() else feature.anchor
					_soften_corridor(context, context.world.metadata.start_cell, approach)
					actions.append(_action(repair_pass, code, "soften_landmark_approach", approach))
			"SIGNAL_HOOK_MISSING", "SIGNAL_HOOK_INVALID":
				if _rebuild_signal_hooks(context):
					actions.append(_action(repair_pass, code, "rebuild_signal_emitters", context.world.metadata.start_cell))
			"SIGNAL_FIELD_MISSING", "SIGNAL_FIELD_EXTERIOR_LEAK":
				_rebuild_signal_fields(context)
				actions.append(_action(repair_pass, code, "rebuild_signal_fields", context.world.metadata.start_cell))
			"DECISION_KNOT_MISSING":
				var knot: Vector2i = context.world.metadata.start_cell + Vector2i(0, 10)
				_repair_decision_knot(context, knot)
				actions.append(_action(repair_pass, code, "insert_decision_knot", knot))
			"FEATURE_OUT_OF_BOUNDS":
				var feature_id := int(failure.get("feature_id", -1))
				var invalid_feature = context.feature_registry.get_feature(feature_id)
				if invalid_feature != null and not invalid_feature.required:
					_remove_optional_feature(context, invalid_feature)
					actions.append(_action(repair_pass, code, "remove_invalid_optional_feature", Vector2i.ZERO))
			"RESERVOIR_MISSING":
				var reservoir_anchor: Vector2i = context.world.metadata.start_cell + Vector2i(10, 14)
				_add_repair_reservoir(context, reservoir_anchor)
				actions.append(_action(repair_pass, code, "insert_finite_reservoir", reservoir_anchor))
			"RESERVOIR_EMPTY":
				var empty_reservoir: GeneratedFeature = context.feature_registry.get_feature(int(failure.get("feature_id", -1)))
				if empty_reservoir != null:
					empty_reservoir.metadata.reserve_units = maxi(24, empty_reservoir.cells.size() * 4)
					actions.append(_action(repair_pass, code, "restore_finite_reserve", empty_reservoir.anchor))
			"FIRST_HAZARD_TOO_CLOSE":
				var reservoir = context.feature_registry.get_feature(int(failure.get("feature_id", -1)))
				if reservoir != null and not reservoir.required:
					var removed_anchor: Vector2i = reservoir.anchor
					_remove_optional_feature(context, reservoir)
					actions.append(_action(repair_pass, code, "remove_unsafe_optional_reservoir", removed_anchor))
			_:
				pass
	if not actions.is_empty():
		_rebuild_signal_fields(context)
	var after_hash := _repair_state_hash(context)
	if before_hash == after_hash:
		actions.clear()
	else:
		for action: Dictionary in actions:
			action.before_hash = before_hash
			action.after_hash = after_hash
		context.repairs.append_array(actions)
	return actions


func _rebuild_signal_fields(context: WorldGenContext) -> void:
	var signal_system := SignalSystemScript.new()
	signal_system.configure(
		context.world,
		context.feature_registry,
		context.signal_emitters,
		context.config.get("signal_fields", {}),
		true,
		false
	)


func _repair_start_space(context: WorldGenContext) -> void:
	var start: Vector2i = context.world.metadata.start_cell
	for y: int in range(start.y - 2, start.y + 3):
		for x: int in range(start.x - 5, start.x + 6):
			var cell := Vector2i(x, y)
			if not context.world.is_in_bounds(cell) or context.world.is_exterior(cell) or context.world.is_protected(cell):
				continue
			var relative := Vector2(float(x - start.x) / 5.5, float(y - start.y) / 2.8)
			if relative.length_squared() <= 1.0:
				_open_interior_cell(context, cell)


func _soften_corridor(context: WorldGenContext, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var cursor := from_cell
	var vertical_first := ((context.seed_value + context.attempt) & 1) == 0
	while cursor != to_cell:
		if (vertical_first and cursor.y != to_cell.y) or cursor.x == to_cell.x:
			cursor.y += signi(to_cell.y - cursor.y)
		elif cursor.x != to_cell.x:
			cursor.x += signi(to_cell.x - cursor.x)
		if not context.world.is_in_bounds(cursor):
			break
		if context.world.is_exterior(cursor) or context.world.is_protected(cursor) or context.world.get_feature_id(cursor) >= 0:
			continue
		if not context.world.is_traversable(cursor):
			context.world.set_material(cursor, CellDataScript.TerrainMaterial.SOFT_SOIL)


func _repair_decision_knot(context: WorldGenContext, knot: Vector2i) -> void:
	if not context.decision_knots.has(knot):
		context.decision_knots.append(knot)
	_soften_corridor(context, context.world.metadata.start_cell, knot)
	if _nearest_food_root_distance(context, knot) > 10:
		_add_repair_root(context, knot + Vector2i(-7, 2), false)
	if _nearest_feature_distance(context, "water_reservoir", knot) > 12:
		_add_repair_reservoir(context, knot + Vector2i(10, 5), false)
	if not _has_hard_material_within(context, knot, 7):
		for y: int in range(knot.y + 4, knot.y + 7):
			for x: int in range(knot.x - 2, knot.x + 3):
				var cell := Vector2i(x, y)
				if (
					context.world.is_in_bounds(cell)
					and not context.world.is_exterior(cell)
					and not context.world.is_protected(cell)
					and context.world.get_feature_id(cell) < 0
				):
					context.world.set_material(cell, CellDataScript.TerrainMaterial.STONE)
	_ensure_safe_soft_direction(context, knot)


func _nearest_feature_distance(context: WorldGenContext, type_id: String, origin: Vector2i) -> int:
	var nearest := 1 << 28
	for feature: GeneratedFeature in context.feature_registry.get_features(type_id):
		for cell: Vector2i in feature.cells:
			nearest = mini(nearest, absi(cell.x - origin.x) + absi(cell.y - origin.y))
	return nearest


func _nearest_food_root_distance(context: WorldGenContext, origin: Vector2i) -> int:
	var nearest := 1 << 28
	for feature: GeneratedFeature in context.feature_registry.get_features("root_cluster"):
		if not bool(feature.metadata.get("food_opportunity", false)):
			continue
		for cell: Vector2i in feature.cells:
			nearest = mini(nearest, absi(cell.x - origin.x) + absi(cell.y - origin.y))
	return nearest


func _has_hard_material_within(context: WorldGenContext, origin: Vector2i, radius: int) -> bool:
	for y: int in range(origin.y - radius, origin.y + radius + 1):
		for x: int in range(origin.x - radius, origin.x + radius + 1):
			var cell := Vector2i(x, y)
			if not context.world.is_in_bounds(cell):
				continue
			if absi(x - origin.x) + absi(y - origin.y) > radius:
				continue
			if context.world.get_material(cell) in [CellDataScript.TerrainMaterial.STONE, CellDataScript.TerrainMaterial.FOUNDATION]:
				return true
	return false


func _ensure_safe_soft_direction(context: WorldGenContext, knot: Vector2i) -> void:
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var lane: Array[Vector2i] = []
		for distance: int in range(1, 5):
			var cell := knot + direction * distance
			if (
				not context.world.is_in_bounds(cell)
				or context.world.is_exterior(cell)
				or context.world.is_protected(cell)
				or context.world.get_feature_id(cell) >= 0
			):
				lane.clear()
				break
			lane.append(cell)
		if lane.size() < 3:
			continue
		for cell: Vector2i in lane:
			if not context.world.is_traversable(cell):
				context.world.set_material(cell, CellDataScript.TerrainMaterial.SOFT_SOIL)
		return


func _find_food_root(context: WorldGenContext):
	for feature: GeneratedFeature in context.feature_registry.get_features("root_cluster"):
		if bool(feature.metadata.get("food_opportunity", false)):
			return feature
	return null


func _add_repair_root(context: WorldGenContext, anchor: Vector2i, required: bool = true) -> GeneratedFeature:
	var cells := _ellipse_cells(context, anchor, Vector2i(3, 2))
	var feature := GeneratedFeatureScript.new("root_cluster", anchor, cells, required)
	feature.metadata = {
		"food_opportunity": true,
		"approach_cells": _approach_cells(context, anchor, Vector2i(4, 2)),
		"repair_inserted": true,
	}
	_ensure_root_lifecycle_metadata(context, feature)
	context.feature_registry.add_feature(feature)
	_claim_feature_cells(context, feature)
	for cell: Vector2i in feature.cells:
		context.world.set_material(cell, CellDataScript.TerrainMaterial.ROOT_SOIL)
	context.signal_emitters.append(_emitter_for_feature(feature))
	return feature


func _ensure_root_lifecycle_metadata(context: WorldGenContext, feature: GeneratedFeature) -> void:
	var root_config: Dictionary = context.config.get("root_feature", {})
	var reserve: int = int(
		root_config.get("required_food_reserve", 12)
		if feature.required
		else root_config.get("optional_food_reserve", 8)
	)
	feature.metadata.lifecycle_state = "SIGNAL"
	feature.metadata.reaction_fired = false
	feature.metadata.reveal_count = 0
	feature.metadata.food_reserve_units = reserve if bool(feature.metadata.get("food_opportunity", false)) else 0
	feature.metadata.initial_food_yield = int(root_config.get("initial_food_yield", 4))
	feature.metadata.forage_interval_seconds = float(root_config.get("forage_interval_seconds", 8.0))
	feature.metadata.food_produced_total = 0
	feature.metadata.food_depleted = int(feature.metadata.food_reserve_units) <= 0


func _add_repair_reservoir(context: WorldGenContext, anchor: Vector2i, required: bool = true) -> void:
	var cells := _ellipse_cells(context, anchor, Vector2i(3, 2))
	var feature := GeneratedFeatureScript.new("water_reservoir", anchor, cells, required)
	feature.metadata = {
		"reserve_units": maxi(24, cells.size() * 4),
		"approach_cells": _approach_cells(context, anchor, Vector2i(4, 2)),
		"repair_inserted": true,
	}
	context.feature_registry.add_feature(feature)
	_claim_feature_cells(context, feature)
	for cell: Vector2i in feature.cells:
		context.world.set_material(cell, CellDataScript.TerrainMaterial.DAMP_CLAY)
	context.signal_emitters.append(_emitter_for_feature(feature))


func _open_interior_cell(context: WorldGenContext, cell: Vector2i) -> void:
	if context.world.is_exterior(cell) or context.world.is_protected(cell):
		return
	context.world.set_material(cell, CellDataScript.TerrainMaterial.SOFT_SOIL)
	context.world.set_excavated(cell, true, true)
	context.world.set_water_units(cell, 0)


func _ellipse_cells(context: WorldGenContext, anchor: Vector2i, radius: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(anchor.y - radius.y, anchor.y + radius.y + 1):
		for x: int in range(anchor.x - radius.x, anchor.x + radius.x + 1):
			var cell := Vector2i(x, y)
			if not context.world.is_in_bounds(cell) or context.world.is_exterior(cell):
				continue
			var normalized := Vector2(float(x - anchor.x) / maxf(1.0, radius.x), float(y - anchor.y) / maxf(1.0, radius.y))
			if normalized.length_squared() <= 1.0:
				cells.append(cell)
	return cells


func _approach_cells(context: WorldGenContext, anchor: Vector2i, radius: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in [
		anchor + Vector2i(-radius.x - 1, 0),
		anchor + Vector2i(radius.x + 1, 0),
		anchor + Vector2i(0, -radius.y - 1),
		anchor + Vector2i(0, radius.y + 1),
	]:
		if context.world.is_in_bounds(cell) and not context.world.is_exterior(cell):
			result.append(cell)
	return result


func _emitter_for_feature(feature: GeneratedFeature) -> Dictionary:
	var channel := "instability"
	if feature.type_id == "root_cluster":
		channel = "root_density"
	elif feature.type_id == "water_reservoir":
		channel = "moisture"
	return {
		"feature_id": feature.id,
		"channel": channel,
		"anchor": feature.anchor,
		"strength": int(feature.metadata.get("signal_strength", 4)),
		"falloff": int(feature.metadata.get("signal_falloff", 1)),
	}


func _claim_feature_cells(context: WorldGenContext, feature: GeneratedFeature) -> void:
	var accepted: Array[Vector2i] = []
	var emptied_optional_ids: Array[int] = []
	for cell: Vector2i in feature.cells:
		if not context.world.is_in_bounds(cell) or context.world.is_exterior(cell) or context.world.is_protected(cell):
			continue
		var previous_id: int = context.world.get_feature_id(cell)
		if previous_id >= 0 and previous_id != feature.id:
			var previous: GeneratedFeature = context.feature_registry.get_feature(previous_id)
			if previous != null and previous.required:
				continue
			if previous != null:
				previous.cells.erase(cell)
				if previous.cells.is_empty() and not previous.required:
					emptied_optional_ids.append(previous.id)
		context.world.set_feature_id(cell, feature.id)
		accepted.append(cell)
	feature.cells = accepted
	for feature_id: int in emptied_optional_ids:
		context.feature_registry.remove_feature(feature_id)


func _rebuild_signal_hooks(context: WorldGenContext) -> bool:
	var rebuilt: Array[Dictionary] = []
	for type_id: String in ["root_cluster", "water_reservoir", "unstable_pocket"]:
		for feature: GeneratedFeature in context.feature_registry.get_features(type_id):
			rebuilt.append(_emitter_for_feature(feature))
	if rebuilt == context.signal_emitters:
		return false
	context.signal_emitters = rebuilt
	return true


func _remove_optional_feature(context: WorldGenContext, feature: GeneratedFeature) -> void:
	if feature == null or feature.required:
		return
	for cell: Vector2i in feature.cells:
		if context.world.get_feature_id(cell) != feature.id:
			continue
		context.world.set_feature_id(cell, -1)
		context.world.set_material(cell, _material_for_stratum(context.world.get_stratum_id(cell)))
	context.feature_registry.remove_feature(feature.id)
	var retained_emitters: Array[Dictionary] = []
	for emitter: Dictionary in context.signal_emitters:
		if int(emitter.get("feature_id", -1)) != feature.id:
			retained_emitters.append(emitter)
	context.signal_emitters = retained_emitters


func _material_for_stratum(stratum_id: int) -> int:
	match stratum_id:
		0:
			return CellDataScript.TerrainMaterial.SOFT_SOIL
		1:
			return CellDataScript.TerrainMaterial.DAMP_CLAY
		2, 3:
			return CellDataScript.TerrainMaterial.STONE
		_:
			return CellDataScript.TerrainMaterial.SOFT_SOIL


func _repair_state_hash(context: WorldGenContext) -> int:
	var value: int = context.world.content_checksum()
	value = int((value * 65599 + context.feature_registry.checksum()) % 2147483647)
	for knot: Vector2i in context.decision_knots:
		value = int((value * 65599 + knot.x * 257 + knot.y) % 2147483647)
	var emitters := context.signal_emitters.duplicate(true)
	emitters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := int(a.get("feature_id", -1))
		var b_id := int(b.get("feature_id", -1))
		if a_id != b_id:
			return a_id < b_id
		return String(a.get("channel", "")) < String(b.get("channel", ""))
	)
	for emitter: Dictionary in emitters:
		value = int((value * 65599 + int(emitter.get("feature_id", -1))) % 2147483647)
		for byte: int in String(emitter.get("channel", "")).to_utf8_buffer():
			value = int((value * 65599 + byte) % 2147483647)
		var anchor: Vector2i = emitter.get("anchor", Vector2i(-1, -1))
		value = int((value * 65599 + anchor.x) % 2147483647)
		value = int((value * 65599 + anchor.y) % 2147483647)
		value = int((value * 65599 + int(emitter.get("strength", 0))) % 2147483647)
		value = int((value * 65599 + int(emitter.get("falloff", -1))) % 2147483647)
	return value


func _action(pass_index: int, reason_code: String, strategy: String, target: Vector2i) -> Dictionary:
	return {
		"pass": pass_index,
		"reason_code": reason_code,
		"strategy": strategy,
		"target": target,
	}
