# Goal
Gate 4 part 1: inventory + equipment foundation, with SAFE destructive actions.
Pure logic, headless-testable, like combat_state.gd.

# Files
- scripts/progression/inventory.gd  (class_name Inventory, RefCounted)
- resources/equipment/equipment.json  (20 starter items)
- tests/unit/test_inventory.gd

# Slots and rarities
Slots: weapon, head, outfit, aura, companion_charm
Rarities: common, rare, epic, legendary

# Item fields (each item in equipment.json)
id (stable, unique), name_key, desc_key, slot, rarity, item_level,
stats { tap_damage_mult, dps_mult, gold_mult, crit_chance_add }, icon_ref

Runtime per-owned-item state: locked (bool), favorite (bool), equipped (bool)

# Inventory API
add(item_id) -> String            # returns a unique OWNED uid, not the item id
remove(uid) -> bool
equip(uid) -> bool                # refuses wrong slot; unequips the previous item in that slot
unequip(slot) -> bool
score(uid) -> float               # visible item score from stats + item_level + rarity weight
compare(uid) -> Dictionary        # vs currently equipped in the same slot:
                                  # {"slot":..., "equipped_uid":..., "delta": {stat: +/-value},
                                  #  "score_delta": float, "is_upgrade": bool}
auto_equip(uid) -> bool           # equips ONLY if score(uid) > score(equipped); else false
set_locked(uid, bool), set_favorite(uid, bool)
total_stat(name) -> float         # summed across EQUIPPED items only

# Salvage — this is the dangerous part, treat it as a transaction
salvage(uid, confirmed_rarity: bool = false, confirmed_favorite: bool = false) -> Dictionary
  Returns {"ok": bool, "reason": String, "gold_awarded": float, "needs": Array}
  Refusal rules, checked in this order:
    1. unknown uid                    -> ok=false, reason "unknown"
    2. item is EQUIPPED               -> ok=false, reason "equipped"
    3. item is LOCKED                 -> ok=false, reason "locked"
    4. rarity is rare/epic/legendary AND not confirmed_rarity
                                      -> ok=false, reason "needs_confirmation", needs ["rarity"]
    5. item is FAVORITE AND not confirmed_favorite
                                      -> ok=false, reason "needs_confirmation", needs ["favorite"]
  On success: remove the item and award gold ONCE. The uid must be gone, so a
  second salvage of the same uid returns reason "unknown". Salvage must be
  atomic: either the item is removed AND gold granted, or neither happens.

salvage_batch(uids: Array, confirmed_rarity, confirmed_favorite) -> Dictionary
  Applies the same rules per item; returns per-uid results and a total. Skipped
  items must not be destroyed.

# Persistence
to_dict()/from_dict() covering owned items, uids, equipped slots, locked and
favorite flags. Unknown or malformed item ids in a loaded save are DROPPED with
a logged warning, never crash. Duplicate uids are rejected.

# Integration
Inventory lives in permanent_state (survives Prestige). SaveManager must
persist it. CombatState must read total_stat("tap_damage_mult") and
total_stat("dps_mult") so equipment actually changes damage.

# Constraints
Typed GDScript, tabs. Under ~400 lines. Data in JSON, not constants.
Do not touch scripts/ui/game.gd. game.tscn root stays Node.

# Done when
godot --headless --path . --script res://tests/unit/test_inventory.gd
exits 0 and scripts/run-tests.sh still passes.
