extends SceneTree

const AppConfigScript = preload("res://src/infrastructure/config/app_config.gd")
const GeneratorScript = preload("res://src/domain/worldgen/structured_world_generator.gd")
const REPORT_PATH := "res://art/qa/reports/phase_5_seed_batch.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var report_document: Dictionary = AppConfigScript.load_json_document(REPORT_PATH)
	var config_document: Dictionary = AppConfigScript.load_json_document("res://config/worldgen/default.json")
	if not bool(report_document.get("ok", false)) or not bool(config_document.get("ok", false)):
		_fail("Authoritative report or worldgen config could not be loaded")
		return
	var report: Dictionary = report_document.data
	if not bool(report.get("authoritative", false)) or int(report.get("curated_count", 0)) != 32 or int(report.get("random_count", 0)) != 256 or int(report.get("total_count", 0)) != 288:
		_fail("Canonical report is not an authoritative 32+256 seed batch")
		return
	var records: Array = report.get("seeds", [])
	if records.size() != 288:
		_fail("Canonical report does not contain all seed records")
		return
	var discovery_records: Array[Dictionary] = []
	var mismatches: Array[Dictionary] = []
	var generator := GeneratorScript.new()
	for index: int in [0, 31, 32, 95, 159, 223, 287]:
		var record: Dictionary = records[index]
		var replay = generator.generate_result(config_document.data, int(record.seed))
		discovery_records.append({"seed": int(record.seed), "metrics": replay.report.get("validation", {}).get("metrics", {}).get("discovery_economy", {})})
		if not replay.success or replay.get_content_hash() != int(record.content_hash):
			mismatches.append({"index": index, "seed": record.seed, "expected": record.content_hash, "actual": replay.get_content_hash()})
	if not mismatches.is_empty():
		_fail("Fresh-process content hash mismatch: %s" % mismatches)
		return
	var evidence := FileAccess.open("res://art/qa/reports/phase20_discovery_replay.json", FileAccess.WRITE)
	if evidence != null:
		evidence.store_string(JSON.stringify({"worldgen_version": 7, "spatial_proxy_note": "Not measured player time", "records": discovery_records}, "  "))
		evidence.close()
	print("PHASE5_FRESH_REPLAY_PASS checked=7 report=%s" % REPORT_PATH)
	quit(0)


func _fail(message: String) -> void:
	push_error("PHASE5_FRESH_REPLAY_FAIL %s" % message)
	quit(1)
