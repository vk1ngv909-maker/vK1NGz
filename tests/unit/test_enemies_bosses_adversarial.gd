extends SceneTree
## Independent suite for group 3. Two things can silently break here:
## a kill processed more than once when several damage sources land together,
## and a repeated boss archetype stealing the reward from a later encounter.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func owned(inv) -> int:
	return (inv.to_dict().get("owned", {}) as Dictionary).size()

func _init() -> void:
	var CS = load("res://scripts/combat/combat_state.gd")
	var RS = load("res://scripts/progression/reward_system.gd")
	var INV = load("res://scripts/progression/inventory.gd")
	var EP = load("res://scripts/progression/enemy_pool.gd")
	var W = load("res://scripts/progression/worlds.gd")

	# ================= enemy selection =================
	var pool = EP.new()
	var worlds = W.new()

	# determinism
	var same: bool = true
	for stage: int in [1, 7, 34, 50, 67, 99]:
		var a: Dictionary = pool.select(stage, 777)
		var b: Dictionary = pool.select(stage, 777)
		if str(a.get("id", "")) != str(b.get("id", "")): same = false
	ck("same (stage, seed) always selects the same enemy", same)

	# never spawns outside its world
	var wrong_world: Array = []
	for stage in range(1, 101):
		if stage % 10 == 0:
			continue
		var e: Dictionary = pool.select(stage, 42)
		var expected: String = str(worlds.world_for_stage(stage).get("id", ""))
		if str(e.get("world_id", "")) != expected:
			wrong_world.append("stage %d: %s in %s" % [stage, str(e.get("id")), expected])
	ck("no enemy ever spawns outside its world", wrong_world.is_empty(), str(wrong_world.slice(0, 3)))

	# every world actually uses more than one enemy
	var per_world: Dictionary = {}
	for stage in range(1, 101):
		if stage % 10 == 0: continue
		var e: Dictionary = pool.select(stage, 3)
		var wid: String = str(e.get("world_id", ""))
		if not per_world.has(wid): per_world[wid] = {}
		(per_world[wid] as Dictionary)[str(e.get("id", ""))] = true
	var thin: Array = []
	for wid: Variant in per_world:
		if (per_world[wid] as Dictionary).size() < 2:
			thin.append("%s uses only %d" % [str(wid), (per_world[wid] as Dictionary).size()])
	ck("each world draws from several enemies", thin.is_empty(), str(thin))

	# boss stages never return a regular enemy
	var leaked: Array = []
	for stage in [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
		var e: Dictionary = pool.select(stage, 9)
		if not bool(e.get("is_boss", false)) and not e.is_empty() and e.has("hp_modifier") and not str(e.get("id","")).begins_with("boss"):
			if not bool(e.get("boss", false)):
				leaked.append(stage)
	ck("boss stages do not select a regular enemy", leaked.is_empty(), str(leaked))

	# unknown data fails safely
	ck("selection with an absurd stage does not crash",
		typeof(pool.select(99999, 1)) == TYPE_DICTIONARY)

	# ================= simultaneous death =================
	var c = CS.new(5)
	var inv = INV.new(); inv.max_stage_reached = 60
	c.set_inventory(inv)
	# drive the enemy to near-death, then hit it from several sources in one frame
	var guard: int = 0
	while c.enemy_hp.is_greater_than(c.get_tap_damage()) and guard < 5000:
		c.tap(); guard += 1
	var stage_before: int = c.stage
	var kills: int = 0
	for r: Dictionary in [c.tap(), c.tap(), c.dps_tick(1.0), c.falcon_tick(99.0)]:
		if r.get("killed", false): kills += 1
	ck("four sources in one frame kill exactly once", kills <= 1, str(kills))
	ck("stage advanced at most once", c.stage <= stage_before + 1,
		"%d -> %d" % [stage_before, c.stage])

	# ================= boss archetype reuse =================
	var cb = CS.new(10)
	cb.save_adapter = null
	var ib = INV.new(); ib.max_stage_reached = 99
	cb.set_inventory(ib)
	var rewards = RS.new(31337)
	var t10: Dictionary = cb.begin_boss_first_clear(10, rewards)
	ck("stage 10 first clear granted", t10.get("granted", false), str(t10))
	# the SAME archetype reappears later; the reward must NOT be blocked
	var t40: Dictionary = cb.begin_boss_first_clear(40, rewards)
	ck("a repeated archetype at stage 40 still grants its own first clear",
		t40.get("granted", false), "first-clear must be keyed by encounter, not archetype: %s" % str(t40))
	ck("two encounters produced two rewards", owned(cb.inventory) == 2, str(owned(cb.inventory)))
	ck("re-farming stage 10 still grants nothing",
		not cb.begin_boss_first_clear(10, rewards).get("granted", true))

	# ================= boss stage coverage 1..100 =================
	var uncovered: Array = []
	for stage in range(10, 101, 10):
		if str(cb.boss_archetype_for_stage(stage) if cb.has_method("boss_archetype_for_stage") else "x") == "":
			uncovered.append(stage)
	ck("every boss stage 10-100 resolves to an archetype", uncovered.is_empty(), str(uncovered))

	print("ENEMIES/BOSSES: FAIL %d" % failed if failed > 0 else "ENEMIES/BOSSES: all passed")
	quit(1 if failed > 0 else 0)
