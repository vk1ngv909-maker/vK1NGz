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

## Next highest-priority action

Gate 5 group 4: eight support heroes, six skills and fifteen relics as validated
content, then the full twenty-item equipment set, then the closing simulation
and regression.

## Placeholders

6 placeholder categories, 0 asset files — all drawn in-engine as labelled
rectangles. Recorded in `docs/ASSET_MANIFEST.md`.
