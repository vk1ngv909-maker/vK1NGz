# Goal
Fix a structural fragility: Prestige currently erases a HARDCODED list of keys,
so any temporary field added later silently survives a prestige and permanently
inflates the player's power. Replace the blacklist with a structural split.

# Required design
Save data becomes:

  {
    "schema_version": 3,
    "run_state":       { ... everything a prestige must destroy ... },
    "permanent_state": { ... everything a prestige must preserve ... }
  }

run_state (rebuilt from scratch on prestige):
  stage, gold, tap_level, support_hero_levels, active_skills,
  skill_timestamps, temporary_buffs, boss_time_left, awaiting_retry

permanent_state (never touched by prestige):
  max_stage, prestige_currency, relic_levels, equipment, achievements,
  settings, statistics, last_seen_utc, offline_claimed_utc

# The critical change in prestige.gd
`apply()` must NOT erase named keys. It must do:

    result["run_state"] = SaveManager.default_run_state()

i.e. rebuild the whole run_state from the canonical defaults. Any field that
exists in run_state is therefore reset automatically, including fields added
years later by someone who never reads prestige.gd.

Permanent values are updated normally (prestige_currency += reward).
The zero-reward refusal behaviour must not change.

# save_manager.gd
- Add `default_run_state() -> Dictionary` and `default_permanent_state() -> Dictionary`.
  `default_data()` composes them.
- SCHEMA_VERSION becomes 3.
- Migration v2 -> v3: take the old FLAT dictionary and route each known key into
  run_state or permanent_state per the lists above. Unknown legacy keys go to
  permanent_state (safer to keep than to destroy player data) and are logged.
- Keep the existing v1 -> v2 migration working, so v1 -> v2 -> v3 chains.
- validate() must accept the new shape and reject a missing run_state or
  permanent_state.

# Update all call sites
combat_arena.gd, prestige.gd, relics/skills/support hero persistence, and every
existing test that reads flat keys must be updated to the nested shape.

# Constraints
Typed GDScript, tabs. Do not touch scripts/ui/game.gd. Keep files under ~400
lines. Migration must never lose permanent player data.

# Done when
scripts/run-tests.sh passes fully, and a v2 fixture migrates to v3 with
max_stage, prestige_currency and relic_levels intact.
