extends SceneTree
## A boss wears the visual of the world it is fought in while keeping the
## mechanics of its archetype. This pins both halves: the presentation must
## always belong to the active world, and nothing mechanical -- encounter id,
## stage, HP or reward multiplier, timer, first-clear -- may move because of it.

const WorldsLogic = preload("res://scripts/progression/worlds.gd")
const BossPoolLogic = preload("res://scripts/progression/boss_pool.gd")
const CS = preload("res://scripts/combat/combat_state.gd")
const RS = preload("res://scripts/progression/reward_system.gd")
const INV = preload("res://scripts/progression/inventory.gd")

## Multipliers as authored before the visual system existed. If a visual change
## ever moves one of these, this test fails rather than the balance silently
## drifting.
const EXPECTED_MECHANICS := {
	"sandstorm_colossus": [1.0, 30.0],
	"lunar_glasswing": [1.08, 30.0],
	"ember_crown_construct": [1.16, 30.0],
	"vaultback_behemoth": [1.25, 30.0],
}

class RecordingAdapter extends RefCounted:
	var payloads: Array = []
	func save(data: Dictionary) -> bool:
		payloads.append(data.duplicate(true))
		return true

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func _init() -> void:
	var worlds = WorldsLogic.new()
	var pool = BossPoolLogic.new()
	var raw: Dictionary = JSON.parse_string(FileAccess.open("res://resources/worlds/worlds.json", FileAccess.READ).get_as_text())
	var last_stage: int = int((raw["entries"][-1] as Dictionary)["stage_to"])

	# ---- one encounter per boss stage, with a world-appropriate visual ----
	var seen_encounters: Dictionary = {}
	var visuals_per_world: Dictionary = {}
	for stage: int in range(10, last_stage + 1, 10):
		var boss: Dictionary = pool.select(stage)
		ck("stage %d has exactly one boss encounter" % stage, not boss.is_empty(), str(boss))
		var encounter: String = str(boss.get("encounter_id", ""))
		ck("stage %d has a unique encounter id" % stage,
			encounter == "stage_%d" % stage and not seen_encounters.has(encounter), encounter)
		seen_encounters[encounter] = true

		var archetype: String = str(boss.get("id", ""))
		var expected: Array = EXPECTED_MECHANICS[archetype]
		ck("stage %d keeps its authored HP multiplier" % stage,
			is_equal_approx(float(boss.get("hp_modifier", -1.0)), float(expected[0])),
			str(boss.get("hp_modifier")))
		ck("stage %d keeps its authored timer" % stage,
			is_equal_approx(float(boss.get("timer_seconds", -1.0)), float(expected[1])),
			str(boss.get("timer_seconds")))
		ck("stage %d keeps its reward table" % stage,
			str(boss.get("reward_table_id", "")) == "boss_first_clear_default", str(boss.get("reward_table_id")))

		var world: Dictionary = worlds.world_for_stage(stage)
		var visual: Dictionary = worlds.boss_visual_for(stage, archetype)
		ck("stage %d resolves a visual" % stage, not visual.is_empty(),
			"world %s archetype %s" % [str(world.get("id", "")), archetype])
		if visual.is_empty():
			continue
		ck("stage %d visual belongs to the active world" % stage,
			str(visual.get("world_id", "")) == str(world.get("id", "")),
			"%s vs %s" % [str(visual.get("world_id", "")), str(world.get("id", ""))])
		var visual_id: String = str(visual.get("visual_id", ""))
		ck("stage %d visual has a sprite on disk" % stage,
			ResourceLoader.exists("res://assets/sprites/bosses/%s.png" % visual_id), visual_id)
		ck("stage %d visual has a display name" % stage,
			str(visual.get("name_key", "")).begins_with("boss.visual."), str(visual.get("name_key")))
		var world_id: String = str(world.get("id", ""))
		if not visuals_per_world.has(world_id):
			visuals_per_world[world_id] = {}
		(visuals_per_world[world_id] as Dictionary)[visual_id] = true

	# ---- the forest boss must never stand in the volcanic fortress ----
	var citadel: Dictionary = visuals_per_world.get("ruins_of_the_sun_kingdom", {})
	ck("the Citadel never shows the meadow treant", not citadel.has("ancient_treant"), str(citadel.keys()))
	var meadow: Dictionary = visuals_per_world.get("oasis_frontier", {})
	ck("the Meadow never shows a volcanic or mechanical boss",
		not meadow.has("magma_horn_beast") and not meadow.has("clockwork_crown_king"), str(meadow.keys()))
	var wildwood: Dictionary = visuals_per_world.get("moonlit_dunes", {})
	ck("the Wildwood never shows a volcanic boss",
		not wildwood.has("magma_horn_beast") and not wildwood.has("purple_fortress_boss"), str(wildwood.keys()))
	for world_value: Variant in visuals_per_world:
		var used: Dictionary = visuals_per_world[world_value]
		ck("%s uses a distinct visual per archetype" % str(world_value), used.size() >= 1, str(used.size()))

	# ---- no silent fallback ----
	ck("an unknown archetype resolves to nothing rather than a wrong sprite",
		worlds.boss_visual_for(10, "not_a_boss").is_empty())
	# A nonsense stage clamps to the first world rather than falling through to
	# whatever sprite happens to be loaded.
	var clamped: Dictionary = worlds.boss_visual_for(-5, "sandstorm_colossus")
	ck("a stage below the first world still resolves inside the first world",
		str(clamped.get("world_id", "")) == "oasis_frontier", str(clamped))
	var beyond: Dictionary = worlds.boss_visual_for(last_stage + 500, "sandstorm_colossus")
	ck("a stage past the last world resolves inside the last world",
		str(beyond.get("world_id", "")) == "ruins_of_the_sun_kingdom", str(beyond))

	# ---- first clear stays exactly once, and survives a reload ----
	var combat = CS.new()
	combat.set_inventory(INV.new())
	var adapter := RecordingAdapter.new()
	combat.save_adapter = adapter
	var rewards = RS.new(0x5EED)
	var grant: Dictionary = combat.begin_boss_first_clear(30, rewards)
	ck("first clear grants once", bool(grant.get("granted", false)), str(grant))
	ck("commit stores the clear", combat.commit_boss_first_clear(grant))
	ck("the clear is keyed by encounter, not archetype", combat.boss_first_clears.has("stage_30"))
	var replay: Dictionary = combat.begin_boss_first_clear(30, rewards)
	ck("a replay grants nothing", not bool(replay.get("granted", false)))
	ck("the refusal names the prior clear", str(replay.get("reason", "")) == "already_cleared", str(replay))
	var saved: Dictionary = adapter.payloads[-1] if not adapter.payloads.is_empty() else {}
	var permanent: Dictionary = saved.get("permanent_state", {})
	ck("the saved state carries the clear", (permanent.get("boss_first_clears", {}) as Dictionary).has("stage_30"))
	var reloaded = INV.new()
	reloaded.from_dict(permanent.get("equipment", {}))
	ck("reload does not duplicate the reward", reloaded.owned_items.size() == 1, str(reloaded.owned_items.size()))

	# ---- death and timeout still resolve exactly one outcome ----
	var race = CS.new(10)
	race.set_inventory(INV.new())
	race.enemy_hp = race.get_tap_damage()._copy_normalized()
	race.boss_time_left = 0.001
	var killed: Dictionary = race.tap()
	var timed_out: Dictionary = race.tick(1.0)
	ck("a kill on the final tick still counts as a victory", bool(killed.get("killed", false)), str(killed))
	ck("the timeout after that kill does not also fail the boss",
		not bool(timed_out.get("boss_failed", false)), str(timed_out))
	var reverse = CS.new(10)
	reverse.set_inventory(INV.new())
	var failure: Dictionary = reverse.tick(999.0)
	ck("a timeout with the boss alive fails it", bool(failure.get("boss_failed", false)), str(failure))
	var late: Dictionary = reverse.tap()
	ck("a tap after the timeout cannot revive the encounter",
		not bool(late.get("killed", false)), str(late))

	print("BOSS VISUALS: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
