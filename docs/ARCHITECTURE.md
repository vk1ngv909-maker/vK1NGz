# Architecture

Godot 4.3, typed GDScript, portrait 1080x1920 design size, `gl_compatibility`
renderer (Android-friendly), `canvas_items` stretch so layouts scale.

## Autoloads

| Autoload | Responsibility |
| --- | --- |
| `EventBus` | Decoupled signals only. No state, no logic. |
| `SaveManager` | Atomic versioned persistence, backup/recovery, migration, offline claim guard. |

Rule: UI never talks to UI. Systems talk through `EventBus` signals, so nothing
holds a circular reference.

## Layers

- `scripts/utilities/big_number.gd` — mantissa/exponent numbers to 1e10000.
  Immutable: every operation returns a new value. The economy never uses raw
  floats for currency.
- `autoload/save_manager.gd` — the only writer of `user://save*.json`.
- `scenes/ui/hud.tscn` — presentation only, 15% / 55% / 30% zones by
  stretch ratio. Actors are sized as a fraction of the combat area so they
  cannot crowd the interface at any resolution.
- `scripts/progression/enemy_pool.gd` — deterministic regular-enemy selection
  scoped to the active world. Boss stages return no regular enemy.
- `scripts/progression/boss_pool.gd` — four repeating boss archetypes. Durable
  first-clear ownership uses `stage_N` encounter IDs rather than archetype IDs.
  Stages above 100 clamp their assignment to stage 100 and reuse the final
  world's boss presentation.

## Save format

`user://save.json` primary, `user://save.backup.json` backup, written via
`user://save.tmp.json` then swapped, so a crash mid-write cannot destroy the
primary. `schema_version` is stamped on every write; v1→v2 migration converts
float gold into a BigNumber dictionary.

## Verification tooling

- `scripts/run-tests.sh` — all headless suites; non-zero exit on any failure.
- `scripts/shot.sh W H out.png` — real rendered capture at a device size, by
  patching the project viewport size for that run.
