# Goal
Gate 5 group 3: twelve original enemies (4 per world), four boss archetypes with
per-ENCOUNTER first-clear tracking, and a deterministic simultaneous-death rule.

# Part 1 — twelve enemies (resources/enemies/enemies.json, schema_version 1)
Four per world, each with a DISTINCT palette and silhouette hint so they are
visually different, not renamed clones.
Fields: id, name_key, desc_key (en+ar), world_id, stage_from, stage_to,
hp_modifier (0.85-1.25), gold_modifier (0.85-1.25), palette {body, accent},
silhouette ("squat"|"tall"|"wide"|"spindly"), size_scale (0.8-1.25),
hit_reaction {recoil_px, flash_strength}, asset_status "PLACEHOLDER".

Original themes, culturally respectful, no real-world religious references:
 oasis_frontier: dune_raider, oasis_scarab, thorn_lizard, mirage_stalker
 moonlit_dunes: night_howler, dust_wraith, moon_moth, glass_serpent
 ruins_of_the_sun_kingdom: sunstone_sentinel, cursed_regalia, ember_djinn_construct, ossuary_warden

# Part 2 — enemy selection (scripts/progression/enemy_pool.gd)
  select(stage, seed) -> Dictionary
  DETERMINISTIC: same (stage, seed) always returns the same enemy.
  Only from the ACTIVE world's pool — never from another world.
  Boss stages must NOT return a regular enemy.
  Unknown/empty pool -> safe fallback + push_error, never crash.
  CombatState applies hp_modifier and gold_modifier; the resulting curve must
  stay inside the approved balance (modifiers are bounded, see ranges above).

# Part 3 — four boss archetypes + ENCOUNTER tracking (CRITICAL)
resources/bosses/bosses.json: 4 archetypes, each with id, name_key, desc_key,
world_id (or "milestone"), hp_modifier, timer_seconds, palette, silhouette,
reward_table_id, asset_status.

Boss stages are every 10th stage. Archetypes REPEAT across stages.
  encounter_id(stage) -> String   e.g. "stage_%d" % stage
First-clear ownership is keyed by ENCOUNTER ID, never by archetype id, so
clearing the archetype at stage 10 must NOT block the reward at stage 40 where
the same archetype reappears. Add an explicit test for that.

# Part 4 — deterministic simultaneous-death rule
Document and implement ONE rule in combat_state.gd:
  "Lethal damage accepted BEFORE the encounter transitions to failed wins.
   Once the encounter is officially failed, later damage is ignored."
Implement an explicit `encounter_state` enum: ACTIVE, VICTORY, FAILED.
All damage paths (tap, dps_tick, falcon_tick, skill) must check it. Death is
processed EXACTLY ONCE regardless of how many sources land in one frame:
add `_death_processed: bool` guarded inside the shared kill transition.
Timer expiry sets FAILED only if state is still ACTIVE.

# Part 5 — boss assignment validation (extend content_validator.gd)
Reject: a boss stage 1-100 with no archetype; a regular enemy selected on a boss
stage; a boss referencing an unknown world; boss stages disagreeing with world
ranges; unknown reward_table_id; duplicate encounter ids; first-clear keyed by
archetype instead of encounter; enemies outside their world's stage range.
Stages beyond 100: documented fallback (clamp to last world's bosses).

# Part 6 — tutorial must not obscure captures
Add `--debug-complete-tutorial` that marks the tutorial complete before the
first frame, so world/enemy captures show the HUD unobstructed.

# Constraints
Typed GDScript, tabs. All name/desc keys in BOTH CSVs, re-import translations.
Do not modify scripts/ui/game.gd. Update docs/ASSET_MANIFEST.md with every new
placeholder. Keep files under ~400 lines.

# Done when
scripts/run-tests.sh passes with all guards, and --debug-world / --debug-stage
render visibly different enemies per world.
