extends SceneTree

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")
const Inventory = preload("res://scripts/progression/inventory.gd")
const SaveManagerScript = preload("res://autoload/save_manager.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	_test_catalog_and_owned_uids()
	_test_equip_compare_and_stats()
	_test_safe_salvage_order_and_once()
	_test_batch_salvage()
	_test_persistence_and_bad_data()
	_test_save_manager_and_prestige_shape()
	_test_combat_integration()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)


func _test_catalog_and_owned_uids() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.max_stage_reached = 999
	_check(inventory.definitions.size() == 20, "catalog loads twenty equipment definitions")
	var first: String = inventory.add("dune_knife")
	var second: String = inventory.add("dune_knife")
	_check(not first.is_empty() and first != second, "duplicate item definitions receive unique owned uids")
	_check(inventory.add("missing_item").is_empty(), "unknown item id is not added")
	_check(inventory.remove(first) and not inventory.remove(first), "remove succeeds once for a known uid")


func _test_equip_compare_and_stats() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.max_stage_reached = 999
	var common: String = inventory.add("dune_knife")
	var legendary: String = inventory.add("blade_of_high_noon")
	var head: String = inventory.add("wanderer_wrap")
	_check(inventory.equip(common), "known item equips into its defined slot")
	_check(is_equal_approx(inventory.total_stat("tap_damage_mult"), 0.05), "equipped item contributes its stats")
	var comparison: Dictionary = inventory.compare(legendary)
	_check(comparison["slot"] == "weapon" and comparison["equipped_uid"] == common, "compare selects currently equipped item in the same slot")
	_check(comparison["is_upgrade"] and float(comparison["score_delta"]) > 0.0, "stronger item compares as an upgrade")
	_check(inventory.auto_equip(legendary), "auto equip accepts a strict score upgrade")
	_check(not bool((inventory.owned_items[common] as Dictionary)["equipped"]), "slot replacement clears previous equipped state")
	_check(not inventory.auto_equip(common), "auto equip rejects a lower score")
	_check(inventory.equip(head) and inventory.equipped_slots.size() == 2, "different equipment slots coexist")
	_check(inventory.unequip("weapon") and not inventory.unequip("weapon"), "unequip only succeeds for an occupied valid slot")
	_check(is_equal_approx(inventory.total_stat("not_a_stat"), 0.0), "unknown stat names safely total to zero")


func _test_safe_salvage_order_and_once() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.max_stage_reached = 999
	var common: String = inventory.add("dune_knife")
	var rare: String = inventory.add("sunsteel_sabre")
	_check(inventory.salvage("missing")["reason"] == "unknown", "salvage checks unknown uid first")
	inventory.equip(rare)
	inventory.set_locked(rare, true)
	inventory.set_favorite(rare, true)
	_check(inventory.salvage(rare, true, true)["reason"] == "locked", "locked refusal wins when an item is also equipped")
	inventory.unequip("weapon")
	_check(inventory.salvage(rare, true, true)["reason"] == "locked", "locked refusal precedes confirmations")
	inventory.set_locked(rare, false)
	var rarity_refusal: Dictionary = inventory.salvage(rare)
	_check(rarity_refusal["reason"] == "needs_confirmation" and rarity_refusal["needs"] == ["rarity"], "non-common rarity needs its own confirmation first")
	var favorite_refusal: Dictionary = inventory.salvage(rare, true)
	_check(favorite_refusal["reason"] == "needs_confirmation" and favorite_refusal["needs"] == ["favorite"], "favorite confirmation is checked after rarity")
	var success: Dictionary = inventory.salvage(rare, true, true)
	_check(success["ok"] and float(success["gold_awarded"]) > 0.0, "confirmed safe salvage returns a positive award")
	_check(inventory.salvage(rare, true, true)["reason"] == "unknown", "salvaged uid is gone and cannot award twice")
	inventory.set_favorite(common, true)
	_check(inventory.salvage(common)["reason"] == "needs_confirmation", "common favorite still requires favorite confirmation")
	_check(inventory.owned_items.has(common), "refused salvage never destroys the item")


func _test_batch_salvage() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.max_stage_reached = 999
	var safe: String = inventory.add("dune_knife")
	var locked: String = inventory.add("traveler_robes")
	var rare: String = inventory.add("scarab_circlet")
	inventory.set_locked(locked, true)
	var batch: Dictionary = inventory.salvage_batch([safe, locked, rare], false, false)
	var results: Dictionary = batch["results"]
	_check(results[safe]["ok"] and not inventory.owned_items.has(safe), "batch salvages eligible item")
	_check(results[locked]["reason"] == "locked" and inventory.owned_items.has(locked), "batch preserves locked item")
	_check(results[rare]["reason"] == "needs_confirmation" and inventory.owned_items.has(rare), "batch preserves unconfirmed rare item")
	_check(is_equal_approx(float(batch["total"]), float(results[safe]["gold_awarded"])), "batch total contains successful awards only")


func _test_persistence_and_bad_data() -> void:
	var original: Inventory = Inventory.new()
	original.max_stage_reached = 999
	var weapon: String = original.add("ifrit_fang")
	var charm: String = original.add("falcon_bell")
	original.set_locked(weapon, true)
	original.set_favorite(charm, true)
	original.equip(charm)
	var saved: Dictionary = original.to_dict()
	var restored: Inventory = Inventory.new(saved)
	_check(restored.owned_items.size() == 2 and bool(restored.owned_items[weapon]["locked"]), "round trip preserves owned uid and locked flag")
	_check(bool(restored.owned_items[charm]["favorite"]) and restored.equipped_slots["companion_charm"] == charm, "round trip preserves favorite and equipped slot")
	var corrupt: Dictionary = saved.duplicate(true)
	(corrupt["owned_items"] as Array).append({"uid": weapon, "item_id": "dune_knife"})
	(corrupt["owned_items"] as Array).append({"uid": "bad", "item_id": "removed_from_catalog"})
	(corrupt["owned_items"] as Array).append("malformed")
	var sanitized: Inventory = Inventory.new(corrupt)
	_check(sanitized.owned_items.size() == 2, "unknown, malformed, and duplicate loaded items are dropped")
	_check(sanitized.add("dune_knife") != weapon, "uid sequence remains unique after load")


func _test_save_manager_and_prestige_shape() -> void:
	var manager: Node = SaveManagerScript.new()
	var inventory: Inventory = Inventory.new()
	inventory.max_stage_reached = 999
	var uid: String = inventory.add("crown_of_stars")
	inventory.set_favorite(uid, true)
	var state: Dictionary = manager.default_data()
	state["permanent_state"]["equipment"] = inventory.to_dict()
	var encoded: String = JSON.stringify(state)
	var decoded: Variant = JSON.parse_string(encoded)
	_check(decoded is Dictionary and manager.validate(decoded), "inventory serialization is valid SaveManager permanent data")
	var reopened: Inventory = Inventory.new(decoded["permanent_state"]["equipment"])
	_check(reopened.owned_items.has(uid) and bool(reopened.owned_items[uid]["favorite"]), "save JSON round trip preserves inventory")
	manager.free()


func _test_combat_integration() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.max_stage_reached = 999
	var weapon: String = inventory.add("dune_knife")
	var charm: String = inventory.add("falcon_bell")
	inventory.equip(weapon)
	inventory.equip(charm)
	var state: CombatState = CombatState.new(1, BigNumber.new(), 1, {"support_hero_levels": {"dune_scout": 1}})
	state.set_inventory(inventory)
	var expected_tap: float = float(CombatState.balance()["tap_damage_per_level"]) * (1.0 + CombatState._diminished(inventory.total_stat("tap_damage_mult")))
	_check(_approx_number(state.get_tap_damage(), expected_tap), "tap damage reads equipped tap multiplier")
	var base_dps: float = state.support_total_dps.mantissa * pow(10.0, state.support_total_dps.exponent)
	var expected_dps: float = base_dps * (1.0 + CombatState._diminished(inventory.total_stat("dps_mult")))
	var dps: Dictionary = state.dps_tick(1.0)
	_check(_approx_number(dps["damage"], expected_dps), "DPS reads equipped DPS multiplier")
	var restored_state: CombatState = CombatState.new(1, null, 1, {}, {"equipment": inventory.to_dict()})
	_check(_approx_number(restored_state.get_tap_damage(), expected_tap), "combat constructor restores permanent equipment")


func _approx_number(value: BigNumber, expected: float) -> bool:
	return is_equal_approx(value.mantissa * pow(10.0, value.exponent), expected)
