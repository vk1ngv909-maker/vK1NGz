# Goal
Close Gate 4: balance-data validation, C23 hardcoded English, C24 skip overlap,
C25 numeral policy.

# Part 1 — balance data validation (autoload/balance_data.gd or in combat_state)
Add `schema_version` to resources/balance.json (start at 1).
Add a validator run at load that checks EVERY required key and REJECTS:
 - missing file / invalid JSON
 - missing required key
 - unknown key (warn, do not crash)
 - wrong value type
 - NaN / INF
 - growth values <= 0
 - enemy_hp_growth <= 1.0 (HP would stop growing or shrink)
 - enemy_gold_growth <= 1.0
 - upgrade_cost_growth <= 1.0 (costs would decrease)
 - tap_damage_growth < 1.0 (damage would shrink per level)
 - explosive values: any growth >= 3.0, or enemy_hp_base <= 0
 - schema_version newer than the code understands

Behaviour: in a debug build, an invalid file must fail LOUDLY —
push_error with the exact offending key and value, and fall back to a
BUILT-IN SAFE DEFAULT set so the game still boots, but set a visible flag
`balance_data_invalid = true` that the HUD shows as a debug banner.
Never silently continue with corrupted progression values.

Add tests/unit/test_balance_validation.gd covering every rejection case above.

# Part 2 — C23: no hardcoded player-facing English
- Replace every remaining player-facing literal with tr("key"), including
  "HERO DPS — PLACEHOLDER", "Cost: %s Gold", boss labels, HP labels, stage
  label, offline text, settings labels, tutorial text.
  Placeholder ART labels (HERO/FALCON/ENEMY rectangles) may stay literal but
  must read "PLACEHOLDER" consistently and be listed in ASSET_MANIFEST.md.
- Add scripts/check_strings.sh: greps scripts/ and scenes/ for suspicious
  player-facing literals (quoted strings containing a space and a letter,
  excluding tr(...) arguments, node paths, res:// paths, and known technical
  keys). Prints findings and exits non-zero if any are found.
- Add a runtime missing-key check: a helper `t(key)` that calls tr(key) and, if
  the result equals the key (i.e. untranslated), push_warning once per key and
  returns a visibly marked string like "!!key!!" in debug builds.
- Add scripts/check_translations.sh: fails if any .csv is NEWER than its
  compiled .translation, so stale compiled translations cannot pass silently.
  Wire both scripts into scripts/run-tests.sh before the suites.

# Part 3 — C24: tutorial Skip must not overlap anything
Move the Skip button into a safe-area-aware container (not a fixed position).
It must not overlap the settings gear, currency row, stage label, combat
targets, or the highlighted tutorial target, in English AND Arabic RTL, at
720x1280 / 1080x1920 / 1080x2400, including with a long tutorial sentence.
Prefer anchoring Skip to the BOTTOM of the overlay, above the nav bar.

# Part 4 — C25: one numeral policy
Add `Settings.numeral_style` with values "western" (default) and "arabic_indic".
Route ALL displayed numbers through one formatter helper so HP, percentages,
stage, gold, timers and damage are consistent on a single screen. Under Arabic,
default to western digits (common in Gulf UIs) unless the setting says
otherwise. Never change internal values or IDs — display only.

# Constraints
Typed GDScript, tabs. Do NOT modify scripts/ui/game.gd. game.tscn root stays
Node. Add every new key to BOTH CSVs and re-import translations.

# Done when
scripts/run-tests.sh passes (including the new string and translation guards),
and the debug capture flags still render.
