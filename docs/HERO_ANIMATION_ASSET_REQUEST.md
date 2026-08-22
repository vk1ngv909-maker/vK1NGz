# Hero animation: what is missing

The rear-view hero motion currently in the game is **two flat images swapped,
with a tween moving the whole rectangle**. That is not character animation and
it is not being presented as finished work. This document records why the
approved artwork cannot be animated as delivered, and exactly what is needed.

## Why the approved art cannot be rigged or re-posed

`hero_rear_idle_v3_2048.png` and `hero_rear_attack_v3_2048.png` are **flattened
renders**, not layered characters.

| Check | Result |
| --- | --- |
| Layers in the file | 1 (flat RGBA) |
| Unique colours | 242,728 (idle) / 238,781 (attack) — continuous-tone painting, not flat cel regions that could be separated by colour |
| Pixels behind the cape | do not exist |
| Pixels behind the sword arm | do not exist |
| Frames supplied | 2 total: one idle pose, one attack pose |

`docs/evidence/hero_v4/why_the_current_asset_cannot_be_rigged.png` shows this
directly: cutting the sword arm out of the idle sprite leaves a hole, because
the cape, belt and torso were never painted behind it. Re-posing that arm leaves
the hole plus a hard seam, and the arm no longer meets the shoulder. Every joint
behaves the same way.

To animate limbs from this file, the regions hidden behind the cape, the arms
and the sword would have to be **painted in**. That is new character art at the
approved quality — it cannot be derived from the pixels that exist, and drawing
it in code would be exactly the geometric, code-drawn body the checkpoint
forbids.

## The concept package does not fill the gap

`CLAUDE_READY_CARTOON_ASSET_BIBLE/ART_BIBLE.md` documents an animation plan —
`idle(4), attack(6), critical_attack(6), hit(3), victory(5)` — but the package
ships **no animation frames**: 0 of its 137 asset files are frame art. The plan
was written; the frames were never produced.

## What is needed

Either option unblocks the work. Option A is faster; Option B also satisfies the
per-part customization the checkpoint asks for (body / outfit / cape / weapon /
head-hair / effects).

### Option A — finished frame sets (32 frames)

Rendered by whatever produced the approved hero, in the same style.

| Animation | Frames | Must show |
| --- | --- | --- |
| `idle` (loops) | 6 | breathing, shoulder movement, weight shift, cape and hair motion, subtle sword movement |
| `attack_a` right-to-left | 8 | prepare, hip and torso rotation, sword-arm travel, pivot, slash, impact pose, recovery |
| `attack_b` left-to-right | 8 | a genuinely different reverse swing — not a mirror of A; sword hand, clothing, cape and body direction stay anatomically consistent |
| `attack_critical` | 10 | larger wind-up, stronger body rotation, overhead or diagonal arc, stronger cape and hair motion, a held impact frame, recovery |

Per-frame requirements:

* Same rear three-quarter camera, same face and hair, same body proportions,
  same teal cape, same outlines and lighting as the approved stills.
* Transparent background, no matte, no halo.
* **One shared canvas and one shared registration point across every frame** —
  the character must not float relative to the frame between poses. The runtime
  already places the hero by baked alpha bounds
  (`resources/hero_sprite_metrics.json`), and will re-bake per frame.
* Suggested canvas: 1024x1024 per frame. The hero draws at roughly 280 px tall
  on a 1080-wide screen, so 1024 is already generous, and 32 frames at 2048
  would be about 64 MB. The approved 2048 stills are unaffected.
* Naming: `hero_<animation>_<index>.png`, zero-padded, e.g. `hero_attack_a_03.png`.
* **State the impact frame index for each attack** (the frame where the blade
  reaches the enemy). Damage, the enemy reaction and the death check are keyed
  to it — the game must never show a number before that frame.

### Option B — layered source

One PSD (or one folder of PNGs, one per layer) where **each part is painted in
full, including the areas hidden behind other parts**:

`body base` (torso, hips, head shape) · `outfit` (tunic, belt, boots) · `cape` ·
`head/hair` · `attacking arm` (upper, forearm, hand) · `supporting arm` ·
`left leg` and `right leg` (thigh, shin, foot) · `sword`

Plus a pivot point per part, and the grip point on the sword. With this I build
the `Skeleton2D` rig, the four animations and the layer slots for future
customization directly.

## What is already built and waiting

* Rear-view composition, hero scale, and the alpha-bounds foot anchor — frozen
  and approved; frames drop into the same anchor machinery.
* Damage deferral to a declared impact moment, and the rule that a tap arriving
  mid-swing is absorbed by the swing in flight rather than restarting it.
* Frame-accurate capture (`--demo-clip` under `--fixed-fps 30`) and the timeline
  log that measures pose, foot point and impact ordering per frame.

## What is NOT built

The combo state machine (A -> B -> A -> B, critical uses C, at most one buffered
next attack) is **not implemented**. It is a small piece of work, but building it
against two static images would produce another animation-shaped illusion, so it
waits for the frames.
