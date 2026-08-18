extends SceneTree
## Independent suite: support-hero DPS must not duplicate rewards, and relic
## power must actually reach combat and survive reload + prestige.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var CS = load("res://scripts/combat/combat_state.gd")
	var R  = load("res://scripts/progression/relics.gd")
	var SMS = load("res://autoload/save_manager.gd")
	var P  = load("res://scripts/progression/prestige.gd")

	# ---------- DPS: rewards exactly once ----------
	var c = CS.new()
	c.set_relic_bonuses(1.0, 1.0)
	# Hire real heroes, otherwise total DPS is legitimately zero and the test
	# would be measuring nothing.
	c.set_support_hero_levels({"dune_scout": 30, "oasis_guard": 30})
	var kills: int = 0
	var gold_events: int = 0
	var advances: int = 0
	var ignored: int = 0
	for i in range(4000):
		var r: Dictionary = c.dps_tick(0.25)
		if r.get("ignored", false):
			ignored += 1
			continue
		if r.get("killed", false):
			kills += 1
			if r.has("gold_awarded"): gold_events += 1
		if r.get("stage_advanced", false): advances += 1
	ck("DPS produced kills", kills > 0, str(kills))
	ck("DPS gold events == kills", gold_events == kills, "gold=%d kills=%d" % [gold_events, kills])
	ck("DPS stage advances == kills", advances == kills, "adv=%d kills=%d" % [advances, kills])

	# ---------- DPS cannot hit a dead enemy or during retry ----------
	var c2 = CS.new(10)          # boss stage
	for i in range(500): c2.tick(1.0)
	ck("boss failed", c2.awaiting_retry)
	var all_ignored: bool = true
	for i in range(20):
		if not c2.dps_tick(1.0).get("ignored", false): all_ignored = false
	ck("DPS ignored while awaiting retry", all_ignored)

	# ---------- Relics actually change power ----------
	var base = CS.new()
	base.set_relic_bonuses(1.0, 1.0)
	var plain: String = base.get_tap_damage().format()
	var buffed = CS.new()
	buffed.set_relic_bonuses(3.0, 1.0)
	ck("relic damage bonus reaches tap damage",
		buffed.get_tap_damage().is_greater_than(base.get_tap_damage()),
		"%s vs %s" % [buffed.get_tap_damage().format(), plain])

	# ---------- Relic currency never negative, no double purchase ----------
	var rl = R.new(0)
	ck("cannot buy with zero currency", rl.buy("sun_blade") == false)
	ck("currency not negative", rl.prestige_currency >= 0, str(rl.prestige_currency))
	var rich = R.new(1000)
	var before_currency: int = rich.prestige_currency
	var first: bool = rich.buy("sun_blade")
	var lvl_after_first: int = rich.get_level("sun_blade")
	ck("first purchase works", first and lvl_after_first == 1, "%s lvl=%d" % [str(first), lvl_after_first])
	ck("currency was actually spent", rich.prestige_currency < before_currency, str(rich.prestige_currency))
	# buy() is a first-purchase-only door; a second buy must be refused outright
	ck("second buy() refused (no double purchase)", rich.buy("sun_blade") == false)
	ck("level did not jump", rich.get_level("sun_blade") == 1, str(rich.get_level("sun_blade")))
	ck("unknown relic id rejected safely", rich.buy("no_such_relic_xyz") == false)

	# ---------- Relics survive save/reload AND prestige ----------
	var sm = SMS.new(); get_root().add_child(sm)
	var state: Dictionary = sm.default_data()
	state["permanent_state"]["relic_levels"] = {"sun_blade": 6}
	state["permanent_state"]["max_stage"] = 250
	ck("saved", sm.save(state))
	var sm2 = SMS.new(); get_root().add_child(sm2)
	var reloaded: Dictionary = sm2.load()
	ck("relic level survived reload",
		int((reloaded["permanent_state"]["relic_levels"] as Dictionary).get("sun_blade", 0)) == 6,
		str(reloaded["permanent_state"]["relic_levels"]))
	var pr = P.new(sm2)
	var after: Dictionary = pr.apply(reloaded.duplicate(true))
	ck("relic level survived prestige",
		int((after["permanent_state"]["relic_levels"] as Dictionary).get("sun_blade", 0)) == 6,
		str(after["permanent_state"]["relic_levels"]))

	print("DPS+RELICS: FAIL %d" % failed if failed > 0 else "DPS+RELICS: all passed")
	quit(1 if failed > 0 else 0)
