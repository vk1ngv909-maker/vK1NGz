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
| C8 | Combat area has large empty upper region; actors sit low | P2 | OPEN — composition pass pending |
| C9 | `_react_to_attack` crashed on an ignored/no-op attack result (only `_gui_input` guarded it) | P1 | RESOLVED — guard moved into `_react_to_attack` so every caller is safe |
| C10 | Damage numbers stacked at one point and were illegible under rapid taps | P2 | RESOLVED — positional scatter + horizontal drift |
| C11 | Falcon attack and boss-failure/Retry states not yet visually captured | P2 | OPEN — logic tested, visuals pending |

## Blockers

- **Android export / on-device performance measurement is impossible here**: no
  Android SDK, no connected device. Gate 6 and the Android Performance matrix
  cannot be satisfied in this container. Desktop-proxy profiling under llvmpipe
  is available but is NOT valid evidence of Android performance and will not be
  presented as such.
- Software rendering (llvmpipe) means frame-time measurements are not
  representative of real GPU performance. Visual/layout evidence is valid;
  performance evidence is not.

## Gate 2 — combat vertical slice (in progress)

Logic lives in `scripts/combat/combat_state.gd` as a pure RefCounted class with
no node access, so the invariants are unit-testable headless. Presentation is
`combat_arena.gd` + `damage_number_pool.gd`.

| Requirement | Status | Evidence |
| --- | --- | --- |
| Tap input, normal + critical damage | PASS | `combat_motion.png` — yellow 5, orange-red 25 |
| Falcon damage (cyan) | LOGIC PASS, visual unconfirmed | `falcon_tick` tested; not yet captured mid-attack |
| Pooled damage numbers | PASS | 32 pre-allocated, reused; scattered so rapid taps stay readable |
| Enemy recoil + flash + HP + death | PASS | enemy renders flashed pink, HP 0%, stage advances |
| Gold reward | PASS | 12.4 Gold after kills |
| Hero upgrade + affordance | PASS | "TAP Lv.1 — 5 dmg / Cost 107.5" greyed when unaffordable |
| Stage progression | PASS | stage 1 -> 2 -> 3 across captures |
| Boss every 10 stages, 30s timer | PASS | `combat_boss.png` — "Stage 10 — BOSS", 29.7s, HP 4.13K (8x) |
| Boss failure keeps gold, Retry | LOGIC PASS, visual unconfirmed | adversarial tests 5-7 |
| Save/reload | PASS | saves on stage change via SaveManager |

Test totals: 95 assertions passing (36 BigNumber + 12 adversarial, 36 save + 17
adversarial, 23 combat + 13 adversarial). `ALL SUITES PASSED`.

Evidence: `docs/evidence/combat_motion.png`, `combat_boss.png`, `combat_idle.png`

## Next highest-priority action

1. Capture falcon attack (cyan damage) and the boss-failure / Retry Boss state.
2. Close C8 composition (actors sit low, large empty upper area).
3. Rapid-tap node-count measurement to prove the pool bounds allocation.
4. Then Gate 2 exit review.

## Placeholders

6 placeholder categories, 0 asset files — all drawn in-engine as labelled
rectangles. Recorded in `docs/ASSET_MANIFEST.md`.
