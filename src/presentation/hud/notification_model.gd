class_name NotificationModel
extends RefCounted

# Phase 9 player-facing event queue (docs/ux/11 spec §14): small, deduplicated,
# cooldown-guarded, self-expiring. Pure logic — time is injected so tests are
# deterministic and no scene tree is required.

const MAX_ACTIVE := 3
const DEFAULT_LIFETIME := 6.0
const DEFAULT_COOLDOWN := 10.0

var _entries: Array[Dictionary] = []
var _category_last_pushed: Dictionary = {}


func push(category: String, text: String, now: float, focus_cell: Vector2i = Vector2i(-1, -1), lifetime: float = DEFAULT_LIFETIME, cooldown: float = DEFAULT_COOLDOWN) -> bool:
	var last: float = _category_last_pushed.get(category, -INF)
	if now - last < cooldown:
		return false
	_category_last_pushed[category] = now
	_prune(now)
	_entries.push_front({
		"category": category,
		"text": text,
		"focus_cell": focus_cell,
		"expires_at": now + lifetime,
		"pushed_at": now,
	})
	while _entries.size() > MAX_ACTIVE:
		_entries.pop_back()
	return true


func active(now: float) -> Array[Dictionary]:
	_prune(now)
	return _entries.duplicate()


func latest_focus_cell(now: float) -> Vector2i:
	_prune(now)
	for entry: Dictionary in _entries:
		var cell: Vector2i = entry.focus_cell
		if cell.x >= 0:
			return cell
	return Vector2i(-1, -1)


func clear() -> void:
	_entries.clear()
	_category_last_pushed.clear()


func _prune(now: float) -> void:
	_entries = _entries.filter(func(entry: Dictionary) -> bool: return now < entry.expires_at)
