class_name StructuredWorldGenerator
extends RefCounted

const DiscoveryScript = preload("res://src/domain/features/discovery_system.gd")
const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GeneratedFeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")
const SignalSystemScript = preload("res://src/domain/features/signal_system.gd")
const WorldGenContextScript = preload("res://src/domain/worldgen/world_gen_context.gd")
const WorldGenerationResultScript = preload("res://src/domain/worldgen/world_generation_result.gd")
const WorldGridScript = preload("res://src/domain/world/world_grid.gd")
const WorldRepairerScript = preload("res://src/domain/worldgen/world_repairer.gd")
const WorldValidatorScript = preload("res://src/domain/worldgen/world_validator.gd")

const STAGE_ORDER: PackedStringArray = [
	"skeleton",
	"strata",
	"landmarks",
	"features",
	"terrain",
	"signal_fields",
	"validation",
	"repair",
]


func generate(config: Dictionary, seed_value: int):
	return generate_result(config, seed_value).world


func generate_result(config: Dictionary, seed_value: int) -> WorldGenerationResult:
	var max_attempts := maxi(1, int(config.get("max_generation_attempts", 3)))
	var last_result: WorldGenerationResult
	var attempt_history: Array[Dictionary] = []
	for attempt: int in range(max_attempts):
		var context := WorldGenContextScript.new(config, seed_value, attempt)
		_run_timed(context, "skeleton", func() -> void: _stage_skeleton(context))
		_run_timed(context, "strata", func() -> void: _stage_strata(context))
		_run_timed(context, "landmarks", func() -> void: _stage_landmarks(context))
		_run_timed(context, "features", func() -> void: _stage_features(context))
		_run_timed(context, "terrain", func() -> void: _stage_terrain(context))
		_run_timed(context, "signal_fields", func() -> void: _stage_signal_fields(context))
		var validator := WorldValidatorScript.new()
		var validation_started := Time.get_ticks_usec()
		context.validation_report = validator.validate(context)
		var initial_failure_codes: PackedStringArray = context.validation_report.get("failure_codes", PackedStringArray()).duplicate()
		var initial_metrics: Dictionary = (context.validation_report.get("metrics", {}) as Dictionary).duplicate(true)
		var validation_ms := (Time.get_ticks_usec() - validation_started) / 1000.0
		context.record_stage("validation", validation_ms, context.validation_report.get("metrics", {}))
		if bool(context.config.get("instrument_stage_stdout", false)):
			print("WORLDGEN_STAGE name=validation ms=%.2f valid=%s failures=%s" % [validation_ms, context.validation_report.get("valid", false), context.validation_report.get("failure_codes", [])])
		var repair_started := Time.get_ticks_usec()
		var max_repairs := maxi(0, int(config.get("max_repair_passes", 4)))
		var repairer := WorldRepairerScript.new()
		for repair_pass: int in range(max_repairs):
			if bool(context.validation_report.get("valid", false)):
				break
			var actions: Array[Dictionary] = repairer.repair(context, context.validation_report, repair_pass)
			if actions.is_empty():
				break
			context.validation_report = validator.validate(context)
		context.record_stage("repair", (Time.get_ticks_usec() - repair_started) / 1000.0, {"action_count": context.repairs.size()})
		if bool(context.config.get("instrument_stage_stdout", false)):
			print("WORLDGEN_STAGE name=repair actions=%d valid=%s" % [context.repairs.size(), context.validation_report.get("valid", false)])
		_finalize_world_metadata(context)
		attempt_history.append({
			"attempt": attempt,
			"initial_failure_codes": initial_failure_codes,
			"initial_metrics": initial_metrics,
			"final_failure_codes": context.validation_report.get("failure_codes", PackedStringArray()).duplicate(),
			"repair_count": context.repairs.size(),
		})
		var report := _build_report(context)
		report.attempt_history = attempt_history.duplicate(true)
		last_result = WorldGenerationResultScript.new(context.world, context.feature_registry, report)
		if last_result.success:
			return last_result
	return last_result


func _run_timed(context: WorldGenContext, stage_name: String, stage_callable: Callable) -> void:
	var started := Time.get_ticks_usec()
	stage_callable.call()
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	context.record_stage(stage_name, elapsed_ms)
	if bool(context.config.get("instrument_stage_stdout", false)):
		print("WORLDGEN_STAGE name=%s ms=%.2f" % [stage_name, elapsed_ms])


func _stage_skeleton(context: WorldGenContext) -> void:
	var size := _validated_world_size(context.config.get("world_size", [96, 72]))
	context.width = size.x
	context.height = size.y
	context.chunk_size = maxi(4, int(context.config.get("chunk_size", 16)))
	context.world = WorldGridScript.new(context.width, context.height, context.chunk_size)
	var rng = context.stage_rng("skeleton")
	context.surface_heights.resize(context.width)
	var surface_config: Dictionary = context.config.get("surface", {})
	var minimum_y := maxi(3, int(context.height * float(surface_config.get("minimum_ratio", 0.06))))
	var maximum_y := maxi(minimum_y + 1, int(context.height * float(surface_config.get("maximum_ratio", 0.12))))
	var current := rng.next_int(minimum_y, maximum_y)
	for x: int in range(context.width):
		if x % 3 == 0:
			current = clampi(current + rng.next_int(-1, 1), minimum_y, maximum_y)
		context.surface_heights[x] = current
	var center_x := context.width / 2 + rng.next_int(-maxi(1, context.width / 16), maxi(1, context.width / 16))
	center_x = clampi(center_x, 9, context.width - 10)
	var start_y := mini(context.height - 12, context.surface_heights[center_x] + 7)
	var start_cell := Vector2i(center_x, start_y + 2)
	context.depth_targets = {
		"chapter_2": int(context.height * 0.48),
		"chapter_3": int(context.height * 0.72),
		"campaign_progress": int(context.height * 0.86),
	}
	context.world.metadata = {
		"seed": context.seed_value,
		"worldgen_version": int(context.config.get("worldgen_version", 3)),
		"generator": "structured_v3",
		"generation_attempt": context.attempt,
		"start_cell": start_cell,
		"surface_heights": context.surface_heights,
		"depth_targets": context.depth_targets.duplicate(true),
	}


func _stage_strata(context: WorldGenContext) -> void:
	var rng = context.stage_rng("strata")
	var definitions: Array = context.config.get("strata", [])
	if definitions.size() < 4:
		definitions = [
			{"id": 0, "end_ratio": 0.30},
			{"id": 1, "end_ratio": 0.54},
			{"id": 2, "end_ratio": 0.78},
			{"id": 3, "end_ratio": 1.0},
		]
	var boundary_names: Array[String] = ["topsoil_end", "transition_end", "wet_end"]
	for boundary_index: int in range(3):
		var values := PackedInt32Array()
		values.resize(context.width)
		var ratio := float((definitions[boundary_index] as Dictionary).get("end_ratio", [0.30, 0.54, 0.78][boundary_index]))
		var current_offset := 0
		for x: int in range(context.width):
			if x % 5 == 0:
				current_offset = clampi(current_offset + rng.next_int(-1, 1), -3, 3)
			var surface_y := context.surface_heights[x]
			values[x] = clampi(surface_y + int((context.height - surface_y) * ratio) + current_offset, surface_y + 5, context.height - 3)
		context.stratum_boundaries[boundary_names[boundary_index]] = values


func _stage_landmarks(context: WorldGenContext) -> void:
	var rng = context.stage_rng("landmarks")
	var start: Vector2i = context.world.metadata.start_cell
	var knot := Vector2i(start.x + rng.next_int(-2, 2), start.y + 10)
	context.decision_knots.append(knot)
	var root_anchor := _clamp_underground(context, knot + Vector2i(-8, 2))
	var reservoir_anchor := _clamp_underground(context, knot + Vector2i(10, 5))
	var foundation_y := int((context.stratum_boundaries.wet_end as PackedInt32Array)[start.x])
	var foundation_anchor := _clamp_underground(context, Vector2i(context.width / 2 + rng.next_int(-context.width / 6, context.width / 6), foundation_y))
	var old_anchor := _clamp_underground(context, Vector2i(rng.next_int(14, context.width - 15), int(context.depth_targets.chapter_3) + rng.next_int(1, 5)))
	var warm_anchor := _clamp_underground(context, Vector2i(rng.next_int(12, context.width - 13), context.height - 9))
	_add_landmark(context, "start_burrow", start, [start], true)
	_add_landmark(context, "major_root_anchor", root_anchor, _cardinal_approaches(context, root_anchor, Vector2i(5, 3)), true)
	_add_landmark(context, "first_reservoir_region", reservoir_anchor, _cardinal_approaches(context, reservoir_anchor, Vector2i(5, 3)), true)
	_add_landmark(context, "foundation_segment", foundation_anchor, _cardinal_approaches(context, foundation_anchor, Vector2i(8, 2)), true)
	_add_landmark(context, "old_burrow_entrance", old_anchor, _cardinal_approaches(context, old_anchor, Vector2i(6, 3)), true)
	_add_landmark(context, "final_warm_chamber", warm_anchor, _cardinal_approaches(context, warm_anchor, Vector2i(6, 3)), true)
	context.world.metadata.landmark_anchors = {
		"major_root_anchor": root_anchor,
		"first_reservoir_region": reservoir_anchor,
		"foundation_segment": foundation_anchor,
		"old_burrow_entrance": old_anchor,
		"final_warm_chamber": warm_anchor,
	}


func _stage_features(context: WorldGenContext) -> void:
	var rng = context.stage_rng("features")
	var anchors: Dictionary = context.world.metadata.landmark_anchors
	_add_root_cluster(context, anchors.major_root_anchor, true, rng)
	_add_reservoir(context, anchors.first_reservoir_region, true, rng)
	var knot: Vector2i = context.decision_knots[0]
	_add_rock_mass(context, _clamp_underground(context, knot + Vector2i(0, 6)), Vector2i(3, 2), rng)
	var counts: Dictionary = context.config.get("feature_counts", {})
	for _index: int in range(maxi(0, int(counts.get("additional_root_clusters", 2)))):
		_add_root_cluster(context, _random_anchor(context, rng, 0.28, 0.68), false, rng)
	for index: int in range(maxi(0, int(counts.get("additional_reservoirs", 1)))):
		# Chapter 2 richer water (docs/production/19): the first additional
		# reservoir sits elevated in the transition band so its breach drains
		# through the mid-world; later ones stay in the wet stratum.
		if index == 0:
			_add_reservoir(context, _random_anchor(context, rng, 0.38, 0.50), false, rng)
		else:
			_add_reservoir(context, _random_anchor(context, rng, 0.42, 0.76), false, rng)
	for _index: int in range(maxi(0, int(counts.get("rock_masses", 5)))):
		_add_rock_mass(context, _random_anchor(context, rng, 0.18, 0.84), Vector2i(rng.next_int(2, 5), rng.next_int(1, 3)), rng)
	for _index: int in range(maxi(0, int(counts.get("natural_cavities", 5)))):
		_add_natural_cavity(context, _random_anchor(context, rng, 0.22, 0.82), Vector2i(rng.next_int(2, 5), rng.next_int(1, 3)))
	var pocket_count := maxi(0, int(counts.get("unstable_pockets", 3)))
	# Chapter 2 overlap knot (docs/production/19): one unstable pocket sits
	# directly below the required reservoir, so a breach floods weak terrain
	# and the two hazards compound instead of living in separate strata.
	if pocket_count > 0:
		var required_reservoir: GeneratedFeature = null
		for feature in context.feature_registry.get_features("water_reservoir"):
			if feature.required:
				required_reservoir = feature
				break
		if required_reservoir != null:
			var overlap_anchor := _clamp_underground(context, required_reservoir.anchor + Vector2i(rng.next_int(-2, 2), rng.next_int(4, 6)))
			_add_unstable_pocket(context, overlap_anchor, Vector2i(rng.next_int(2, 4), rng.next_int(2, 3)))
			pocket_count -= 1
	for _index: int in range(pocket_count):
		_add_unstable_pocket(context, _random_anchor(context, rng, 0.34, 0.82), Vector2i(rng.next_int(2, 4), rng.next_int(2, 3)))
	_add_foundation(context, anchors.foundation_segment, rng)
	_add_old_burrow(context, anchors.old_burrow_entrance, rng)
	_add_warm_chamber(context, anchors.final_warm_chamber)


func _stage_terrain(context: WorldGenContext) -> void:
	var rng = context.stage_rng("terrain")
	var owner_by_cell: Dictionary = {}
	var terrain_features := context.feature_registry.get_features_by_role("feature")
	terrain_features.sort_custom(func(a: GeneratedFeature, b: GeneratedFeature) -> bool:
		if a.required != b.required:
			return a.required
		return a.id < b.id
	)
	var empty_optional_ids: Array[int] = []
	for feature: GeneratedFeature in terrain_features:
		var accepted_cells: Array[Vector2i] = []
		for cell: Vector2i in feature.cells:
			if context.world.is_in_bounds(cell) and not owner_by_cell.has(cell):
				owner_by_cell[cell] = feature
				accepted_cells.append(cell)
		feature.cells = accepted_cells
		if feature.cells.is_empty() and not feature.required:
			empty_optional_ids.append(feature.id)
	for feature_id: int in empty_optional_ids:
		context.feature_registry.remove_feature(feature_id)
	var margin := maxi(1, int(context.config.get("protected_margin", 1)))
	# Phase 13 authored topsoil variation: sparse small stones knit the soft
	# topsoil band so uniform regions read less tiled. Stabilising-only (stone
	# raises allowed spans), so the content validator stays authoritative.
	var topsoil_stone_ratio := clampf(float(context.config.get("topsoil_stone_ratio", 0.006)), 0.0, 0.05)
	for y: int in range(context.height):
		for x: int in range(context.width):
			var cell := Vector2i(x, y)
			var exterior := y < context.surface_heights[x]
			var protected_cell := x < margin or x >= context.width - margin or y >= context.height - margin
			if exterior:
				context.world.initialize_cell(cell, CellDataScript.TerrainMaterial.EMPTY, true, protected_cell, true)
				continue
			var stratum_id := _stratum_at(context, cell)
			var material := _base_material(stratum_id, rng)
			if stratum_id == 0 and rng.next_float() < topsoil_stone_ratio:
				material = CellDataScript.TerrainMaterial.STONE
			var excavated := false
			var owner: GeneratedFeature = owner_by_cell.get(cell)
			if owner != null:
				match owner.type_id:
					"root_cluster":
						material = CellDataScript.TerrainMaterial.ROOT_SOIL
					"old_burrow" when (owner.metadata.get("weak_cells", []) as Array).has(cell):
						material = CellDataScript.TerrainMaterial.LOOSE_SOIL
					"water_reservoir":
						material = CellDataScript.TerrainMaterial.DAMP_CLAY
					"rock_mass":
						material = CellDataScript.TerrainMaterial.STONE
					"unstable_pocket":
						material = CellDataScript.TerrainMaterial.LOOSE_SOIL
					"foundation":
						material = CellDataScript.TerrainMaterial.FOUNDATION
						protected_cell = true
					"natural_cavity", "old_burrow", "warm_chamber":
						excavated = true
			context.world.initialize_cell(cell, material, excavated, protected_cell, false)
			context.world.set_stratum_id(cell, stratum_id)
			if owner != null:
				context.world.set_feature_id(cell, owner.id)
	_carve_start_burrow(context)
	_reconcile_registry_with_owner_layer(context)
	_ensure_required_reservoir_shoulders(context)
	_reconcile_registry_with_owner_layer(context)
	_ensure_decision_knot_safe_route(context)
	_reconcile_registry_with_owner_layer(context)
	_trim_preexposed_food_roots(context)
	for landmark: GeneratedFeature in context.feature_registry.get_features_by_role("landmark"):
		for cell: Vector2i in landmark.cells:
			if context.world.is_in_bounds(cell):
				context.world.set_landmark(cell, true)
	context.world.mark_all_chunks_dirty()


## Phase 13: optional food Roots may not touch generated open cells — the
## Signal → Reveal lifecycle requires excavation before exposure, so trim the
## exposed fringe here, deterministically, before validation sees the world.
func _trim_preexposed_food_roots(context: WorldGenContext) -> void:
	var restore_rng := DeterministicRng.new(0)
	for pass_index: int in range(3):
		var any_trimmed := false
		for feature in context.feature_registry.get_features("root_cluster"):
			if feature.required or not bool(feature.metadata.get("food_opportunity", false)):
				continue
			var exposed: Array[Vector2i] = []
			for feature_cell: Vector2i in feature.cells:
				for neighbor: Vector2i in context.world.get_cardinal_neighbors(feature_cell):
					if feature.cells.has(neighbor):
						continue
					if context.world.is_in_bounds(neighbor) and context.world.is_traversable(neighbor):
						exposed.append(feature_cell)
						break
			if exposed.is_empty():
				continue
			if not (feature.cells.has(feature.anchor) and exposed.has(feature.anchor)) and feature.cells.size() - exposed.size() >= 3:
				for cell: Vector2i in exposed:
					feature.cells.erase(cell)
					if context.world.get_feature_id(cell) == feature.id:
						context.world.set_feature_id(cell, -1)
						context.world.set_material(cell, _base_material(context.world.get_stratum_id(cell), restore_rng))
				any_trimmed = true
			else:
				context.feature_registry.remove_feature(feature.id)
				for cell: Vector2i in feature.cells:
					if context.world.get_feature_id(cell) == feature.id:
						context.world.set_feature_id(cell, -1)
						context.world.set_material(cell, _base_material(context.world.get_stratum_id(cell), restore_rng))
				any_trimmed = true
		if not any_trimmed:
			break


func _reconcile_registry_with_owner_layer(context: WorldGenContext) -> void:
	var empty_optional_ids: Array[int] = []
	for feature: GeneratedFeature in context.feature_registry.get_features_by_role("feature"):
		var owned_cells: Array[Vector2i] = []
		for cell: Vector2i in feature.cells:
			if context.world.get_feature_id(cell) == feature.id:
				owned_cells.append(cell)
		feature.cells = owned_cells
		if feature.cells.is_empty() and not feature.required:
			empty_optional_ids.append(feature.id)
	for feature_id: int in empty_optional_ids:
		context.feature_registry.remove_feature(feature_id)


func _ensure_decision_knot_safe_route(context: WorldGenContext) -> void:
	for knot: Vector2i in context.decision_knots:
		_release_feature_owner(context, knot)
		context.world.set_material(knot, CellDataScript.TerrainMaterial.SOFT_SOIL)
		context.world.set_excavated(knot, false, false)
		context.world.set_water_units(knot, 0)
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var lane: Array[Vector2i] = []
			for distance: int in range(1, 5):
				var cell := knot + direction * distance
				if not context.world.is_in_bounds(cell) or context.world.is_exterior(cell) or context.world.is_protected(cell):
					lane.clear()
					break
				var owner_id: int = context.world.get_feature_id(cell)
				var owner: GeneratedFeature = context.feature_registry.get_feature(owner_id) if owner_id >= 0 else null
				if owner != null and owner.required:
					lane.clear()
					break
				lane.append(cell)
			if lane.size() < 3:
				continue
			for cell: Vector2i in lane:
				_release_feature_owner(context, cell)
				context.world.set_material(cell, CellDataScript.TerrainMaterial.SOFT_SOIL)
				context.world.set_excavated(cell, false, false)
				context.world.set_water_units(cell, 0)
			break


func _release_feature_owner(context: WorldGenContext, cell: Vector2i) -> void:
	var owner_id: int = context.world.get_feature_id(cell)
	if owner_id < 0:
		return
	var owner: GeneratedFeature = context.feature_registry.get_feature(owner_id)
	if owner != null:
		owner.cells.erase(cell)
	context.world.set_feature_id(cell, -1)


func _ensure_required_reservoir_shoulders(context: WorldGenContext) -> void:
	var shoulder_cells: Dictionary = {}
	for reservoir: GeneratedFeature in context.feature_registry.get_features("water_reservoir"):
		if not reservoir.required:
			continue
		for reservoir_cell: Vector2i in reservoir.cells:
			for neighbor: Vector2i in context.world.get_cardinal_neighbors(reservoir_cell):
				if context.world.get_feature_id(neighbor) != reservoir.id:
					shoulder_cells[neighbor] = true
	var ordered_cells: Array = shoulder_cells.keys()
	ordered_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return context.world.cell_to_index(a) < context.world.cell_to_index(b)
	)
	for cell: Vector2i in ordered_cells:
		if context.world.is_exterior(cell) or context.world.is_protected(cell):
			continue
		var owner_id: int = context.world.get_feature_id(cell)
		if owner_id >= 0:
			var owner: GeneratedFeature = context.feature_registry.get_feature(owner_id)
			if owner != null and owner.required:
				continue
			if owner != null:
				owner.cells.erase(cell)
		context.world.set_feature_id(cell, -1)
		context.world.set_material(cell, CellDataScript.TerrainMaterial.STONE)
		context.world.set_excavated(cell, false, false)
		context.world.set_water_units(cell, 0)


func _stage_signal_fields(context: WorldGenContext) -> void:
	if bool(context.config.get("discoveries_enabled", true)):
		DiscoveryScript.populate(context)
	for feature: GeneratedFeature in context.feature_registry.get_features_by_role("feature"):
		var channel := ""
		match feature.type_id:
			"root_cluster":
				channel = "root_density"
			"water_reservoir":
				channel = "moisture"
			"unstable_pocket":
				channel = "instability"
		if channel.is_empty():
			continue
		context.signal_emitters.append({
			"feature_id": feature.id,
			"channel": channel,
			"anchor": feature.anchor,
			"strength": int(feature.metadata.get("signal_strength", 4)),
			"falloff": int(feature.metadata.get("signal_falloff", 1)),
		})
	var signal_system := SignalSystemScript.new()
	signal_system.configure(
		context.world,
		context.feature_registry,
		context.signal_emitters,
		context.config.get("signal_fields", {}),
		true,
		false
	)


func _add_landmark(context: WorldGenContext, type_id: String, anchor: Vector2i, approaches: Array[Vector2i], required: bool) -> void:
	var landmark := GeneratedFeatureScript.new(type_id, anchor, [anchor], required, "landmark")
	landmark.hidden = type_id != "start_burrow"
	landmark.metadata = {"approach_cells": approaches}
	context.feature_registry.add_feature(landmark)


## Authored root-cluster silhouettes (Phase 13 "authored root variations").
## All shapes stay ellipse-anchored around the anchor so validator assumptions
## (approach cells, signal falloff) hold; only the trailing growth differs.
const ROOT_SHAPES: Array[String] = ["runner", "forked", "taproot"]


func _add_root_cluster(context: WorldGenContext, anchor: Vector2i, required: bool, rng) -> void:
	var cells := _ellipse_cells(context, anchor, Vector2i(3, 2))
	var shape := "taproot"
	if required:
		# Required roots keep the authored inward tap so the early-food
		# witness path geometry stays predictable.
		for step: int in range(1, 5):
			var inward_cell := _clamp_underground(context, anchor + Vector2i(step, 0))
			if not cells.has(inward_cell):
				cells.append(inward_cell)
	else:
		shape = String(ROOT_SHAPES[rng.next_int(0, ROOT_SHAPES.size() - 1)])
		match shape:
			"runner":
				var runner_direction: int = 1 if rng.next_int(0, 1) == 0 else -1
				var runner_cursor := anchor
				for step: int in range(rng.next_int(4, 7)):
					runner_cursor += Vector2i(runner_direction, rng.next_int(-1, 1))
					runner_cursor = _clamp_underground(context, runner_cursor)
					if not cells.has(runner_cursor):
						cells.append(runner_cursor)
			"forked":
				for fork_direction: int in [-1, 1]:
					var fork_cursor := anchor
					for step: int in range(rng.next_int(2, 4)):
						fork_cursor += Vector2i(fork_direction, rng.next_int(-1, 1))
						fork_cursor = _clamp_underground(context, fork_cursor)
						if not cells.has(fork_cursor):
							cells.append(fork_cursor)
			"taproot":
				var tap_cursor := anchor
				for step: int in range(rng.next_int(3, 6)):
					tap_cursor += Vector2i(rng.next_int(-1, 1), 1)
					tap_cursor = _clamp_underground(context, tap_cursor)
					if not cells.has(tap_cursor):
						cells.append(tap_cursor)
	var feature := GeneratedFeatureScript.new("root_cluster", anchor, cells, required)
	var root_config: Dictionary = context.config.get("root_feature", {})
	var food_opportunity: bool = required or int(rng.next_int(0, 99)) < 60
	var food_reserve: int = int(root_config.get("required_food_reserve", 12) if required else root_config.get("optional_food_reserve", 8))
	feature.metadata = {
		"shape_id": shape,
		"food_opportunity": food_opportunity,
		"signal_strength": 5,
		"signal_falloff": 1,
		"approach_cells": _cardinal_approaches(context, anchor, Vector2i(4, 3)),
		"lifecycle_state": "SIGNAL",
		"reaction_fired": false,
		"reveal_count": 0,
		"food_reserve_units": food_reserve if food_opportunity else 0,
		"initial_food_yield": int(root_config.get("initial_food_yield", 4)),
		"forage_interval_seconds": float(root_config.get("forage_interval_seconds", 8.0)),
		"food_produced_total": 0,
		"food_depleted": not food_opportunity or food_reserve <= 0,
	}
	context.feature_registry.add_feature(feature)


func _add_reservoir(context: WorldGenContext, anchor: Vector2i, required: bool, rng) -> void:
	var radius := Vector2i(3, 2) if required else Vector2i(rng.next_int(3, 5), rng.next_int(2, 3))
	var cells := _ellipse_cells(context, anchor, radius)
	var feature := GeneratedFeatureScript.new("water_reservoir", anchor, cells, required)
	feature.metadata = {
		"reserve_units": maxi(32, cells.size() * rng.next_int(3, 6)),
		"signal_strength": 5,
		"signal_falloff": 1,
		"approach_cells": _cardinal_approaches(context, anchor, radius + Vector2i.ONE),
	}
	context.feature_registry.add_feature(feature)


func _add_rock_mass(context: WorldGenContext, anchor: Vector2i, radius: Vector2i, rng) -> void:
	var cells := _ellipse_cells(context, anchor, radius)
	if rng.next_int(0, 1) == 1 and cells.size() > 4:
		cells.remove_at(rng.next_int(0, cells.size() - 1))
	var feature := GeneratedFeatureScript.new("rock_mass", anchor, cells, false)
	feature.metadata = {"approach_cells": _cardinal_approaches(context, anchor, radius + Vector2i.ONE)}
	context.feature_registry.add_feature(feature)


func _add_natural_cavity(context: WorldGenContext, anchor: Vector2i, radius: Vector2i) -> void:
	var feature := GeneratedFeatureScript.new("natural_cavity", anchor, _ellipse_cells(context, anchor, radius), false)
	feature.metadata = {"approach_cells": _cardinal_approaches(context, anchor, radius + Vector2i.ONE)}
	context.feature_registry.add_feature(feature)


func _add_unstable_pocket(context: WorldGenContext, anchor: Vector2i, radius: Vector2i) -> void:
	var feature := GeneratedFeatureScript.new("unstable_pocket", anchor, _ellipse_cells(context, anchor, radius), false)
	feature.metadata = {
		"signal_strength": 4,
		"signal_falloff": 1,
		"approach_cells": _cardinal_approaches(context, anchor, radius + Vector2i.ONE),
	}
	context.feature_registry.add_feature(feature)


func _add_foundation(context: WorldGenContext, anchor: Vector2i, rng) -> void:
	var cells: Array[Vector2i] = []
	var half_width := mini(12, maxi(7, context.width / 8))
	var gap_x: int = anchor.x + int(rng.next_int(-3, 3))
	# Authored variation (Phase 14): the wall rides high or low in its band.
	var tall: bool = rng.next_int(0, 1) == 0
	var y_from := anchor.y - 2 if tall else anchor.y - 1
	var y_to := anchor.y + 2 if tall else anchor.y + 3
	for x: int in range(anchor.x - half_width, anchor.x + half_width + 1):
		if absi(x - gap_x) <= 2:
			continue
		for y: int in range(y_from, y_to):
			var cell := Vector2i(x, y)
			if context.world.is_in_bounds(cell) and not _is_above_surface(context, cell):
				cells.append(cell)
	var feature := GeneratedFeatureScript.new("foundation", anchor, cells, true)
	feature.metadata = {"approach_cells": [Vector2i(gap_x, anchor.y + 2)], "gap_x": gap_x}
	context.feature_registry.add_feature(feature)


## Phase 15 prefab mutation system: the old burrow is assembled from authored
## prefab pieces and one authored mutation, deterministically per seed. Every
## mutation keeps the required-landmark contract (anchor + approach cells).
const OLD_BURROW_MUTATIONS: Array[String] = ["two_room_sealed", "collapsed_wing", "triple_nest"]


func _add_old_burrow(context: WorldGenContext, anchor: Vector2i, rng) -> void:
	var cells := _ellipse_cells(context, anchor, Vector2i(5, 3))
	var mutation := String(OLD_BURROW_MUTATIONS[rng.next_int(0, OLD_BURROW_MUTATIONS.size() - 1)])
	var weak_cells: Array[Vector2i] = []
	match mutation:
		"two_room_sealed":
			var second := _clamp_underground(context, anchor + Vector2i(rng.next_int(7, 10) * (-1 if rng.next_int(0, 1) == 0 else 1), rng.next_int(-2, 2)))
			for cell: Vector2i in _ellipse_cells(context, second, Vector2i(4, 2)):
				if not cells.has(cell):
					cells.append(cell)
			var cursor := anchor
			while cursor.x != second.x:
				cursor.x += signi(second.x - cursor.x)
				if not cells.has(cursor):
					cells.append(cursor)
		"collapsed_wing":
			# A second wing partially choked with loose fill: the shortcut
			# exists but must be re-dug through weak terrain.
			var wing := _clamp_underground(context, anchor + Vector2i(rng.next_int(6, 9) * (-1 if rng.next_int(0, 1) == 0 else 1), rng.next_int(-1, 2)))
			var wing_cells := _ellipse_cells(context, wing, Vector2i(4, 2))
			var cursor := anchor
			while cursor.x != wing.x:
				cursor.x += signi(wing.x - cursor.x)
				wing_cells.append(cursor)
			for index: int in range(wing_cells.size()):
				var cell: Vector2i = wing_cells[index]
				if not cells.has(cell):
					cells.append(cell)
				if index % 2 == 0:
					weak_cells.append(cell)
		"triple_nest":
			# Three chamber hints around the main hall — the old family nest.
			for direction: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 1)]:
				var nest := _clamp_underground(context, anchor + Vector2i(direction.x * rng.next_int(6, 8), direction.y * rng.next_int(3, 4)))
				for cell: Vector2i in _ellipse_cells(context, nest, Vector2i(3, 2)):
					if not cells.has(cell):
						cells.append(cell)
	var feature := GeneratedFeatureScript.new("old_burrow", anchor, cells, true)
	feature.metadata = {
		"approach_cells": _cardinal_approaches(context, anchor, Vector2i(6, 4)),
		"mutation": mutation,
		"weak_cells": weak_cells,
	}
	context.feature_registry.add_feature(feature)


func _add_warm_chamber(context: WorldGenContext, anchor: Vector2i) -> void:
	var feature := GeneratedFeatureScript.new("warm_chamber", anchor, _ellipse_cells(context, anchor, Vector2i(6, 3)), true)
	feature.metadata = {"approach_cells": _cardinal_approaches(context, anchor, Vector2i(7, 4)), "stable_warm_region": true}
	context.feature_registry.add_feature(feature)


func _carve_start_burrow(context: WorldGenContext) -> void:
	var start: Vector2i = context.world.metadata.start_cell
	for y: int in range(start.y - 2, start.y + 3):
		for x: int in range(start.x - 5, start.x + 6):
			var cell := Vector2i(x, y)
			var relative := Vector2(float(x - start.x) / 5.5, float(y - start.y) / 2.8)
			if context.world.is_in_bounds(cell) and relative.length_squared() <= 1.0:
				context.world.initialize_cell(cell, CellDataScript.TerrainMaterial.SOFT_SOIL, true, false, false)
				context.world.set_stratum_id(cell, 0)
				context.world.set_feature_id(cell, -1)
	for y: int in range(context.surface_heights[start.x], start.y):
		var shaft := Vector2i(start.x, y)
		context.world.initialize_cell(shaft, CellDataScript.TerrainMaterial.SOFT_SOIL, true, false, false)
		context.world.set_stratum_id(shaft, 0)
		context.world.set_feature_id(shaft, -1)


func _base_material(stratum_id: int, rng) -> int:
	var roll: int = int(rng.next_int(0, 99))
	match stratum_id:
		0:
			return CellDataScript.TerrainMaterial.LOOSE_SOIL if roll < 14 else CellDataScript.TerrainMaterial.SOFT_SOIL
		1:
			return CellDataScript.TerrainMaterial.DAMP_CLAY if roll < 34 else CellDataScript.TerrainMaterial.SOFT_SOIL
		2:
			return CellDataScript.TerrainMaterial.STONE if roll < 30 else CellDataScript.TerrainMaterial.DAMP_CLAY
		_:
			return CellDataScript.TerrainMaterial.STONE if roll < 42 else CellDataScript.TerrainMaterial.DAMP_CLAY


func _stratum_at(context: WorldGenContext, cell: Vector2i) -> int:
	if cell.y <= int((context.stratum_boundaries.topsoil_end as PackedInt32Array)[cell.x]):
		return 0
	if cell.y <= int((context.stratum_boundaries.transition_end as PackedInt32Array)[cell.x]):
		return 1
	if cell.y <= int((context.stratum_boundaries.wet_end as PackedInt32Array)[cell.x]):
		return 2
	return 3


func _ellipse_cells(context: WorldGenContext, anchor: Vector2i, radius: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(anchor.y - radius.y, anchor.y + radius.y + 1):
		for x: int in range(anchor.x - radius.x, anchor.x + radius.x + 1):
			var cell := Vector2i(x, y)
			if not context.world.is_in_bounds(cell) or _is_above_surface(context, cell):
				continue
			var normalized := Vector2(float(x - anchor.x) / maxf(1.0, radius.x), float(y - anchor.y) / maxf(1.0, radius.y))
			if normalized.length_squared() <= 1.0:
				cells.append(cell)
	return cells


func _cardinal_approaches(context: WorldGenContext, anchor: Vector2i, radius: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in [
		anchor + Vector2i(-radius.x, 0),
		anchor + Vector2i(radius.x, 0),
		anchor + Vector2i(0, -radius.y),
		anchor + Vector2i(0, radius.y),
	]:
		if context.world.is_in_bounds(cell) and not _is_above_surface(context, cell):
			result.append(cell)
	return result


func _random_anchor(context: WorldGenContext, rng, minimum_depth_ratio: float, maximum_depth_ratio: float) -> Vector2i:
	var x: int = int(rng.next_int(8, context.width - 9))
	var surface_y: int = context.surface_heights[x]
	var y: int = surface_y + int((context.height - surface_y) * rng.next_float() * (maximum_depth_ratio - minimum_depth_ratio) + (context.height - surface_y) * minimum_depth_ratio)
	return _clamp_underground(context, Vector2i(x, y))


func _clamp_underground(context: WorldGenContext, cell: Vector2i) -> Vector2i:
	var x := clampi(cell.x, 7, context.width - 8)
	var y := clampi(cell.y, context.surface_heights[x] + 3, context.height - 5)
	return Vector2i(x, y)


func _is_above_surface(context: WorldGenContext, cell: Vector2i) -> bool:
	return not context.world.is_in_bounds(cell) or cell.y < context.surface_heights[cell.x]


func _validated_world_size(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2 and int(value[0]) >= 32 and int(value[1]) >= 24:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(96, 72)


func _finalize_world_metadata(context: WorldGenContext) -> void:
	var validation: Dictionary = context.validation_report
	context.world.metadata.generation_valid = bool(validation.get("valid", false))
	context.world.metadata.validation_metrics = (validation.get("metrics", {}) as Dictionary).duplicate(true)
	context.world.metadata.validation_failure_codes = validation.get("failure_codes", PackedStringArray()).duplicate()
	context.world.metadata.repairs = context.repairs.duplicate(true)
	var validated_knots: Array = context.validation_report.get("metrics", {}).get("validated_decision_knots", [])
	context.world.metadata.decision_knots = validated_knots.duplicate() if not validated_knots.is_empty() else context.decision_knots.duplicate()
	context.world.metadata.signal_emitters = context.signal_emitters.duplicate(true)
	context.world.metadata.feature_summaries = context.feature_registry.stable_summaries()
	context.world.metadata.stage_order = context.stage_trace.duplicate()
	context.world.metadata.stage_timings_ms = context.stage_timings_ms.duplicate(true)
	context.world.metadata.config_hash = _config_checksum(context.config)
	context.world.metadata.content_hash = _content_hash(context)


func _build_report(context: WorldGenContext) -> Dictionary:
	return {
		"valid": bool(context.validation_report.get("valid", false)),
		"seed": context.seed_value,
		"worldgen_version": int(context.config.get("worldgen_version", 3)),
		"attempt": context.attempt,
		"stage_order": context.stage_trace.duplicate(),
		"stage_timings_ms": context.stage_timings_ms.duplicate(true),
		"total_generation_ms": context.total_generation_ms(),
		"validation": context.validation_report.duplicate(true),
		"repairs": context.repairs.duplicate(true),
		"feature_count": context.feature_registry.count(),
		"config_hash": int(context.world.metadata.config_hash),
		"content_hash": int(context.world.metadata.content_hash),
	}


func _content_hash(context: WorldGenContext) -> int:
	var value: int = int(context.world.content_checksum())
	value = int((value * 65599 + context.feature_registry.checksum()) % 2147483647)
	var emitters := context.signal_emitters.duplicate(true)
	emitters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := int(a.get("feature_id", -1))
		var b_id := int(b.get("feature_id", -1))
		if a_id != b_id:
			return a_id < b_id
		return String(a.get("channel", "")) < String(b.get("channel", ""))
	)
	value = _hash_variant(value, emitters)
	value = int((value * 65599 + _config_checksum(context.config)) % 2147483647)
	var validated_knots: Array = context.validation_report.get("metrics", {}).get("validated_decision_knots", [])
	var hash_knots: Array = validated_knots if not validated_knots.is_empty() else context.decision_knots
	for knot: Vector2i in hash_knots:
		value = int((value * 65599 + knot.x * 257 + knot.y) % 2147483647)
	return value


func _config_checksum(config: Dictionary) -> int:
	var content_config := config.duplicate(true)
	for excluded_key: String in ["default_seed", "instrument_stage_stdout", "batch_gate", "status"]:
		content_config.erase(excluded_key)
	return _hash_variant(41, content_config)


func _hash_variant(value: int, variant: Variant) -> int:
	var mixed := value
	if variant == null:
		return _hash_mix(mixed, 0)
	if variant is bool:
		return _hash_mix(mixed, 1 if variant else 2)
	if variant is int:
		return _hash_mix(mixed, int(variant))
	if variant is float:
		return _hash_mix(mixed, roundi(float(variant) * 100000.0))
	if variant is String or variant is StringName:
		for byte: int in String(variant).to_utf8_buffer():
			mixed = _hash_mix(mixed, byte)
		return mixed
	if variant is Vector2i:
		mixed = _hash_mix(mixed, variant.x)
		return _hash_mix(mixed, variant.y)
	if variant is Array:
		mixed = _hash_mix(mixed, variant.size())
		for item: Variant in variant:
			mixed = _hash_variant(mixed, item)
		return mixed
	if variant is Dictionary:
		var keys: Array = variant.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for key: Variant in keys:
			mixed = _hash_variant(mixed, String(key))
			mixed = _hash_variant(mixed, variant[key])
		return mixed
	return _hash_variant(mixed, str(variant))


func _hash_mix(value: int, addition: int) -> int:
	return int((value * 65599 + addition + 2147483647) % 2147483647)
