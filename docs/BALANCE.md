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

### Still open

- Legendary equipment pulls first Prestige to 13.5 min, well below the window.
  Equipment rarity scaling needs its own pass so rarity stays meaningful without
  collapsing the intended pacing.
- 8h offline gold pulls it to 22.2 min, marginally below the window.

C17 therefore stays **OPEN** on equipment/offline scaling, even though the
baseline curve now meets the target.
