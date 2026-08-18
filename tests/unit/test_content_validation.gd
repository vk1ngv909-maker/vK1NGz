extends SceneTree

const ValidatorLogic = preload("res://autoload/content_validator.gd")

var failed: int = 0
var baseline: Dictionary = {}
var validator: Node


func _init() -> void:
	validator = ValidatorLogic.new()
	baseline = _load_dataset()
	_check(validator.validate_dataset(baseline.duplicate(true)), "authored content validates")
	_run_rejection_fixtures()
	validator.free()
	print("CONTENT VALIDATION: FAIL %d" % failed if failed > 0 else "CONTENT VALIDATION: all passed")
	quit(1 if failed > 0 else 0)


func _run_rejection_fixtures() -> void:
	_reject("duplicate ids", func(d: Dictionary) -> void: d.worlds.entries.append(d.worlds.entries[0].duplicate(true)), "id")
	_reject("missing field", func(d: Dictionary) -> void: d.worlds.entries[0].erase("name_key"), "name_key")
	_reject("unknown field", func(d: Dictionary) -> void: d.worlds.entries[0]["future_field"] = true, "future_field")
	_reject("wrong type", func(d: Dictionary) -> void: d.worlds.entries[0]["stage_from"] = "one", "stage_from")
	_reject("out of range", func(d: Dictionary) -> void: d.support_heroes.entries[0]["base_cost"] = 0, "base_cost")
	_reject_missing_locale("en")
	_reject_missing_locale("ar")
	_reject("invalid asset", func(d: Dictionary) -> void: d.enemies.entries[0]["asset_ref"] = "res://missing.png", "asset_ref")
	_reject("invalid stage range", func(d: Dictionary) -> void: d.worlds.entries[0]["stage_to"] = 0, "stage")
	_reject("overlapping worlds", func(d: Dictionary) -> void: d.worlds.entries[1]["stage_from"] = 30, "stage_from")
	_reject("world gap", func(d: Dictionary) -> void: d.worlds.entries[1]["stage_from"] = 35, "stage_from")
	_reject("unknown world reference", func(d: Dictionary) -> void: d.enemies.entries[0]["world_id"] = "missing", "world_id")
	_reject("unknown enemy reference", func(d: Dictionary) -> void: d.worlds.entries[0]["enemy_pool"] = ["missing"], "enemy_pool")
	_reject("unknown boss reference", func(d: Dictionary) -> void: d.worlds.entries[0]["boss_ids"] = ["missing"], "boss_ids")
	_reject("unknown skill reference", func(d: Dictionary) -> void: d.reward_tables.entries[0]["skill_ids"] = ["missing"], "skill_ids")
	_reject("unknown relic reference", func(d: Dictionary) -> void: d.reward_tables.entries[0]["relic_ids"] = ["missing"], "relic_ids")
	_reject("unknown item reference", func(d: Dictionary) -> void: d.reward_tables.entries[0]["item_ids"] = ["missing"], "item_ids")
	_reject("unknown reward table reference", func(d: Dictionary) -> void: d.bosses.entries[0]["reward_table_id"] = "missing", "reward_table_id")
	_reject("boss on non-boss stage", func(d: Dictionary) -> void: d.bosses.entries[0]["stage"] = 11, "stage")
	_reject("enemy outside world", func(d: Dictionary) -> void: d.enemies.entries[0]["stage_to"] = 34, "stage")
	_reject("invalid hp modifier", func(d: Dictionary) -> void: d.enemies.entries[0]["hp_modifier"] = 0, "hp_modifier")
	_reject("invalid gold modifier", func(d: Dictionary) -> void: d.enemies.entries[0]["gold_modifier"] = -1, "gold_modifier")
	_reject("zero cost", func(d: Dictionary) -> void: d.relics.entries[0]["cost"] = 0, "cost")
	_reject("negative cost", func(d: Dictionary) -> void: d.support_heroes.entries[0]["base_cost"] = -1, "base_cost")
	_reject("cooldown not greater than duration", func(d: Dictionary) -> void: d.skills.entries[0]["cooldown"] = d.skills.entries[0]["duration"], "cooldown")
	_reject("unsafe relic scaling", func(d: Dictionary) -> void: d.relics.entries[0]["growth"] = 1.0, "growth")
	_reject("invalid equipment slot", func(d: Dictionary) -> void: d.equipment.entries[0]["slot"] = "boots", "slot")
	_reject("decreasing rarity unlock stages", func(d: Dictionary) -> void: d.equipment.entries[3]["unlock_stage"] = 1, "unlock_stage")
	_reject("locked reward item", func(d: Dictionary) -> void: d.reward_tables.entries[0]["item_ids"] = ["blade_of_high_noon"], "item_ids")
	_reject("empty reward table", func(d: Dictionary) -> void: d.reward_tables.entries[0]["eligible_rarities"] = [], "eligible_rarities")
	_reject("negative weight", func(d: Dictionary) -> void: d.reward_tables.entries[0]["drop_weights"]["common"] = -1, "drop_weights")
	_reject("zero total weight", func(d: Dictionary) -> void: d.reward_tables.entries[0]["drop_weights"] = {"common": 0}, "drop_weights")
	_reject("NaN weight", func(d: Dictionary) -> void: d.reward_tables.entries[0]["drop_weights"]["common"] = NAN, "drop_weights")
	_reject("INF weight", func(d: Dictionary) -> void: d.reward_tables.entries[0]["drop_weights"]["common"] = INF, "drop_weights")
	_reject("extreme weight", func(d: Dictionary) -> void: d.reward_tables.entries[0]["drop_weights"]["common"] = 1_000_001, "drop_weights")
	_reject("newer content schema", func(d: Dictionary) -> void: d.worlds["schema_version"] = 2, "schema_version")


func _reject(label: String, mutate: Callable, expected_field: String) -> void:
	var fixture: Dictionary = baseline.duplicate(true)
	mutate.call(fixture)
	var accepted: bool = validator.validate_dataset(fixture)
	var names_field: bool = false
	for message: String in validator.errors:
		if "field=%s" % expected_field in message or expected_field in message:
			names_field = true
			break
	_check(not accepted and names_field, "%s is rejected with file/id/field" % label)


func _reject_missing_locale(locale: String) -> void:
	var keys: Dictionary = _locale_keys()
	(keys[locale] as Dictionary).erase("world.oasis_frontier.name")
	var accepted: bool = validator.validate_dataset(baseline.duplicate(true), true, keys)
	_check(not accepted and validator.last_error_file != "" and not validator.errors.is_empty(), "missing %s localization is rejected" % locale)


func _load_dataset() -> Dictionary:
	var result: Dictionary = {}
	for type_name: String in validator.CONTENT_PATHS:
		var path: String = str(validator.CONTENT_PATHS[type_name])
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		var entries: Array = (parsed as Dictionary).get("entries", (parsed as Dictionary).get(type_name, [])) if parsed is Dictionary else parsed as Array
		var version: int = int((parsed as Dictionary).get("schema_version", 1)) if parsed is Dictionary else 1
		result[type_name] = {"file": path, "schema_version": version, "entries": entries}
	return result


func _locale_keys() -> Dictionary:
	var result: Dictionary = {"en": {}, "ar": {}}
	for locale: String in result:
		var file: FileAccess = FileAccess.open("res://localization/strings.%s.csv" % locale, FileAccess.READ)
		while not file.eof_reached():
			var line: String = file.get_line()
			var comma: int = line.find(",")
			if comma > 0:
				(result[locale] as Dictionary)[line.substr(0, comma)] = true
		file.close()
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)
