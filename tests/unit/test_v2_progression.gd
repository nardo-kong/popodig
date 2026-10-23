extends "res://tests/test_case.gd"

const Chapters = preload("res://src/domain/progression/chapter_model.gd")
const Tutorial = preload("res://src/presentation/hud/context_tutorial_model.gd")
const Home = preload("res://src/domain/progression/home_progress.gd")


func run() -> Array[Dictionary]:
	var chapters := Chapters.new()
	chapters.configure({"v2_progression": true})
	var context := {"sleeping_ready": true, "storage_ready": true, "food_total": 12, "colony_depth": 35, "chapter_depths": {"chapter_2": 34, "chapter_3": 52}, "discoveries_found": 1, "production_batches": 0, "capability_level": 0, "water_settled": true, "supports_built": true, "water_learned": false}
	assert_equal(chapters.evaluate(context), 0, "v2 cannot advance just by depth and old room flags")
	context.production_batches = 1
	context.capability_level = 1
	assert_equal(chapters.evaluate(context), 1, "First chapter rewards discovery, crafting and tools without demanding early water exposure")
	context.colony_depth = 60
	context.water_learned = true
	assert_equal(chapters.evaluate(context), 0, "Second chapter awaits deep capability")
	context.capability_level = 2
	assert_equal(chapters.evaluate(context), 1, "Deep capability and risk preparation open the old-burrow chapter")
	assert_true(not chapters.campaign_complete, "Chapter three is not itself a completed home")
	context.warm_home_ready = true
	chapters.evaluate(context)
	assert_true(chapters.campaign_complete, "Stable warm home completes v2 campaign")
	assert_equal(chapters.evaluate(context), 0, "Campaign rewards cannot fire repeatedly")
	var restored := Chapters.new()
	restored.configure({})
	restored.apply_save_data(JSON.parse_string(JSON.stringify(chapters.to_save_data())))
	assert_equal(restored.rules_version, 2, "Chapter save retains rule version rather than silently changing goals")
	var tutorial := Tutorial.new()
	tutorial.configure_v2(true)
	assert_equal(tutorial.current_id(), "promise", "New tutorial starts with a visible promise")
	tutorial.advance({"first_find": true})
	assert_equal(tutorial.current_id(), "found", "A real discovery leads naturally to home construction")
	tutorial.restore_id("upgrade")
	assert_equal(tutorial.current_text_key(), "tutorial.v2.upgrade", "Stable tutorial ID restores after step order changes")
	tutorial.restore_id("unknown_future_step")
	assert_equal(tutorial.current_id(), "promise", "Unknown tutorial IDs restart safely")
	var home := Home.new()
	var home_context := {"sleeping_ready": true, "storage_ready": true, "food_total": 12, "production_batches": 1, "capability_level": 1, "collection_count": 1, "mouse_count": 3}
	assert_equal(home.evaluate(home_context, 50.0).size(), 5, "Home milestones record discovery, shelter, crafting, tools and family")
	assert_equal(home.evaluate(home_context, 100.0).size(), 0, "Home milestones do not repeat")
	var loaded_home := Home.new()
	assert_true(loaded_home.apply_save_data(JSON.parse_string(JSON.stringify(home.to_save_data()))).ok, "Home memories persist")
	home_context.campaign_complete = true
	assert_equal(loaded_home.evaluate(home_context, 200.0), ["deep_home"], "Only the new final-home memory is awarded after reload")
	return results
