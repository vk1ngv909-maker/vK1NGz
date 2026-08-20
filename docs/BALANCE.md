# Balance

All balance values live in `resources/*.json`. Never hardcode them in scripts.
Every change must record before/after simulation results here.

## C17 — first-Prestige pacing (OPEN, P2)

### Correction to an earlier assessment

A previous ledger entry described a ~10-minute first Prestige as "close to the
brief's 25-45 minute target". **That was wrong.** 10 minutes is at least 15
minutes faster than the minimum target, not close to it. The curve is also
suspiciously steep: roughly 10 minutes to stage 25, then tens of hours to
stage 50.

### Acceptance criteria (C17 stays open until all are met)

1. First Prestige occurs within **25-45 minutes** of prototype play.
2. The post-Prestige run remains **measurably faster** than the run before it.
3. The curve must not jump sharply from ~10 minutes to many hours; the wall
   should be a slope, not a cliff.
4. The simulation must be re-run **after** equipment and offline rewards are
   integrated, since both change progression speed.
5. No balance value changes silently — before/after results recorded here and
   in `docs/GAUNTLET_LEDGER.md`.

### Baseline (Gate 3, seed 20260818, taps 5/s, no equipment, no offline)

| run | to stage 50 | to 50% of max | to 80% of max | upgrades | final gold |
| --- | --- | --- | --- | --- | --- |
| A (no relics) | 203290s (56.5h) | 620s | 14400s | 734 | 752.26M |
| B (post-prestige) | 162640s (45.2h) | 490s | 11520s | 734 | 752.26M |

- Post-Prestige improvement: **20.0% faster** ✔ (criterion 2 met)
- First Prestige (stage 25): **~620s ≈ 10.3 min** ✘ (criterion 1 NOT met — target 1500-2700s)
- Wall: worst stall 39200s at stage 49 ✘ (criterion 3 NOT met — cliff, not slope)

### Current prototype formulas (from the master brief)

```
enemy_hp(stage)     = 10 * 1.55^(stage-1)
boss_hp(stage)      = enemy_hp(stage) * 8
enemy_gold(stage)   = 5 * 1.48^(stage-1)
upgrade_cost(level) = 100 * 1.075^level
prestige_currency   = floor((max_stage / 25)^1.65)
```

The gap between the gold exponent (1.48) and the HP exponent (1.55) is what
produces the cliff: gold falls behind HP by ~4.5% per stage compounding. Any
retune must be measured, not guessed.

## Root cause found (C21) — a formula defect, not a tuning problem

Re-measuring after equipment and offline landed showed the cliff was immune to
tuning: closing the gold/HP exponent gap (1.48 -> 1.55) barely moved the wall
(83.3h to stage 40 in every variant). That falsified the "gold falls behind HP"
hypothesis.

The real cause: **tap damage was implemented LINEARLY** —
`damage = per_level * tap_level` — while enemy HP grows exponentially
(`1.55^stage`) and upgrade cost grows exponentially in level (`1.075^level`).
Beating stage N therefore needs a level count that is exponential in N, at a
cost that is exponential in that level: a double exponential. An impassable
wall was mathematically guaranteed.

This also **deviates from the master brief**, which specifies
`tap_damage = base_tap x hero_level_multiplier x permanent_multipliers` — a
multiplier per level, i.e. multiplicative growth, not linear.

### Fix

`tap_damage = tap_damage_per_level * tap_damage_growth^(level-1) * multipliers`
with `tap_damage_growth = 1.06`, chosen by measured sweep, not by guess.
Balance also moved out of a script constant into `resources/balance.json`, as
the brief requires.

## Before / after (seed 20260818, taps 5/s)

| metric | before (linear) | after (growth 1.06) | target |
| --- | --- | --- | --- |
| first Prestige, no equipment | 9.6 min | **35.7 min** | 25-45 min ✔ |
| first Prestige, common | 9.0 min | 34.8 min | — |
| first Prestige, rare | 7.4 min | 27.7 min | — |
| first Prestige, epic | 5.8 min | 20.6 min | below window |
| first Prestige, legendary | 4.1 min | 13.5 min | below window |
| with ~1h offline gold | 7.8 min | 29.9 min | in window |
| with ~8h offline gold | 7.3 min | 22.2 min | slightly below |
| reach stage 50 | never (stalled at 40, 86h) | **14.0 h** | reachable |
| worst stall | 309717s (86h) @40 | **11245s (3.1h)** @40 | slope, not cliff |
| post-Prestige improvement | 20.0% faster | **20.0% faster** | must stay faster ✔ |

### Criteria status

1. First Prestige 25-45 min — **MET** (35.7 min)
2. Post-Prestige measurably faster — **MET** (20.0%)
3. No jump from minutes to tens of hours — **LARGELY MET**: worst stall fell
   from 86h to 3.1h, stage 50 from unreachable to 14h. Still steep at depth.
4. Re-run after equipment and offline — **DONE** (this table)
5. Record before/after — **DONE**

## Final tuning (Gate 4 close)

Two changes, both chosen by measured sweep:

1. **Equipment diminishing returns.** Raw summed bonuses let a full legendary
   set reach 1.93x tap damage, collapsing first Prestige to 13.4 min.
   Effective bonus is now `raw / (1 + k*raw)` with **k = 2.5**, chosen from a
   sweep of k in {0, 1.0, 1.5, 2.5, 4.0}. Rejected: k=0 (legendary 18.6 min,
   below target), k=1.0 and 1.5 (legendary 24.6 / 25.9, marginal), k=4.0
   (works, but flattens rarity to a 5.9-min spread so legendary stops feeling
   meaningful). k=2.5 keeps an 7.9-min spread across rarities with every tier
   inside the window.

2. **Offline formula corrected to the brief.** It was
   `seconds * max_stage * 0.5`, which handed a stage-1 player 14400 gold for one
   absence and pulled first Prestige to 22.1 min. It is now the brief's
   `min(hours,8) * gold_per_second * 0.35`, with gold_per_second estimated from
   what the player's best stage actually pays per kill
   (`offline_kills_per_second = 0.15`).

### Final measured results (all through the real equipment/offline paths)

| scenario | first Prestige | target |
| --- | --- | --- |
| no equipment | **36.5 min** | 25-45 ✔ |
| common set | **33.8 min** | 25-45 ✔ |
| rare set | **30.6 min** | 25-45 ✔ |
| epic set | **28.4 min** | 25-40 ✔ |
| legendary set | **26.4 min** | >= 25 ✔ |
| 1h offline | **33.8 min** | >= 25 ✔ |
| 8h offline | **26.1 min** | >= 25 ✔ |
| stage 50 | 14.0 h | reachable ✔ |
| worst stall | 11276s (3.1h) @40 | slope ✔ |
| post-Prestige | 20.0% faster | must stay faster ✔ |

No NaN, INF or negative gold in any run (`gold_ok=true` throughout).

**C17 CLOSED.** Every individual acceptance target passes.

### The legendary + offline combination — claim retracted, then made true

An earlier note claimed the ~20.4 min "full legendary set + 8h offline" case was
unreachable because "legendary gear drops from deep boss first-clears". **That
was wrong.** Inspection found there was no drop system at all, and
`equipment.json` had no unlock field: nothing prevented a fresh player from
holding legendary gear. The invariant was asserted, not implemented.

It is now enforced and tested. Every item declares `unlock_stage`, gated by
rarity:

| rarity | unlock_stage |
| --- | --- |
| common | 1 |
| rare | 10 |
| epic | 25 |
| legendary | **50** |

`Inventory.add()` refuses any item whose `unlock_stage` exceeds the player's
`max_stage_reached`, so legendary equipment cannot exist before stage 50 — well
past the first Prestige at stage 25. `tests/unit/test_equipment_gating.gd`
proves it: a fresh player is refused, is still refused at stage 25, and is only
allowed at stage 50. It also checks that unlock stages never decrease as rarity
rises, so future content cannot reopen the hole.

With the gate in place the 20.4 min combination is mechanically unreachable
before the first Prestige, and C17's targets stand.

### Still open

Nothing blocking. Re-measure again when support-hero DPS purchasing is added to
the simulated policy, since that will change the curve.


## Speed relic curve (accepted and rejected candidates)

Speed relics were measured at 0.6 seconds saved per prestige point against 45
for damage, which is not a choice. The curve was chosen by a deterministic sweep
(`tests/simulations/sim_speed_sweep.gd`), not by taste:

    falcon_rate = min(relic_speed_rate_max,
                      1 + relic_speed_rate_gain * bonus / (1 + relic_speed_rate_softcap * bonus))

Targets: 8-12% faster first Prestige at 10 points, 15-22% at 25, 25-35% at 60,
and weaker than damage and gold at the same investment. Baseline 2018s.

| gain | softcap | max | 10 pts | 25 pts | 60 pts | verdict |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0.00 / 0.35 / 1.00 | 12 | 1.4-1.6% | 2.6-2.9% | 4.5-5.8% | rejected, far below every target |
| 12 | 0.00 / 0.35 / 1.00 | 12 | 3.0-3.1% | 4.9-5.5% | 8.4-10.9% | rejected, below every target |
| 18 | 0.00 / 0.35 / 1.00 | 12 | 4.4-4.7% | 7.0-8.0% | 12.0-15.3% | rejected, below every target |
| 24 | 0.00 / 0.35 / 1.00 | 12 | 5.3-6.2% | 8.0-10.3% | 12.7-19.5% | rejected, below every target |
| 30 | 0.00 / 0.35 / 1.00 | 12 | 7.0-7.6% | 11.0-12.6% | 18.3-23.1% | rejected, below 25pt and 60pt targets |
| 40 | 0.00 | 12 | 9.8% | 15.9% | 24.6% | rejected, 60pt saturates on the rate cap |
| 40 | 0.35 | 24 | 9.4% | 15.2% | 26.5% | **accepted**, but sits on the low edge of two windows |
| 40 | 1.00 / 2.00 | 24 | 8.4-9.0% | 12.7-14.1% | 19.4-23.0% | rejected, below 25pt and 60pt targets |
| 55 | 0.35 | 24 | 12.6% | 19.8% | 33.0% | rejected, 10pt above its window |
| 55 | 1.00 | 24 | 11.9% | 18.3% | 29.3% | **shipped**, centred in all three windows |
| 55 | 2.00 | 24 | 11.1% | 16.5% | 24.8% | rejected, 60pt below its window |
| 70 | 0.35 / 1.00 / 2.00 | 24 | 13.7-15.3% | 20.2-23.9% | 29.6-38.4% | rejected, 10pt above its window |
| 90 | 0.35 / 1.00 / 2.00 | 24 | 16.8-18.8% | 24.4-28.8% | 34.9-40.2% | rejected, above every window and beats gold at 10 points |

Shipped: `relic_speed_rate_gain = 55.0`, `relic_speed_rate_softcap = 1.0`,
`relic_speed_rate_max = 24.0`. At 60 points the falcon strikes every 0.10s
instead of 1.50s, and the cap keeps the interval from ever approaching zero.

Measured sensitivity with the shipped curve, against the 2018s baseline:

| Investment | damage | gold | speed |
| --- | --- | --- | --- |
| 10 points | -22.4% | -15.4% | **-11.9%** |
| 25 points | -37.5% | -28.2% | **-18.3%** |
| 60 points | -57.0% | -45.6% | **-29.3%** |

Deeper runs at 25 points: to stage 50, damage -36.7%, gold -31.8%,
speed -18.0%; to stage 60, damage -36.7%, gold -30.5%, speed -17.9%. Speed
stays useful in the mid and late game and stays the weakest of the three at
every investment measured.

The zero-relic run is unchanged: the C17 measurement still reports 2077s
(34.6 min) on every run, inside the 25-45 minute window.
