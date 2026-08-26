class_name ContextTutorialModel
extends RefCounted

# Phase 9 contextual tutorial (docs/ux/11 spec §11-12): action-first, one
# sentence at a time, strictly forward-moving. Steps carry translation keys;
# the presentation layer resolves them through Localization so both slice
# languages share one state machine. Pure logic over a flags dictionary.

const STEPS: Array[Dictionary] = [
	{"id": "dig", "require": "", "text_key": "tutorial.dig"},
	{"id": "digging", "require": "designated", "text_key": "tutorial.digging"},
	{"id": "sleep", "require": "open_space", "text_key": "tutorial.sleep"},
	{"id": "sleep_ready", "require": "sleeping_zone", "text_key": "tutorial.sleep_ready"},
	{"id": "root_clue", "require": "root_clue", "text_key": "tutorial.root_clue"},
	{"id": "root_found", "require": "root_revealed", "text_key": "tutorial.root_found"},
	{"id": "moisture", "require": "moisture_clue", "text_key": "tutorial.moisture"},
	{"id": "breach", "require": "breach", "text_key": "tutorial.breach"},
	{"id": "stability", "require": "stability_warning", "text_key": "tutorial.stability"},
	{"id": "done", "require": "objective_reached", "text_key": "tutorial.done"},
]

var index := 0


func current_text_key() -> String:
	return String(STEPS[index].text_key)


func current_id() -> String:
	return String(STEPS[index].id)


## Advances while the NEXT step's requirement flag is present. Monotonic:
## the tutorial never moves backward even if flags disappear.
func advance(flags: Dictionary) -> bool:
	var moved := false
	while index + 1 < STEPS.size() and not String(STEPS[index + 1].require).is_empty() and bool(flags.get(String(STEPS[index + 1].require), false)):
		index += 1
		moved = true
	return moved


func is_finished() -> bool:
	return index >= STEPS.size() - 1
