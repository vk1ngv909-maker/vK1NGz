# Aren rig integration — audit and plan

Audit of the supplied animation package against what the integration needs.
**Result: the package is a rig *definition*. The rig itself — the artwork every
bone drives — was not supplied, and two of the four required attack animations
are absent. Integration has not started.**

## 1. What was supplied

One file: `aren_animation_tracks.json` (18.6 KB), kept at
`docs/design/aren_animation_tracks.json`.

It is internally consistent — every reference in it resolves:

| Contents | Count | Validation |
| --- | --- | --- |
| Bones | 24 | single root (`root_anchor`), no orphan parents |
| Layer slots with z-order (front/rear facing) | 27 | every slot names a bone that exists |
| Sockets | 10 | all ten required ones present, every one names a bone that exists |
| Animation tracks | 4 | `idle`, `idle_variant`, `attack_a`, `seam_test` |
| Named events | 2 | `impact_a` @ 0.22 s, `glance_kiro` @ 0.62 s |

The geometry is sound. Solving forward kinematics on the rest pose puts the
standing figure 332 px tall with both feet at y=510 against a declared
`ground_y` of 512 — a 2 px registration error, i.e. correctly registered. The
1000 px canvas width against a 147 px rest-pose stance is the clearance the
sword arc needs. No proportion conflict with the approved hero.

`seam_test` is a QA track: 3 s of extreme joint rotations (arms to ±150°, legs
to ±70°) whose only purpose is to expose holes and seams in layer art. Its
presence is itself confirmation that real layer art is expected to exist.

## 2. What is missing

### Blocker 1 — the layer artwork (27 files, 0 supplied)

The JSON declares *where* each layer sits and *which bone* moves it. It contains
no pixels. Searching 352 files across `assets/`, `resources/`, `scenes/`, the
concept package and the upload folder found **zero** of the 27:

`character_shadow` · `cape_back_lower` · `cape_back_mid` · `cape_back_upper` ·
`boot_rear` · `leg_rear_lower` · `leg_rear_thigh` · `arm_rear_upper` ·
`arm_rear_forearm` · `hand_rear` · `pelvis` · `torso_base` · `leg_front_thigh` ·
`leg_front_lower` · `boot_front` · `outfit_front` · `belt_and_pouches` ·
`cape_clasp` · `neck` · `head` · `hair_back` · `expression_eyes` · `hair_front` ·
`arm_front_upper` · `arm_front_forearm` · `hand_front` · `weapon_short_sword`

A `Skeleton2D` with 24 bones and nothing to skin renders nothing. The only way
to put something on screen without these files is to draw body parts in code,
which is exactly what the checkpoint forbids and what was already rejected.

Each layer must be painted **complete**, including the parts hidden behind other
layers — the arm needs whole cape and torso behind it, or `seam_test` will tear
it open. That is the specific failure recorded in
`docs/evidence/hero_v4/why_the_current_asset_cannot_be_rigged.png`.

Required per file: transparent PNG, same identity, palette, outline weight and
lighting as the approved hero; positioned in the rig's own 1000x560 canvas space
so each layer's placement matches its bone; the sword as its own file so
`weapon_grip` can swap it.

### Blocker 2 — `attack_b` (left-to-right counter-swing)

Not in the package. Required, and explicitly must not be a mirror of `attack_a`
— so it cannot be synthesised. Needs its own key list and its own `impact_b`
event time.

### Blocker 3 — `attack_critical`

Not in the package. Required, and explicitly must not be a scaled normal slash.
Needs its own key list and its own `impact_critical` event time.

### Not blocking

No `.tscn`, `.gd`, `.tres`, preview scene or rig documentation was supplied. I
do not need them: I can build the scene, the importer and the controller from
the JSON. `hit_react_light/heavy`, `level_up`, `victory`, `defeat` and
`skill_cast` are also absent — per instruction those states stay documented and
unfaked.

## 3. Integration plan, once the missing files arrive

1. **Importer** — `tools/build_aren_rig.py` reads the JSON and generates
   `scenes/actors/aren.tscn`: `Skeleton2D` with the 24 `Bone2D` nodes at their
   rest transforms, one `Sprite2D` per layer parented to its bone at the given
   z-order, and a `Marker2D` per socket at its declared offset. Generated, not
   hand-authored, so a re-supplied rig regenerates cleanly.
2. **Animations** — each track becomes an `Animation` on an `AnimationPlayer`:
   one rotation track per keyed bone plus a root-offset track, cubic
   interpolation as declared, `loop` honoured. Events become method-call keys
   at their exact declared times. Secondary motion (`hair_*`, `cape_*`
   coefficients) drives a follow-through pass on those bones.
3. **Placement** — the existing approved composition is preserved: `root_anchor`
   maps onto the current foot anchor, so lower-centre placement, hero scale,
   rear view, the shared vertical axis with the enemy, and the falcon's position
   (which the rig also declares as `companion_home`) all stay exactly as
   approved.
4. **State machine** — `IDLE / WINDUP / SWING / IMPACT / RECOVER` per attack,
   alternating `attack_a` → `attack_b`, critical using `attack_critical` without
   disturbing the A/B cursor; at most one buffered attack; states with no
   supplied animation stay documented and unreachable.
5. **Impact-driven damage** — the existing deferral already waits for a declared
   impact moment; it switches from a timer to the animation's own `impact_a` /
   `impact_b` / `impact_critical` events. No damage number before its event.
6. **Weapon** — `weapon_short_sword` parents to `weapon_grip`; the slash trail
   and impact tracking read `weapon_tip`. The equipment system is untouched
   mechanically; the sword becomes swappable art.
7. **Tests and evidence** — the 17 listed checks with negative controls, then
   the runtime capture (`--demo-clip` under `--fixed-fps 30`) and the MP4,
   contact sheet, drift and impact-timing measurements.

## 4. Baseline recorded

`docs/evidence/hero_v4/baseline_hashes.txt` holds SHA-256 for every file under
`resources/`, the save manager, balance loader, combat state, progression
scripts and both localization CSVs, taken at commit `6bca2d4` before any
integration. Balance, IDs, save schema and localization are verified against it
when integration lands.
