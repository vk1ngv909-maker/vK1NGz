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

### Status

**No balance values have been changed yet.** Re-measurement is scheduled after
Gate 4 equipment and offline rewards land, per criterion 4.
