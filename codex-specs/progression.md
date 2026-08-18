# Goal
Gate 3 progression loop: support-hero DPS, active skills, Prestige and permanent
Relics. Logic must be pure and headless-testable, like combat_state.gd.

# Files
- scripts/progression/support_heroes.gd  (class_name SupportHeroes, RefCounted)
- scripts/progression/skill_system.gd    (class_name SkillSystem, RefCounted)
- scripts/progression/prestige.gd        (class_name Prestige, RefCounted)
- scripts/progression/relics.gd          (class_name Relics, RefCounted)
- resources/heroes/support_heroes.json   (data, not constants in code)
- resources/skills/skills.json
- resources/relics/relics.json
- tests/unit/test_progression.gd

# support_heroes.gd
Load 8 heroes from JSON: id, name_key, role, base_dps, base_cost, cost_growth,
unlock_stage, milestones [10,25,50,100,200].
  hire(id) / level_up(id, count) spending BigNumber gold, never negative.
  total_dps() -> BigNumber, summing level * base_dps * milestone multipliers.
  Milestone at level L multiplies that hero's dps by 2 for each reached tier.

# skill_system.gd — CRITICAL correctness area
Load 6 skills from JSON, each with DISTINCT duration and cooldown:
  sand_fury (tap dmg x3, 10s dur / 45s cd)
  falcon_storm (falcon rate x4, 8s / 60s)
  golden_wind (gold x2.5, 12s / 90s)
  time_fracture (boss timer +10s, 1s / 120s)
  ancestor_call (support dps x3, 15s / 75s)
  critical_eclipse (crit chance +40%, crit dmg x2, 9s / 50s)

  activate(id, now_ms) -> bool
    MUST return false and change nothing if the skill is already active OR still
    on cooldown. This is the guard against double-activation power doubling.
  tick(now_ms) — expires skills and clears cooldowns based on absolute
    timestamps, NOT accumulated deltas, so it survives app suspend/resume.
  multiplier_for(kind) -> float
    Different skills stack MULTIPLICATIVELY across different kinds, but the same
    skill NEVER stacks with itself.
  to_dict()/from_dict() persisting activated_at_ms and cooldown_until_ms as
  absolute UTC ms so cooldowns keep running while the game is closed.

# prestige.gd — CRITICAL data-integrity area
  reward_for(max_stage) -> int   # floor((max_stage / 25) ^ 1.65)
  can_prestige(max_stage) -> bool  # FALSE when reward_for() == 0
  preview(state) -> Dictionary
    Must return explicit lists so the UI can show them:
      {"resets": [...], "keeps": [...], "reward": int}
  apply(state) -> Dictionary
    RESET: stage->1, gold->0, tap_level->1, support hero levels->0,
           active skills and cooldowns cleared, temporary buffs cleared
    PRESERVE: prestige_currency (+= reward), relics, equipment, max_stage,
              achievements, settings, statistics
    Must REFUSE (return state unchanged + {"refused": true}) when
    can_prestige() is false.

# relics.gd
15 relics from JSON across damage/gold/speed/skills/utility. Each: id, name_key,
category, level, max_level, base_effect, growth, cost, unlock_condition.
  buy/upgrade spends prestige_currency, never negative.
  total_bonus(category) -> float

# Integration
SaveManager must persist: support hero levels, skill timestamps, prestige
currency, relic levels, max_stage. Saving must happen IMMEDIATELY after a
successful prestige.

# Constraints
Typed GDScript, tabs. Reuse BigNumber. Balance values live in the JSON files,
not in script constants. Do not touch scripts/ui/game.gd. Keep each file under
~400 lines. No inventory/equipment UI — that is Gate 4.

# Done when
godot --headless --path . --script res://tests/unit/test_progression.gd
prints 0 failures and exits 0, and scripts/run-tests.sh still passes.
