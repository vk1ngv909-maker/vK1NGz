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

## The hero

One hero, drawn from behind, using two delivered 2048x2048 poses:
`hero_rear_idle_v3_2048.png` and `hero_rear_attack_v3_2048.png`. The geometric
hero that preceded them — polygons drawn by a script — was rejected on sight and
is deleted; `tests/unit/test_hero_assets.gd` fails if it or its generator comes
back, or if combat ever references `Polygon2D`.

Both files sit inside transparent padding and do not fill their square
identically, so neither the canvas nor a naive centre can place them. The alpha
bounds are baked by `tools/build_hero_metrics.py` into
`resources/hero_sprite_metrics.json`, and `scripts/ui/hero_placement.gd` sizes
the rectangle so the **visible body** is 26 % of the arena and offsets it so the
body's bottom-centre lands on the anchor. Measured in the running game, both
poses put their feet on the same point to 0.000 px.

Imported with `compress/mode=0` (lossless), `mipmaps/generate=true` — an 8x
downscale without mipmaps aliases badly at 720x1280 — `process/fix_alpha_border=true`
so no halo appears at the cut edge, and `detect_3d/compress_to=0` so the texture
can never be silently swapped to VRAM compression. The node draws with
`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`; nothing uses nearest-neighbour.

## The attack

A tap plays wind-up (0.05 s) in the idle pose, then swaps to the attack pose for
travel (0.10 s), a 0.05 s hold on the enemy, and recovery (0.11 s) before
swapping back — 0.31 s in total. Damage, the enemy reaction and the death check
are all deferred by `attack_travel_seconds()` = 0.15 s, so nothing is shown
before the hit connects.

A tap arriving mid-swing has one deterministic rule, split at the moment of
impact: **before** the blade lands the tap is **absorbed** — the swing in flight
keeps going, connects, and the absorbed tap's damage is presented at that same
impact; **after** it lands the swing **restarts** from the top. Nothing queues
either way, so no two tweens can drive one property.

Absorbing is not cosmetic. Damage used to wait on a timer of its own, so during
rapid tapping a number could surface while the visible blade was barely off the
hero. Recorded at 30 fps, 26 of 29 damage events landed with the arc under 85 %
of the way to the enemy. With the rule in place all 16 events land at 92-98 %.

That rule is counted in **game** time, not wall clock. The first attempt
compared `Time.get_ticks_msec()` against game-time tweens, which meant it never
fired under a fixed frame rate and the recording looked unchanged. The hero returns to `hud.hero_anchor` — the anchor the layout
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
* `hero_1to1_crop_720x1280.png`, `hero_1to1_crop_1080x2400.png`,
  `hero_clip_1to1_720x1280.png` — unscaled runtime crops, for inspecting the
  texture's own edges.
* `hero_runtime_720x1280.gif` — 9 s of the running game at 720x1280: idle, five
  rapid taps, normal and critical hits, an enemy death, and the return to idle.
  Captured with `--demo-clip` under `--fixed-fps 30`, so one frame is one
  thirtieth of a game second and playback runs at the speed a device would.
  Re-sampled to 25 fps for the GIF because its frame delay is stored in
  hundredths of a second and 1/30 s is not representable — at 30 fps the file
  plays 9 % fast. Playback length matches the recorded game time exactly.
* `hero_runtime_timeline.csv` — one row per recorded frame: pose, foot point,
  live numbers, stage, cumulative tap damage, and how far the arc had travelled.
  This is the frame-level evidence behind the claims above.

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
* `tests/unit/test_hero_assets.gd` — both PNGs exist, are 2048x2048, carry an
  alpha channel and real transparent pixels, still match their baked bounds, are
  what the runtime references, and place both poses' feet on one point; plus the
  rejected geometric hero staying deleted, and a negative control showing that
  canvas placement would drift.
