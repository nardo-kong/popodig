class_name WorldHoverInfo
extends RefCounted

var _world
var _registry
var _items
var _fog
var _discoveries
var _zones
var _signals


func configure(world, registry, items, fog, discoveries, zones, signals) -> void:
	_world = world
	_registry = registry
	_items = items
	_fog = fog
	_discoveries = discoveries
	_zones = zones
	_signals = signals


func inspect(cell: Vector2i, locale: String = "zh") -> Dictionary:
	var zh := locale.begins_with("zh")
	if not _world.is_in_bounds(cell):
		return {}
	# Never inspect authoritative objects behind fully dark terrain. Even
	# material names / pile counts would spoil a buried cavity or feature.
	if _fog.distance_to_frontier(cell) > 3:
		return _entry("unknown", "尚未探索" if zh else "Unexplored", "這裡還看不清楚。" if zh else "You cannot see what is here yet.", "從已挖開的邊緣逐步探索。" if zh else "Explore outwards from an open passage.")
	var rows: Array[Dictionary] = []
	if _fog.distance_to_frontier(cell) <= 1:
		for pile_id: int in _items.get_pile_ids_at(cell):
			var pile = _items.get_pile(pile_id)
			if pile != null and pile.count > 0:
				rows.append({"icon": pile.item_type, "name": ResourceVisuals.title(pile.item_type, locale), "count": pile.count, "purpose": ResourceVisuals.purpose(pile.item_type, locale)})
	if not rows.is_empty():
		var result := _entry("resource", ("地上的物資" if zh else "Supplies on the ground"), "\n".join(rows.map(func(row: Dictionary) -> String: return "%s × %d\n%s" % [row.name, row.count, row.purpose])), "食物會自動取用；按 3 在乾燥空地劃倉儲，鼠鼠會搬進去。" if zh else "Mice eat automatically. Press 3 and mark a dry open store to gather supplies.", str(rows[0].icon))
		result["title"] = "%s × %d" % [rows[0].name, rows[0].count] if rows.size() == 1 else result.title
		result["body"] = str(rows[0].purpose) if rows.size() == 1 else result.body
		result["items"] = rows
		if rows.size() == 1:
			var actions := {
				"FOOD": ["不用逐隻餵食。按 3，在乾燥空地劃倉儲，鼠鼠會自動搬運。", "No individual feeding is needed. Press 3 to mark a dry open store; mice will gather the food."],
				"GENERAL_MATERIAL": ["按 2／3／7 在空地劃區，鼠鼠會用建材自動佈置。", "Use 2 / 3 / 7 to mark a zone on open ground. Mice bring materials to set it up."],
				"STONE": ["按 7 建工坊，選「石材 → 建材」。", "Make a workshop (7), then choose Stone → materials."],
				"ORE": ["在工坊選「礦石 → 金屬」，鼠鼠會自主供料加工。", "Choose Ore → metal in a workshop. Mice supply and craft automatically."],
				"METAL": ["備齊可到達的材料，在家園面板升級鼠群工具。", "Gather the reachable costs, then upgrade colony tools in the home panel."],
			}
			var words: Array = actions.get(str(rows[0].icon), [result.action, result.action])
			result["action"] = str(words[0 if zh else 1])
		return result
	var feature = _registry.get_feature(_world.get_feature_id(cell))
	if feature != null and feature.type_id == "root_cluster" and not feature.hidden:
		var reserve := int(feature.metadata.get("food_reserve_units", 0))
		var edible: bool = bool(feature.metadata.get("food_opportunity", reserve > 0))
		if not edible:
			return _entry("root", "樹根｜天然結構" if zh else "Tree roots · natural structure", "這片根系沒有可採集的食物。" if zh else "These roots do not offer gatherable food.", "可沿根系周圍探索，尋找其他食物來源。" if zh else "Explore around the roots for other food sources.", "ROOT")
		var body := ("這是仍在生長的根系，與地上的食物堆不同。\n" if zh else "These are living roots, distinct from food lying on the floor.\n") + (("這片根系的食物已採完。" if zh else "This root cluster has no food left.") if reserve <= 0 else ("附近可採集食物；儲量有限。" if zh else "Food can be gathered nearby; the reserve is finite."))
		var action := ("尋找其他根系，或把現有食物搬到家裡。" if zh else "Find another root cluster or bring existing food home.") if reserve <= 0 else ("按 4，在樹根旁已挖開、乾燥的空地劃覓食區。" if zh else "Press 4 and mark a dry, open forage zone beside these roots.")
		return _entry("root", "樹根｜食物來源" if zh else "Tree roots · food source", body, action, "ROOT")
	if feature != null and feature.type_id == "discovery" and not bool(feature.metadata.get("claimed", false)) and _discoveries.signal_band(cell) > 0:
		var definition: Dictionary = DiscoverySystem.definition_for(str(feature.metadata.get("definition_id", "")))
		var kind := str(definition.get("kind", ""))
		var titles := {"food": ["小芽｜食物線索", "Sprout · food clue"], "material": ["細纖維｜建材線索", "Fibres · building-material clue"], "stone": ["灰色石紋｜石材線索", "Grey stone · raw-stone clue"], "ore": ["銅色微光｜礦石線索", "Copper glint · ore clue"], "collectible": ["閃光｜收藏線索", "Glimmer · keepsake clue"]}
		var words: Array = titles.get(kind, ["土壁線索", "Clue in the wall"])
		var result := _entry("clue", str(words[0 if zh else 1]), "這是土裡的線索，還不是地上的物資。挖近後才會知道藏著什麼。" if zh else "This is a clue in the soil, not a supply pile. Dig closer to discover what it holds.", "選挖掘（1），左鍵拖曳相連的土格，讓鼠鼠挖過去。" if zh else "Select Dig (1) and drag connected soil cells to send mice towards it.")
		result["glyph"] = kind
		return result
	if _signals != null and _world.is_solid(cell) and _world.get_root_signal(cell) > 0:
		return _entry("root_clue", "細根鬚｜樹根線索" if zh else "Root threads · roots nearby", "土壁的分岔細線提示附近可能有根系；還未看見完整樹根。" if zh else "Branching threads suggest roots nearby; the full roots have not been exposed.", "沿根鬚探索；找到樹根後，再在旁邊設覓食區。" if zh else "Follow the threads, then place a forage zone beside exposed roots.")
	if _world.is_traversable(cell):
		var zone = _zones.get_zone_at(cell)
		if zone != null:
			var names := {Zone.Type.SLEEPING: ["睡眠區", "Sleeping area"], Zone.Type.STORAGE: ["倉儲區", "Storage"], Zone.Type.FOOD_FORAGE: ["覓食區", "Forage zone"], Zone.Type.PRODUCTION: ["工坊", "Workshop"]}
			var words: Array = names.get(zone.zone_type, ["已劃定區域", "Designated zone"])
			var body := "鼠鼠會自動佈置和使用這片區域。" if zh else "Mice set up and use this zone automatically."
			if zone.zone_type == Zone.Type.FOOD_FORAGE:
				body = "要靠近已發現的樹根，才會產出食物。" if zh else "It needs exposed roots nearby to produce food."
			return _entry("zone", str(words[0 if zh else 1]), body, "可用右鍵清除區域，重新安排位置。" if zh else "Use right-click to erase the zone and change the layout.")
		return _entry("space", "已挖開的空間" if zh else "Open space", "這裡可以規劃生活與工作區。" if zh else "Plan living and working areas here.", "2 睡眠 · 3 倉儲 · 4 覓食 · 7 工坊" if zh else "2 Sleep · 3 Store · 4 Forage · 7 Workshop")
	return _entry("ground", "土壁" if zh else "Underground wall", "還未挖開的地形。" if zh else "Ground that has not been excavated.", "選挖掘（1），由可到達的邊緣左鍵拖曳。" if zh else "Select Dig (1) and drag from a reachable edge.")


func _entry(kind: String, title: String, body: String, action: String, icon: String = "") -> Dictionary:
	return {"kind": kind, "title": title, "body": body, "action": action, "icon": icon}
