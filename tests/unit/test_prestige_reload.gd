extends SceneTree
## Simulates closing and reopening the game around a Prestige, using a FRESH
## SaveManager instance for the reload so nothing is carried in memory.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var SMS = load("res://autoload/save_manager.gd")
	var P = load("res://scripts/progression/prestige.gd")

	# --- session 1: play, then prestige ---
	var sm1 = SMS.new()
	get_root().add_child(sm1)
	var state: Dictionary = sm1.default_data()
	state["run_state"]["stage"] = 200
	state["run_state"]["tap_level"] = 77
	state["run_state"]["support_hero_levels"] = {"h1": 40}
	state["run_state"]["temporary_buffs"] = {"x": 2.0}
	state["permanent_state"]["max_stage"] = 200
	state["permanent_state"]["relic_levels"] = {"r1": 4}
	state["permanent_state"]["prestige_currency"] = 3
	ck("session 1 saves", sm1.save(state))

	var pr = P.new(sm1)
	var after: Dictionary = pr.apply(state.duplicate(true))
	ck("prestige applied", not after.get("refused", false))
	var expected_currency: int = int(after["permanent_state"]["prestige_currency"])
	ck("currency granted", expected_currency > 3, str(expected_currency))

	# --- simulate app close: drop everything, build a NEW manager ---
	sm1.queue_free()
	var sm2 = SMS.new()
	get_root().add_child(sm2)
	var reloaded: Dictionary = sm2.load()

	ck("reload source is primary (prestige was saved)", sm2.last_load_source == "primary", str(sm2.last_load_source))
	var run_state: Dictionary = reloaded["run_state"]
	var permanent_state: Dictionary = reloaded["permanent_state"]
	ck("stage still 1 after reopen", int(run_state.get("stage", -1)) == 1, str(run_state.get("stage")))
	ck("tap_level still 1 after reopen", int(run_state.get("tap_level", -1)) == 1, str(run_state.get("tap_level")))
	ck("max_stage survived reopen", int(permanent_state.get("max_stage", 0)) == 200, str(permanent_state.get("max_stage")))
	ck("prestige currency survived reopen", int(permanent_state.get("prestige_currency", 0)) == expected_currency,
		"%d vs %d" % [int(permanent_state.get("prestige_currency", 0)), expected_currency])
	ck("relics survived reopen", int((permanent_state.get("relic_levels", {}) as Dictionary).get("r1", 0)) == 4,
		str(permanent_state.get("relic_levels")))
	ck("support levels still zero after reopen",
		(run_state.get("support_hero_levels", {}) as Dictionary).is_empty(), str(run_state.get("support_hero_levels")))
	ck("temporary buffs still empty after reopen",
		(run_state.get("temporary_buffs", {}) as Dictionary).is_empty(), str(run_state.get("temporary_buffs")))

	print("PRESTIGE RELOAD: FAIL %d" % failed if failed > 0 else "PRESTIGE RELOAD: all passed")
	quit(1 if failed > 0 else 0)

func _all_zero(d) -> bool:
	for k in (d as Dictionary):
		if int(d[k]) != 0: return false
	return true
