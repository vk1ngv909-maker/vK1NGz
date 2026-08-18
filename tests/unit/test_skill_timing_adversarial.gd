extends SceneTree
## Independent timing suite: skills must behave correctly across app close and
## must not be exploitable by manipulating the clock.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var S = load("res://scripts/progression/skill_system.gd")
	var t0: int = 1_700_000_000_000   # absolute ms

	# --- an ACTIVE skill that expires while the game is closed ---
	var a = S.new()
	a.activate("sand_fury", t0)                       # 10s duration, 45s cooldown
	var snapshot: Dictionary = a.to_dict()
	var b = S.new()
	b.from_dict(snapshot)
	b.tick(t0 + 20_000)                               # reopened 20s later
	ck("skill expired while closed", is_equal_approx(b.multiplier_for("tap_damage"), 1.0),
		str(b.multiplier_for("tap_damage")))
	ck("still on cooldown after reopen", b.activate("sand_fury", t0 + 20_000) == false)

	# --- cooldown cannot be reset by closing and reopening repeatedly ---
	var c = S.new()
	c.activate("golden_wind", t0)                     # 12s / 90s
	for i in range(5):
		var snap: Dictionary = c.to_dict()
		c = S.new()
		c.from_dict(snap)                             # simulate 5 close/reopen cycles
		c.tick(t0 + 30_000)
	ck("cooldown survives repeated reopen", c.activate("golden_wind", t0 + 30_000) == false)
	c.tick(t0 + 95_000)
	ck("cooldown ends only at the real time", c.activate("golden_wind", t0 + 95_000) == true)

	# --- clock rolled BACKWARD must not extend or clear anything unfairly ---
	var d = S.new()
	d.activate("critical_eclipse", t0)                # 9s / 50s
	d.tick(t0 - 500_000)                              # device clock jumped back
	ck("backward clock does not clear cooldown state", d.activate("critical_eclipse", t0 - 500_000) == false)
	d.tick(t0 + 60_000)
	ck("recovers correctly after forward time", d.activate("critical_eclipse", t0 + 60_000) == true)

	# --- absurd timestamps must not create infinite or negative durations ---
	var e = S.new()
	e.activate("ancestor_call", t0)
	e.tick(9_223_372_036_854)                         # far future
	ck("far-future tick expires cleanly", is_equal_approx(e.multiplier_for("support_dps"), 1.0),
		str(e.multiplier_for("support_dps")))
	var f = S.new()
	var ok_neg: bool = f.activate("sand_fury", -1)
	f.tick(0)
	ck("negative timestamp does not crash or leave INF",
		is_finite(f.multiplier_for("tap_damage")), str(f.multiplier_for("tap_damage")))

	# --- corrupted saved timestamps must not be trusted ---
	var g = S.new()
	g.from_dict({"activated_at_ms": {"sand_fury": "not_a_number"}, "cooldown_until_ms": {"sand_fury": null}})
	g.tick(t0)
	ck("corrupt skill save does not crash", is_finite(g.multiplier_for("tap_damage")),
		str(g.multiplier_for("tap_damage")))

	print("SKILL TIMING: FAIL %d" % failed if failed > 0 else "SKILL TIMING: all passed")
	quit(1 if failed > 0 else 0)
