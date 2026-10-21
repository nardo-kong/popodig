extends SceneTree

const TEST_SCRIPTS: PackedStringArray = [
	"res://tests/unit/test_discovery_worldgen.gd",
	"res://tests/unit/test_collection_book.gd",
	"res://tests/integration/test_production_flow.gd",
	"res://tests/unit/test_frontier_cues.gd",
	"res://tests/integration/test_discovery_flow.gd",
	"res://tests/unit/test_foundation.gd",
	"res://tests/unit/test_smoke_manifest.gd",
	"res://tests/unit/test_world_grid.gd",
	"res://tests/unit/test_structured_worldgen.gd",
	"res://tests/unit/test_signal_system.gd",
	"res://tests/unit/test_water_system.gd",
	"res://tests/unit/test_stability_system.gd",
	"res://tests/unit/test_terrain_atlas.gd",
	"res://tests/unit/test_terrain_edge_rules.gd",
	"res://tests/unit/test_vfx_pool.gd",
	"res://tests/unit/test_audio_bank.gd",
	"res://tests/unit/test_settings_store.gd",
	"res://tests/unit/test_fog_of_war.gd",
	"res://tests/unit/test_session_telemetry.gd",
	"res://tests/unit/test_chapter_model.gd",
	"res://tests/unit/test_notification_model.gd",
	"res://tests/unit/test_context_tutorial.gd",
	"res://tests/unit/test_localization.gd",
	"res://tests/unit/test_save_service.gd",
	"res://tests/unit/test_save_roundtrip.gd",
	"res://tests/integration/test_exterior_semantics.gd",
	"res://tests/unit/test_dig_system.gd",
	"res://tests/integration/test_mouse_dig_flow.gd",
	"res://tests/unit/test_colony_jobs.gd",
	"res://tests/integration/test_colony_simulation.gd",
	"res://tests/unit/test_zone_system.gd",
	"res://tests/integration/test_zone_colony_flow.gd",
	"res://tests/integration/test_root_feature_flow.gd",
	"res://tests/integration/test_seal_colony_flow.gd",
	"res://tests/integration/test_stability_colony_flow.gd",
	"res://tests/integration/test_water_colony_flow.gd",
	"res://tests/integration/test_save_soak.gd",
]

const COMPILE_GATES: PackedStringArray = [
	"res://src/domain/worldgen/structured_world_generator.gd",
	"res://src/domain/worldgen/world_validator.gd",
	"res://src/domain/worldgen/world_repairer.gd",
	"res://src/domain/features/signal_system.gd",
	"res://src/domain/features/root_feature_system.gd",
	"res://src/domain/features/water_system.gd",
	"res://src/domain/features/seal_system.gd",
	"res://src/domain/features/stability_system.gd",
	"res://src/presentation/world/world_chunk_view.gd",
	"res://src/presentation/world/water_fx_view.gd",
	"res://src/presentation/world/terrain_edge_rules.gd",
	"res://src/presentation/fx/vfx_view.gd",
	"res://src/presentation/audio/audio_director.gd",
	"res://src/infrastructure/config/settings_store.gd",
	"res://src/presentation/world/fog_of_war_view.gd",
	"res://src/presentation/hud/settings_view.gd",
	"res://src/presentation/debug/worldgen_debug_overlay.gd",
	"res://src/domain/zones/zone_system.gd",
	"res://src/domain/jobs/job_system.gd",
	"res://src/domain/colony/mouse_agent.gd",
	"res://src/domain/colony/colony_simulation.gd",
	"res://src/domain/progression/chapter_model.gd",
	"res://src/presentation/app/game_app.gd",
]


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed := 0
	var failed := 0
	for script_path: String in COMPILE_GATES:
		var compile_script := load(script_path) as Script
		if compile_script == null or not compile_script.can_instantiate():
			failed += 1
			print("FAIL | Compile gate: %s | Script could not be loaded or instantiated" % script_path)
		else:
			passed += 1
			print("PASS | Compile gate: %s" % script_path)
	var requested: PackedStringArray = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			requested = argument.trim_prefix("--suite=").split(",", false)
	var selected: Dictionary = {}
	for script_path: String in TEST_SCRIPTS:
		var suite_name := script_path.get_file().trim_suffix(".gd").trim_prefix("test_")
		if not requested.is_empty() and not requested.has(suite_name):
			continue
		selected[suite_name] = true
		var test_script := load(script_path) as Script
		if test_script == null or not test_script.can_instantiate():
			failed += 1
			print("FAIL | %s | Script could not be loaded or instantiated" % script_path)
			continue
		var test_case: Variant = test_script.new()
		var results: Array = test_case.run()
		if results.is_empty():
			failed += 1
			print("FAIL | Suite returned no assertions: %s" % script_path)
		for result: Dictionary in results:
			if result.passed:
				passed += 1
				print("PASS | %s" % result.description)
			else:
				failed += 1
				print("FAIL | %s | %s" % [result.description, result.details])
	for suite_name: String in requested:
		if not selected.has(suite_name):
			failed += 1
			print("FAIL | Unknown requested suite: %s" % suite_name)
	print("TEST_SUMMARY passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	quit(0 if failed == 0 else 1)
