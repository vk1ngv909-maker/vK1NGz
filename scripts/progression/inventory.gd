class_name Inventory
extends RefCounted

const DATA_PATH: String = "res://resources/equipment/equipment.json"
const SLOTS: Array[String] = ["weapon", "head", "outfit", "aura", "companion_charm"]
const STAT_NAMES: Array[String] = ["tap_damage_mult", "dps_mult", "gold_mult", "crit_chance_add"]
const RARITY_SCORE: Dictionary = {"common": 0.0, "rare": 25.0, "epic": 60.0, "legendary": 120.0}
const RARITY_SALVAGE: Dictionary = {"common": 0.4, "rare": 0.55, "epic": 0.75, "legendary": 1.0}
const MAX_OWNED_ITEMS: int = 100

var definitions: Dictionary = {}
var owned_items: Dictionary = {}
var equipped_slots: Dictionary = {}
## Unknown or malformed ownership records are preserved verbatim. They are not
## usable, but a later catalog/migration can recover them instead of a load
## silently destroying player property.
var quarantined: Array = []
var capacity: int = MAX_OWNED_ITEMS
var _next_uid: int = 1

func _init(saved: Dictionary = {}) -> void:
	_load_data()
	if not saved.is_empty():
		from_dict(saved)


## Highest stage the player has reached. Equipment cannot enter the inventory
## before its rarity's unlock_stage, which is what makes "no legendary gear
## before the first Prestige" an enforced invariant rather than an assumption.
var max_stage_reached: int = 1

func acquire(item_id: String, max_stage: int) -> String:
	if not definitions.has(item_id):
		push_warning("Inventory.acquire: unknown item id '%s'" % item_id)
		return ""
	if max_stage < unlock_stage_for(item_id):
		push_warning("Inventory: '%s' is locked until stage %d (reached %d)" % [item_id, unlock_stage_for(item_id), max_stage])
		return ""
	if is_full():
		return ""
	return _insert_owned(item_id)

func load_owned(item_id: String, uid: String = "", saved_flags: Dictionary = {}) -> String:
	## Loading established ownership deliberately has no unlock-stage check.
	if not definitions.has(item_id):
		_quarantine(saved_flags if not saved_flags.is_empty() else {"uid": uid, "item_id": item_id})
		push_warning("Inventory.load_owned: quarantined unknown item id '%s'" % item_id)
		return ""
	if not uid.is_empty() and owned_items.has(uid):
		push_warning("Inventory.load_owned: rejecting duplicate uid '%s'" % uid)
		return ""
	return _insert_owned(item_id, uid, saved_flags)

func migrate_owned(value: Variant) -> String:
	## Legacy migrations receive the same leniency as load_owned().
	if value is String:
		return load_owned(value as String)
	if not value is Dictionary:
		_quarantine(value)
		push_warning("Inventory.migrate_owned: quarantined malformed record")
		return ""
	var item: Dictionary = value as Dictionary
	var item_id: String = str(item.get("item_id", item.get("id", "")))
	if item_id.is_empty():
		_quarantine(item)
		push_warning("Inventory.migrate_owned: quarantined record without item id")
		return ""
	return load_owned(item_id, str(item.get("uid", "")), item)

func debug_add(item_id: String) -> String:
	if not is_debug_grant_allowed():
		return ""
	return load_owned(item_id)

func is_debug_grant_allowed() -> bool:
	## This explicit release-build guard is kept separate so export tests can
	## assert that debug inventory grants are unreachable.
	return OS.is_debug_build() and _has_debug_grant_flag()

func add(item_id: String) -> String:
	## Compatibility for existing gameplay/UI callers. New acquisition code must
	## pass its explicit progression boundary to acquire().
	return acquire(item_id, max_stage_reached)

func is_full() -> bool:
	return owned_items.size() >= maxi(0, capacity)

func owns_item(item_id: String) -> bool:
	for owned_value: Variant in owned_items.values():
		if str((owned_value as Dictionary).get("item_id", "")) == item_id:
			return true
	return false

func _insert_owned(item_id: String, requested_uid: String = "", flags: Dictionary = {}) -> String:
	var uid: String = requested_uid
	if uid.is_empty():
		uid = "owned_%d" % _next_uid
		while owned_items.has(uid):
			_next_uid += 1
			uid = "owned_%d" % _next_uid
		_next_uid += 1
	owned_items[uid] = {
		"uid": uid,
		"item_id": item_id,
		"locked": bool(flags.get("locked", false)),
		"favorite": bool(flags.get("favorite", false)),
		"equipped": false,
	}
	return uid

func unlock_stage_for(item_id: String) -> int:
	var def: Variant = definitions.get(item_id)
	if def is Dictionary:
		return int((def as Dictionary).get("unlock_stage", 1))
	return 1

func is_unlocked(item_id: String) -> bool:
	if not definitions.has(item_id):
		return false
	return max_stage_reached >= unlock_stage_for(item_id)

func remove(uid: String) -> bool:
	if not owned_items.has(uid):
		return false
	var owned: Dictionary = owned_items[uid]
	if bool(owned.get("equipped", false)):
		var definition: Dictionary = definitions.get(str(owned.get("item_id", "")), {})
		var slot: String = str(definition.get("slot", ""))
		if equipped_slots.get(slot, "") == uid:
			equipped_slots.erase(slot)
	owned_items.erase(uid)
	return true

func equip(uid: String) -> bool:
	if not owned_items.has(uid):
		return false
	var owned: Dictionary = owned_items[uid]
	var definition: Dictionary = definitions.get(str(owned.get("item_id", "")), {})
	var slot: String = str(definition.get("slot", ""))
	if slot not in SLOTS:
		return false
	var previous_uid: String = str(equipped_slots.get(slot, ""))
	if not previous_uid.is_empty() and owned_items.has(previous_uid):
		(owned_items[previous_uid] as Dictionary)["equipped"] = false
	equipped_slots[slot] = uid
	owned["equipped"] = true
	return true

func unequip(slot: String) -> bool:
	if slot not in SLOTS or not equipped_slots.has(slot):
		return false
	var uid: String = str(equipped_slots[slot])
	if owned_items.has(uid):
		(owned_items[uid] as Dictionary)["equipped"] = false
	equipped_slots.erase(slot)
	return true

func score(uid: String) -> float:
	var definition: Dictionary = _definition_for_uid(uid)
	if definition.is_empty():
		return 0.0
	var stats: Dictionary = definition["stats"]
	var stat_score: float = 0.0
	stat_score += float(stats["tap_damage_mult"]) * 100.0
	stat_score += float(stats["dps_mult"]) * 100.0
	stat_score += float(stats["gold_mult"]) * 80.0
	stat_score += float(stats["crit_chance_add"]) * 200.0
	return float(definition["item_level"]) * 10.0 + float(RARITY_SCORE[definition["rarity"]]) + stat_score

func compare(uid: String) -> Dictionary:
	var definition: Dictionary = _definition_for_uid(uid)
	if definition.is_empty():
		return {}
	var slot: String = str(definition["slot"])
	var equipped_uid: String = str(equipped_slots.get(slot, ""))
	var equipped_definition: Dictionary = _definition_for_uid(equipped_uid)
	var delta: Dictionary = {}
	for stat: String in STAT_NAMES:
		var equipped_value: float = 0.0
		if not equipped_definition.is_empty():
			equipped_value = float((equipped_definition["stats"] as Dictionary)[stat])
		delta[stat] = float((definition["stats"] as Dictionary)[stat]) - equipped_value
	var score_delta: float = score(uid) - score(equipped_uid)
	return {
		"slot": slot,
		"equipped_uid": equipped_uid,
		"delta": delta,
		"score_delta": score_delta,
		"is_upgrade": equipped_uid.is_empty() or score_delta > 0.0,
	}

func auto_equip(uid: String) -> bool:
	var comparison: Dictionary = compare(uid)
	if comparison.is_empty() or not bool(comparison["is_upgrade"]):
		return false
	return equip(uid)

func set_locked(uid: String, value: bool) -> bool:
	if not owned_items.has(uid):
		return false
	(owned_items[uid] as Dictionary)["locked"] = value
	return true

func set_favorite(uid: String, value: bool) -> bool:
	if not owned_items.has(uid):
		return false
	(owned_items[uid] as Dictionary)["favorite"] = value
	return true

func is_locked(uid: String) -> bool:
	return owned_items.has(uid) and bool((owned_items[uid] as Dictionary).get("locked", false))

func is_favorite(uid: String) -> bool:
	return owned_items.has(uid) and bool((owned_items[uid] as Dictionary).get("favorite", false))

func is_equipped(uid: String) -> bool:
	return owned_items.has(uid) and bool((owned_items[uid] as Dictionary).get("equipped", false))

func total_stat(name: String) -> float:
	if name not in STAT_NAMES:
		return 0.0
	var total: float = 0.0
	for uid_value: Variant in equipped_slots.values():
		var definition: Dictionary = _definition_for_uid(str(uid_value))
		if not definition.is_empty():
			total += float((definition["stats"] as Dictionary)[name])
	return total

func salvage(uid: String, confirmed_rarity: bool = false, confirmed_favorite: bool = false) -> Dictionary:
	var refusal: Dictionary = _salvage_refusal(uid, confirmed_rarity, confirmed_favorite)
	if not refusal.is_empty():
		return refusal
	var definition: Dictionary = _definition_for_uid(uid)
	var gold_awarded: float = maxf(1.0, floor(score(uid) * float(RARITY_SALVAGE[definition["rarity"]])))
	# No mutation occurs before every guard and the award have been calculated.
	owned_items.erase(uid)
	return {"ok": true, "reason": "", "gold_awarded": gold_awarded, "needs": []}

func salvage_refusal_preview(uid: String) -> Dictionary:
	## Pure preview used by every caller that needs to explain salvage safety.
	## It deliberately reports every confirmation warning, while hard refusals
	## use exactly the same precedence as salvage().
	if not owned_items.has(uid):
		return {"ok": false, "reason": "unknown", "needs": []}
	var owned: Dictionary = owned_items[uid]
	# Locked wins when malformed/legacy data says the item is both states.
	if bool(owned.get("locked", false)):
		return {"ok": false, "reason": "locked", "needs": []}
	if bool(owned.get("equipped", false)):
		return {"ok": false, "reason": "equipped", "needs": []}
	var definition: Dictionary = _definition_for_uid(uid)
	var needs: Array[String] = []
	if str(definition.get("rarity", "common")) != "common":
		needs.append("rarity")
	if bool(owned.get("favorite", false)):
		needs.append("favorite")
	return {"ok": true, "reason": "", "needs": needs}

func salvage_batch(uids: Array, confirmed_rarity: bool, confirmed_favorite: bool) -> Dictionary:
	var results: Dictionary = {}
	var total: float = 0.0
	for uid_value: Variant in uids:
		var uid: String = str(uid_value)
		var result: Dictionary = salvage(uid, confirmed_rarity, confirmed_favorite)
		results[uid] = result
		if bool(result["ok"]):
			total += float(result["gold_awarded"])
	return {"results": results, "total": total, "gold_awarded": total}

func to_dict() -> Dictionary:
	var serialized_items: Array = []
	var owned_by_uid: Dictionary = {}
	for uid_value: Variant in owned_items:
		var serialized: Dictionary = (owned_items[uid_value] as Dictionary).duplicate(true)
		serialized_items.append(serialized)
		owned_by_uid[str(uid_value)] = serialized.duplicate(true)
	return {
		"owned_items": serialized_items,
		# Compatibility view for v1/v2 migrations and older callers. from_dict()
		# reads owned_items first, so this does not duplicate ownership on reload.
		"owned": owned_by_uid,
		"equipped_slots": equipped_slots.duplicate(true),
		"next_uid": _next_uid,
		"quarantined": quarantined.duplicate(true),
	}

func from_dict(saved: Dictionary) -> void:
	owned_items.clear()
	equipped_slots.clear()
	quarantined.clear()
	_next_uid = maxi(1, int(saved.get("next_uid", 1)))
	var saved_quarantine: Variant = saved.get("quarantined", [])
	if saved_quarantine is Array:
		quarantined = (saved_quarantine as Array).duplicate(true)
	var serialized: Variant = saved.get("owned_items", saved.get("owned", []))
	if serialized is Dictionary:
		var migrated_records: Array = []
		for legacy_uid: Variant in serialized:
			var legacy_value: Variant = (serialized as Dictionary)[legacy_uid]
			if legacy_value is Dictionary:
				var record: Dictionary = (legacy_value as Dictionary).duplicate(true)
				record["uid"] = str(record.get("uid", legacy_uid))
				migrated_records.append(record)
			else:
				migrated_records.append(legacy_value)
		serialized = migrated_records
	if not serialized is Array:
		_quarantine(serialized)
		push_warning("Inventory: quarantined malformed owned-items save data")
		return
	var legacy_equipped_uids: Array[String] = []
	for value: Variant in serialized as Array:
		var loaded_uid: String = migrate_owned(value)
		if value is Dictionary and bool((value as Dictionary).get("equipped", false)) and not loaded_uid.is_empty():
			legacy_equipped_uids.append(loaded_uid)
	var saved_slots: Variant = saved.get("equipped_slots", saved.get("equipped", {}))
	if not saved_slots is Dictionary:
		push_warning("Inventory: ignoring malformed equipped-slots save data")
		saved_slots = {}
	for slot_value: Variant in saved_slots:
		var slot: String = str(slot_value)
		var uid: String = str((saved_slots as Dictionary)[slot_value])
		if slot in SLOTS and owned_items.has(uid):
			var definition: Dictionary = _definition_for_uid(uid)
			if str(definition.get("slot", "")) == slot:
				equipped_slots[slot] = uid
	for uid: String in legacy_equipped_uids:
		var definition: Dictionary = _definition_for_uid(uid)
		var slot: String = str(definition.get("slot", ""))
		if slot in SLOTS and not equipped_slots.has(slot):
			equipped_slots[slot] = uid
	for uid_value: Variant in owned_items:
		(owned_items[uid_value] as Dictionary)["equipped"] = equipped_slots.values().has(str(uid_value))

func _salvage_refusal(uid: String, confirmed_rarity: bool, confirmed_favorite: bool) -> Dictionary:
	var preview: Dictionary = salvage_refusal_preview(uid)
	if not bool(preview.get("ok", false)):
		return {"ok": false, "reason": str(preview.get("reason", "unknown")), "gold_awarded": 0.0, "needs": []}
	var needs: Array = preview.get("needs", [])
	if needs.has("rarity") and not confirmed_rarity:
		return {"ok": false, "reason": "needs_confirmation", "gold_awarded": 0.0, "needs": ["rarity"]}
	if needs.has("favorite") and not confirmed_favorite:
		return {"ok": false, "reason": "needs_confirmation", "gold_awarded": 0.0, "needs": ["favorite"]}
	return {}

func _definition_for_uid(uid: String) -> Dictionary:
	if not owned_items.has(uid):
		return {}
	return definitions.get(str((owned_items[uid] as Dictionary).get("item_id", "")), {})

func _quarantine(value: Variant) -> void:
	quarantined.append(value.duplicate(true) if value is Dictionary or value is Array else value)

func _has_debug_grant_flag() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args.has("--debug-grant")

func _load_data() -> void:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Inventory: cannot read %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var values: Variant = (parsed as Dictionary).get("equipment") if parsed is Dictionary else parsed
	if not values is Array:
		push_error("Inventory: invalid data at %s" % DATA_PATH)
		return
	for value: Variant in values as Array:
		if _valid_definition(value):
			var definition: Dictionary = (value as Dictionary).duplicate(true)
			var id: String = str(definition["id"])
			if definitions.has(id):
				push_error("Inventory: duplicate equipment id '%s'" % id)
			else:
				definitions[id] = definition

func _valid_definition(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var item: Dictionary = value as Dictionary
	for field: String in ["id", "name_key", "desc_key", "slot", "rarity", "item_level", "stats", "icon_ref"]:
		if not item.has(field):
			return false
	if str(item["id"]).is_empty() or str(item["slot"]) not in SLOTS or not RARITY_SCORE.has(str(item["rarity"])):
		return false
	var item_level: Variant = item["item_level"]
	if not (item_level is int or item_level is float) or not is_finite(float(item_level)):
		return false
	if float(item_level) != floor(float(item_level)) or int(item_level) < 1 or not item["stats"] is Dictionary:
		return false
	for stat: String in STAT_NAMES:
		var stat_value: Variant = (item["stats"] as Dictionary).get(stat)
		if not (stat_value is int or stat_value is float) or not is_finite(float(stat_value)):
			return false
	return true
