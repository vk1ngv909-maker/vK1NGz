extends Node

const BigNumber = preload("res://scripts/utilities/big_number.gd")

const SCHEMA_VERSION: int = 3
const PRIMARY_PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save.backup.json"
const TEMP_PATH: String = "user://save.tmp.json"
const MAX_OFFLINE_SECONDS: int = 28_800
const RUN_STATE_KEYS: Array[String] = [
	"stage", "gold", "tap_level", "support_hero_levels", "active_skills",
	"skill_timestamps", "temporary_buffs", "boss_time_left", "awaiting_retry",
]
const PERMANENT_STATE_KEYS: Array[String] = [
	"max_stage", "prestige_currency", "relic_levels", "equipment", "achievements",
	"settings", "statistics", "last_seen_utc", "offline_claimed_utc", "tutorial",
	"boss_first_clears", "reward_pity",
]

var last_load_source: String = "default"
var data: Dictionary = {}


func _ready() -> void:
	if data.is_empty():
		data = default_data()


func save(save_data: Dictionary) -> bool:
	save_data["schema_version"] = SCHEMA_VERSION
	if not validate(save_data):
		push_error("SaveManager.save: refusing to save invalid data")
		return false
	if not _write_verified_temp(save_data):
		return false

	if FileAccess.file_exists(PRIMARY_PATH):
		var copy_error: Error = DirAccess.copy_absolute(PRIMARY_PATH, BACKUP_PATH)
		if copy_error != OK:
			push_error("SaveManager.save: could not create backup (%s)" % error_string(copy_error))
			DirAccess.remove_absolute(TEMP_PATH)
			return false

	if not _replace_primary_from_temp():
		return false
	data = save_data.duplicate(true)
	return true


func load() -> Dictionary:
	var primary: Variant = _read_json(PRIMARY_PATH)
	if validate(primary):
		data = migrate((primary as Dictionary).duplicate(true))
		last_load_source = "primary"
		return data

	var backup: Variant = _read_json(BACKUP_PATH)
	if validate(backup):
		data = migrate((backup as Dictionary).duplicate(true))
		if not _restore_primary(data):
			push_error("SaveManager.load: backup loaded but primary restore failed")
		last_load_source = "backup"
		return data

	data = default_data()
	last_load_source = "default"
	return data


func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var candidate: Dictionary = value as Dictionary
	if not candidate.has("schema_version") or not _is_integer_number(candidate["schema_version"]):
		return false
	if _contains_non_finite_number(candidate):
		return false
	var version: int = int(candidate["schema_version"])
	if version == 1 or version == 2:
		return _validate_state_fields(candidate, candidate)
	if version != SCHEMA_VERSION:
		return false
	if not candidate.get("run_state") is Dictionary:
		return false
	if not candidate.get("permanent_state") is Dictionary:
		return false
	return _validate_state_fields(candidate["run_state"] as Dictionary, candidate["permanent_state"] as Dictionary)


func migrate(save_data: Dictionary) -> Dictionary:
	var version: int = int(save_data.get("schema_version", -1))
	if version == 1:
		save_data = _migrate_v1_to_v2(save_data)
		version = 2
	if version == 2:
		return _migrate_v2_to_v3(save_data)
	if version == SCHEMA_VERSION:
		return _with_defaults(save_data)
	push_error("SaveManager.migrate: unsupported schema version %d" % version)
	return default_data()


static func default_run_state() -> Dictionary:
	return {
		"stage": 1,
		"gold": BigNumber.from_float(0.0).to_dict(),
		"tap_level": 1,
		"support_hero_levels": {},
		"active_skills": {},
		"skill_timestamps": {"activated_at_ms": {}, "cooldown_until_ms": {}},
		"temporary_buffs": {},
		"boss_time_left": 0.0,
		"awaiting_retry": false,
	}


static func default_permanent_state() -> Dictionary:
	return {
		"max_stage": 1,
		"prestige_currency": 0,
		"relic_levels": {},
		"equipment": {"owned_items": [], "equipped_slots": {}, "next_uid": 1},
		"boss_first_clears": {},
		"reward_pity": {},
		"achievements": [],
		"settings": {
			"master_volume": 1.0,
			"music_volume": 0.8,
			"sfx_volume": 0.8,
			"ui_volume": 0.8,
			"vibration": true,
			"reduced_flash": false,
			"damage_numbers": true,
			"language": "en",
			"numeral_style": "western",
		},
		"tutorial": {"completed": false, "current_step": 0},
		"statistics": {},
		"last_seen_utc": int(Time.get_unix_time_from_system()),
		"offline_claimed_utc": 0,
	}


func default_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"run_state": default_run_state(),
		"permanent_state": default_permanent_state(),
	}


func claim_offline(now_utc: int) -> Dictionary:
	if data.is_empty():
		data = self.load()
	var permanent_state: Dictionary = data["permanent_state"]
	var last_seen: int = int(permanent_state.get("last_seen_utc", now_utc))
	var already_claimed: int = int(permanent_state.get("offline_claimed_utc", 0))
	if now_utc < last_seen or already_claimed >= last_seen:
		return {"seconds": 0, "granted": false}

	var elapsed: int = mini(now_utc - last_seen, MAX_OFFLINE_SECONDS)
	if elapsed <= 0:
		return {"seconds": 0, "granted": false}

	permanent_state["offline_claimed_utc"] = now_utc
	if not save(data):
		permanent_state["offline_claimed_utc"] = already_claimed
		return {"seconds": 0, "granted": false}
	return {"seconds": elapsed, "granted": true}


func _migrate_v1_to_v2(save_data: Dictionary) -> Dictionary:
	var migrated: Dictionary = _legacy_v2_defaults()
	for key: Variant in save_data:
		migrated[key] = save_data[key]
	if migrated["gold"] is int or migrated["gold"] is float:
		migrated["gold"] = BigNumber.from_float(float(migrated["gold"])).to_dict()
	migrated["schema_version"] = 2
	return migrated


func _migrate_v2_to_v3(save_data: Dictionary) -> Dictionary:
	var migrated: Dictionary = default_data()
	var run_state: Dictionary = migrated["run_state"]
	var permanent_state: Dictionary = migrated["permanent_state"]
	for key_value: Variant in save_data:
		var key: String = str(key_value)
		if key == "schema_version":
			continue
		if key in RUN_STATE_KEYS:
			run_state[key] = save_data[key_value]
		elif key in PERMANENT_STATE_KEYS:
			permanent_state[key] = save_data[key_value]
		else:
			permanent_state[key] = save_data[key_value]
			push_warning("SaveManager.migrate: preserving unknown legacy key '%s' in permanent_state" % key)
	return migrated


func _legacy_v2_defaults() -> Dictionary:
	var flat: Dictionary = {"schema_version": 2}
	for key: Variant in default_run_state():
		flat[key] = default_run_state()[key]
	for key: Variant in default_permanent_state():
		flat[key] = default_permanent_state()[key]
	return flat


func _with_defaults(save_data: Dictionary) -> Dictionary:
	var complete: Dictionary = default_data()
	for key: Variant in save_data:
		if key == "run_state" and save_data[key] is Dictionary:
			for run_key: Variant in save_data[key]:
				(complete["run_state"] as Dictionary)[run_key] = save_data[key][run_key]
		elif key == "permanent_state" and save_data[key] is Dictionary:
			for permanent_key: Variant in save_data[key]:
				(complete["permanent_state"] as Dictionary)[permanent_key] = save_data[key][permanent_key]
		else:
			complete[key] = save_data[key]
	return complete


func _validate_state_fields(run_state: Dictionary, permanent_state: Dictionary) -> bool:
	if not run_state.has("gold") or not _valid_gold(run_state["gold"]):
		return false
	if run_state.has("stage"):
		if not _is_integer_number(run_state["stage"]) or int(run_state["stage"]) < 1:
			return false
	if run_state.has("tap_level"):
		if not _is_integer_number(run_state["tap_level"]) or int(run_state["tap_level"]) < 1:
			return false
	if permanent_state.has("max_stage"):
		if not _is_integer_number(permanent_state["max_stage"]) or int(permanent_state["max_stage"]) < 1:
			return false
	for timestamp_field: String in ["last_seen_utc", "offline_claimed_utc"]:
		if permanent_state.has(timestamp_field):
			if not _is_integer_number(permanent_state[timestamp_field]) or int(permanent_state[timestamp_field]) < 0:
				return false
	if permanent_state.has("prestige_currency"):
		if not _is_integer_number(permanent_state["prestige_currency"]) or int(permanent_state["prestige_currency"]) < 0:
			return false
	if run_state.has("support_hero_levels") and not _valid_level_dictionary(run_state["support_hero_levels"]):
		return false
	if permanent_state.has("relic_levels") and not _valid_level_dictionary(permanent_state["relic_levels"]):
		return false
	if run_state.has("skill_timestamps") and not _valid_skill_timestamps(run_state["skill_timestamps"]):
		return false
	return true


func _valid_gold(value: Variant) -> bool:
	if value is int:
		return int(value) >= 0
	if value is float:
		return is_finite(float(value)) and float(value) >= 0.0
	if not value is Dictionary:
		return false
	var gold_data: Dictionary = value as Dictionary
	if not gold_data.has("mantissa") or not gold_data.has("exponent"):
		return false
	if not _is_number(gold_data["mantissa"]) or not _is_integer_number(gold_data["exponent"]):
		return false
	if not is_finite(float(gold_data["mantissa"])):
		return false
	var number: BigNumber = BigNumber.from_dict(gold_data)
	return number.is_valid() and number.mantissa >= 0.0


func _contains_non_finite_number(value: Variant) -> bool:
	if value is float:
		return not is_finite(float(value))
	if value is Dictionary:
		for child: Variant in (value as Dictionary).values():
			if _contains_non_finite_number(child):
				return true
	elif value is Array:
		for child: Variant in value as Array:
			if _contains_non_finite_number(child):
				return true
	return false


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(float(value)) and float(value) == floor(float(value))
	return false


func _valid_level_dictionary(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for level: Variant in (value as Dictionary).values():
		if not _is_integer_number(level) or int(level) < 0:
			return false
	return true


func _valid_skill_timestamps(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var timestamps: Dictionary = value as Dictionary
	for field: String in ["activated_at_ms", "cooldown_until_ms"]:
		if not timestamps.has(field) or not timestamps[field] is Dictionary:
			return false
		for timestamp: Variant in (timestamps[field] as Dictionary).values():
			if not _is_integer_number(timestamp) or int(timestamp) < 0:
				return false
	return true


func _write_verified_temp(save_data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open temporary save (%s)" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(save_data))
	file.flush()
	file.close()
	var verification: Variant = _read_json(TEMP_PATH)
	if not verification is Dictionary:
		push_error("SaveManager: temporary save verification failed")
		DirAccess.remove_absolute(TEMP_PATH)
		return false
	return true


func _replace_primary_from_temp() -> bool:
	var rename_error: Error = DirAccess.rename_absolute(TEMP_PATH, PRIMARY_PATH)
	if rename_error != OK:
		push_error("SaveManager: could not replace primary save (%s)" % error_string(rename_error))
		DirAccess.remove_absolute(TEMP_PATH)
		return false
	return true


func _restore_primary(restored_data: Dictionary) -> bool:
	if not _write_verified_temp(restored_data):
		return false
	return _replace_primary_from_temp()


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data
