extends SceneTree

# Phase 10 save fixture exporter (docs/tech/15_DATA_SAVE_SPEC.md §15).
# Regenerates the committed save fixtures under tests/fixtures/saves/ by
# driving the runtime app into each documented milestone and exporting the
# full save document. One milestone per process; the caller must pass the
# milestone's QA demo arguments on the command line, e.g.:
#   godot --headless --script res://tools/qa/export_phase10_fixtures.gd \
#       -- --profile=development --fixture=water_breach --qa-phase7-demo=breach
# Fixtures: new_game, zones_mice (--qa-phase4-demo), root_reveal
# (--qa-phase6-demo=reveal), water_breach (--qa-phase7-demo=breach),
# post_collapse (--qa-phase8-demo=collapse).
# The v1 migration fixture is derived from new_game in the same run.

const SaveServiceScript = preload("res://src/infrastructure/persistence/save_service.gd")

const FIXTURES: Dictionary = {
	"new_game": [],
	"zones_mice": ["--qa-phase4-demo"],
	"root_reveal": ["--qa-phase6-demo=reveal"],
	"water_breach": ["--qa-phase7-demo=breach"],
	"post_collapse": ["--qa-phase8-demo=collapse"],
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture_name := ""
	var user_args := OS.get_cmdline_user_args()
	for argument: String in user_args:
		if argument.begins_with("--fixture="):
			fixture_name = argument.trim_prefix("--fixture=")
	if not FIXTURES.has(fixture_name):
		printerr("EXPORT_FIXTURES_FAIL unknown fixture: %s" % fixture_name)
		quit(1)
		return
	for required: String in FIXTURES[fixture_name]:
		if not user_args.has(required):
			printerr("EXPORT_FIXTURES_FAIL fixture %s requires %s on the command line" % [fixture_name, required])
			quit(1)
			return
	var packed := load("res://scenes/app/game_app.tscn") as PackedScene
	if packed == null:
		printerr("EXPORT_FIXTURES_FAIL main scene could not be loaded")
		quit(1)
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	scene._paused = true
	await process_frame
	await process_frame
	if scene.world_grid == null or scene.colony_simulation == null:
		printerr("EXPORT_FIXTURES_FAIL app did not initialize")
		quit(1)
		return
	for _tick: int in range(6):
		scene.colony_simulation.fixed_tick(0.2)
	var document: Dictionary = scene._build_save_document()
	if fixture_name == "new_game":
		var v1_document: Dictionary = document.duplicate(true)
		v1_document.erase("progression")
		v1_document.header.save_schema_version = 1
		v1_document.header.last_saved_at = "2025-01-01T00:00:00"
		_write_fixture("v1_schema", v1_document)
	_write_fixture(fixture_name, document)
	print("EXPORT_FIXTURES_PASS fixture=%s bytes=%d features=%d mice=%d" % [
		fixture_name,
		FileAccess.open("res://tests/fixtures/saves/%s.json" % fixture_name, FileAccess.READ).get_length(),
		scene.worldgen_result.feature_registry.count(),
		scene.colony_simulation.get_mice().size(),
	])
	scene.queue_free()
	quit(0)


func _write_fixture(fixture_name: String, document: Dictionary) -> void:
	var path := "res://tests/fixtures/saves/%s.json" % fixture_name
	var result: Dictionary = SaveServiceScript.save_game(path, document)
	if not bool(result.ok):
		printerr("EXPORT_FIXTURES_FAIL write failed for %s: %s" % [fixture_name, String(result.error)])
		quit(1)
		return
	var verify: Dictionary = SaveServiceScript.load_game(path)
	if not bool(verify.ok):
		printerr("EXPORT_FIXTURES_FAIL fixture %s does not reload: %s" % [fixture_name, String(verify.error)])
		quit(1)
		return
