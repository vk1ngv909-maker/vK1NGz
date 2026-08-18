extends Node

const SUPPORTED_SCHEMA_VERSION: int = 1
const SCHEMA_PATH: String = "res://resources/schemas/content_schema.json"
const CONTENT_PATHS: Dictionary = {
	"worlds": "res://resources/worlds/worlds.json",
	"enemies": "res://resources/enemies/enemies.json",
	"bosses": "res://resources/bosses/bosses.json",
	"support_heroes": "res://resources/heroes/support_heroes.json",
	"skills": "res://resources/skills/skills.json",
	"relics": "res://resources/relics/relics.json",
	"equipment": "res://resources/equipment/equipment.json",
	"reward_tables": "res://resources/rewards/reward_tables.json",
}
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "head", "outfit", "aura", "companion_charm"]
const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]
const MAX_WEIGHT: float = 1_000_000.0
const EnemyBossValidator = preload("res://scripts/progression/enemy_boss_validator.gd")

var content_invalid: bool = false
var errors: Array[String] = []
var last_error_file: String = ""
var last_error_id: String = ""
var last_error_field: String = ""
var schema: Dictionary = {}


func _ready() -> void:
	if OS.is_debug_build():
		validate_all()


func validate_all(path_overrides: Dictionary = {}) -> bool:
	_reset()
	schema = _read_json(SCHEMA_PATH) as Dictionary
	if schema.is_empty() or int(schema.get("schema_version", 0)) > SUPPORTED_SCHEMA_VERSION:
		_reject(SCHEMA_PATH, "<schema>", "schema_version", "missing or newer than supported")
		return false
	var dataset: Dictionary = {}
	for type_name: String in CONTENT_PATHS:
		var path: String = str(path_overrides.get(type_name, CONTENT_PATHS[type_name]))
		var parsed: Variant = _read_json(path)
		if parsed == null:
			_reject(path, "<file>", "<json>", "missing or invalid JSON")
			dataset[type_name] = {"file": path, "schema_version": 0, "entries": []}
			continue
		var version: int = 1
		var entries: Variant = parsed
		if parsed is Dictionary:
			version = int((parsed as Dictionary).get("schema_version", 0))
			entries = (parsed as Dictionary).get("entries", (parsed as Dictionary).get(type_name))
		if version > SUPPORTED_SCHEMA_VERSION:
			_reject(path, "<file>", "schema_version", "newer than supported")
		if not entries is Array:
			_reject(path, "<file>", "entries", "must be an array")
			entries = []
		dataset[type_name] = {"file": path, "schema_version": version, "entries": entries}
	return validate_dataset(dataset, false)


func validate_dataset(dataset: Dictionary, reset_first: bool = true, localization: Dictionary = {}) -> bool:
	if reset_first:
		_reset()
	if schema.is_empty():
		var loaded: Variant = _read_json(SCHEMA_PATH)
		if loaded is Dictionary:
			schema = loaded as Dictionary
	var catalogs: Dictionary = {}
	for type_name: String in CONTENT_PATHS:
		var packet: Dictionary = dataset.get(type_name, {"file": str(CONTENT_PATHS[type_name]), "schema_version": 1, "entries": []})
		var path: String = str(packet.get("file", CONTENT_PATHS[type_name]))
		var version: int = int(packet.get("schema_version", 1))
		if version > SUPPORTED_SCHEMA_VERSION:
			_reject(path, "<file>", "schema_version", "newer than supported")
		var entries: Variant = packet.get("entries", [])
		if not entries is Array:
			_reject(path, "<file>", "entries", "must be an array")
			continue
		var ids: Dictionary = {}
		for index: int in (entries as Array).size():
			var entry_value: Variant = (entries as Array)[index]
			var fallback_id: String = "<entry:%d>" % index
			if not entry_value is Dictionary:
				_reject(path, fallback_id, "<entry>", "must be a dictionary")
				continue
			var entry: Dictionary = entry_value as Dictionary
			var entry_id: String = str(entry.get("id", fallback_id))
			if ids.has(entry_id):
				_reject(path, entry_id, "id", "duplicate id")
			else:
				ids[entry_id] = entry
			_validate_shape(type_name, path, entry_id, entry)
		catalogs[type_name] = ids
	var locale_keys: Dictionary = localization if not localization.is_empty() else _load_locale_keys()
	_validate_localization(dataset, locale_keys)
	_validate_worlds(dataset, catalogs)
	_validate_references(dataset, catalogs)
	_validate_rules(dataset, catalogs)
	return not content_invalid


func _validate_shape(type_name: String, path: String, entry_id: String, entry: Dictionary) -> void:
	var type_schema: Dictionary = (schema.get("types", {}) as Dictionary).get(type_name, {})
	var required: Array = type_schema.get("required", [])
	var properties: Dictionary = type_schema.get("properties", {})
	for field_value: Variant in required:
		var field: String = str(field_value)
		if not entry.has(field):
			_reject(path, entry_id, field, "missing required field")
	for field_value: Variant in entry:
		var field: String = str(field_value)
		if not properties.has(field):
			_reject(path, entry_id, field, "unknown field")
			continue
		_validate_content_property(path, entry_id, field, entry[field_value], properties[field] as Dictionary)


func _validate_content_property(path: String, entry_id: String, field: String, value: Variant, rule: Dictionary) -> void:
	var expected: String = str(rule.get("type", "variant"))
	var correct: bool = true
	match expected:
		"string", "asset_ref": correct = value is String and not str(value).is_empty()
		"integer": correct = value is int or (value is float and is_finite(float(value)) and float(value) == floor(float(value)))
		"number": correct = (value is int or value is float) and is_finite(float(value))
		"array": correct = value is Array
		"dictionary": correct = value is Dictionary
	if not correct:
		_reject(path, entry_id, field, "wrong type; expected %s" % expected)
		return
	if expected in ["integer", "number"]:
		var number: float = float(value)
		if rule.has("minimum") and number < float(rule["minimum"]):
			_reject(path, entry_id, field, "out of range")
		if rule.has("exclusive_minimum") and number <= float(rule["exclusive_minimum"]):
			_reject(path, entry_id, field, "out of range")
		if rule.has("maximum") and number > float(rule["maximum"]):
			_reject(path, entry_id, field, "out of range")
	if expected == "asset_ref" and not _valid_asset_ref(str(value)):
		_reject(path, entry_id, field, "missing or invalid asset reference")


func _validate_localization(dataset: Dictionary, locale_keys: Dictionary) -> void:
	for type_name: String in dataset:
		var packet: Dictionary = dataset[type_name]
		var path: String = str(packet.get("file", type_name))
		for entry_value: Variant in packet.get("entries", []):
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value as Dictionary
			var entry_id: String = str(entry.get("id", "<entry>"))
			for field_value: Variant in entry:
				var field: String = str(field_value)
				if not field.ends_with("_key"):
					continue
				var key: String = str(entry[field_value])
				for locale: String in ["en", "ar"]:
					if not (locale_keys.get(locale, {}) as Dictionary).has(key):
						_reject(path, entry_id, field, "missing %s localization key '%s'" % [locale, key])


func _validate_worlds(dataset: Dictionary, catalogs: Dictionary) -> void:
	var packet: Dictionary = dataset.get("worlds", {})
	var path: String = str(packet.get("file", CONTENT_PATHS.worlds))
	var worlds: Array = packet.get("entries", []).duplicate()
	worlds.sort_custom(func(a: Variant, b: Variant) -> bool: return int((a as Dictionary).get("stage_from", 0)) < int((b as Dictionary).get("stage_from", 0)))
	var expected_stage: int = 1
	for value: Variant in worlds:
		if not value is Dictionary:
			continue
		var world: Dictionary = value as Dictionary
		var entry_id: String = str(world.get("id", "<entry>"))
		var stage_from: int = int(world.get("stage_from", 0))
		var stage_to: int = int(world.get("stage_to", 0))
		if stage_from > stage_to:
			_reject(path, entry_id, "stage_from", "invalid stage range")
		if stage_from < expected_stage:
			_reject(path, entry_id, "stage_from", "overlapping world range")
		elif stage_from > expected_stage:
			_reject(path, entry_id, "stage_from", "gap between world ranges")
		expected_stage = maxi(expected_stage, stage_to + 1)
		_validate_world_nested(path, entry_id, world)
	if (catalogs.get("worlds", {}) as Dictionary).is_empty():
		_reject(path, "<file>", "entries", "world table is empty")


func _validate_world_nested(path: String, entry_id: String, world: Dictionary) -> void:
	var palette: Variant = world.get("palette")
	if palette is Dictionary:
		for field: String in ["sky", "sand", "accent"]:
			if not (palette as Dictionary).has(field) or not Color.html_is_valid(str((palette as Dictionary).get(field, ""))):
				_reject(path, entry_id, "palette.%s" % field, "missing or invalid color")
	var transition: Variant = world.get("transition")
	if transition is Dictionary:
		var fade: Variant = (transition as Dictionary).get("fade_seconds")
		if not (fade is int or fade is float) or not is_finite(float(fade)) or float(fade) < 0.0 or float(fade) > 10.0:
			_reject(path, entry_id, "transition.fade_seconds", "out of range")
	var layers: Variant = world.get("background_layers")
	if layers is Array:
		for layer: Variant in layers as Array:
			if not layer is String or "PLACEHOLDER" not in str(layer):
				_reject(path, entry_id, "background_layers", "unlabelled placeholder asset")


func _validate_references(dataset: Dictionary, catalogs: Dictionary) -> void:
	var singular: Dictionary = {"world":"worlds", "enemy":"enemies", "boss":"bosses", "skill":"skills", "relic":"relics", "item":"equipment", "reward_table":"reward_tables"}
	for type_name: String in dataset:
		var packet: Dictionary = dataset[type_name]
		var path: String = str(packet.get("file", type_name))
		var properties: Dictionary = (((schema.get("types", {}) as Dictionary).get(type_name, {}) as Dictionary).get("properties", {}))
		for entry_value: Variant in packet.get("entries", []):
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value as Dictionary
			var entry_id: String = str(entry.get("id", "<entry>"))
			for field_value: Variant in properties:
				var field: String = str(field_value)
				var reference: String = str((properties[field] as Dictionary).get("reference", ""))
				if reference.is_empty() or not entry.has(field):
					continue
				var target: Dictionary = catalogs.get(singular.get(reference, ""), {})
				var refs: Array = entry[field] if entry[field] is Array else [entry[field]]
				for ref: Variant in refs:
					if type_name == "reward_tables" and field == "boss_id" and str(ref) == "any":
						continue
					if not target.has(str(ref)):
						_reject(path, entry_id, field, "unknown %s reference '%s'" % [reference, str(ref)])


func _validate_rules(dataset: Dictionary, catalogs: Dictionary) -> void:
	_validate_enemy_and_boss_rules(dataset, catalogs)
	_validate_skill_rules(dataset)
	_validate_relic_rules(dataset)
	_validate_equipment_rules(dataset)
	_validate_reward_rules(dataset)


func _validate_enemy_and_boss_rules(dataset: Dictionary, catalogs: Dictionary) -> void:
	for issue: Dictionary in EnemyBossValidator.validate(dataset, catalogs):
		_reject(str(issue.path), str(issue.id), str(issue.field), str(issue.reason))


func validate_first_clear_keys(first_clears: Dictionary, archetype_ids: Array = []) -> bool:
	var issues: Array[Dictionary] = EnemyBossValidator.validate_first_clear_keys(first_clears, archetype_ids)
	for issue: Dictionary in issues:
		_reject(str(issue.path), str(issue.id), str(issue.field), str(issue.reason))
	return issues.is_empty()


func validate_encounter_ids(encounter_ids: Array) -> bool:
	var issues: Array[Dictionary] = EnemyBossValidator.validate_encounter_ids(encounter_ids)
	for issue: Dictionary in issues:
		_reject(str(issue.path), str(issue.id), str(issue.field), str(issue.reason))
	return issues.is_empty()


func _validate_skill_rules(dataset: Dictionary) -> void:
	var packet: Dictionary = dataset.get("skills", {})
	var path: String = str(packet.get("file", "skills"))
	for value: Variant in packet.get("entries", []):
		if value is Dictionary:
			var skill: Dictionary = value as Dictionary
			if float(skill.get("cooldown", 0.0)) <= float(skill.get("duration", 0.0)):
				_reject(path, str(skill.get("id", "<entry>")), "cooldown", "must be greater than duration")


func _validate_relic_rules(dataset: Dictionary) -> void:
	var packet: Dictionary = dataset.get("relics", {})
	var path: String = str(packet.get("file", "relics"))
	for value: Variant in packet.get("entries", []):
		if value is Dictionary:
			var relic: Dictionary = value as Dictionary
			var total_scale: float = float(relic.get("base_effect", 0.0)) + float(relic.get("growth", 0.0)) * float(relic.get("max_level", 0))
			if not is_finite(total_scale) or total_scale > 20.0:
				_reject(path, str(relic.get("id", "<entry>")), "growth", "unsafe relic scaling")
			if float(relic.get("cost", 0.0)) <= 0.0:
				_reject(path, str(relic.get("id", "<entry>")), "cost", "cost must be positive")


func _validate_equipment_rules(dataset: Dictionary) -> void:
	var packet: Dictionary = dataset.get("equipment", {})
	var path: String = str(packet.get("file", "equipment"))
	var first_unlock: Dictionary = {}
	for value: Variant in packet.get("entries", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var entry_id: String = str(item.get("id", "<entry>"))
		var slot: String = str(item.get("slot", ""))
		if slot not in EQUIPMENT_SLOTS:
			_reject(path, entry_id, "slot", "invalid equipment slot")
		var rarity: String = str(item.get("rarity", ""))
		if rarity not in RARITIES:
			_reject(path, entry_id, "rarity", "invalid rarity")
		else:
			var unlock: int = int(item.get("unlock_stage", 0))
			first_unlock[rarity] = mini(int(first_unlock.get(rarity, unlock)), unlock)
	var previous: int = 0
	for rarity: String in RARITIES:
		if first_unlock.has(rarity):
			if int(first_unlock[rarity]) < previous:
				_reject(path, rarity, "unlock_stage", "decreasing rarity unlock stages")
			previous = int(first_unlock[rarity])


func _validate_reward_rules(dataset: Dictionary) -> void:
	var packet: Dictionary = dataset.get("reward_tables", {})
	var path: String = str(packet.get("file", "reward_tables"))
	for value: Variant in packet.get("entries", []):
		if not value is Dictionary:
			continue
		var table: Dictionary = value as Dictionary
		var entry_id: String = str(table.get("id", "<entry>"))
		var rarities: Variant = table.get("eligible_rarities", [])
		if not rarities is Array or (rarities as Array).is_empty():
			_reject(path, entry_id, "eligible_rarities", "empty reward table")
		var equipment_packet: Dictionary = dataset.get("equipment", {})
		for item_id: Variant in table.get("item_ids", []):
			for item_value: Variant in equipment_packet.get("entries", []):
				if item_value is Dictionary and str((item_value as Dictionary).get("id", "")) == str(item_id):
					if int((item_value as Dictionary).get("unlock_stage", 1)) > int(table.get("min_unlock_stage", 1)):
						_reject(path, entry_id, "item_ids", "reward table could grant a locked rarity")
		for field: String in ["slot_weights", "drop_weights"]:
			var weights: Variant = table.get(field, {})
			if not weights is Dictionary or (weights as Dictionary).is_empty():
				_reject(path, entry_id, field, "empty reward table")
				continue
			var total: float = 0.0
			for key: Variant in weights:
				var weight: Variant = (weights as Dictionary)[key]
				if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight) < 0.0 or float(weight) > MAX_WEIGHT:
					_reject(path, entry_id, "%s.%s" % [field, str(key)], "negative, non-finite, or extreme weight")
				else:
					total += float(weight)
			if not is_finite(total) or total <= 0.0:
				_reject(path, entry_id, field, "zero-total weight")


func _valid_asset_ref(reference: String) -> bool:
	if reference.begins_with("placeholder://"):
		return reference.length() > "placeholder://".length()
	return reference.begins_with("res://") and FileAccess.file_exists(reference)


func _load_locale_keys() -> Dictionary:
	var result: Dictionary = {"en": {}, "ar": {}}
	for locale: String in result:
		var path: String = "res://localization/strings.%s.csv" % locale
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		while not file.eof_reached():
			var line: String = file.get_line()
			var comma: int = line.find(",")
			if comma > 0:
				(result[locale] as Dictionary)[line.substr(0, comma)] = true
		file.close()
	return result


func _read_json(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed


func _reset() -> void:
	content_invalid = false
	errors.clear()
	last_error_file = ""
	last_error_id = ""
	last_error_field = ""


func _reject(path: String, entry_id: String, field: String, reason: String) -> void:
	content_invalid = true
	last_error_file = path
	last_error_id = entry_id
	last_error_field = field
	var message: String = "ContentValidator: file=%s id=%s field=%s: %s" % [path, entry_id, field, reason]
	errors.append(message)
	push_error(message)
