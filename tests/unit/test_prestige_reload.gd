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
	state["stage"] = 200
	state["max_stage"] = 200
	state["tap_level"] = 77
	state["support_hero_levels"] = {"h1": 40}
	state["relic_levels"] = {"r1": 4}
	state["prestige_currency"] = 3
	state["temporary_buffs"] = {"x": 2.0}
	ck("session 1 saves", sm1.save(state))

	var pr = P.new(sm1)
	var after: Dictionary = pr.apply(state.duplicate(true))
	ck("prestige applied", not after.get("refused", false))
	var expected_currency: int = int(after["prestige_currency"])
	ck("currency granted", expected_currency > 3, str(expected_currency))

	# --- simulate app close: drop everything, build a NEW manager ---
	sm1.queue_free()
	var sm2 = SMS.new()
	get_root().add_child(sm2)
	var reloaded: Dictionary = sm2.load()

	ck("reload source is primary (prestige was saved)", sm2.last_load_source == "primary", str(sm2.last_load_source))
	ck("stage still 1 after reopen", int(reloaded.get("stage", -1)) == 1, str(reloaded.get("stage")))
	ck("tap_level still 1 after reopen", int(reloaded.get("tap_level", -1)) == 1, str(reloaded.get("tap_level")))
	ck("max_stage survived reopen", int(reloaded.get("max_stage", 0)) == 200, str(reloaded.get("max_stage")))
	ck("prestige currency survived reopen", int(reloaded.get("prestige_currency", 0)) == expected_currency,
		"%d vs %d" % [int(reloaded.get("prestige_currency", 0)), expected_currency])
	ck("relics survived reopen", int((reloaded.get("relic_levels", {}) as Dictionary).get("r1", 0)) == 4,
		str(reloaded.get("relic_levels")))
	ck("support levels still zero after reopen",
		_all_zero(reloaded.get("support_hero_levels", {})), str(reloaded.get("support_hero_levels")))
	ck("temporary buffs still empty after reopen",
		(reloaded.get("temporary_buffs", {}) as Dictionary).is_empty(), str(reloaded.get("temporary_buffs")))

	print("PRESTIGE RELOAD: FAIL %d" % failed if failed > 0 else "PRESTIGE RELOAD: all passed")
	quit(1 if failed > 0 else 0)

func _all_zero(d) -> bool:
	for k in (d as Dictionary):
		if int(d[k]) != 0: return false
	return true
