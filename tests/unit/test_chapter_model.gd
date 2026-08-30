extends RefCounted

# Phase 13 unit tests: chapter milestone progression (GDD §13, world/04 §6,
# colony/10 §14) — per-requirement gating, monotonic advancement, milestone
# population growth values, and additive save compatibility.

const ChapterModelScript = preload("res://src/domain/progression/chapter_model.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	results = []
	_test_chapter_1_requires_every_goal()
	_test_chapter_1_completes_and_grants_growth()
	_test_advancement_is_monotonic()
	_test_chapter_2_gate()
	_test_chapter_3_campaign_completion()
	_test_save_data_round_trip_and_old_saves()
	return results


func _make_model() -> ChapterModel:
	var model: ChapterModel = ChapterModelScript.new()
	model.configure({})
	return model


func _complete_ch1_context() -> Dictionary:
	return {
		"colony_depth": 40,
		"chapter_depths": {"chapter_2": 34, "chapter_3": 51},
		"sleeping_ready": true,
		"storage_ready": true,
		"food_total": 12,
		"signals_learned": true,
		"water_settled": true,
		"supports_built": true,
	}


func _test_chapter_1_requires_every_goal() -> void:
	var model := _make_model()
	var context := _complete_ch1_context()
	var broken: Dictionary
	for missing_key: String in ["sleeping_ready", "storage_ready", "signals_learned"]:
		broken = context.duplicate(true)
		broken[missing_key] = false
		model.evaluate(broken)
		_assert(model.current_chapter == ChapterModelScript.CHAPTER_1_SETTLE, "Chapter 1 holds without %s" % missing_key)
	broken = context.duplicate(true)
	broken["food_total"] = 4
	model.evaluate(broken)
	_assert(model.current_chapter == ChapterModelScript.CHAPTER_1_SETTLE, "Chapter 1 holds below the food target")
	broken = context.duplicate(true)
	broken["colony_depth"] = 30
	model.evaluate(broken)
	_assert(model.current_chapter == ChapterModelScript.CHAPTER_1_SETTLE, "Chapter 1 holds above the transition band")


func _test_chapter_1_completes_and_grants_growth() -> void:
	var model := _make_model()
	var growth_events: Array = []
	model.chapter_advanced.connect(func(new_chapter: int, growth: int) -> void:
		growth_events.append({"chapter": new_chapter, "growth": growth})
	)
	var advanced := model.evaluate(_complete_ch1_context())
	_assert(advanced == 1, "A complete Chapter 1 advances exactly one chapter")
	_assert(model.current_chapter == ChapterModelScript.CHAPTER_2_ADAPT, "Chapter becomes 2 · Adapt")
	_assert(growth_events.size() == 1 and int(growth_events[0].growth) == 2, "Chapter 2 milestone grants 2 new mice (spec 10 §14)")


func _test_advancement_is_monotonic() -> void:
	var model := _make_model()
	model.evaluate(_complete_ch1_context())
	# A regression snapshot (missed goals) must never move the chapter back.
	model.evaluate({"colony_depth": 0, "chapter_depths": {}, "sleeping_ready": false})
	_assert(model.current_chapter == ChapterModelScript.CHAPTER_2_ADAPT, "Chapter progression never regresses")


func _test_chapter_2_gate() -> void:
	var model := _make_model()
	model.evaluate(_complete_ch1_context())
	var context := _complete_ch1_context()
	context["colony_depth"] = 55
	model.evaluate(context)
	_assert(model.current_chapter == ChapterModelScript.CHAPTER_3_OLD_BURROW, "Depth + settled water + supports advance to Chapter 3")
	var partial := _make_model()
	partial.evaluate(_complete_ch1_context())
	var no_supports := context.duplicate(true)
	no_supports["supports_built"] = false
	partial.evaluate(no_supports)
	_assert(partial.current_chapter == ChapterModelScript.CHAPTER_2_ADAPT, "Chapter 2 holds without completed reinforcements")


## GDD §14: the campaign completes when the final home is stable in the deep
## warm area — a set-up sleeping zone inside the revealed warm chamber.
func _test_chapter_3_campaign_completion() -> void:
	var model := _make_model()
	var context := _complete_ch1_context()
	context["colony_depth"] = 55
	model.evaluate(context)
	_assert(model.current_chapter == ChapterModelScript.CHAPTER_3_OLD_BURROW, "Fixture reaches Chapter 3")
	var no_home := context.duplicate(true)
	no_home["warm_home_ready"] = false
	model.evaluate(no_home)
	_assert(not model.campaign_complete, "Campaign holds without the warm-chamber home")
	context["warm_home_ready"] = true
	model.evaluate(context)
	_assert(model.campaign_complete, "A warm-chamber sleeping zone completes the campaign")
	_assert(model.evaluate(context) == 0, "Campaign completion fires exactly once")


func _test_save_data_round_trip_and_old_saves() -> void:
	var model := _make_model()
	model.evaluate(_complete_ch1_context())
	var saved: Dictionary = model.to_save_data()
	var restored := _make_model()
	restored.apply_save_data(saved)
	_assert(restored.current_chapter == ChapterModelScript.CHAPTER_2_ADAPT, "Chapter survives the save round trip")
	# A pre-Phase-13 v2 save has no chapter_model section at all.
	var legacy := _make_model()
	legacy.apply_save_data({})
	_assert(legacy.current_chapter == ChapterModelScript.CHAPTER_1_SETTLE, "Old saves restore to Chapter 1")


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
