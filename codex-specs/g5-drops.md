# Goal
Gate 5 part 1+2: a real, deterministic equipment acquisition system, and
inventory load/migration safety so the new unlock gate cannot destroy legitimate
owned items.

# Files
- scripts/progression/reward_system.gd (class_name RewardSystem, RefCounted)
- resources/rewards/reward_tables.json
- tests/unit/test_rewards.gd

# reward_tables.json
Data-driven. Each table: id, source ("boss_first_clear"), boss_id,
eligible_rarities [], slot_weights {}, drop_weights {rarity: weight},
min_unlock_stage, duplicate_policy ("allow"|"reroll"), pity (optional int).

# RewardSystem
  _init(seed: int)                      # DETERMINISTIC. No uncontrolled RNG.
  roll(table_id, max_stage, inventory) -> Dictionary
     {"granted": bool, "item_id": String, "rarity": String, "reason": String}
  Rules:
   - never returns an item whose unlock_stage > max_stage
   - never returns a rarity above what the table allows
   - respects drop weights via the seeded RNG only
   - full inventory -> {"granted": false, "reason": "inventory_full"}
   - duplicate handling per duplicate_policy
   - unknown table id / malformed data -> granted=false, reason "invalid", logged
  Same seed + same inputs MUST produce the same item, always.

# Boss first-clear transaction (in combat_state.gd + combat_arena.gd)
  permanent_state gains `boss_first_clears: {boss_stage: true}`.
  On boss death:
    1. if boss_first_clears already has this stage -> NO reward (farming)
    2. otherwise: mark it, roll the reward, add to inventory, SAVE — as ONE
       transaction. If any step fails, none of it is committed.
  Rapid taps, reload, and backgrounding must not produce a second reward.
  Offline progress and the tutorial must NEVER grant equipment.

# Debug isolation
Any debug grant path must be behind `OS.is_debug_build()` AND an explicit
`--debug-grant` flag, and must be impossible in an exported release build.

# Inventory load/migration safety — CRITICAL
Separate four operations that currently share one door:
  acquire(item_id, max_stage) -> String   # enforces unlock_stage (the gate)
  load_owned(item_id) -> String           # NO unlock check; already-owned items
                                          # are never deleted for being "too rare"
  migrate_owned(...)                      # same leniency as load_owned
  debug_add(item_id) -> String            # debug builds only
`from_dict()` must use load_owned, NOT acquire. A player who already owns
legendary gear must never lose it because balance data changed.
Unknown/malformed ids are QUARANTINED into a `quarantined` list preserved in the
save (not deleted), and reported — documented policy, not silent loss.
Equipped-slot links must survive migration; duplicate uids rejected.

# Tests (tests/unit/test_rewards.gd)
Same seed -> same result; unlock_stage respected at every max_stage; legendary
never granted below 50; inventory_full; duplicate policy; invalid table;
first-clear grants once; farming the same boss grants nothing; reload does not
re-grant; load_owned keeps a legendary item for a stage-1 player while acquire
refuses one.

# Constraints
Typed GDScript, tabs, data in JSON. Do not modify scripts/ui/game.gd.
Keep files under ~400 lines.

# Done when
scripts/run-tests.sh passes with all guards.
