extends RefCounted

const ALLOWED_STATUSES: PackedStringArray = ["PASS", "SKIPPED_NOT_IMPLEMENTED", "FAIL"]

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	var document := AppConfigService.load_json_document("res://tests/smoke_manifest.json")
	_assert_true(document.ok, "Smoke manifest parses")
	if not document.ok:
		return results
	_assert_equal(document.data.get("current_phase"), 1, "Smoke manifest phase is current")
	var checks: Array = document.data.get("checks", [])
	_assert_true(not checks.is_empty(), "Smoke manifest contains checks")
	var seen_ids: Dictionary = {}
	for check: Dictionary in checks:
		var check_id := String(check.get("id", ""))
		var status := String(check.get("status", ""))
		_assert_true(not check_id.is_empty(), "Smoke check has an ID")
		_assert_true(not seen_ids.has(check_id), "Smoke check ID is unique: %s" % check_id)
		_assert_true(ALLOWED_STATUSES.has(status), "Smoke check status is valid: %s" % check_id)
		_assert_true(status != "FAIL", "Smoke check is not failing: %s" % check_id)
		if status == "SKIPPED_NOT_IMPLEMENTED":
			_assert_true(int(check.get("target_phase", 0)) > 0, "Skipped smoke check has target phase: %s" % check_id)
		seen_ids[check_id] = true
	return results


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({
		"passed": passed,
		"description": description,
		"details": "" if passed else "Expected %s, got %s" % [expected, actual],
	})
