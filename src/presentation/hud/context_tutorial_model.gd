class_name ContextTutorialModel
extends RefCounted

# Phase 9 contextual tutorial (docs/ux/11 spec §11-12): action-first, one
# sentence at a time, strictly forward-moving. Pure logic over a flags
# dictionary so the state machine is unit-testable without a scene.

const STEPS: Array[Dictionary] = [
	{"id": "dig", "require": "", "text": "这里有点挤，挖一点空间吧——按住左键在附近泥土上拖动，指定要挖的格子。"},
	{"id": "digging", "require": "designated", "text": "鼠鼠们会自己完成挖掘，不需要手动指挥每一格。"},
	{"id": "sleep", "require": "open_space", "text": "有空间了！按 2 选择睡眠区，在洞穴地面上涂抹给鼠鼠安家。"},
	{"id": "sleep_ready", "require": "sleeping_zone", "text": "睡眠区就绪。食物会越来越重要——留意土里的根须线索。"},
	{"id": "root_clue", "require": "root_clue", "text": "根须越密，说明附近越可能有可食用的根簇。挖过去看看。"},
	{"id": "root_found", "require": "root_revealed", "text": "发现根簇！按 4 规划食物/觅食区，根簇才能持续产出食物。"},
	{"id": "moisture", "require": "moisture_clue", "text": "湿土意味着水。提前想好排水路线，或按 5 准备封堵。"},
	{"id": "breach", "require": "breach", "text": "水涌出来了！鼠鼠会自动抢救物资——封堵或挖排水道由你决定。"},
	{"id": "stability", "require": "stability_warning", "text": "天花板出现裂纹——收窄跨度，或按 6 用材料加固。"},
	{"id": "done", "require": "objective_reached", "text": "鼠鼠们的家已经初具规模。剩下的地下世界由你决定。"},
]

var index := 0


func current_text() -> String:
	return String(STEPS[index].text)


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
