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
	{"id": "forage", "require": "forage_ready", "text_key": "tutorial.forage"},
	{"id": "moisture", "require": "moisture_clue", "text_key": "tutorial.moisture"},
	{"id": "breach", "require": "breach", "text_key": "tutorial.breach"},
	{"id": "stability", "require": "stability_warning", "text_key": "tutorial.stability"},
	{"id": "done", "require": "objective_reached", "text_key": "tutorial.done"},
]

const V2_STEPS: Array[Dictionary] = [
	{"id": "promise", "require": "", "text_key": "tutorial.v2.promise"},
	{"id": "found", "require": "first_find", "text_key": "tutorial.v2.found"},
	{"id": "store", "require": "sleeping_zone", "text_key": "tutorial.v2.store"},
	{"id": "raw", "require": "storage_ready", "text_key": "tutorial.v2.raw"},
	{"id": "workshop", "require": "raw_ready", "text_key": "tutorial.v2.workshop"},
	{"id": "craft", "require": "workshop_ready", "text_key": "tutorial.v2.craft"},
	{"id": "upgrade", "require": "production_ready", "text_key": "tutorial.v2.upgrade"},
	{"id": "supply", "require": "tools_ready", "text_key": "tutorial.v2.supply"},
	{"id": "deeper", "require": "food_supply_ready", "text_key": "tutorial.v2.deeper"},
	{"id": "adapt", "require": "chapter2", "text_key": "tutorial.v2.adapt"},
	{"id": "supports", "require": "supports_ready", "text_key": "tutorial.v2.supports"},
	{"id": "deep", "require": "deep_tools_ready", "text_key": "tutorial.v2.deep"},
	{"id": "old", "require": "old_burrow_ready", "text_key": "tutorial.v2.old"},
	{"id": "warm", "require": "warm_chamber_ready", "text_key": "tutorial.v2.warm"},
	{"id": "home", "require": "campaign_complete", "text_key": "tutorial.v2.home"},
]

var v2 := false

var index := 0


func current_text_key() -> String:
	return String(_steps()[index].text_key)


func current_id() -> String:
	return String(_steps()[index].id)


## Advances while the NEXT step's requirement flag is present. Monotonic:
## the tutorial never moves backward even if flags disappear.
func advance(flags: Dictionary) -> bool:
	var moved := false
	while index + 1 < _steps().size() and not String(_steps()[index + 1].require).is_empty() and bool(flags.get(String(_steps()[index + 1].require), false)):
		index += 1
		moved = true
	return moved


func is_finished() -> bool:
	return index >= _steps().size() - 1


func _steps() -> Array[Dictionary]:
	return V2_STEPS if v2 else STEPS


func configure_v2(enabled: bool) -> void:
	v2 = enabled
	index = clampi(index, 0, _steps().size() - 1)


func restore_id(id: String) -> void:
	for candidate: int in range(_steps().size()):
		if str(_steps()[candidate].id) == id:
			index = candidate
			return
	index = 0
