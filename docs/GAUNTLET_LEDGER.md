# Gauntlet Ledger — Desert Ascendant

Updated: 2026-08-18 · Godot 4.3.stable.official.77dcf97d8

## Environment (verified this session)

| Capability | Status | Evidence |
| --- | --- | --- |
| Godot 4.3 | installed at `/opt/godot/godot`, on PATH | `godot --version` |
| Headless script execution | works | test suites exit 0 |
| Offscreen rendering + screenshot | works via `xvfb-run` + llvmpipe | PNG captured and visually inspected |
| Codex CLI delegation | works | BigNumber built via `scripts/codex-run.sh` |
| Android export/device test | **NOT available** | no SDK, no device — see Blockers |

Render command:
`LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a --server-args="-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3`

## Milestone / Gate status

Current milestone: **M0 → Gate 1 (Technical Foundation)**

| Gate 1 requirement | Status |
| --- | --- |
| Portrait boot works | **PASS** — real captures at 720x1280, 1080x1920, 1080x2400 |
| Architecture documented | **PASS** — docs/ARCHITECTURE.md |
| BigNumber tests pass | **PASS** — 36 own + 12 independent adversarial |
| Save recovery from damaged primary | **PASS** — 36 own + 17 independent adversarial |

**GATE 1 PASSED** (2026-08-18).

## Completed

- Godot 4.3 installed; headless + rendering pipelines proven.
- Project scaffold: portrait 1080x1920, gl_compatibility, folder tree per brief §8.
- **BigNumber** (`scripts/utilities/big_number.gd`, 227 lines, typed GDScript).
  - Built by Codex from `codex-specs/bignumber.md`.
  - Codex's own suite: 36 pass / 0 fail.
  - **Independent adversarial suite** (`tests/unit/test_big_number_adversarial.gd`):
    12/12 pass. Written against the spec, not derived from the implementation.
  - Harness negative-control verified: exits 1 when an assertion is broken.

## Critic findings

| # | Finding | Severity | Status |
| --- | --- | --- | --- |
| C1 | Codex authored both impl and its tests — passing them is weak evidence | P1 | RESOLVED — independent adversarial suite added |
| C2 | Spec asked for `OS.exit_code`, which does not exist in Godot 4.3 | P2 | RESOLVED — Codex used `quit(code)`; spec practice noted |
| C3 | A stray `.pyc` from an earlier smoke test was committed | P2 | RESOLVED — removed, .gitignore extended |
| C4 | Screenshot tooling was fake: `--resolution` did not change the render, so all three "resolutions" were the same 1080x1920 image | **P0** | RESOLVED — shot.sh patches the project viewport per run; dimensions asserted |
| C5 | At 720x1280 the hero, enemy, HP bar, upgrade labels and skill buttons were clipped off-screen | P1 | RESOLVED — layout made proportional; re-verified by capture |
| C6 | Gold icon label overflowed its box at 720 wide | P2 | RESOLVED — clip_text |
| C7 | Faint ghost text from a stale framebuffer in the tall capture | P3 | MITIGATED — extra frame before capture; re-check next capture |
| C8 | Combat area has large empty upper region; actors sit low | P2 | RESOLVED — actors moved to the middle band |
| C9 | `_react_to_attack` crashed on an ignored/no-op attack result (only `_gui_input` guarded it) | P1 | RESOLVED — guard moved into `_react_to_attack` so every caller is safe |
| C10 | Damage numbers stacked at one point and were illegible under rapid taps | P2 | RESOLVED — positional scatter + horizontal drift |
| C11 | Falcon attack and boss-failure/Retry states not yet visually captured | P2 | RESOLVED — both captured |
| C12 | Falcon dealt damage but never visibly moved, so it did not appear to own its damage | P2 | RESOLVED — lunge tween fires on the same frame as the cyan number |
| C13 | Retry Boss button sits between hero and enemy inside the combat area | P3 | OPEN — acceptable in blockout, revisit in UI polish |
| C18 | Comparing an item against itself reported "DOWNGRADE" instead of no change, which could push a player to salvage a sidegrade | P2 | RESOLVED — added a SAME verdict |
| C19 | A duplicate local variable in `inventory_panel.gd` (introduced by me) caused a parse error that silently blanked the entire HUD while every logic suite still passed | **P1** | RESOLVED — fixed, and `run-tests.sh` now boots the game and fails on any parse error |
| C20 | The inventory UI offers a Salvage button on an equipped item | P2 | RESOLVED — button state derives from `salvage_refusal_preview()`, one source of truth |
| C21 | Tap damage was implemented LINEARLY while enemy HP grows exponentially, guaranteeing an impassable wall — and deviating from the brief's `base_tap x hero_level_multiplier` | **P1** | RESOLVED — multiplicative growth (1.06), chosen by measured sweep; first Prestige 9.6 -> 35.7 min, worst stall 86h -> 3.1h |
| C22 | Compiled `.translation` files were stale, so newly added Arabic keys rendered as raw `ui.tutorial.*` identifiers in the running game | P2 | RESOLVED — reimported; keys now render |
| C23 | Some production-facing strings were still English under Arabic | P2 | RESOLVED — `check_strings.sh` guard added so regressions fail the suite |
| C24 | Tutorial Skip button overlapped the settings gear | P2 | RESOLVED — anchored to the overlay bottom, safe-area aware |
| C25 | Mixed numeral systems under Arabic | P3 | RESOLVED — single formatter, western digits default under Arabic, `numeral_style` setting for the alternative |
| C27 | Offline formula was `seconds * max_stage * 0.5`, not the brief's `min(hours,8) * gold_per_second * 0.35`; it handed a stage-1 player 14400 gold and pulled first Prestige to 22.1 min | P2 | RESOLVED — brief formula implemented, measured at 26.1 min for an 8h absence |
| C28 | Equipment bonuses summed raw, so a full legendary set nearly doubled early damage (first Prestige 13.4 min) | P2 | RESOLVED — diminishing returns `raw/(1+2.5*raw)`, chosen by sweep |
| C29 | `sim_balance_c17.gd` passed raw multipliers straight to `set_relic_bonuses`, bypassing the diminishing-returns curve, so it reported equipment numbers players would never experience | P2 | RESOLVED — the sim now goes through the real curve |
| C33 | `next_level_gain` was derived inline in the heroes panel, so the number a player reads could drift from the real value | P2 | RESOLVED — one shared method, asserted equal to the real per-hero delta |
| C34 | `--start-stage` moved the run stage but not `max_stage`, so captures showed skills locked that a real player at that stage would already own — a misleading image, not a game bug (unlock logic verified correct at max_stage 90) | P2 | RESOLVED — the debug flag now raises `max_stage` too |
| C35 | Panel chrome (title, Close, Buy Quantity) kept the English text baked into the scene because `refresh_localized_text()` ran only on a language-change signal, never on open | P2 | RESOLVED — refreshed on open; Arabic panel now reads أبطال الدعم / كمية الشراء / إغلاق |
| C36 | I declared a debug variable against an anchor that lives in a different file, so it was never declared and every scene using the arena hit a parse error — caught only because I captured before running the parse guard | P2 | RESOLVED — declared properly; lesson: run the guard before trusting any capture |
| C32 | Enemy name labels took their colour straight from the enemy palette, so some names were nearly invisible against the body colour | P2 | RESOLVED — label colour now chosen by luminance contrast plus an outline; measured contrast spread went from near-zero to 225 |
| C30 | Clipped Arabic text in the top HUD ("الذهب — ACEHOLDER") | P2 | **RESOLVED** — two causes at once: a localized PLACEHOLDER sentence was being rendered inside a fixed 72px icon swatch, and under RTL `clip_text` cuts from the left, which is what produced "ACEHOLDER". The swatch is art, so it no longer renders text at all; the key was deleted from both CSVs; gold and stage labels are clip-guarded. Guard: `test_hud_layout.gd`. Evidence: `c30_ar_topbar.png`, `c30_en_topbar.png` |
| C31 | The claim that legendary gear was unobtainable before first Prestige was **unfounded** — there was no drop system and no unlock field, so nothing enforced it | **P1** | RESOLVED — `unlock_stage` added per rarity (legendary 50), enforced in `Inventory.add()`, proven by `test_equipment_gating.gd` |
| C26 | A unit test hardcoded a number derived from a balance value, so retuning balance failed a correctness test | P2 | RESOLVED — expectation now derived from `balance()` |
| C14 | `Prestige.apply()` resets a hardcoded key list, so any temporary field added later silently survives a prestige | P2 | **RESOLVED** — save split into run_state/permanent_state; apply() rebuilds run_state from the canonical factory |
| C16 | `SkillSystem.from_dict` coerced saved timestamps without type checks, raising engine errors on a corrupt save | P2 | RESOLVED — non-numeric values dropped, negatives clamped |
| C17 | **CLOSED** — every acceptance target now measured and passing (see docs/BALANCE.md). Was: First-Prestige pacing OFF TARGET: ~10.3 min to stage 25 versus the brief's 25-45 min, and the curve then jumps to ~56h for stage 50 — a cliff, not a slope. An earlier entry called 10 min "close to target"; that assessment was wrong and is corrected in docs/BALANCE.md | P2 | OPEN — acceptance criteria and baseline recorded in `docs/BALANCE.md`; re-measure after Gate 4 equipment + offline land |
| C15 | `scripts/shot.sh` dropped forwarded game args (my `shift 3` conflicted with Codex's `${@:4}`), so the prestige dialog never opened and the first capture looked like a plain HUD | P2 | RESOLVED — args forwarded correctly; Codex's claim of having inspected the dialog did not hold up |

## Blockers

- **Android export / on-device performance measurement is impossible here**: no
  Android SDK, no connected device. Gate 6 and the Android Performance matrix
  cannot be satisfied in this container. Desktop-proxy profiling under llvmpipe
  is available but is NOT valid evidence of Android performance and will not be
  presented as such.
- Software rendering (llvmpipe) means frame-time measurements are not
  representative of real GPU performance. Visual/layout evidence is valid;
  performance evidence is not.

## Gate 2 — combat vertical slice — **PASSED** (2026-08-18)

Logic lives in `scripts/combat/combat_state.gd` as a pure RefCounted class with
no node access, so the invariants are unit-testable headless. Presentation is
`combat_arena.gd` + `damage_number_pool.gd`.

| Requirement | Status | Evidence |
| --- | --- | --- |
| Tap input, normal + critical damage | PASS | `combat_motion.png` — yellow 5, orange-red 25 |
| Falcon damage (cyan) + visible strike | PASS | `combat_falcon.png` — falcon lunges toward the enemy and the cyan 2 appears in the same frame as the yellow 5 |
| Pooled damage numbers | PASS | 32 pre-allocated, reused; scattered so rapid taps stay readable |
| Enemy recoil + flash + HP + death | PASS | enemy renders flashed pink, HP 0%, stage advances |
| Gold reward | PASS | 12.4 Gold after kills |
| Hero upgrade + affordance | PASS | "TAP Lv.1 — 5 dmg / Cost 107.5" greyed when unaffordable |
| Stage progression | PASS | stage 1 -> 2 -> 3 across captures |
| Boss every 10 stages, 30s timer | PASS | `combat_boss.png` — "Stage 10 — BOSS", 29.7s, HP 4.13K (8x) |
| Boss failure keeps gold, Retry | PASS | `combat_boss_fail.png` (BOSS FAILED / TIME UP, Retry Boss button, gold kept) and `combat_boss_retry.png` (banner back to BOSS BATTLE, timer 29.9s, HP restored 100%) |
| Pool bounds allocation | PASS | `test_pool_bounds.gd` — stable at 32 nodes after 1200 hits |
| Composition | PASS | actors raised from y 0.60/0.52 to 0.42/0.34; dead space at top removed |
| Layout unbroken at all sizes | PASS | re-captured 720x1280, 1080x1920, 1080x2400 after the fixes |
| Save/reload | PASS | saves on stage change via SaveManager |

Test totals: 98 assertions passing (36 BigNumber + 12 adversarial, 36 save + 17
adversarial, 23 combat + 13 adversarial). `ALL SUITES PASSED`.

Evidence: `docs/evidence/combat_motion.png`, `combat_boss.png`, `combat_idle.png`

## Gate 3 — progression loop — **PASSED** (2026-08-18)

| Requirement | Status | Evidence |
| --- | --- | --- |
| Prestige refused when reward is 0 | PASS | logic + `prestige_zero.png` (confirm disabled, "Reach a higher stage first") |
| Player sees exactly what resets / keeps | PASS | `prestige_dialog.png` — WILL RESET (8) / WILL KEEP (8) / YOU RECEIVE 30 |
| Save immediately after prestige | PASS | `test_prestige_reload.gd` — reload source is `primary` |
| Close and reopen after prestige | PASS | fresh SaveManager instance reloads correct state |
| Relics / equipment / max_stage preserved | PASS | adversarial + reload tests |
| Gold / hero levels / temp buffs wiped | PASS | adversarial + reload tests |
| Skill double-activation blocked | PASS | re-activating while active returns false and does not raise the multiplier |
| Skills stack across kinds, never with themselves | PASS | adversarial test |
| Cooldowns survive close/reopen | PASS | absolute UTC ms timestamps; verified across a to_dict/from_dict cycle |
| 8 support heroes, 6 skills, 15 relics, data-driven | PASS | JSON under `resources/` |
| Dialog fits all portrait sizes | PASS | `prestige_dialog.png` (720x1280), `prestige_dialog_tall.png` (1080x2400) |

| C14 structural fix | PASS | `test_c14_future_field.gd` — invented run fields destroyed, invented permanent fields kept, without editing prestige.gd |
| Save migration v1/v2 -> v3 | PASS | `test_migration_adversarial.gd` — real on-disk fixtures, all permanent data intact |
| Support DPS in live combat | PASS | `test_dps_relics_adversarial.gd` — gold events == kills, stage advances == kills |
| DPS cannot hit dead enemy / during retry | PASS | same suite |
| Skill READY / ACTIVE / COOLDOWN visuals | PASS | `skills_active.png` (ACTIVE 10s/12s), `skills_states.png` (COOLDOWN 45s/90s/50s) — state shown by text, not colour alone |
| Skill expiry while game closed | PASS | `test_skill_timing_adversarial.gd` |
| Cooldown not bypassable by reopening | PASS | 5 close/reopen cycles cannot clear it |
| Corrupt/absurd timestamps safe | PASS | far-future, negative and non-numeric values handled |
| Relics change power and persist | PASS | reaches `get_tap_damage()`, survives reload and prestige |
| Post-Prestige run measurably faster | PASS | simulation: 20.0% faster to stage 50 |

Test totals: 14 suites, `ALL SUITES PASSED`.

### Simulation results (deterministic, seed 20260818)

| run | to stage 50 | to 50% of max | to 80% of max | upgrades | final gold |
| --- | --- | --- | --- | --- | --- |
| A (no relics) | 203290s | 620s | 14400s | 734 | 752.26M |
| B (post-prestige, damage relics) | 162640s | 490s | 11520s | 734 | 752.26M |

Post-Prestige improvement: **20.0% faster**. No NaN, INF or negative gold at any
step. Worst stall: 39200s at stage 49 (run A) — the intended progression wall.

Upgrades and final gold are identical by design: both runs kill the same number
of enemies to reach stage 50, so they earn the same gold and can afford the same
upgrades. Only elapsed time differs, which is exactly what relics should change.

## Gate 4 — MVP systems — **PASSED** (2026-08-18)

| Requirement | Status | Evidence |
| --- | --- | --- |
| Inventory + equipment foundation (5 slots, 4 rarities, 20 items) | DONE | `inventory.png` |
| Item score + comparison with per-stat deltas | DONE | `salvage_confirm.png` shows the compare block |
| Equip / unequip, wrong-slot rejected | DONE | adversarial suite |
| Lock / favorite | DONE | badges rendered as TEXT, not colour alone |
| Salvage safety | DONE | locked, equipped, rare+, favorite all refuse; exactly-once proven under 50 rapid calls |
| Offline rewards | DONE | `offline_dialog.png` (2h), `offline_capped.png` (8h cap line) |
| Settings affect the live game | DONE | Settings autoload drives real audio buses; 11 assertions |
| C20 salvage button state | DONE | `salvage_equipped_disabled.png`; UI state derives from a pure `salvage_refusal_preview()` so it cannot disagree with the logic |
| Localization en/ar | DONE | 127 keys in both files |
| Arabic RTL visual evidence | DONE | `rtl_ar_inventory.png`, `rtl_ar_tutorial.png` — RTL flow, correct shaping, translated rarities and badges |
| Tutorial | DONE | 9 assertions; `rtl_ar_tutorial.png` shows step text and Skip |
| Balance re-simulation | DONE | see docs/BALANCE.md — every C17 target now passes |
| Balance data validated | DONE | `balance_data.gd` + `test_balance_validation.gd`; schema_version added; invalid data fails loudly and falls back to safe defaults |
| Settings verified independently | DONE | `test_settings_adversarial.gd` — 18 assertions reading real `AudioServer` bus state back, including after a simulated restart |
| Reduced flashing verified visually | DONE | `flash_normal.png` vs `flash_reduced.png` — enemy region 238.1 vs 130.6 mean brightness, **45% dimmer**, recoil and HP response retained |
| Vibration | DONE (scoped) | gated through `Settings.vibrate()`; dispatch counter proves no request is issued when disabled. **No physical device available — device vibration is NOT claimed** |
| C23 hardcoded English | RESOLVED | `check_strings.sh` guard in run-tests.sh; Arabic captures show localized HUD |
| C24 Skip overlap | RESOLVED | Skip anchored to the bottom of the overlay; `rtl_ar_1080x2400.png` |
| C25 numeral policy | RESOLVED | one formatter, `numeral_style` setting, western digits default under Arabic |

Independent adversarial totals this gate: inventory 23, offline 13.
Full suite: 16 suites, `ALL SUITES PASSED`, plus a new parse guard.

## Gate 5 — content expansion (in progress)

### Group 1 — acquisition + inventory safety (DONE)

| Requirement | Status | Evidence |
| --- | --- | --- |
| Deterministic seeded reward generator | DONE | same seed -> same item, verified across seeds |
| Rewards never exceed unlock_stage | DONE | 4 stages x 40 seeds, zero violations |
| Legendary never granted below stage 50 | DONE | 200 seeds, zero occurrences |
| Boss first-clear grants exactly once | DONE | 25 farming repeats grant nothing |
| Reload cannot repeat a first clear | DONE | saved first-clear map refuses on reconstruct |
| Rollback leaves no partial state | DONE | item removed, stage retryable |
| Loading must not delete owned gear | DONE | a legendary item survives a load at max_stage 1, while *acquiring* one is still refused |
| Unknown ids quarantined, not deleted | DONE | documented policy, preserved in save |
| Invalid reward table refuses safely | DONE | reason "invalid" |

Four separate doors now exist where one used to: `acquire()` enforces the gate,
`load_owned()` and `migrate_owned()` never delete gear for being "too rare", and
`debug_add()` is isolated. `from_dict()` uses the lenient path — that separation
is what stops a balance-data change from confiscating a player's equipment.

Independent adversarial totals this group: rewards 9, first-clear 9.

### Group 2 — reward reliability, schemas, worlds (DONE)

**Failure injection** (`test_reward_failure_injection.gd`, 11 assertions) drives
a substituted save adapter, not hand-edited end state:

| Injected failure | Result |
| --- | --- |
| save fails at commit | clean retry: not claimed, no reward |
| retry after rollback | succeeds exactly once |
| reload after interruption | cannot re-grant |
| interruption at every boundary (0,1,2) | every outcome is a valid state |
| pity counter on failed save | not half-advanced |
| `debug_add()` in a release build | refused |

The invariant holds: after any failure the player is either (A) unclaimed with
no reward, or (B) claimed with exactly one reward. Never claimed-without-reward,
never a duplicate, never a reward below its unlock stage.

**Content validation**: `resources/schemas/content_schema.json` (versioned) plus
`autoload/content_validator.gd`, failing loudly in debug with file, entry id and
field named. Broken-fixture tests cover each rejection rule.

**Worlds** (`test_worlds_adversarial.gd`, 15 assertions):

| world | stages | palette |
| --- | --- | --- |
| oasis_frontier | 1-33 | sand/teal |
| moonlit_dunes | 34-66 | night blue/violet |
| ruins_of_the_sun_kingdom | 67-100 | crimson/gold |

Contiguous, no gaps or overlaps; every stage 1-100 maps to exactly one world;
both sides of every boundary checked; stages beyond 100 clamp to the last world
(documented fallback); palettes are distinct; all name/desc keys exist in en and ar.

Live evidence — background colour measured from the rendered frame, not assumed:
stage 1 RGB(204,168,106), stage 34 RGB(132,125,170), stage 67 RGB(188,114,66).
`world_stage1.png`, `world_stage34.png`, `world_stage67.png`.

31 suites, `ALL SUITES PASSED`.

### Group 3 — twelve enemies, four bosses (DONE)

| world | enemies |
| --- | --- |
| oasis_frontier | dune_raider, oasis_scarab, thorn_lizard, mirage_stalker |
| moonlit_dunes | night_howler, dust_wraith, moon_moth, glass_serpent |
| ruins_of_the_sun_kingdom | sunstone_sentinel, cursed_regalia, ember_djinn_construct, ossuary_warden |

Boss archetypes: sandstorm_colossus, lunar_glasswing, ember_crown_construct, vaultback_behemoth — they REPEAT across the
ten boss stages, so first-clear ownership is keyed by **encounter id (stage)**,
never by archetype. Clearing an archetype at stage 10 does not block its reward
at stage 40; that case has its own test.

**Simultaneous-death rule (documented and implemented):** lethal damage accepted
while `encounter_state == ACTIVE` wins; once the encounter is officially FAILED,
later damage is ignored. `_death_processed` guards the shared kill transition so
four sources landing in one frame process the kill exactly once. Both orderings
are tested, so the outcome does not depend on frame-processing order.

Independent adversarial results:
- `test_enemies_bosses_adversarial.gd` — 12/12: deterministic selection, no
  enemy ever outside its world, boss stages never return a regular enemy,
  four sources kill once, repeated archetype still grants its own first clear.
- `test_encounter_race.gd` — 10/10: both race orderings, rapid taps during
  death, and transitions 30->31, 33->34, 60->61, 66->67, 90->91, 100->101.

Balance after enemy modifiers: first Prestige **36.2 min** (target 25-45),
legendary 27.0, 8h offline 25.8, stage 50 in 13.7h, no NaN or negative gold.

Group 2 visual evidence completed here: `world1_en.png`, `world34_en.png`,
`world67_en.png`, `world34_ar_720.png`, `world67_ar_2400.png`.

34 suites, `ALL SUITES PASSED`.

### Group 4A — eight heroes, six distinct skills (DONE, visually verified)

| hero | role | unlock stage | milestone effect types |
| --- | --- | --- | --- |
| dune_scout | ranged | 1 | all_hero_dps_mult, crit_chance_add |
| oasis_guard | melee | 8 | self_dps_mult, tap_damage_add |
| sun_priestess | support | 18 | gold_mult, skill_duration_mult |
| falconer | ranged | 32 | all_hero_dps_mult, crit_chance_add, self_dps_mult |
| scarab_knight | melee | 48 | all_hero_dps_mult, self_dps_mult, tap_damage_add |
| mirage_weaver | magic | 64 | all_hero_dps_mult, self_dps_mult, skill_duration_mult |
| djinn_binder | magic | 82 | all_hero_dps_mult, self_dps_mult, skill_cooldown_mult |
| star_vizier | support | 100 | gold_mult, skill_cooldown_mult, skill_duration_mult |

Milestone effects vary by role rather than every hero being a DPS clone:
`all_hero_dps_mult`, `tap_damage_add`, `gold_mult`, `crit_chance_add`,
`skill_duration_mult`, `self_dps_mult`. The earliest hero scales ALL heroes, so
it stays relevant late.

**Skills are mechanically distinct, verified in isolation:** sand_fury moves
tap damage only; golden_wind moves gold only; critical_eclipse adds crit chance
clamped to <= 0.95; falcon_storm changes falcon RATE; ancestor_call moves
support DPS; time_fracture adds +10s to the boss timer, clamped to [0, 60], so
it can never produce a negative or infinite timer.

Independent adversarial results — `test_heroes_skills_adversarial.gd`, 17/17:
- rapid hire input hires exactly once and spends gold once
- **a bulk buy of 29 levels produces exactly the same DPS as 29 single buys**,
  which is the milestone-fires-once proof
- locked hero refused, unknown id safe, level 5000 stays finite
- same skill never stacks with itself

Balance after heroes and skills: first Prestige **35.4 min** (target 25-45),
legendary 28.1, 8h offline 25.6, no NaN or negative gold.

Carry-over fixes: the hardcoded "DESERT BACKGROUND" label now follows the
active world, and `--debug-boss` captures each archetype.

Evidence:
- Bosses (all four archetypes): `boss_sandstorm.png`, `boss_lunar_glasswing.png`,
  `boss_ember_crown_construct.png`, `boss_vaultback_behemoth.png` — each shows
  the localized name, its own palette and silhouette, HP bar, active timer,
  damage numbers, hero facing the boss and the falcon beside it.
- Boss journey: `journey_fail.png` (BOSS FAILED / TIME UP), `journey_retry.png`.
- Skill states: `boss_lunar_glasswing.png` shows LOCKED with the unlock stage in
  text; `skills_all_states.png` shows ACTIVE with a countdown and READY.
- Heroes: `heroes_panel.png` (en), `heroes_ar_720.png` (ar RTL),
  `heroes_en_2400.png` (tall).

Runtime checks (`test_ui_matches_runtime.gd`, 7/7) confirm the panel is not
lying to the player: Buy Max buys exactly the advertised quantity and one more
is unaffordable, the displayed next-level gain equals the real per-hero DPS
delta, crossing a milestone actually raises DPS, and reopening mid-ACTIVE or
mid-COOLDOWN restores the true state.
35 suites, `ALL SUITES PASSED`.

## Gate 5 group 4A — CLOSED

Closure evidence: the three journeys were driven through production code paths
and captured, with every displayed figure printed next to the value the shared
calculation functions return.

**1. Hero purchase journey** (`hero_journey_locked.png`, `_affordable.png`,
`_hired.png`, `_upgraded.png`, `_buymax.png`, `_milestone.png`, Oasis Guard,
1,000,000 starting gold). Card text matched the roster on every step:

| Step | Gold | Level | Hero DPS | Next-level gain | State shown |
| --- | --- | --- | --- | --- | --- |
| locked | 1M | 0 | 0 | 7 | LOCKED — Unlock at stage 8 |
| affordable | 1M | 0 | 0 | 7 | AVAILABLE — AFFORDABLE |
| hired | 999.86K | 1 | 7 | 7.56 | AVAILABLE — AFFORDABLE |
| upgraded | 999.71K | 2 | 14.56 | 8.15 | AVAILABLE — AFFORDABLE |
| Buy Max | 46.15K | 78 | 44.75K | 2.39K | AVAILABLE — NOT AFFORDABLE |
| milestone | 997.92K | 10 | 199.26 | 28.69 | Milestone 10 / 25 |

The milestone is a real effect, not a label: hero DPS goes 86.22 at level 9 to
199.26 at level 10 (x2.31 = x1.155 growth x2.0 milestone), measured level by
level.

**2. Boss victory and first clear** (`boss_victory_kill.png`, `_victory.png`,
`_reward.png`, `_replay.png`, `_reload.png`). Stage 10 Sandstorm Colossus,
killed by a real tap through the ordinary death path, from a wiped save each
run: items 0 -> 1, granted `dune_knife`, and the live inventory capture shows
exactly "Dune Knife — COMMON · Score 15". Killing the same boss again leaves the
count at 1 (`already_cleared`); reloading the written save also leaves it at 1.

**3. All six skills live** (`skill_<id>_ready|active|cooldown.png`, 18 captures).
Each ACTIVE capture carries the effect the data promises and reverts on
COOLDOWN: sand_fury tap x3.0, falcon_storm falcon rate x4.0, golden_wind gold
x2.5, ancestor_call support DPS x3.0, critical_eclipse crit damage x2.0, and
time_fracture boss timer 30.0s -> 40.0s while active only. Button countdowns
match the data (ACTIVE 10/8/12/1/15/9 s; COOLDOWN from 45/60/90/120/75/50 s).

**Falcon Storm frame sequence** (`falconseq_storm_00..11.png` vs
`falconseq_baseline_00..11.png`), consecutive rendered frames, not a still:

- Movement: falcon x = 48.2 (rest) -> 343.7 -> 281.6 -> 48.2 across successive
  frames, with the cyan falcon damage number on the boss in the same frame.
- Rate: 12 strikes in 4.54s with Falcon Storm active versus 3 strikes in 4.49s
  without it — x4.0, exactly the declared multiplier.

Bugs found and fixed during this closure pass:

- **C37/P2** — after a kill the HUD read the new stage over the corpse of the
  old encounter ("Stage 11 — BOSS" while the stage-10 boss was still dissolving).
  The HUD now describes the encounter on screen until the next one spawns.
- **C38/P1** — a run starting on a stage other than the saved one inherited the
  saved boss countdown, so a boss appeared already at TIME UP / BOSS FAILED. The
  saved timer is now only restored for the stage it belongs to.
- **C39** — my own capture driver used `Time.get_ticks_msec()` while the HUD
  ticks on unix milliseconds, so an "ACTIVE" skill rendered READY. Caught by
  printing the real button text at capture time rather than trusting the state
  object; all 18 skill captures were retaken.

Tests: `test_group4a_closure.gd` (new, 45 checks) pins the journeys as
invariants — hire/upgrade/Buy Max/milestone arithmetic, first-clear grant,
replay refusal, reload without duplication, a different boss stage still
granting, and each skill's effect appearing and disappearing with its window.
37 suites, `ALL SUITES PASSED`, with string, translation-freshness and parse
guards green. C17 balance re-measured after all fixes: first prestige 35.5 min
(target 25-45), all equipment and offline paths 25.8-35.5 min, `CRITERION 1: MET`.

Group 4A is closed.

## Visual re-theme — world 1 vertical slice (awaiting approval)

The owner approved Option A: the visual theme and content names move to the
neutral cartoon fantasy of the supplied package, while Arabic and RTL stay.
No id changed anywhere, so saves, first clears and owned equipment are
untouched.

**Final asset count: 46 of 46 built.** 26 characters, enemies, bosses and the
companion come from the package. All 20 equipment icons now exist: 8 cleaned
from the package (weapon and aura slots) and **12 drawn from scratch** by
`tools/make_equipment_icons.py`, because the package carries weapon-type icons
only. The real slot ids are `weapon`, `head`, `outfit`, `aura` and
`companion_charm` — there is no `armor` or `amulet` slot — so the twelve are
4 `head`, 4 `outfit` and 4 `companion_charm`, verified against
`resources/equipment/equipment.json` before drawing. Every icon is 256x256
lossless WebP, transparent, centred inside a 12% safe margin, with a rarity
frame whose corner brackets thicken by tier and a badge of one to four pips, so
rarity reads without colour. Full mapping and rejected options:
`docs/ASSET_MAPPING.md`.

**World resource release.** Measured live over four switch cycles
(`--demo-world-cycle 4`): with Emerald Meadow active, 4 layers resident and
50.10 MB of texture memory; after switching to a world with no built art,
**0 layers resident, 0 still in the resource cache, 17.01 MB** — and identical
figures on every cycle, so nothing accumulates. The four layers therefore cost
33.1 MB while their world is on screen and nothing when it is not.

**Sky sharpness.** The sky was being painted at 540x960 and stretched. It is now
authored directly on the 1080x1920 master: the vertical gradient is evaluated at
1920 rows instead of being an upscaled 959-row ramp, and only the cloud pixels
are resampled, once. Inspected at 1080x1920 and 1080x2400 — cloud edges are
crisp and the gradient shows no banding.

**Background cleaning.** The package's own crops keep the reference sheet's
flat colour wherever the silhouette encloses it, plus its drop shadow and pale
halo. Measured on the 34 selected assets, before and after `clean_assets.py`:

| Check | Before | After |
| --- | --- | --- |
| Sheet colour sealed inside a silhouette | 6,643 px in one boss alone | 0 px across all 34 |
| Sheet colour on the cut edge (halo) | present on 18 sprites | 0 px across all 34 |
| Neighbouring-character fragments at the crop border | present | 0 |
| Total background pixels removed | — | 46,436 |

Two discriminators do the work: the sheet's warm cast (red well above blue)
separates it from white fur and pale ice, and the artwork's bold dark outline
blocks a flood fill that starts from the transparent exterior. A first attempt
that matched plain colour distance ate the frost moth's white fur, which is why
the rule is written the way it is.

`tests/unit/test_sprite_background.gd` enforces all three checks. Negative
control: dropping a raw concept crop back in fails it with 6,643 px.

**Parallax structure.** `oasis_frontier` is rebuilt from the flat 540x959
concept into four layers on the 1080x1920 master canvas, segmented by the
painting's own composition rather than sliced into equal bands:

| Layer | Stored | Drawn width vs viewport | Content |
| --- | --- | --- | --- |
| sky | 1080x1920 | 1.00 | Sky and clouds only, gradient authored at master size |
| distant | 892x1344 | 1.18 | Mountains, ruins, trees |
| arena | 1080x1920 | 1.00 | The floor the actors stand on |
| foreground | 1028x1632 | 1.12 | Framing plants, stones and crystals |

The wider layers travel further as the run advances through the world's stages,
so progress pans the depths at different speeds. Back layers are stored at
reduced resolution because they carry soft content: texture memory with the world
on screen is 50.3 MB against a 17.0 MB baseline, so the four layers cost
33.1 MB and are fully released on a world switch.

**Performance.** Average process time was 162 ms with the built world and
169 ms on a world with no art, i.e. the artwork added no measurable CPU cost.
Both numbers come from llvmpipe software rendering in this container and are
**not** device performance; no Android SDK or device is available here.

Bugs found and fixed during the slice:

- **C40/P1** — the parallax layers painted over the HUD bars, hiding gold,
  stage and the skill row, because they are deliberately larger than the
  combat window. The window now clips them.
- **C41/P1** — at 720x1280 and 1080x2400 the arena floor was missing and the
  sky's below-horizon fill showed instead: a `TextureRect` will not shrink
  below its texture size unless `expand_mode` is `IGNORE_SIZE`, so the arena
  layer stayed at master size and its band fell outside the visible window.
  Caught by reading back the live layer geometry rather than trusting the shot.
- **C42/P2** — the enemy name was printed across the creature's face. The rect
  is scaled per enemy about its centre, so the label is now placed after layout
  and its scale inverted.
- **C43** — a first cleaning pass keyed on colour distance removed the frost
  moth's white fur. Replaced with the warm-cast rule above.
- **C44** — the concept package was being imported by Godot (137 files into
  `.godot/imported`), which would ship concept art in an export. It now carries
  a `.gdignore`.

The content validator was tightened rather than relaxed: `asset_status` may now
be `CONCEPT_SOURCED` instead of only `PLACEHOLDER`, but only when the sprite
file actually exists, and a world background layer naming a `res://` path must
resolve or the world is rejected.

Evidence: `docs/evidence/slice1/` — normal enemy, boss, inventory, heroes,
skills and equipment screens at 720x1280, 1080x1920 and 1080x2400 in English
and Arabic (36 captures), composed into three review boards:
`slice1_review_720x1280.webp`, `slice1_review_1080x1920.webp`,
`slice1_review_1080x2400.webp`.

A sixth defect surfaced while reviewing them:

- **C45/P2** — the skills panel kept its English title and Close button when
  opened in Arabic, the same defect class as C35 on the heroes panel.
  `refresh_localized_text()` is now called on open, not only on a language
  change.

Group 4A stays closed; no Group 4B content was added.

## Visual polish pass (awaiting final approval)

Art direction approved; this pass answers the audit's seven blockers.

**1. No visible placeholder text, either language.** `HERO DPS — PLACEHOLDER`
now reads the roster's real damage per second through `hud.hero_dps`. The unused
`hud.desert_placeholder`, `hud.hero_placeholder`, `hud.falcon_placeholder` keys
were deleted and `hud.enemy_placeholder` became `hud.enemy_unknown`.
`grep PLACEHOLDER localization/*.csv` returns **0** lines.

**2. Gold.** The 72x64 yellow block is a drawn cartoon coin
(`assets/sprites/ui/coin.webp`), 64px, with the amount at 30px on a dark plate.

**3. Overlay contrast.** World name, boss warning, boss timer, HP readout, gold
and stage now carry a dark translucent plate plus a 6px outline and a drop
shadow; the enemy name has the same treatment at 21px; damage numbers went to
32px (42px critical) with an 8px outline and a shadow. The enemy HP bar gained
a dark trough and a bright fill — it was a pale bar on pale grass.

**4. Touch size and wasted space.** Skill cards 88px -> 168px tall, navigation
96px -> 112px with 16pt -> 22pt labels, and the upgrade row became two 108px
panelled buttons at 24pt, which fills the band that used to hold two small
captions. Skill card type is sized from the card width, so nothing clips at
720x1280 in Arabic.

**5. Six skill icons with four distinguishable states.** Each skill has its own
drawn icon (fist, diving falcon, coins in a gust, cracked clock, three spirits,
eclipse). State is carried by the icon treatment as well as by text and framing:
READY full colour with a gold frame, ACTIVE full colour inside a heavy green
ring with a countdown, COOLDOWN drained to grey with a thin frame and a
countdown, LOCKED a flat silhouette with the unlock stage. Colour alone never
carries the state.

**6. All twenty equipment icons proven.**
`docs/evidence/equipment_contact_sheet.webp` shows every item with its id, slot
and rarity, grouped by the five real slots — `weapon`, `head`, `outfit`, `aura`,
`companion_charm` — four rarities each. A new `--debug-inventory-all` fixture
grants one of every defined item so the live panel can be captured too.

**7. Tall-screen layout.** The item list now hugs its contents up to 52% of the
panel height, snapped to whole rows, so the comparison and the actions sit
directly under the selection instead of being pushed to the far bottom; spare
height collects below the actions.

Also: hero cards went to 19pt body text with a 20pt cost/action button on a
wider card, which the audit flagged as a weak hierarchy.

Evidence: `docs/evidence/slice2/` — combat, boss, skills panel, live skill
states, all-items inventory, equipment comparison and heroes, in English and
Arabic at 720x1280 and 1080x2400.

## Moonlit Wildwood and Obsidian Citadel — both worlds built

**Arabic health readout fixed first.** The label read `صحة 8.5 / 0`: two
separate `%s` placeholders let the bidirectional algorithm reorder the runs, so
the maximum was announced as the current value. The pair is now emitted as one
Unicode-isolated left-to-right run (`Settings.format_pair`, U+2066/U+2069) and
the Arabic string became `الصحة: %s`. Regular enemies and bosses share the one
call site, so both are covered. `test_rtl_numeric_isolation.gd` pins it across
zero, full, decimal, BigNumber and extreme BigNumber values in both locales, and
fails if any caller goes back to two placeholders. Verified on screen in Arabic:
**الصحة: 3.5 / 8.5** at 720x1280 and 1080x2400.

**Both worlds rebuilt as four layers each.** The sky segmentation was
generalized: it now grows from the top edge by distance from the sky's own
colour instead of by blueness, which is what let a daylight meadow, a night
forest and a volcanic sky all segment with one rule, and it stops at the first
row the sky no longer covers so the fill cannot leak down a matching cliff.

| World | sky | distant | arena | foreground |
| --- | --- | --- | --- | --- |
| Emerald Meadow | moon-free daylight gradient + clouds | mountains, ruins, trees | sand disc | plants, stones, crystals |
| Moonlit Wildwood | night gradient + moon | moonlit trees and ruins | pale teal glade | glowing mushrooms and roots |
| Obsidian Citadel | crimson-violet sky | volcanic fortress and gate | dark stone platform with lava veins | magenta crystals and braziers |

Every world's sky and arena layer is authored at the full 1080x1920 master;
`test_world_boundaries.gd` asserts that, plus continuous stage ranges, four
correctly named layers per world that exist on disk, and the right world owning
its first, middle and last stage.

**World resource release, four full cycles across all three worlds (12
switches):** baseline 51.87 MB; each world resident at 51.95-52.45 MB with
exactly 4 layers and **foreign_cached = 0** on every measurement, so no other
world's layers are ever held; after releasing, **19.37 MB with 0 layers**. The
four layers cost ~32.6 MB while their world is on screen and are fully returned.
Memory does not grow across cycles (0.5 MB drift, not a trend). These are
llvmpipe software-rendering figures and are **not** Android performance.

**Balance untouched.** No balance value was edited; the C17 simulation still
reports first prestige at **35.5 min**, `CRITERION 1: MET`, identical to the
run before the worlds work.

**Known design point, not a defect:** boss archetypes are milestone-based
(`world_id: "milestone"`) with an escalating hp_modifier ramp of 1.00 / 1.08 /
1.16 / 1.25 by stage, so the Ancient Treant can appear inside the Citadel. Enemy
pools *are* world-bound and correct. Rebinding bosses to worlds would change
which modifier lands on which stage — a balance change — so it is left for an
explicit decision rather than made silently.

Evidence: `docs/evidence/worlds23/` — normal and boss combat plus the skill
showcase for both worlds, English and Arabic, at 720x1280 and 1080x2400, and the
live all-items inventory through the debug-only path (`OS.is_debug_build()` and
an explicit flag, unreachable in a release build).
`docs/evidence/equipment_contact_sheet.webp` proves 20 unique ids with English
display name, slot and rarity, and the builder asserts on any duplicate.

## Corrective checkpoint — boss visual identity decoupled

The Citadel was showing `Ancient Treant`, a forest boss inside a volcanic
fortress. Fixed by separating what a boss *is* from what it *looks like*.

**Architecture.** Each world entry carries a `boss_visuals` map from mechanical
archetype id to `{visual_id, name_key}`. `Worlds.boss_visual_for(stage,
archetype)` resolves it, and the arena uses the result for the sprite and the
displayed name only. Combat still runs entirely on the archetype: encounter id,
stage number, HP multiplier, gold multiplier, timer, reward table, first-clear
record and save fields are untouched. Twelve visuals were cleaned from the
approved package, four per world:

| Archetype (mechanics) | Emerald Meadow | Moonlit Wildwood | Obsidian Citadel |
| --- | --- | --- | --- |
| `sandstorm_colossus` | Ancient Treant | Mushroom Monarch | Magma Horn Beast |
| `lunar_glasswing` | Grove Hydra | Crystal Wyrm | Fortress Warden |
| `ember_crown_construct` | Meadow Roc | Moonlit Owl Guardian | Clockwork Crown King |
| `vaultback_behemoth` | Stoneshell Titan | Frostmane Behemoth | Obsidian Star Knight |

**Proof that nothing mechanical moved.** `git diff` against the previous commit
reports **no change at all** to `balance.json`, `equipment.json`, `bosses.json`,
`support_heroes.json`, `skills.json`, `relics.json` or `reward_tables.json`; the
only data change is the additive `boss_visuals` block. `test_boss_visuals.gd`
pins the authored HP multiplier (1.00 / 1.08 / 1.16 / 1.25) and 30s timer for
every boss stage, one encounter per stage with a unique id, first clear granted
exactly once and surviving a reload, a kill on the final tick still counting as
a victory rather than also timing out, and a tap after a timeout not reviving
the encounter. It also asserts the Citadel never shows the treant and the meadow
never shows a volcanic or mechanical boss.

**The validator fails loudly.** A deliberately broken mapping produces:
`ContentValidator: file=res://resources/worlds/worlds.json
id=ruins_of_the_sun_kingdom field=boss_visuals.ember_crown_construct.visual_id:
world 'ruins_of_the_sun_kingdom' (stages 67-100) maps archetype
'ember_crown_construct' to invalid visual 'not_a_sprite'`. A boss archetype may
only claim `CONCEPT_SOURCED` when every world maps it to a sprite that exists.

**Three aura icons redrawn.** `ember_halo`, `djinn_radiance` and
`solar_ascendance` looked like a wand, a wand and a spellbook. They are now a
golden flame halo, a violet energy ring with orbiting crystal shards, and a sun
disc inside a radiant orbit. Ids, rarity, stats, save data and display names are
unchanged, and the other seventeen icons were not touched.

**Balance simulation.** The C17 simulation is not fully deterministic: five runs
on identical code give 2117-2155s (35.3-35.9 min). The figures recorded before
this change (2115s / 35.3 min and 2128s / 35.5 min) sit inside that band, and no
balance value was edited, so first-prestige timing is unchanged within the
simulation's own tolerance. `CRITERION 1: MET` on every run.

Evidence: `docs/evidence/boss_visuals/` — one boss per world, English and
Arabic, at 720x1280 and 1080x2400.

## Next highest-priority action

Gate 5 group 4B: fifteen Relics and the relic sensitivity simulations, then the
closing Gate 5 regression. Open question for the owner: whether boss archetypes
should be rebound to worlds, which is a balance change and needs a re-measured
progression run.

## Placeholders

6 placeholder categories, 0 asset files — all drawn in-engine as labelled
rectangles. Recorded in `docs/ASSET_MANIFEST.md`.
