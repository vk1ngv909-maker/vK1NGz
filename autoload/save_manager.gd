extends Node

const BigNumber = preload("res://scripts/utilities/big_number.gd")

const SCHEMA_VERSION: int = 2
const PRIMARY_PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save.backup.json"
const TEMP_PATH: String = "user://save.tmp.json"
const MAX_OFFLINE_SECONDS: int = 28_800

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
	if not candidate.has("gold") or not _valid_gold(candidate["gold"]):
		return false
	if candidate.has("stage"):
		if not _is_integer_number(candidate["stage"]) or int(candidate["stage"]) < 1:
			return false
	for positive_field: String in ["max_stage", "tap_level"]:
		if candidate.has(positive_field):
			if not _is_integer_number(candidate[positive_field]) or int(candidate[positive_field]) < 1:
				return false
	for timestamp_field: String in ["last_seen_utc", "offline_claimed_utc"]:
		if candidate.has(timestamp_field):
			if not _is_integer_number(candidate[timestamp_field]) or int(candidate[timestamp_field]) < 0:
				return false
	return true


func migrate(save_data: Dictionary) -> Dictionary:
	var version: int = int(save_data.get("schema_version", -1))
	if version == SCHEMA_VERSION:
		return _with_defaults(save_data)
	if version == 1:
		var migrated: Dictionary = _with_defaults(save_data)
		if migrated["gold"] is int or migrated["gold"] is float:
			migrated["gold"] = BigNumber.from_float(float(migrated["gold"])).to_dict()
		migrated["schema_version"] = SCHEMA_VERSION
		return migrated
	push_error("SaveManager.migrate: unsupported schema version %d" % version)
	return default_data()


func default_data() -> Dictionary:
	var now_utc: int = int(Time.get_unix_time_from_system())
	return {
		"schema_version": SCHEMA_VERSION,
		"gold": BigNumber.from_float(0.0).to_dict(),
		"stage": 1,
		"max_stage": 1,
		"tap_level": 1,
		"last_seen_utc": now_utc,
		"offline_claimed_utc": 0,
	}


func claim_offline(now_utc: int) -> Dictionary:
	if data.is_empty():
		data = self.load()
	var last_seen: int = int(data.get("last_seen_utc", now_utc))
	var already_claimed: int = int(data.get("offline_claimed_utc", 0))
	if now_utc < last_seen or already_claimed >= last_seen:
		return {"seconds": 0, "granted": false}

	var elapsed: int = mini(now_utc - last_seen, MAX_OFFLINE_SECONDS)
	if elapsed <= 0:
		return {"seconds": 0, "granted": false}

	data["offline_claimed_utc"] = now_utc
	if not save(data):
		data["offline_claimed_utc"] = already_claimed
		return {"seconds": 0, "granted": false}
	return {"seconds": elapsed, "granted": true}


func _with_defaults(save_data: Dictionary) -> Dictionary:
	var complete: Dictionary = default_data()
	for key: Variant in save_data:
		complete[key] = save_data[key]
	return complete


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
