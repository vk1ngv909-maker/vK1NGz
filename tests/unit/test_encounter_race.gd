extends SceneTree
## The documented rule: lethal damage accepted BEFORE the encounter transitions
## to FAILED wins. Once officially failed, later damage is ignored. This must not
## depend on frame-processing order, so both orders are tested explicitly.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var CS = load("res://scripts/combat/combat_state.gd")
	var INV = load("res://scripts/progression/inventory.gd")

	# ---- lethal damage lands FIRST, then the timer expires: victory wins ----
	var a = CS.new(10)
	var ia = INV.new(); ia.max_stage_reached = 60
	a.set_inventory(ia)
	a.enemy_hp = a.get_tap_damage()          # one tap is lethal
	a.boss_time_left = 0.001
	var r: Dictionary = a.tap()
	a.tick(1.0)                               # timer expires in the same frame
	ck("lethal damage before timeout -> victory", r.get("killed", false), str(r))
	ck("a won encounter is not also marked failed", not a.awaiting_retry,
		"awaiting_retry=%s" % str(a.awaiting_retry))

	# ---- timer expires FIRST, then damage arrives: damage is ignored ----
	var b = CS.new(10)
	var ib = INV.new(); ib.max_stage_reached = 60
	b.set_inventory(ib)
	b.boss_time_left = 0.001
	b.tick(1.0)                               # officially failed now
	ck("timeout marks the encounter failed", b.awaiting_retry)
	var after: Dictionary = b.tap()
	ck("damage after an official failure is ignored", after.get("ignored", false), str(after))
	ck("a failed encounter cannot be won retroactively", b.awaiting_retry)

	# ---- rapid tapping during boss death does not double-process ----
	var c = CS.new(20)
	var ic = INV.new(); ic.max_stage_reached = 60
	c.set_inventory(ic)
	c.enemy_hp = c.get_tap_damage()
	var kills: int = 0
	for i in range(30):
		if c.tap().get("killed", false): kills += 1
	ck("rapid taps during death process the kill once", kills == 1, str(kills))

	# ---- stage transitions, inside a world and across boundaries ----
	var pairs := [[30, 31], [33, 34], [60, 61], [66, 67], [90, 91], [100, 101]]
	var bad: Array = []
	var W = load("res://scripts/progression/worlds.gd")
	var w = W.new()
	for pair: Array in pairs:
		var from_w: String = str(w.world_for_stage(int(pair[0])).get("id", ""))
		var to_w: String = str(w.world_for_stage(int(pair[1])).get("id", ""))
		if from_w.is_empty() or to_w.is_empty():
			bad.append("%d->%d unresolved" % [pair[0], pair[1]])
	ck("every tested transition resolves to a world", bad.is_empty(), str(bad))
	ck("33->34 crosses worlds",
		str(w.world_for_stage(33).get("id")) != str(w.world_for_stage(34).get("id")))
	ck("30->31 stays in the same world",
		str(w.world_for_stage(30).get("id")) == str(w.world_for_stage(31).get("id")))
	ck("100->101 uses the documented clamp",
		str(w.world_for_stage(101).get("id")) == str(w.world_for_stage(100).get("id")))

	print("ENCOUNTER RACE: FAIL %d" % failed if failed > 0 else "ENCOUNTER RACE: all passed")
	quit(1 if failed > 0 else 0)
