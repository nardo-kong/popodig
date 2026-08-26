extends RefCounted

const TutorialModelScript = preload("res://src/presentation/hud/context_tutorial_model.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_starts_on_intro_step()
	_test_stays_without_flags()
	_test_advances_with_flag()
	_test_never_moves_backward()
	_test_jumps_multiple_steps()
	_test_reaches_done_step()
	return results


func _test_starts_on_intro_step() -> void:
	var model = TutorialModelScript.new()
	_assert(model.current_id() == "dig", "Tutorial starts on the dig intro step")
	_assert(model.current_text_key() == "tutorial.dig", "Intro step carries its translation key")
	_assert(not Localization.text(model.current_text_key()).is_empty(), "Intro step resolves a localized sentence")


func _test_stays_without_flags() -> void:
	var model = TutorialModelScript.new()
	_assert(not model.advance({}), "No flags means no advancement")
	_assert(model.current_id() == "dig", "Step stays on intro without flags")


func _test_advances_with_flag() -> void:
	var model = TutorialModelScript.new()
	_assert(model.advance({"designated": true}), "Designated flag advances to the digging step")
	_assert(model.current_id() == "digging", "Current step follows the flag order")


func _test_never_moves_backward() -> void:
	var model = TutorialModelScript.new()
	model.advance({"designated": true, "open_space": true})
	var before := model.current_id()
	_assert(not model.advance({}), "Missing flags do not move the tutorial")
	_assert(model.current_id() == before, "Tutorial index is monotonic")


func _test_jumps_multiple_steps() -> void:
	var model = TutorialModelScript.new()
	model.advance({
		"designated": true,
		"open_space": true,
		"sleeping_zone": true,
		"root_clue": true,
	})
	_assert(model.current_id() == "root_clue", "Multiple flags jump several steps at once")
	model.advance({
		"root_revealed": true,
		"moisture_clue": true,
		"breach": true,
		"stability_warning": true,
	})
	_assert(model.current_id() == "stability", "Later flags continue the jump to the stability step")


func _test_reaches_done_step() -> void:
	var model = TutorialModelScript.new()
	model.advance({
		"designated": true,
		"open_space": true,
		"sleeping_zone": true,
		"root_clue": true,
		"root_revealed": true,
		"moisture_clue": true,
		"breach": true,
		"stability_warning": true,
		"objective_reached": true,
	})
	_assert(model.is_finished(), "All flags reach the final done step")
	_assert(model.current_id() == "done", "Final step id is done")


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
