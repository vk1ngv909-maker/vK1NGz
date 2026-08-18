extends SceneTree
## Independent suite for group 4A. The money risks: buying twice with the same
## gold, milestones firing more than once on a bulk purchase, and a skill
## silently stacking with itself.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var SH = load("res://scripts/progression/support_heroes.gd")
	var SK = load("res://scripts/progression/skill_system.gd")
	var BN = load("res://scripts/utilities/big_number.gd")
	var raw: Dictionary = JSON.parse_string(FileAccess.open("res://resources/heroes/support_heroes.json", FileAccess.READ).get_as_text())
	var heroes: Array = raw["entries"]

	# ---------- content shape ----------
	ck("eight heroes exist", heroes.size() == 8, str(heroes.size()))
	var roles: Dictionary = {}
	for h: Variant in heroes:
		roles[str((h as Dictionary)["role"])] = int(roles.get(str((h as Dictionary)["role"]), 0)) + 1
	ck("four roles, two heroes each", roles.size() == 4 and roles.values().all(func(v): return int(v) == 2), str(roles))

	# milestone effects must VARY, or the heroes are DPS clones
	var effect_types: Dictionary = {}
	for h: Variant in heroes:
		for m: Variant in (h as Dictionary).get("milestones", []):
			effect_types[str((m as Dictionary).get("effect", (m as Dictionary).get("type", "")))] = true
	ck("milestones use several different effect types", effect_types.size() >= 3, str(effect_types.keys()))

	# unlock stages must be spread, not all at 1
	var unlocks: Array = []
	for h: Variant in heroes:
		unlocks.append(int((h as Dictionary)["unlock_stage"]))
	unlocks.sort()
	ck("unlock stages are spaced across progression", unlocks[-1] > unlocks[0] + 10, str(unlocks))

	# ---------- purchase safety ----------
	var s = SH.new()
	var first_id: String = str((heroes[0] as Dictionary)["id"])
	var late: Dictionary = {}
	for h: Variant in heroes:
		if int((h as Dictionary)["unlock_stage"]) > 1:
			late = h; break

	ck("a locked hero cannot be hired",
		s.hire(str(late.get("id", "")), 1) == false if not late.is_empty() else true)

	# rapid input must not hire twice off the same gold
	var s2 = SH.new()
	s2.gold = BN.from_float(1e9)
	var before: String = s2.gold.format()
	var hires: int = 0
	for i in range(20):
		if s2.hire(first_id, 100): hires += 1
	ck("rapid hire input hires exactly once", hires == 1, str(hires))
	ck("gold was spent once, not twenty times", s2.gold.format() != before)
	ck("gold never negative", not s2.gold.is_less_than(BN.from_float(0.0)), s2.gold.format())

	# ---------- milestones fire exactly once, even on a bulk buy ----------
	var s3 = SH.new()
	s3.gold = BN.from_float(1e30)
	s3.hire(first_id, 100)
	var stepwise = SH.new()
	stepwise.gold = BN.from_float(1e30)
	stepwise.hire(first_id, 100)
	for i in range(29):
		stepwise.level_up(first_id, 1)
	s3.level_up(first_id, 29)                     # one bulk buy to the same level
	ck("bulk buy reaches the same level as stepwise",
		s3.get_level(first_id) == stepwise.get_level(first_id),
		"%d vs %d" % [s3.get_level(first_id), stepwise.get_level(first_id)])
	ck("bulk buy grants the same DPS as stepwise (milestones once)",
		s3.total_dps().format() == stepwise.total_dps().format(),
		"%s vs %s" % [s3.total_dps().format(), stepwise.total_dps().format()])

	# ---------- buy quantities ----------
	if s3.has_method("max_affordable"):
		var poor = SH.new()
		poor.gold = BN.from_float(0.0)
		ck("Max with no gold buys nothing", poor.max_affordable(first_id, poor.gold) == 0,
			str(poor.max_affordable(first_id, poor.gold)))

	# ---------- extreme levels stay finite ----------
	var s4 = SH.new()
	s4.gold = BN.from_float(1e300)
	s4.hire(first_id, 100)
	s4.level_up(first_id, 5000)
	ck("very high levels stay valid (no NaN/INF)", s4.total_dps().is_valid(), s4.total_dps().format())

	ck("unknown hero id fails safely", s4.hire("no_such_hero", 100) == false)

	# ---------- skills remain mechanically distinct ----------
	var sk = SK.new()
	var t0: int = 1_700_000_000_000
	sk.activate("sand_fury", t0)
	ck("sand_fury raises tap damage only",
		sk.multiplier_for("tap_damage") > 1.0 and is_equal_approx(sk.multiplier_for("gold"), 1.0),
		"tap=%f gold=%f" % [sk.multiplier_for("tap_damage"), sk.multiplier_for("gold")])
	var sk2 = SK.new()
	sk2.activate("golden_wind", t0)
	ck("golden_wind raises gold only",
		sk2.multiplier_for("gold") > 1.0 and is_equal_approx(sk2.multiplier_for("tap_damage"), 1.0),
		"gold=%f tap=%f" % [sk2.multiplier_for("gold"), sk2.multiplier_for("tap_damage")])
	var sk3 = SK.new()
	sk3.activate("critical_eclipse", t0)
	var crit: float = sk3.bonus_for("crit_chance")
	ck("critical_eclipse adds crit chance within a safe range", crit > 0.0 and crit <= 0.95, str(crit))

	# same skill never stacks with itself
	var sk4 = SK.new()
	sk4.activate("sand_fury", t0)
	var once: float = sk4.multiplier_for("tap_damage")
	sk4.activate("sand_fury", t0 + 10)
	ck("re-activating does not stack the same skill",
		is_equal_approx(sk4.multiplier_for("tap_damage"), once), str(sk4.multiplier_for("tap_damage")))

	print("HEROES/SKILLS: FAIL %d" % failed if failed > 0 else "HEROES/SKILLS: all passed")
	quit(1 if failed > 0 else 0)
