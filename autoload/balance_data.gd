extends Node

const BALANCE_PATH: String = "res://resources/balance.json"
const SUPPORTED_SCHEMA_VERSION: int = 1
const SAFE_DEFAULTS: Dictionary = {
	"schema_version": 1,
	"enemy_hp_base": 10.0,
	"enemy_hp_growth": 1.55,
	"boss_hp_multiplier": 8.0,
	"enemy_gold_base": 5.0,
	"enemy_gold_growth": 1.48,
	"upgrade_cost_base": 100.0,
	"upgrade_cost_growth": 1.075,
	"tap_damage_per_level": 5.0,
	"critical_chance": 0.2,
	"critical_multiplier": 5.0,
	"falcon_interval": 1.5,
	"falcon_damage_multiplier": 0.4,
	"boss_duration": 30.0,
	"boss_stage_interval": 10.0,
	"tap_damage_growth": 1.06,
	"equipment_diminishing_k": 1.5,
	"offline_efficiency": 0.35,
	"offline_kills_per_second": 0.15,
	"relic_speed_rate_gain": 55.0,
	"relic_speed_rate_softcap": 1.0,
	"relic_speed_rate_max": 24.0,
	"falcon_strikes_per_tick_cap": 512,
	"falcon_catchup_seconds": 2.0,
}
const REQUIRED_KEYS: Array[String] = [
	"schema_version",
	"enemy_hp_base",
	"enemy_hp_growth",
	"boss_hp_multiplier",
	"enemy_gold_base",
	"enemy_gold_growth",
	"upgrade_cost_base",
	"upgrade_cost_growth",
	"tap_damage_per_level",
	"critical_chance",
	"critical_multiplier",
	"falcon_interval",
	"falcon_damage_multiplier",
	"boss_duration",
	"boss_stage_interval",
	"tap_damage_growth",
	"equipment_diminishing_k",
	"offline_efficiency",
	"offline_kills_per_second",
	"relic_speed_rate_gain",
	"relic_speed_rate_softcap",
	"relic_speed_rate_max",
	"falcon_strikes_per_tick_cap",
	"falcon_catchup_seconds",
]
const GROWTH_KEYS: Array[String] = [
	"enemy_hp_growth",
	"enemy_gold_growth",
	"upgrade_cost_growth",
	"tap_damage_growth",
]

var balance_data_invalid: bool = false
var last_error_key: String = ""
var last_error_value: Variant = null
var _data: Dictionary = SAFE_DEFAULTS.duplicate(true)


func _ready() -> void:
	load_from_path(BALANCE_PATH)


func data() -> Dictionary:
	return _data


func load_from_path(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_reject("<file>", path)
		_use_safe_defaults()
		return _data
	var source: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error: Error = json.parse(source)
	if parse_error != OK or not json.data is Dictionary:
		_reject("<json>", json.get_error_message() if parse_error != OK else json.data)
		_use_safe_defaults()
		return _data
	if not validate(json.data as Dictionary):
		_use_safe_defaults()
		return _data
	_data = (json.data as Dictionary).duplicate(true)
	balance_data_invalid = false
	return _data


func validate(candidate: Dictionary) -> bool:
	last_error_key = ""
	last_error_value = null
	for key: String in REQUIRED_KEYS:
		if not candidate.has(key):
			return _reject(key, "<missing>")
	for key_value: Variant in candidate:
		var key: String = str(key_value)
		if key not in REQUIRED_KEYS:
			push_warning("BalanceData: unknown key '%s' value=%s" % [key, _value_text(candidate[key_value])])
	var schema_value: Variant = candidate["schema_version"]
	if not (schema_value is int or schema_value is float) or not is_finite(float(schema_value)) or float(schema_value) != floor(float(schema_value)):
		return _reject("schema_version", schema_value)
	if int(schema_value) > SUPPORTED_SCHEMA_VERSION:
		return _reject("schema_version", schema_value)
	if int(schema_value) < 1:
		return _reject("schema_version", schema_value)
	for key: String in REQUIRED_KEYS:
		if key == "schema_version":
			continue
		var value: Variant = candidate[key]
		if not (value is int or value is float):
			return _reject(key, value)
		if not is_finite(float(value)):
			return _reject(key, value)
	for key: String in GROWTH_KEYS:
		var growth: float = float(candidate[key])
		if growth <= 0.0 or growth >= 3.0:
			return _reject(key, candidate[key])
	for key: String in ["enemy_hp_growth", "enemy_gold_growth", "upgrade_cost_growth"]:
		if float(candidate[key]) <= 1.0:
			return _reject(key, candidate[key])
	if float(candidate["tap_damage_growth"]) < 1.0:
		return _reject("tap_damage_growth", candidate["tap_damage_growth"])
	if float(candidate["enemy_hp_base"]) <= 0.0:
		return _reject("enemy_hp_base", candidate["enemy_hp_base"])
	return true


func _reject(key: String, value: Variant) -> bool:
	last_error_key = key
	last_error_value = value
	if OS.is_debug_build():
		push_error("BalanceData: invalid key=%s value=%s" % [key, _value_text(value)])
	return false


func _use_safe_defaults() -> void:
	_data = SAFE_DEFAULTS.duplicate(true)
	balance_data_invalid = true


func _value_text(value: Variant) -> String:
	if value is float:
		var number: float = float(value)
		if is_nan(number):
			return "NaN"
		if is_inf(number):
			return "INF" if number > 0.0 else "-INF"
	return str(value)
