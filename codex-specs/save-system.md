# Goal
Versioned atomic save system for a Godot 4.3 idle game, with backup, corruption
recovery, schema migration and value validation.

# Files
- autoload/save_manager.gd   (extends Node, registered as autoload SaveManager)
- tests/unit/test_save_manager.gd  (extends SceneTree, headless)

# Paths
primary: user://save.json   backup: user://save.backup.json   temp: user://save.tmp.json

# Required behaviour
SCHEMA_VERSION := 2

save(data: Dictionary) -> bool
  1. write JSON to temp path, flush and close
  2. read temp back and verify it parses — if not, abort and return false
  3. copy existing primary (if any) to backup
  4. rename/replace temp -> primary
  Never leave primary partially written. Always stamp data["schema_version"].

load() -> Dictionary
  1. try primary; if it parses AND validates, migrate if needed and return
  2. else try backup; if good, migrate, RESTORE it to primary, return it
  3. else return default_data()
  Set a readable property last_load_source: "primary" | "backup" | "default"

validate(d: Dictionary) -> bool
  reject: missing schema_version, non-Dictionary, negative gold, stage < 1,
  NaN/INF numbers, gold that is not a number or BigNumber dict.

migrate(d) -> Dictionary
  v1 -> v2: v1 stored {"gold": float}; v2 stores {"gold": {"mantissa":..,"exponent":..}}
  Convert it. Unknown/newer version -> return default_data() and log.

default_data() -> Dictionary
  {schema_version, gold (BigNumber dict for 0), stage: 1, max_stage: 1,
   tap_level: 1, last_seen_utc: int, offline_claimed_utc: int}

# Offline / duplicate-reward safety
claim_offline(now_utc: int) -> Dictionary
  Returns {"seconds": int, "granted": bool}. Caps elapsed at 8 hours (28800).
  If now_utc < last_seen_utc (clock rollback) -> seconds 0, granted false.
  Must be idempotent: calling twice for the same last_seen must grant only once
  (use offline_claimed_utc as the guard).

# Test file must cover
atomic write, backup created, corrupted primary recovers from backup and the
primary is restored, both files corrupt -> defaults, v1->v2 migration fixture,
malformed values rejected, negative gold rejected, clock rollback, offline cap
at 8h, and claim_offline twice grants only once.
Print "PASS n / FAIL n" and quit(1) on any failure.

# Constraints
Typed GDScript, tabs, under ~400 lines. Reuse scripts/utilities/big_number.gd
for gold. No external addons.

# Done when
godot --headless --path . --script res://tests/unit/test_save_manager.gd
prints 0 failures and exits 0.
