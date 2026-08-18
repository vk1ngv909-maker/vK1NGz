# Goal
Gate 5 group 2: an injectable save adapter for failure testing, versioned
content schemas + validators, and three live worlds with stage transitions.

# Part 1 — injectable save adapter (needed for failure-injection tests)
combat_arena / the first-clear transaction must call saving through an
INJECTABLE object, not SaveManager directly:

  class_name SaveAdapter (scripts/utilities/save_adapter.gd)
    func save(data: Dictionary) -> bool     # default: delegates to SaveManager

  CombatState gains `save_adapter: SaveAdapter` (defaults to the real one).
  Tests substitute a failing adapter to simulate a crash at a boundary.

  commit_boss_first_clear(transaction) -> bool
    Saves via the adapter. If the adapter returns false, it MUST call
    rollback_boss_first_clear(transaction) so the player is left in a clean
    retryable state — never "boss claimed but reward missing".

  Pity counter must be part of the SAME transaction: it is only persisted when
  the save succeeds, never partially advanced.

  debug_add() must be unreachable unless OS.is_debug_build(); add
  `is_debug_grant_allowed()` returning false in release so a test can assert it.

# Part 2 — versioned content schemas + validator
- resources/schemas/content_schema.json with `schema_version` and, per content
  type (worlds, enemies, bosses, support_heroes, skills, relics, equipment,
  reward_tables): required fields, types, numeric ranges, and reference fields.
- autoload/content_validator.gd validating EVERY content file at boot in debug.
  It must reject, with the offending file, entry id and field named in the error:
  duplicate ids; missing/unknown fields; wrong types; out-of-range numbers;
  missing en OR ar localization keys; missing/invalid asset refs; invalid stage
  ranges; overlapping world ranges; GAPS between world ranges; unknown
  cross-references (world/enemy/boss/skill/relic/item/reward table); bosses on
  non-boss stages; enemies outside their world; invalid hp/gold modifiers;
  negative or zero costs; skill cooldown <= duration; unsafe relic scaling;
  invalid equipment slot; decreasing rarity unlock stages; reward tables that
  could grant a locked rarity; empty reward tables; negative/zero-total/NaN/INF/
  extreme weights; content schema_version newer than supported.
- In debug: fail loudly (push_error naming file+id+field) and set a visible
  flag. Never silently skip an invalid entry.
- tests/unit/test_content_validation.gd with a deliberately broken fixture for
  EACH rejection rule above.

# Part 3 — three worlds, live
resources/worlds/worlds.json:
  oasis_frontier      stages 1-33
  moonlit_dunes       stages 34-66
  ruins_of_the_sun_kingdom stages 67-100
Each: id, name_key, desc_key (en+ar), stage_from, stage_to, palette
{sky, sand, accent}, background_layers [] (labelled placeholders), music_ref
(labelled placeholder), enemy_pool [], boss_ids [], transition {fade_seconds}.

scripts/progression/worlds.gd (class_name Worlds):
  world_for_stage(stage) -> Dictionary      # authored range
  Beyond stage 100: documented fallback — clamp to the LAST world and log once.
  Ranges must be contiguous and non-overlapping (validator enforces it).

Live wiring in combat_arena/hud:
  On stage change, if the world changed: update the combat background ColorRect
  to the world palette, update a visible world-name label (localized), and
  switch the music reference. The change must happen ONCE per boundary, must
  not reset combat, must not re-grant rewards, and must survive save/reload and
  prestige (prestige returns to world 1).

Add `--debug-world N` to jump to a stage for capture.

# Constraints
Typed GDScript, tabs. Do not modify scripts/ui/game.gd. All new strings in BOTH
CSVs; re-import translations. Placeholders labelled and added to
docs/ASSET_MANIFEST.md.

# Done when
scripts/run-tests.sh passes with all guards, and --debug-world renders each
world with a different palette and name.
