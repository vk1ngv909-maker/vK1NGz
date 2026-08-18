# Implementation Plan

| Gate | Scope | Status |
| --- | --- | --- |
| 1 | Portrait boot, BigNumber, save recovery | **PASSED** |
| 2 | Combat vertical slice | **PASSED** |
| 3 | Progression loop: support DPS, skills, Prestige, Relics | **PASSED** |
| 4 | MVP systems: inventory, equipment, offline rewards, settings, localization, tutorial | NEXT |
| 5 | Content expansion (only after 1-4) | not started |
| 6 | Release candidate | blocked — no Android SDK/device in this environment |

## Gate 4 entry criteria (next session)

Inventory with 5 slots, equipment compare/lock/salvage with confirmation for
Rare+, offline reward dialog wired to the existing `claim_offline` guard,
settings (audio, vibration, reduced flash), localization CSV structure, and a
short tutorial — none of which may break the Gate 2/3 loops.

## Standing rules

- Codex builds; Claude verifies with independent adversarial suites. Codex's own
  tests are never sufficient evidence on their own.
- Visual claims require a rendered capture that was actually inspected.
- Balance values live in `resources/*.json`, never in script constants.
