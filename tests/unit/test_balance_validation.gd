extends SceneTree

const BalanceDataLogic = preload("res://autoload/balance_data.gd")

var passed: int = 0
var failed: int = 0
var validator: Node


func _init() -> void:
	validator = BalanceDataLogic.new()
	_check(validator.validate(validator.SAFE_DEFAULTS.duplicate(true)), "built-in defaults validate")
	_test_missing_file_and_json()
	_test_required_keys_and_types()
	_test_non_finite_values()
	_test_growth_rules()
	_test_schema_and_unknown_keys()
	validator.free()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_missing_file_and_json() -> void:
	validator.load_from_path("user://balance-does-not-exist.json")
	_check(validator.balance_data_invalid, "missing file marks balance invalid")
	_check(validator.last_error_key == "<file>", "missing file reports exact pseudo-key")
	_check(validator.data() == validator.SAFE_DEFAULTS, "missing file uses safe defaults")
	var invalid_json_path: String = "user://invalid-balance.json"
	var file: FileAccess = FileAccess.open(invalid_json_path, FileAccess.WRITE)
	file.store_string("{ definitely not json")
	file.close()
	validator.load_from_path(invalid_json_path)
	_check(validator.balance_data_invalid and validator.last_error_key == "<json>", "invalid JSON is rejected loudly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_json_path))


func _test_required_keys_and_types() -> void:
	for key: String in validator.REQUIRED_KEYS:
		var missing: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
		missing.erase(key)
		_check(not validator.validate(missing), "missing required key is rejected: %s" % key)
		_check(validator.last_error_key == key and validator.last_error_value == "<missing>", "missing key is identified: %s" % key)
	for key: String in validator.REQUIRED_KEYS:
		var wrong_type: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
		wrong_type[key] = "wrong type"
		_check(not validator.validate(wrong_type), "wrong value type is rejected: %s" % key)
		_check(validator.last_error_key == key and validator.last_error_value == "wrong type", "wrong type identifies key and value: %s" % key)


func _test_non_finite_values() -> void:
	for invalid_number: float in [NAN, INF, -INF]:
		var candidate: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
		candidate["critical_multiplier"] = invalid_number
		_check(not validator.validate(candidate), "non-finite value is rejected")
		_check(validator.last_error_key == "critical_multiplier", "non-finite value identifies its key")


func _test_growth_rules() -> void:
	for key: String in validator.GROWTH_KEYS:
		for invalid_growth: float in [0.0, -0.1, 3.0]:
			var candidate: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
			candidate[key] = invalid_growth
			_check(not validator.validate(candidate) and validator.last_error_key == key, "growth bound rejected: %s=%s" % [key, invalid_growth])
	for key: String in ["enemy_hp_growth", "enemy_gold_growth", "upgrade_cost_growth"]:
		var candidate: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
		candidate[key] = 1.0
		_check(not validator.validate(candidate) and validator.last_error_key == key, "non-growing progression rejected: %s" % key)
	var shrinking_damage: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
	shrinking_damage["tap_damage_growth"] = 0.99
	_check(not validator.validate(shrinking_damage) and validator.last_error_key == "tap_damage_growth", "shrinking tap damage is rejected")
	var zero_hp: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
	zero_hp["enemy_hp_base"] = 0.0
	_check(not validator.validate(zero_hp) and validator.last_error_key == "enemy_hp_base", "non-positive enemy HP base is rejected")


func _test_schema_and_unknown_keys() -> void:
	var future: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
	future["schema_version"] = validator.SUPPORTED_SCHEMA_VERSION + 1
	_check(not validator.validate(future), "newer schema is rejected")
	_check(validator.last_error_key == "schema_version" and validator.last_error_value == 2, "newer schema identifies exact key and value")
	var unknown: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
	unknown["future_tuning_note"] = 42
	_check(validator.validate(unknown), "unknown key warns without rejecting")
	var invalid_path: String = "user://unsafe-balance.json"
	var file: FileAccess = FileAccess.open(invalid_path, FileAccess.WRITE)
	var invalid_file_data: Dictionary = validator.SAFE_DEFAULTS.duplicate(true)
	invalid_file_data["enemy_hp_growth"] = 1.0
	file.store_string(JSON.stringify(invalid_file_data))
	file.close()
	validator.load_from_path(invalid_path)
	_check(validator.balance_data_invalid, "invalid loaded data sets visible invalid flag")
	_check(validator.data() == validator.SAFE_DEFAULTS, "invalid loaded data falls back to built-in defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
