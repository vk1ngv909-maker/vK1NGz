class_name RewardSystem
extends RefCounted

const TABLE_PATH: String = "res://resources/rewards/reward_tables.json"
const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]

var tables: Dictionary = {}
var _seed: int = 0
var _data_valid: bool = true


func _init(seed: int) -> void:
	_seed = seed
	_load_tables()


func roll(table_id: String, max_stage: int, inventory: Inventory) -> Dictionary:
	var refused: Dictionary = _result(false, "", "", "invalid")
	if not _data_valid or not tables.has(table_id) or inventory == null:
		push_error("RewardSystem.roll: invalid table or inventory for '%s'" % table_id)
		return refused
	var table: Dictionary = tables[table_id]
	if not _valid_table(table):
		push_error("RewardSystem.roll: malformed table '%s'" % table_id)
		return refused
	if inventory.is_full():
		return _result(false, "", "", "inventory_full")
	if max_stage < int(table["min_unlock_stage"]):
		return _result(false, "", "", "locked")

	var candidates: Array[Dictionary] = _eligible_items(table, max_stage, inventory)
	if candidates.is_empty():
		var reason: String = "duplicate" if str(table["duplicate_policy"]) == "reroll" else "no_eligible_item"
		return _result(false, "", "", reason)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _roll_seed(table_id, max_stage, inventory)
	var rarity: String = _choose_rarity(table, candidates, rng)
	var slot: String = _choose_slot(table, candidates, rarity, rng)
	var final_candidates: Array[Dictionary] = []
	for definition: Dictionary in candidates:
		if str(definition["rarity"]) == rarity and str(definition["slot"]) == slot:
			final_candidates.append(definition)
	if final_candidates.is_empty():
		push_error("RewardSystem.roll: table '%s' produced an empty selection" % table_id)
		return refused
	final_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	var selected: Dictionary = final_candidates[rng.randi_range(0, final_candidates.size() - 1)]
	return _result(true, str(selected["id"]), str(selected["rarity"]), "")


func table_id_for_boss(boss_stage: int) -> String:
	var fallback: String = ""
	var ids: Array[String] = []
	for id_value: Variant in tables:
		ids.append(str(id_value))
	ids.sort()
	for table_id: String in ids:
		var table: Dictionary = tables[table_id]
		if str(table.get("source", "")) != "boss_first_clear":
			continue
		var boss_id: Variant = table.get("boss_id")
		if (boss_id is int or boss_id is float) and int(boss_id) == boss_stage:
			return table_id
		if str(boss_id) == str(boss_stage):
			return table_id
		if str(boss_id) == "any":
			fallback = table_id
	return fallback


func _eligible_items(table: Dictionary, max_stage: int, inventory: Inventory) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	var rarities: Array = table["eligible_rarities"]
	var reroll_duplicates: bool = str(table["duplicate_policy"]) == "reroll"
	for id_value: Variant in inventory.definitions:
		var definition: Dictionary = inventory.definitions[id_value]
		var item_id: String = str(definition.get("id", ""))
		if str(definition.get("rarity", "")) not in rarities:
			continue
		if int(definition.get("unlock_stage", 1)) > max_stage:
			continue
		if reroll_duplicates and inventory.owns_item(item_id):
			continue
		eligible.append(definition)
	return eligible


func _choose_rarity(table: Dictionary, candidates: Array[Dictionary], rng: RandomNumberGenerator) -> String:
	var available: Dictionary = {}
	for definition: Dictionary in candidates:
		available[str(definition["rarity"])] = true
	var weights: Dictionary = {}
	for rarity: String in RARITIES:
		if available.has(rarity):
			weights[rarity] = float((table["drop_weights"] as Dictionary).get(rarity, 0.0))
	return _weighted_key(weights, rng)


func _choose_slot(table: Dictionary, candidates: Array[Dictionary], rarity: String, rng: RandomNumberGenerator) -> String:
	var available: Dictionary = {}
	for definition: Dictionary in candidates:
		if str(definition["rarity"]) == rarity:
			available[str(definition["slot"])] = true
	var weights: Dictionary = {}
	for slot_value: Variant in available:
		var slot: String = str(slot_value)
		weights[slot] = float((table["slot_weights"] as Dictionary).get(slot, 0.0))
	return _weighted_key(weights, rng)


func _weighted_key(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var keys: Array[String] = []
	var total: float = 0.0
	for key_value: Variant in weights:
		var key: String = str(key_value)
		var weight: float = maxf(0.0, float(weights[key_value]))
		if weight > 0.0:
			keys.append(key)
			total += weight
	keys.sort()
	if keys.is_empty() or total <= 0.0:
		return ""
	var target: float = rng.randf() * total
	var cursor: float = 0.0
	for key: String in keys:
		cursor += float(weights[key])
		if target < cursor:
			return key
	return keys.back()


func _roll_seed(table_id: String, max_stage: int, inventory: Inventory) -> int:
	var owned_ids: Array[String] = []
	for owned_value: Variant in inventory.owned_items.values():
		owned_ids.append(str((owned_value as Dictionary).get("item_id", "")))
	owned_ids.sort()
	var signature: String = "%s|%d|%s" % [table_id, max_stage, ",".join(owned_ids)]
	return _seed ^ signature.hash()


func _load_tables() -> void:
	var file: FileAccess = FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		_data_valid = false
		push_error("RewardSystem: cannot read %s" % TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		_data_valid = false
		push_error("RewardSystem: reward table root must be an array")
		return
	for value: Variant in parsed as Array:
		if not _valid_table(value):
			_data_valid = false
			push_error("RewardSystem: malformed reward table data")
			continue
		var table: Dictionary = (value as Dictionary).duplicate(true)
		var table_id: String = str(table["id"])
		if tables.has(table_id):
			_data_valid = false
			push_error("RewardSystem: duplicate table id '%s'" % table_id)
			continue
		tables[table_id] = table


func _valid_table(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var table: Dictionary = value as Dictionary
	for field: String in ["id", "source", "boss_id", "eligible_rarities", "slot_weights", "drop_weights", "min_unlock_stage", "duplicate_policy"]:
		if not table.has(field):
			return false
	if str(table["id"]).is_empty() or str(table["source"]) != "boss_first_clear":
		return false
	if not table["eligible_rarities"] is Array or not table["slot_weights"] is Dictionary or not table["drop_weights"] is Dictionary:
		return false
	var min_stage: Variant = table["min_unlock_stage"]
	if not (min_stage is int or min_stage is float) or not is_finite(float(min_stage)) or float(min_stage) != floor(float(min_stage)) or int(min_stage) < 1:
		return false
	if str(table["duplicate_policy"]) not in ["allow", "reroll"]:
		return false
	if (table["eligible_rarities"] as Array).is_empty() or (table["slot_weights"] as Dictionary).is_empty():
		return false
	for rarity_value: Variant in table["eligible_rarities"] as Array:
		var rarity: String = str(rarity_value)
		var rarity_weight: Variant = (table["drop_weights"] as Dictionary).get(rarity)
		if rarity not in RARITIES or not (rarity_weight is int or rarity_weight is float):
			return false
		if not is_finite(float(rarity_weight)) or float(rarity_weight) <= 0.0:
			return false
	for slot_value: Variant in table["slot_weights"]:
		if str(slot_value) not in ["weapon", "head", "outfit", "aura", "companion_charm"]:
			return false
		var weight: Variant = (table["slot_weights"] as Dictionary)[slot_value]
		if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight) <= 0.0:
			return false
	if table.has("pity"):
		var pity: Variant = table["pity"]
		if not (pity is int or pity is float) or not is_finite(float(pity)) or float(pity) != floor(float(pity)) or int(pity) < 1:
			return false
	return true


func _result(granted: bool, item_id: String, rarity: String, reason: String) -> Dictionary:
	return {"granted": granted, "item_id": item_id, "rarity": rarity, "reason": reason}
