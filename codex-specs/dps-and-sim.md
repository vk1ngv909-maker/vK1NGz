# Goal
1) Wire support-hero DPS into live combat. 2) Add a deterministic progression
simulation proving a post-Prestige run is faster than the run before it.

# Part 1 — DPS in combat (scripts/combat/combat_state.gd)
Add:
  dps_tick(delta: float) -> Dictionary
    Applies (support_total_dps + falcon_dps) * delta as damage of kind "dps".
    Returns the same result shape as tap(): damage, kind, killed, gold_awarded,
    stage_advanced — and {"ignored": true} when the enemy is dead or
    awaiting_retry.

CRITICAL: a kill by DPS must award gold and advance the stage EXACTLY ONCE,
exactly like a tap kill. The same guard must cover both paths — do not duplicate
the kill/reward logic; route tap(), falcon_tick() and dps_tick() through one
shared internal _apply_damage() that owns the kill transition.

combat_arena.gd calls dps_tick(delta) each frame and shows the damage number in
a distinct colour for kind "dps" (soft green), separate from falcon cyan.

CombatState must read support hero levels from run_state so DPS reflects the
player's actual heroes.

# Part 2 — Relic power must be real
Relic bonuses (damage category) must multiply tap damage and DPS. Expose
`set_relic_bonuses(damage_mult: float, gold_mult: float)` on CombatState and
apply them in get_tap_damage() and gold rewards.

# Part 3 — Simulation (tests/simulations/sim_progression.gd)
extends SceneTree, headless, DETERMINISTIC (fixed seed, fixed time step).
Simulate a player using a simple policy: tap at a fixed rate, buy the cheapest
affordable upgrade whenever possible.

Run A: fresh game, no prestige currency, no relics. Record simulated seconds to
reach stage 50.
Then prestige (reward from max_stage 50), spend the currency on damage relics.
Run B: same policy, same seed, from stage 1 with those relics.
Record simulated seconds to reach stage 50 again.

Print a table: run, seconds_to_stage_50, upgrades_bought, final_gold.
ASSERT run B is strictly faster than run A, and fail (quit(1)) if it is not.
Also assert no NaN/INF/negative gold appears at any point.

# Constraints
Typed GDScript, tabs. Deterministic: no Time.get_ticks, no real clock — advance
a simulated clock in fixed steps. Do not touch scripts/ui/game.gd.

# Done when
godot --headless --path . --script res://tests/simulations/sim_progression.gd
prints the table, asserts B < A, and exits 0. scripts/run-tests.sh still passes.
