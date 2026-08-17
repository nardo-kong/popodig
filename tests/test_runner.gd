extends SceneTree

const TEST_SCRIPTS: PackedStringArray = [
	"res://tests/unit/test_foundation.gd",
	"res://tests/unit/test_smoke_manifest.gd",
	"res://tests/unit/test_world_grid.gd",
	"res://tests/unit/test_dig_system.gd",
	"res://tests/integration/test_mouse_dig_flow.gd",
]


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed := 0
	var failed := 0
	for script_path: String in TEST_SCRIPTS:
		var test_script := load(script_path) as Script
		if test_script == null or not test_script.can_instantiate():
			failed += 1
			print("FAIL | %s | Script could not be loaded or instantiated" % script_path)
			continue
		var test_case: Variant = test_script.new()
		var results: Array = test_case.run()
		for result: Dictionary in results:
			if result.passed:
				passed += 1
				print("PASS | %s" % result.description)
			else:
				failed += 1
				print("FAIL | %s | %s" % [result.description, result.details])
	print("TEST_SUMMARY passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	quit(0 if failed == 0 else 1)
