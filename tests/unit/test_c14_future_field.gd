extends SceneTree
## C14 regression: a temporary field invented AFTER prestige.gd was written must
## still be destroyed by a prestige, without anyone editing prestige.gd.
## This is the whole point of the run_state / permanent_state split.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var SMS = load("res://autoload/save_manager.gd")
	var P = load("res://scripts/progression/prestige.gd")
	var sm = SMS.new()
	get_root().add_child(sm)
	var pr = P.new(sm)

	var state: Dictionary = sm.default_data()
	state["permanent_state"]["max_stage"] = 300
	state["permanent_state"]["prestige_currency"] = 7
	state["permanent_state"]["relic_levels"] = {"r1": 5}

	# A field nobody anticipated, added straight into run_state.
	state["run_state"]["totally_new_temp_buff"] = {"damage_x": 9999.0}
	state["run_state"]["another_future_field"] = 12345
	state["run_state"]["stage"] = 300

	# And an invented PERMANENT field, which must survive.
	state["permanent_state"]["future_cosmetic_unlocks"] = ["golden_falcon"]

	var after: Dictionary = pr.apply(state.duplicate(true))
	ck("prestige applied", not after.get("refused", false))

	var run: Dictionary = after.get("run_state", {})
	ck("unknown temp field DESTROYED without editing prestige.gd",
		not run.has("totally_new_temp_buff"), str(run.get("totally_new_temp_buff")))
	ck("second unknown temp field DESTROYED",
		not run.has("another_future_field"), str(run.get("another_future_field")))
	ck("known run field still reset", int(run.get("stage", -1)) == 1, str(run.get("stage")))

	var perm: Dictionary = after.get("permanent_state", {})
	ck("unknown PERMANENT field preserved",
		(perm.get("future_cosmetic_unlocks", []) as Array).has("golden_falcon"), str(perm.get("future_cosmetic_unlocks")))
	ck("max_stage preserved", int(perm.get("max_stage", 0)) == 300, str(perm.get("max_stage")))
	ck("relics preserved", int((perm.get("relic_levels", {}) as Dictionary).get("r1", 0)) == 5)
	ck("currency increased", int(perm.get("prestige_currency", 0)) > 7, str(perm.get("prestige_currency")))

	# run_state must match the canonical defaults exactly in key set
	var defaults: Dictionary = sm.default_run_state()
	var extra: Array = []
	for k in run:
		if not defaults.has(k): extra.append(k)
	ck("run_state has no leftover keys beyond defaults", extra.is_empty(), str(extra))

	print("C14: FAIL %d" % failed if failed > 0 else "C14: all passed")
	quit(1 if failed > 0 else 0)
