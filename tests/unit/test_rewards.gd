extends SceneTree

const Inventory = preload("res://scripts/progression/inventory.gd")
const RewardSystem = preload("res://scripts/progression/reward_system.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	_test_determinism_and_unlocks()
	_test_inventory_full_and_duplicates()
	_test_invalid_table()
	_test_first_clear_once_and_reload()
	_test_load_is_lenient_but_acquire_is_gated()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)


func _test_determinism_and_unlocks() -> void:
	var first: Dictionary = RewardSystem.new(12345).roll("boss_first_clear_default", 50, Inventory.new())
	var second: Dictionary = RewardSystem.new(12345).roll("boss_first_clear_default", 50, Inventory.new())
	_check(first == second and bool(first["granted"]), "same seed and inputs return the same item")
	for max_stage: int in range(1, 61):
		var inventory: Inventory = Inventory.new()
		var reward: Dictionary = RewardSystem.new(9000 + max_stage).roll("boss_first_clear_default", max_stage, inventory)
		_check(bool(reward["granted"]), "stage %d has an eligible reward" % max_stage)
		if bool(reward["granted"]):
			var definition: Dictionary = inventory.definitions[str(reward["item_id"])]
			_check(int(definition["unlock_stage"]) <= max_stage, "stage %d never rolls locked equipment" % max_stage)
			_check(str(definition["rarity"]) == str(reward["rarity"]), "reported rarity matches the item")
			_check(str(reward["rarity"]) != "legendary" or max_stage >= 50, "legendary never rolls below stage 50")


func _test_inventory_full_and_duplicates() -> void:
	var full: Inventory = Inventory.new()
	full.capacity = 0
	var refusal: Dictionary = RewardSystem.new(1).roll("boss_first_clear_default", 50, full)
	_check(not bool(refusal["granted"]) and refusal["reason"] == "inventory_full", "full inventory is refused explicitly")

	var inventory: Inventory = Inventory.new()
	for definition_value: Variant in inventory.definitions.values():
		var definition: Dictionary = definition_value
		if str(definition["rarity"]) == "common":
			inventory.load_owned(str(definition["id"]))
	var reroll: RewardSystem = RewardSystem.new(7)
	var no_duplicate: Dictionary = reroll.roll("boss_first_clear_default", 1, inventory)
	_check(not bool(no_duplicate["granted"]) and no_duplicate["reason"] == "duplicate", "reroll policy refuses when every eligible item is owned")
	(reroll.tables["boss_first_clear_default"] as Dictionary)["duplicate_policy"] = "allow"
	var allowed: Dictionary = reroll.roll("boss_first_clear_default", 1, inventory)
	_check(bool(allowed["granted"]) and inventory.owns_item(str(allowed["item_id"])), "allow policy may return an owned item")


func _test_invalid_table() -> void:
	var reward: Dictionary = RewardSystem.new(4).roll("missing_table", 10, Inventory.new())
	_check(not bool(reward["granted"]) and reward["reason"] == "invalid", "unknown table id is invalid")
	var malformed: RewardSystem = RewardSystem.new(4)
	malformed.tables["bad"] = {"id": "bad"}
	reward = malformed.roll("bad", 10, Inventory.new())
	_check(not bool(reward["granted"]) and reward["reason"] == "invalid", "malformed table is invalid")


func _test_first_clear_once_and_reload() -> void:
	var state: CombatState = CombatState.new(10, null, 1, {}, {"max_stage": 10})
	var rewards: RewardSystem = RewardSystem.new(88)
	var first: Dictionary = state.begin_boss_first_clear(10, rewards)
	_check(bool(first.get("granted", false)) and state.inventory.owned_items.size() == 1, "first boss clear grants one item")
	var farmed: Dictionary = state.begin_boss_first_clear(10, rewards)
	_check(not bool(farmed.get("granted", false)) and farmed.get("reason") == "already_cleared", "farming the same boss grants nothing")
	_check(state.inventory.owned_items.size() == 1, "rapid duplicate first-clear call cannot add another item")

	var permanent: Dictionary = {
		"max_stage": state.max_stage_reached,
		"equipment": state.inventory.to_dict(),
		"boss_first_clears": state.boss_first_clears.duplicate(true),
	}
	var reloaded: CombatState = CombatState.new(10, null, 1, {}, permanent)
	var after_reload: Dictionary = reloaded.begin_boss_first_clear(10, RewardSystem.new(88))
	_check(not bool(after_reload.get("granted", false)) and after_reload.get("reason") == "already_cleared", "reload does not re-grant a cleared boss")
	_check(reloaded.inventory.owned_items.size() == 1, "reload preserves the one committed reward")


func _test_load_is_lenient_but_acquire_is_gated() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.max_stage_reached = 1
	_check(inventory.debug_add("blade_of_high_noon").is_empty(), "debug grant requires the explicit command-line flag")
	_check(inventory.acquire("blade_of_high_noon", 1).is_empty(), "acquire refuses legendary equipment at stage 1")
	var uid: String = inventory.load_owned("blade_of_high_noon", "legacy_legendary", {"favorite": true})
	_check(uid == "legacy_legendary" and inventory.owned_items.has(uid), "load_owned preserves established legendary ownership")
	inventory.equip(uid)
	var saved: Dictionary = inventory.to_dict()
	(saved["owned_items"] as Array).append({"uid": "unknown_1", "item_id": "retired_item"})
	var restored: Inventory = Inventory.new(saved)
	_check(restored.owned_items.has(uid) and restored.is_equipped(uid), "equipped link survives lenient load")
	_check(restored.quarantined.size() == 1 and str((restored.quarantined[0] as Dictionary)["item_id"]) == "retired_item", "unknown item is preserved in quarantine")
	_check((restored.to_dict()["quarantined"] as Array).size() == 1, "quarantine survives save serialization")
