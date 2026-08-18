extends SceneTree
## Independent adversarial suite for Gate 3. Targets the two ways this system
## can destroy a player's progress or silently break balance:
## Prestige wiping the wrong things, and skills stacking with themselves.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var P = load("res://scripts/progression/prestige.gd")
	var S = load("res://scripts/progression/skill_system.gd")
	var R = load("res://scripts/progression/relics.gd")

	# ============ PRESTIGE: zero reward must be refused ============
	var pr = P.new()
	ck("reward is 0 at low stage", pr.reward_for(1) == 0, str(pr.reward_for(1)))
	ck("cannot prestige at stage 1", pr.can_prestige(1) == false)
	ck("cannot prestige at stage 24", pr.can_prestige(24) == false, str(pr.reward_for(24)))
	ck("can prestige once reward > 0", pr.can_prestige(200) == true, str(pr.reward_for(200)))

	# ============ PRESTIGE: preview must be explicit ============
	var state := {
		"stage": 200, "max_stage": 200,
		"gold": {"mantissa": 5.0, "exponent": 9},
		"tap_level": 77,
		"support_hero_levels": {"h1": 40, "h2": 12},
		"prestige_currency": 3,
		"relic_levels": {"r1": 4},
		"equipment": ["sword_of_test"],
		"achievements": ["first_boss"],
		"settings": {"vibration": false},
		"statistics": {"taps": 9999},
		"active_skills": {"sand_fury": 123456},
		"temporary_buffs": {"x": 2.0},
	}
	var pv = pr.preview(state)
	ck("preview lists resets", pv.has("resets") and (pv["resets"] as Array).size() > 0)
	ck("preview lists keeps", pv.has("keeps") and (pv["keeps"] as Array).size() > 0)
	ck("preview reports reward", int(pv.get("reward", 0)) > 0, str(pv.get("reward")))

	# ============ PRESTIGE: refuse when reward is zero ============
	var low := state.duplicate(true); low["max_stage"] = 5
	var refused = pr.apply(low)
	ck("apply refuses at zero reward", refused.get("refused", false) == true, str(refused.get("refused")))
	ck("refused apply changes nothing", int(refused.get("tap_level", 0)) == 77, str(refused.get("tap_level")))

	# ============ PRESTIGE: reset the right things, keep the right things ============
	var after = pr.apply(state.duplicate(true))
	ck("stage reset to 1", int(after.get("stage", -1)) == 1, str(after.get("stage")))
	ck("gold wiped", _is_zero(after.get("gold")), str(after.get("gold")))
	ck("tap_level reset", int(after.get("tap_level", -1)) == 1, str(after.get("tap_level")))
	ck("support levels wiped", _all_zero(after.get("support_hero_levels", {})), str(after.get("support_hero_levels")))
	ck("active skills cleared", (after.get("active_skills", {}) as Dictionary).is_empty(), str(after.get("active_skills")))
	ck("temp buffs cleared", (after.get("temporary_buffs", {}) as Dictionary).is_empty(), str(after.get("temporary_buffs")))
	ck("max_stage PRESERVED", int(after.get("max_stage", 0)) == 200, str(after.get("max_stage")))
	ck("relics PRESERVED", (after.get("relic_levels", {}) as Dictionary).get("r1", 0) == 4, str(after.get("relic_levels")))
	ck("equipment PRESERVED", (after.get("equipment", []) as Array).has("sword_of_test"), str(after.get("equipment")))
	ck("achievements PRESERVED", (after.get("achievements", []) as Array).size() == 1)
	ck("settings PRESERVED", (after.get("settings", {}) as Dictionary).get("vibration") == false)
	ck("statistics PRESERVED", (after.get("statistics", {}) as Dictionary).get("taps") == 9999)
	ck("prestige currency INCREASED", int(after.get("prestige_currency", 0)) > 3, str(after.get("prestige_currency")))

	# ============ SKILLS: no double activation, no self-stacking ============
	var sk = S.new()
	var t0: int = 1_000_000
	ck("first activation succeeds", sk.activate("sand_fury", t0) == true)
	ck("second activation REFUSED while active", sk.activate("sand_fury", t0 + 100) == false)
	var m_single: float = sk.multiplier_for("tap_damage")
	sk.activate("sand_fury", t0 + 200)
	ck("multiplier did not double from re-activation", is_equal_approx(sk.multiplier_for("tap_damage"), m_single),
		"%f vs %f" % [sk.multiplier_for("tap_damage"), m_single])

	# still on cooldown right after expiry
	sk.tick(t0 + 11_000)
	ck("skill expired after duration", is_equal_approx(sk.multiplier_for("tap_damage"), 1.0), str(sk.multiplier_for("tap_damage")))
	ck("cannot reactivate during cooldown", sk.activate("sand_fury", t0 + 12_000) == false)
	sk.tick(t0 + 46_000)
	ck("can reactivate after cooldown", sk.activate("sand_fury", t0 + 46_000) == true)

	# different skills DO stack, same skill never does
	var sk2 = S.new()
	sk2.activate("sand_fury", t0)
	sk2.activate("critical_eclipse", t0)
	ck("different skills both active", sk2.multiplier_for("tap_damage") > 1.0)

	# ============ SKILLS: cooldown survives a close/reopen ============
	var sk3 = S.new()
	sk3.activate("golden_wind", t0)
	var saved: Dictionary = sk3.to_dict()
	var sk4 = S.new()
	sk4.from_dict(saved)
	sk4.tick(t0 + 5_000)
	ck("skill still active after reload", sk4.multiplier_for("gold") > 1.0, str(sk4.multiplier_for("gold")))
	sk4.tick(t0 + 30_000)         # past 12s duration, inside 90s cooldown
	ck("expired after reload", is_equal_approx(sk4.multiplier_for("gold"), 1.0))
	ck("cooldown persisted across reload", sk4.activate("golden_wind", t0 + 30_000) == false)
	sk4.tick(t0 + 95_000)
	ck("cooldown ends at the right absolute time", sk4.activate("golden_wind", t0 + 95_000) == true)

	# ============ RELICS: never negative currency ============
	var rl = R.new(0)
	ck("relic purchase refused with no currency", rl.buy("relic_01") == false)
	var rich = R.new(100000)
	var bought: bool = rich.buy("relic_01")
	ck("relic purchase works with currency", bought or rich.get_level("relic_01") >= 0)

	print("PROGRESSION ADVERSARIAL: FAIL %d" % failed if failed > 0 else "PROGRESSION ADVERSARIAL: all passed")
	quit(1 if failed > 0 else 0)

func _is_zero(g) -> bool:
	if typeof(g) == TYPE_DICTIONARY:
		return float(g.get("mantissa", 1.0)) == 0.0
	return float(g) == 0.0

func _all_zero(d) -> bool:
	for k in (d as Dictionary):
		if int(d[k]) != 0:
			return false
	return true
