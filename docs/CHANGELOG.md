# Changelog

## Gate 4 corrective checkpoint (2026-08-18)

- C30 root-caused: a localized "PLACEHOLDER" sentence rendered inside a 72px
  icon swatch, clipped from the left under RTL. The swatch renders no text now,
  the key is gone from both CSVs, and `test_hud_layout.gd` guards the top HUD
  against any label overflowing for any BigNumber magnitude.
- C31: equipment `unlock_stage` gating added and enforced. Legendary gear is
  locked until stage 50, so it cannot exist before the first Prestige at 25 —
  previously this was only assumed, with no mechanism behind it.

## Gate 4 close (2026-08-18)

- Equipment diminishing returns (k=2.5) and the brief's offline formula, both
  tuned by measured sweep. Every C17 pacing target now passes; C17 closed.
- Balance data validated with a schema version; invalid data fails loudly and
  falls back to safe defaults instead of corrupting progression silently.
- Guards added to run-tests.sh: hardcoded player-facing strings, stale compiled
  translations, and script parse errors all fail the suite.
- Salvage button state derives from one pure preview function (C20).
- Settings verified against real AudioServer buses; reduced flashing measured at
  45% dimmer with recoil and HP feedback retained.
- Tutorial Skip moved out of the settings gear; single numeral policy.

## Gate 3 — Progression loop (2026-08-18)

**Structural**
- Save data split into `run_state` (destroyed by Prestige) and
  `permanent_state` (never touched). Schema v3.
- `Prestige.apply()` no longer erases a hardcoded key list; it rebuilds
  `run_state` from `SaveManager.default_run_state()`, so any temporary field
  added in future is reset automatically. (Resolves C14.)
- Migration v1 → v2 → v3 verified against real on-disk fixtures; no permanent
  player data is lost.

**Added**
- 8 support heroes, 6 active skills, 15 relics — all data-driven from JSON.
- Support-hero DPS wired into live combat (`dps_tick`), routed through the same
  kill transition as tapping so rewards cannot duplicate.
- Relic damage/gold bonuses reach live combat calculations.
- Prestige confirmation dialog: WILL RESET / WILL KEEP / YOU RECEIVE.
- Deterministic progression simulation with milestone and stall reporting.

**Fixed**
- `SkillSystem.from_dict` trusted saved timestamps; corrupt values now dropped.
- `scripts/shot.sh` dropped forwarded game arguments, hiding UI from capture.

## Gate 2 — Combat vertical slice
- Tap/critical/falcon/DPS damage, pooled damage numbers, enemy reactions,
  boss timer, failure and Retry.

## Gate 1 — Technical foundation
- BigNumber, atomic versioned saves with backup/recovery, portrait boot.
