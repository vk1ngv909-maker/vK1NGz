# Goal
Playable combat vertical slice for the Godot 4.3 portrait idle game.
Separate testable LOGIC from PRESENTATION so the logic can be unit-tested headless.

# Files
- scripts/combat/combat_state.gd   (class_name CombatState, extends RefCounted) — PURE LOGIC, no nodes
- scripts/combat/combat_arena.gd   — presentation, drives hud + actors
- scripts/combat/damage_number_pool.gd — pooled floating damage labels
- tests/unit/test_combat_state.gd  (extends SceneTree)

# combat_state.gd — pure logic, no Node/scene access
Uses BigNumber (scripts/utilities/big_number.gd) for hp/gold/damage.

Data:
  stage: int = 1, is_boss: bool, enemy_hp: BigNumber, enemy_max_hp: BigNumber,
  gold: BigNumber, tap_level: int = 1, boss_time_left: float,
  awaiting_retry: bool

Formulas (from the design brief, keep them in one CONST block so balance is data):
  enemy_hp(stage) = 10 * 1.55^(stage-1)
  boss_hp(stage)  = enemy_hp(stage) * 8
  enemy_gold(stage) = 5 * 1.48^(stage-1)
  upgrade_cost(level) = 100 * 1.075^level
  tap_damage = 5 * tap_level

Boss rule: every 10th stage is a boss (stage % 10 == 0), 30.0 second timer.

Required methods, each returning a small result Dictionary describing what
happened so the presentation layer can react without recomputing:

  tap() -> Dictionary
    Applies tap damage. Rolls critical: 20% chance, x5 damage.
    Returns {"damage": BigNumber, "kind": "normal"|"critical", "killed": bool,
             "gold_awarded": BigNumber, "stage_advanced": bool}
    MUST be a no-op returning {"ignored": true} when the enemy is already dead
    or awaiting_retry is true. This is the guard against double rewards.

  falcon_tick(delta) -> Dictionary
    Falcon auto-attacks every 1.5s for 40% of tap damage, kind "falcon".
    Same no-op guard.

  tick(delta) -> Dictionary
    Advances the boss timer when is_boss. On timeout: sets awaiting_retry=true,
    does NOT remove gold, returns {"boss_failed": true}.

  retry_boss() -> void      # only valid while awaiting_retry
  buy_tap_upgrade() -> bool # spends gold if affordable, else false, never negative

CRITICAL INVARIANTS (the tests must prove these):
  - one tap = one damage application
  - gold for a kill is awarded EXACTLY once even if tap() is called again
    in the same frame after death
  - stage advances EXACTLY once per kill
  - gold never negative
  - failing a boss keeps gold and returns to farming, not stage 0

# combat_arena.gd — presentation
- Reads a tap on the combat area only (not over HUD buttons).
- Hero always faces the enemy (hero is left of enemy; if the enemy ever moves,
  flip hero.scale.x accordingly). Falcon stays beside/above the hero.
- Damage colours: normal = light yellow, critical = orange-red and larger font,
  falcon = cyan. Use these to make the type readable.
- Enemy reacts to every hit: a short recoil tween (offset ~12px then back) and
  a white flash, plus HP bar update. On death: a distinct death reaction
  (scale down + fade) before the next enemy spawns.
- Boss: show a warning label, a visible 30s countdown, and on failure show a
  "Retry Boss" button that calls retry_boss().
- Damage numbers MUST come from damage_number_pool.gd (pre-allocate 32, reuse).
  Rapid tapping must not create unbounded nodes.
- Save on stage change via SaveManager; load on start.

# Constraints
Typed GDScript, tabs. No external assets — placeholders stay labelled rectangles.
Do NOT modify scripts/ui/game.gd (screenshot capture lives there).
game.tscn root node type stays Node.
Do not add heroes, inventory, relics, skills logic — slice only.

# Done when
godot --headless --path . --script res://tests/unit/test_combat_state.gd
prints 0 failures and exits 0, AND the game still renders:
bash scripts/shot.sh 1080 1920 /tmp/c.png
