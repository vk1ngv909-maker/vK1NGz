# Rear-view combat direction

The approved composition puts the camera behind a single hero. This records
what the implementation guarantees and how each claim was checked.

## Composition

| Rule | Where it lives | Value |
| --- | --- | --- |
| One hero, lower centre, seen from behind | `hud.gd` `COMBAT_AXIS`, `HERO_ANCHOR_Y` | 0.5, 0.94 |
| Enemy directly ahead on the same axis | `hud.gd` `ENEMY_ANCHOR_Y` | 0.52 |
| Normal enemy height | `hud.gd` `ENEMY_HEIGHT_BAND` | 18–25 % of the arena |
| Boss height | `hud.gd` `BOSS_HEIGHT_BAND` | 32–42 % of the arena |
| Width limits for wide silhouettes | `ENEMY_MAX_WIDTH`, `BOSS_MAX_WIDTH` | 0.44, 0.62 |
| Falcon beside the hero, never in the lane | `hud.gd` `_layout_combat` | hero.x − falcon.w × 1.15 |

The bands are divided by each creature's authored `size_scale` before the
rectangle is sized, so the *drawn* result lands in the band rather than the
rectangle.

## The attack

A tap plays wind-up (0.06 s), travel (0.13 s), a 0.07 s hold on the enemy, then
recovery (0.16 s). Damage, the enemy reaction and the death check are all
deferred by `attack_travel_seconds()` = 0.19 s, so nothing is shown before the
hit connects. The hero returns to `hud.hero_anchor` — the anchor the layout
stored, not wherever the hero happened to be — so repeated tapping cannot make
the hero drift.

A weapon may declare `attack_style: "ranged"`; that path fires a magic bolt from
the hero to the enemy over the same 0.19 s instead of lunging. Every shipped
weapon is melee, and the field is optional, so no existing item's id or stats
changed.

## Damage numbers

Six lanes around the enemy's live rectangle (`lower_left`, `middle_right`,
`upper_left`, `lower_right`, `middle_left`, `upper_right`) with an optional
`upper_center`. Selection is round-robin with two rules: never a third number in
a row on the same side, and prefer a lane no live number occupies. Lanes are
resolved against the enemy, pushed off the HP bar, boss banner and name plate,
and clamped on screen — a critical is given a wider box because it carries a
word as well as a number. The pool is fixed at 32 labels.

## Evidence

`docs/evidence/combat_rear/`:

* `attack_0_idle` … `attack_5_recovery` — one ordered attack, frame by frame.
* `attack_verify.txt` — three runs of `--demo-attack-verify`.
* 12 combat captures: three worlds × normal/boss × EN/AR × 720×1280 and
  1080×2400.
* 4 Hero Training captures, both languages, both resolutions.
* `attack_verify_ranged.png` — the staff bolt on the enemy.

Measured by `--demo-attack-verify`: the arc had travelled 97–100 % of the way to
the enemy on the frame the tap's own damage number first existed; the hero's
position after 200 rapid taps matched the anchor to 0.000 px; the pool held 32
children throughout; the staff bolt arrived 0–23 px from the enemy centre,
inside an enemy reach of 94–181 px.

Timings come from `xvfb-run` with llvmpipe. They describe animation scheduling,
not Android performance, and the wall-clock column drifts by up to a frame under
software rendering — the geometric check is the claim.

## Tests

* `tests/unit/test_combat_composition.gd` — the composition constants, band
  mapping across six aspect ratios, lane distribution, side rule, HUD
  avoidance, critical width, pool bounds under 1200 attacks, with negative
  controls for the side rule and the width allowance.
* `tests/unit/test_attack_timing.gd` — the deferral contract, with a negative
  control for a zero-travel attack.
