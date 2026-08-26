extends RefCounted

const NotificationModelScript = preload("res://src/presentation/hud/notification_model.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_push_and_dedupe()
	_test_cooldown_expiry_allows_republish()
	_test_entries_expire()
	_test_active_cap_drops_oldest()
	_test_latest_focus_cell_skips_invalid()
	_test_clear_resets()
	return results


func _test_push_and_dedupe() -> void:
	var model = NotificationModelScript.new()
	_assert(model.push("breach", "第一条", 10.0, Vector2i(3, 4)), "First push in a category is accepted")
	_assert(not model.push("breach", "冷却中被拒绝", 12.0), "Republish inside the cooldown is rejected")
	_assert(model.active(12.0).size() == 1, "Rejected push does not add an entry")


func _test_cooldown_expiry_allows_republish() -> void:
	var model = NotificationModelScript.new()
	model.push("food_low", "第一次", 0.0, Vector2i(-1, -1), 20.0, 10.0)
	_assert(not model.push("food_low", "太早", 9.9, Vector2i(-1, -1), 20.0, 10.0), "Republish at 9.9s stays inside a 10s cooldown")
	_assert(model.push("food_low", "冷却结束", 10.0, Vector2i(-1, -1), 20.0, 10.0), "Republish after the cooldown is accepted")
	var active := model.active(10.0)
	_assert(active.size() == 2, "Both lifetime-valid entries stay active")


func _test_entries_expire() -> void:
	var model = NotificationModelScript.new()
	model.push("breach", "短命条目", 0.0, Vector2i(1, 1), 6.0, 1.0)
	_assert(model.active(5.9).size() == 1, "Entry is active before expiry")
	_assert(model.active(6.1).is_empty(), "Entry is pruned after its lifetime")
	_assert(model.push("breach", "过期后可重新推送", 6.2, Vector2i(-1, -1), 6.0, 1.0), "Expired entry no longer blocks its category")


func _test_active_cap_drops_oldest() -> void:
	var model = NotificationModelScript.new()
	for index: int in range(5):
		model.push("cat_%d" % index, "条目 %d" % index, float(index), Vector2i(index, 0), 60.0, 0.0)
	var active := model.active(5.0)
	_assert(active.size() == 3, "Active list is capped at three entries")
	_assert(String(active[0].text) == "条目 4", "Newest entry is kept at the front")
	_assert(String(active[2].text) == "条目 2", "Oldest entries are dropped first")


func _test_latest_focus_cell_skips_invalid() -> void:
	var model = NotificationModelScript.new()
	model.push("a", "无焦点", 0.0, Vector2i(-1, -1), 60.0, 0.0)
	_assert(model.latest_focus_cell(1.0) == Vector2i(-1, -1), "Invalid focus cells are skipped")
	model.push("b", "有焦点", 1.0, Vector2i(7, 9), 60.0, 0.0)
	_assert(model.latest_focus_cell(2.0) == Vector2i(7, 9), "Latest valid focus cell is returned")
	model.push("c", "无焦点更新", 2.0, Vector2i(-1, -1), 60.0, 0.0)
	_assert(model.latest_focus_cell(3.0) == Vector2i(7, 9), "Older valid focus survives a newer focusless entry")


func _test_clear_resets() -> void:
	var model = NotificationModelScript.new()
	model.push("breach", "条目", 0.0, Vector2i(1, 1), 60.0, 60.0)
	model.clear()
	_assert(model.active(1.0).is_empty(), "Clear removes all entries")
	_assert(model.push("breach", "清除后立即可推送", 2.0), "Clear resets category cooldowns")


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
