# Changelog

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
