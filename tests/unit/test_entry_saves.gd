extends "res://tests/test_case.gd"
const Saves = preload("res://src/infrastructure/persistence/save_service.gd")


func run() -> Array[Dictionary]:
	var directory := "user://qa_entry_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	assert_equal(Saves.latest_slot(directory), "", "No save produces no misleading continue action")
	assert_true(Saves.save_game(directory.path_join("autosave.json"), {"home": "automatic"}).ok, "Entry fixture writes automatic save")
	assert_equal(Saves.latest_slot(directory), "autosave", "Continue can find an automatic save")
	assert_true(Saves.save_game(directory.path_join("quicksave.json"), {"home": "manual"}).ok, "Entry fixture writes manual save")
	assert_true(Saves.latest_slot(directory) in ["quicksave", "autosave"], "Continue selects a known saved slot")
	assert_true(Saves.archive_slots(directory).ok, "Starting anew preserves both previous slots")
	assert_equal(Saves.latest_slot(directory), "", "Old slots do not masquerade as the new home")
	var archive := directory.path_join("archive")
	var entries := DirAccess.get_files_at(archive)
	assert_equal(entries.size(), 2, "Both previous home documents remain available in the archive")
	var homes: Array[String] = []
	for entry: String in entries:
		homes.append(str(JSON.parse_string(FileAccess.get_file_as_string(archive.path_join(entry))).home))
		DirAccess.remove_absolute(archive.path_join(entry))
	assert_true(homes.has("automatic") and homes.has("manual"), "Archive retains the original contents without replacing either")
	DirAccess.remove_absolute(archive)
	DirAccess.remove_absolute(directory)
	return results
