extends "res://tests/test_case.gd"

const Book = preload("res://src/domain/progression/collection_book.gd")


func run() -> Array[Dictionary]:
	var book := Book.new()
	assert_equal(book.entries().size(), 18, "Collection book has eighteen authored entries")
	assert_equal(book.unique_count(), 0, "Fresh book does not unlock unknown entries")
	book.on_discovery({"definition_id": "amber_drop"})
	book.on_discovery({"definition_id": "amber_drop"})
	book.on_discovery({"definition_id": "fiber_cache"})
	assert_equal(book.unique_count(), 1, "Duplicate finds do not inflate unique completion")
	assert_equal(book.entries()[0].count, 2, "Repeated finds retain their actual count")
	assert_true(book.entries()[0].zh == "琥珀淚滴", "Collected entry has a real authored Chinese name")
	var restored := Book.new()
	assert_true(restored.apply_save_data(JSON.parse_string(JSON.stringify(book.to_save_data()))).ok, "Collection book survives JSON save and load")
	assert_equal(restored.to_save_data(), book.to_save_data(), "Collection save preserves counts exactly")
	assert_true(not restored.apply_save_data({"collected": {"unrecognised": 2}}).ok, "Unknown collection definitions are explicitly rejected")
	assert_equal(restored.unique_count(), 1, "Invalid collection load preserves the live book")
	return results
