extends SceneTree
## Boss first-clear is a one-time transaction: farming, rapid repeats and a
## reload must never mint a second reward.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func owned_count(inv) -> int:
	return (inv.to_dict().get("owned", {}) as Dictionary).size()

func _init() -> void:
	var CS = load("res://scripts/combat/combat_state.gd")
	var RS = load("res://scripts/progression/reward_system.gd")
	var INV = load("res://scripts/progression/inventory.gd")

	var c = CS.new(10)
	var inv = INV.new()
	inv.max_stage_reached = 60
	c.set_inventory(inv)
	var rewards = RS.new(4242)

	ck("first clear is granted", c.begin_boss_first_clear(10, rewards).get("granted", false))
	var after_first: int = owned_count(c.inventory)
	ck("exactly one item was added", after_first == 1, str(after_first))

	var extra: int = 0
	for i in range(25):
		if c.begin_boss_first_clear(10, rewards).get("granted", false):
			extra += 1
	ck("farming the same boss grants nothing", extra == 0, str(extra))
	ck("inventory did not grow while farming", owned_count(c.inventory) == after_first,
		str(owned_count(c.inventory)))

	var reason: String = str(c.begin_boss_first_clear(10, rewards).get("reason", ""))
	ck("refusal reason is already_cleared", reason == "already_cleared", reason)

	# a reload carrying the saved first-clear map must still refuse
	var c2 = CS.new(10, null, 1, {}, {"boss_first_clears": c.boss_first_clears.duplicate(true)})
	ck("reload cannot repeat the first clear",
		not c2.begin_boss_first_clear(10, RS.new(4242)).get("granted", true))

	# rollback must leave the stage retryable, not half-committed
	var c3 = CS.new(30)
	var inv3 = INV.new()
	inv3.max_stage_reached = 60
	c3.set_inventory(inv3)
	var tx: Dictionary = c3.begin_boss_first_clear(30, RS.new(7))
	ck("stage 30 first clear granted", tx.get("granted", false), str(tx))
	c3.rollback_boss_first_clear(tx)
	ck("rollback removed the granted item", owned_count(c3.inventory) == 0,
		str(owned_count(c3.inventory)))
	ck("rollback leaves the boss retryable", not bool(c3.boss_first_clears.get("30", false)),
		str(c3.boss_first_clears))

	print("FIRST CLEAR: FAIL %d" % failed if failed > 0 else "FIRST CLEAR: all passed")
	quit(1 if failed > 0 else 0)
