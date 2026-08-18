# Goal
Gate 5 group 4A: eight distinct support heroes, six mechanically distinct
skills, their UI panels, plus two carry-over fixes.

# Carry-over fixes (do these first)
1. The combat background label is hardcoded "DESERT BACKGROUND — PLACEHOLDER"
   for every world. Make it show the ACTIVE world's localized name, or remove it
   from player-facing UI entirely. It must not say "desert" in Moonlit Dunes.
2. Add `--debug-boss <archetype_id>` so each boss archetype can be captured.

# Part 1 — eight support heroes (resources/heroes/support_heroes.json, v1)
Two melee, two ranged, two magic, two support. Each: id, name_key, desc_key
(en+ar), role, unlock_stage (spaced across 1-100), base_cost, cost_growth,
base_dps, dps_growth, milestones [10,25,50,100,200] each with a TYPED effect,
passive {type, value}, sprite_ref, anim_ref, asset_status "PLACEHOLDER".

Milestone effect types must VARY per hero so they are not eight DPS clones:
  self_dps_mult, all_hero_dps_mult, tap_damage_add, gold_mult,
  crit_chance_add, skill_duration_mult, skill_cooldown_mult
Give each role a mechanical identity, e.g. melee = self dps + tap support,
ranged = crit support, magic = all-hero dps, support = gold / skill support.
Early heroes must stay relevant: at least one early hero's milestones scale
ALL heroes, so it keeps mattering.

API (scripts/progression/support_heroes.gd):
  is_unlocked(id, max_stage), hire(id, max_stage), level_up(id, count)
  cost_for(id, count) and max_affordable(id, gold)  # for x1/x10/x25/x100/Max
  total_dps(), passive_bonus(kind)
  Milestones fire EXACTLY ONCE per threshold crossing, even with a bulk buy.
  Gold never negative. Locked hero cannot be hired. Unknown id fails safely.
  Very large levels must not produce NaN/INF (use BigNumber).

# Part 2 — six skills must be MECHANICALLY distinct (not six multipliers)
Extend skill_system.gd + resources/skills/skills.json so each acts differently:
  sand_fury        -> tap_damage multiplier
  falcon_storm     -> falcon attack RATE multiplier (more visible strikes)
  golden_wind      -> gold multiplier, applied at award time, never duplicating
  time_fracture    -> boss timer: ADD +10s once per activation, clamped to
                      [0, 60]; can never make the timer negative or infinite.
                      Document this single rule.
  ancestor_call    -> support-hero DPS multiplier
  critical_eclipse -> crit chance +0.40 (clamped to <= 0.95) and crit damage x2
Add per-skill: unlock_condition {max_stage}, level, upgrade_cost, scaling rule,
icon_ref, vfx_ref, sfx_ref, and a LOCKED state in the UI.
Stacking: different kinds multiply; the same skill never stacks with itself;
document any incompatible pair explicitly in the JSON.

# Part 3 — UI
scenes/ui/heroes_panel.tscn + scripts/ui/heroes_panel.gd showing per hero:
name, role, level, current DPS, next-level gain, cost, milestone progress,
locked/available, buy-quantity selector (x1/x10/x25/x100/Max), affordable or
disabled state. States must be readable WITHOUT colour alone (text labels).
Skills panel must show name, level, effect, duration, cooldown, unlock
requirement, state, remaining active seconds, remaining cooldown seconds.
Both panels: close button, scrollable, fit 720x1280 with 16px margins.
Debug hooks: --debug-heroes, --debug-heroes-locked, --debug-skills-panel.

# Constraints
Typed GDScript, tabs. All keys in BOTH CSVs; re-import translations. Do not
modify scripts/ui/game.gd. Update docs/ASSET_MANIFEST.md.

# Done when
scripts/run-tests.sh passes with all guards and each debug flag renders.
