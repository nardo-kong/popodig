class_name ChapterModel
extends RefCounted

# Phase 13 chapter milestone progression (docs/design/02 GDD §13 chapter
# goals; docs/world/04 §6 gating "milestone knowledge/objectives, not
# invisible walls"; docs/systems/10 §14 population growth at chapter points).
# Pure logic over a caller-supplied context snapshot so tests can drive it
# without a running world.

signal chapter_advanced(new_chapter: int, growth_count: int)

const CHAPTER_1_SETTLE := 1
const CHAPTER_2_ADAPT := 2
const CHAPTER_3_OLD_BURROW := 3

const DEFAULT_CONFIG := {
	"chapter_2_growth": 2,
	"chapter_3_growth": 2,
	"chapter1_food_target": 10,
}

var rules_version := 1
var current_chapter := CHAPTER_1_SETTLE
var campaign_complete := false
var _config: Dictionary = {}


func configure(balance: Dictionary = {}) -> void:
	rules_version = 2 if bool(balance.get("v2_progression", false)) else 1
	_config = DEFAULT_CONFIG.duplicate()
	_config.merge(balance.get("population", {}), true)


func get_growth_for_chapter(chapter: int) -> int:
	return maxi(0, int(_config.get("chapter_%d_growth" % chapter, 0)))


## Evaluates milestone conditions against a context snapshot:
##   colony_depth      — deepest cell the colony actually reached (y)
##   chapter_depths    — {"chapter_2": y, "chapter_3": y} from worldgen metadata
##   sleeping_ready    — a valid, set-up Sleeping zone exists
##   storage_ready     — a valid, set-up Storage zone exists
##   food_total        — current stored food units
##   signals_learned   — root AND water signals recognised beyond UNKNOWN
##   water_settled     — no active flowing water (chapter 2 gate)
##   supports_built    — at least one reinforcement completed (chapter 2 gate)
##   warm_home_ready   — a set-up sleeping zone inside the revealed warm
##                       chamber (GDD §14 final-home stability condition)
## Returns the number of chapters advanced (0, 1, or 2).
func evaluate(context: Dictionary) -> int:
	var advanced := 0
	if current_chapter == CHAPTER_1_SETTLE and _chapter_1_complete(context):
		current_chapter = CHAPTER_2_ADAPT
		advanced += 1
		chapter_advanced.emit(current_chapter, get_growth_for_chapter(2))
	if current_chapter == CHAPTER_2_ADAPT and _chapter_2_complete(context):
		current_chapter = CHAPTER_3_OLD_BURROW
		advanced += 1
		chapter_advanced.emit(current_chapter, get_growth_for_chapter(3))
	if current_chapter == CHAPTER_3_OLD_BURROW and not campaign_complete and bool(context.get("warm_home_ready", false)):
		campaign_complete = true
		advanced += 1
	return advanced


## GDD Chapter 1 "Settle": dry sleeping, reliable food access, basic storage,
## signals learned, and the colony has dug down into the transition band.
func _chapter_1_complete(context: Dictionary) -> bool:
	if not (bool(context.get("sleeping_ready", false)) and bool(context.get("storage_ready", false))):
		return false
	if int(context.get("food_total", 0)) < int(_config.get("chapter1_food_target", 10)):
		return false
	if rules_version >= 2:
		if int(context.get("discoveries_found", 0)) < 1 or int(context.get("production_batches", 0)) < 1 or int(context.get("capability_level", 0)) < 1:
			return false
	elif not bool(context.get("signals_learned", false)):
		return false
	var depths: Dictionary = context.get("chapter_depths", {})
	return int(context.get("colony_depth", -1)) >= int(depths.get("chapter_2", 1 << 28))


## GDD Chapter 2 "Adapt": reach the old-burrow depth range while having
## managed water (nothing still flowing) and unstable terrain (supports used).
## PROVISIONAL thresholds — Phase 14 may tighten them.
func _chapter_2_complete(context: Dictionary) -> bool:
	if rules_version >= 2 and (int(context.get("capability_level", 0)) < 2 or not bool(context.get("water_learned", false))):
		return false
	if not (bool(context.get("water_settled", false)) and bool(context.get("supports_built", false))):
		return false
	var depths: Dictionary = context.get("chapter_depths", {})
	return int(context.get("colony_depth", -1)) >= int(depths.get("chapter_3", 1 << 28))


## Persistence: additive optional key inside the save's progression section
## (docs/tech/15) — old v2 saves restore to Chapter 1 via the default.
func to_save_data() -> Dictionary:
	return {"chapter": current_chapter, "campaign_complete": campaign_complete, "rules_version": rules_version}


func apply_save_data(data: Dictionary) -> void:
	rules_version = clampi(int(data.get("rules_version", rules_version)), 1, 2)
	current_chapter = clampi(int(data.get("chapter", CHAPTER_1_SETTLE)), CHAPTER_1_SETTLE, CHAPTER_3_OLD_BURROW)
	campaign_complete = bool(data.get("campaign_complete", false))
