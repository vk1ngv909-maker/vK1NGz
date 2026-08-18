extends SceneTree

const SaveManagerScript = preload("res://autoload/save_manager.gd")

var passed: int = 0
var failed: int = 0
var manager: Node


func _init() -> void:
	manager = SaveManagerScript.new()
	_cleanup()
	_test_atomic_write_and_backup()
	_test_corruption_recovery()
	_test_both_corrupt_defaults()
	_test_v1_migration()
	_test_v2_migration()
	_test_validation()
	_test_offline_claims()
	_cleanup()
	manager.free()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)


func _cleanup() -> void:
	for path: String in [manager.PRIMARY_PATH, manager.BACKUP_PATH, manager.TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _fixture(gold: float = 0.0, stage: int = 1) -> Dictionary:
	var result: Dictionary = manager.default_data()
	result["run_state"]["gold"] = {"mantissa": gold, "exponent": 0}
	result["run_state"]["stage"] = stage
	result["permanent_state"]["max_stage"] = stage
	result["permanent_state"]["last_seen_utc"] = 100
	result["permanent_state"]["offline_claimed_utc"] = 0
	return result


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "opens fixture path %s" % path)
		return
	file.store_string(text)
	file.close()


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed


func _test_atomic_write_and_backup() -> void:
	_cleanup()
	var first: Dictionary = _fixture(2.0, 2)
	first.erase("schema_version")
	_check(manager.save(first), "atomic save succeeds")
	_check(first["schema_version"] == manager.SCHEMA_VERSION, "save stamps schema version")
	_check(FileAccess.file_exists(manager.PRIMARY_PATH), "atomic save creates primary")
	_check(not FileAccess.file_exists(manager.TEMP_PATH), "atomic save leaves no temporary file")
	var primary: Variant = _read_json(manager.PRIMARY_PATH)
	_check(primary is Dictionary and manager.validate(primary), "atomic save writes parseable valid JSON")

	var second: Dictionary = _fixture(5.0, 5)
	_check(manager.save(second), "second save succeeds")
	_check(FileAccess.file_exists(manager.BACKUP_PATH), "second save creates backup")
	var backup: Variant = _read_json(manager.BACKUP_PATH)
	_check(backup is Dictionary and int(backup["run_state"]["stage"]) == 2, "backup contains previous primary")


func _test_corruption_recovery() -> void:
	_write_text(manager.PRIMARY_PATH, "{corrupt")
	var recovered: Dictionary = manager.load()
	_check(manager.last_load_source == "backup", "corrupt primary loads backup")
	_check(int(recovered["run_state"]["stage"]) == 2, "backup data is returned")
	var restored: Variant = _read_json(manager.PRIMARY_PATH)
	_check(restored is Dictionary and int(restored["run_state"]["stage"]) == 2, "backup is restored to primary")
	_check(manager.validate(restored), "restored primary is valid")


func _test_both_corrupt_defaults() -> void:
	_write_text(manager.PRIMARY_PATH, "not json")
	_write_text(manager.BACKUP_PATH, "also not json")
	var loaded: Dictionary = manager.load()
	_check(manager.last_load_source == "default", "two corrupt files use defaults")
	_check(int(loaded["schema_version"]) == manager.SCHEMA_VERSION, "defaults use current schema")
	_check(int(loaded["run_state"]["stage"]) == 1, "defaults start at stage one")
	_check(loaded["run_state"]["gold"] is Dictionary and float(loaded["run_state"]["gold"]["mantissa"]) == 0.0, "defaults contain zero BigNumber gold")


func _test_v1_migration() -> void:
	_cleanup()
	var v1: Dictionary = {
		"schema_version": 1,
		"gold": 1250.0,
		"stage": 3,
		"max_stage": 4,
		"tap_level": 2,
		"last_seen_utc": 50,
		"offline_claimed_utc": 0,
	}
	_write_text(manager.PRIMARY_PATH, JSON.stringify(v1))
	var migrated: Dictionary = manager.load()
	_check(manager.last_load_source == "primary", "v1 fixture loads from primary")
	_check(int(migrated["schema_version"]) == 3, "v1 migration chains through current schema")
	_check(migrated["run_state"]["gold"] is Dictionary, "v1 numeric gold becomes a BigNumber dictionary")
	_check(is_equal_approx(float(migrated["run_state"]["gold"]["mantissa"]), 1.25), "v1 gold mantissa is converted")
	_check(int(migrated["run_state"]["gold"]["exponent"]) == 3, "v1 gold exponent is converted")


func _test_v2_migration() -> void:
	var v2: Dictionary = {
		"schema_version": 2,
		"stage": 80,
		"gold": {"mantissa": 7.0, "exponent": 4},
		"tap_level": 9,
		"max_stage": 125,
		"prestige_currency": 17,
		"relic_levels": {"sun_blade": 3},
		"future_purchase": {"owned": true},
	}
	var migrated: Dictionary = manager.migrate(v2)
	_check(int(migrated["schema_version"]) == 3, "v2 migration advances to v3")
	_check(int(migrated["permanent_state"]["max_stage"]) == 125, "v2 migration preserves max stage")
	_check(int(migrated["permanent_state"]["prestige_currency"]) == 17, "v2 migration preserves prestige currency")
	_check(int(migrated["permanent_state"]["relic_levels"]["sun_blade"]) == 3, "v2 migration preserves relic levels")
	_check(migrated["permanent_state"].has("future_purchase"), "unknown legacy data is preserved permanently")


func _test_validation() -> void:
	var missing_version: Dictionary = _fixture()
	missing_version.erase("schema_version")
	_check(not manager.validate(missing_version), "missing schema version is rejected")
	_check(not manager.validate("not a dictionary"), "non-dictionary is rejected")
	var bad_gold_type: Dictionary = _fixture()
	bad_gold_type["run_state"]["gold"] = "lots"
	_check(not manager.validate(bad_gold_type), "malformed gold type is rejected")
	var bad_gold_shape: Dictionary = _fixture()
	bad_gold_shape["run_state"]["gold"] = {"mantissa": 1.0}
	_check(not manager.validate(bad_gold_shape), "malformed BigNumber is rejected")
	var negative_number: Dictionary = _fixture()
	negative_number["run_state"]["gold"] = -1.0
	_check(not manager.validate(negative_number), "negative numeric gold is rejected")
	var negative_big_number: Dictionary = _fixture()
	negative_big_number["run_state"]["gold"] = {"mantissa": -1.0, "exponent": 10}
	_check(not manager.validate(negative_big_number), "negative BigNumber gold is rejected")
	var bad_stage: Dictionary = _fixture()
	bad_stage["run_state"]["stage"] = 0
	_check(not manager.validate(bad_stage), "stage below one is rejected")
	var malformed_stage: Dictionary = _fixture()
	malformed_stage["run_state"]["stage"] = "one"
	_check(not manager.validate(malformed_stage), "non-numeric stage is rejected")
	var malformed_timestamp: Dictionary = _fixture()
	malformed_timestamp["permanent_state"]["last_seen_utc"] = 10.5
	_check(not manager.validate(malformed_timestamp), "fractional timestamp is rejected")
	var nan_value: Dictionary = _fixture()
	nan_value["extra"] = NAN
	_check(not manager.validate(nan_value), "NaN anywhere in save is rejected")
	var inf_value: Dictionary = _fixture()
	inf_value["run_state"]["gold"] = {"mantissa": INF, "exponent": 0}
	_check(not manager.validate(inf_value), "infinite gold is rejected")
	var missing_run_state: Dictionary = _fixture()
	missing_run_state.erase("run_state")
	_check(not manager.validate(missing_run_state), "missing run state is rejected")
	var missing_permanent_state: Dictionary = _fixture()
	missing_permanent_state.erase("permanent_state")
	_check(not manager.validate(missing_permanent_state), "missing permanent state is rejected")


func _test_offline_claims() -> void:
	_cleanup()
	manager.data = _fixture()
	var rollback: Dictionary = manager.claim_offline(99)
	_check(not rollback["granted"] and int(rollback["seconds"]) == 0, "clock rollback grants nothing")

	manager.data = _fixture()
	var capped: Dictionary = manager.claim_offline(100 + 50_000)
	_check(capped["granted"] and int(capped["seconds"]) == 28_800, "offline elapsed time is capped at eight hours")

	_cleanup()
	manager.data = _fixture()
	var first: Dictionary = manager.claim_offline(500)
	var second: Dictionary = manager.claim_offline(500)
	_check(first["granted"] and int(first["seconds"]) == 400, "first offline claim grants elapsed time")
	_check(not second["granted"] and int(second["seconds"]) == 0, "repeated offline claim is idempotent")
