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
| C14 | `Prestige.apply()` resets a hardcoded key list, so any temporary field added later silently survives a prestige | P2 | **RESOLVED** — save split into run_state/permanent_state; apply() rebuilds run_state from the canonical factory |
| C16 | `SkillSystem.from_dict` coerced saved timestamps without type checks, raising engine errors on a corrupt save | P2 | RESOLVED — non-numeric values dropped, negatives clamped |
| C17 | First-Prestige pacing: reaching stage 50 takes ~56 simulated hours. Stage 25 (first prestige) is ~10 minutes, close to the brief's 25-45 min target, so this is wall depth rather than a broken curve | P2 | OPEN — Milestone 3 balance work |
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

## Next highest-priority action

**Gate 4 — MVP systems.** Inventory and equipment (compare, lock, salvage with
confirmation for Rare+), offline rewards dialog on the existing collect-once
guard, settings, localization structure, and tutorial — without breaking the
Gate 2/3 loops.

## Placeholders

6 placeholder categories, 0 asset files — all drawn in-engine as labelled
rectangles. Recorded in `docs/ASSET_MANIFEST.md`.
