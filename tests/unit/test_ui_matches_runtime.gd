extends SceneTree
## Point 6: the numbers a player reads must equal what the game actually
## computes. A panel that displays a stale or independently-derived value is a
## lie the player acts on, and no screenshot alone catches it.

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
	var first: String = str((heroes[0] as Dictionary)["id"])

	# ---- Buy Max must buy exactly what it advertises ----
	var s = SH.new()
	s.gold = BN.from_float(500000.0)
	s.hire(first, 100)
	var advertised: int = s.max_affordable(first, s.gold)
	var level_before: int = s.get_level(first)
	s.level_up(first, advertised)
	ck("Buy Max buys exactly the advertised quantity",
		s.get_level(first) - level_before == advertised,
		"advertised %d, bought %d" % [advertised, s.get_level(first) - level_before])
	ck("Buy Max leaves gold non-negative", not s.gold.is_less_than(BN.from_float(0.0)), s.gold.format())
	ck("one more level than Max is unaffordable",
		s.max_affordable(first, s.gold) == 0 or s.cost_for(first, 1).is_greater_than(s.gold),
		"remaining gold %s" % s.gold.format())

	# ---- displayed next-level gain must equal the real DPS delta ----
	var s2 = SH.new()
	s2.gold = BN.from_float(1e20)
	s2.hire(first, 100)
	# The panel shows THIS HERO's gain, so compare against this hero's delta.
	var hero_before: BigNumber = s2.hero_dps(first)
	var predicted: BigNumber = s2.next_level_gain(first)
	s2.level_up(first, 1)
	var actual: BigNumber = s2.hero_dps(first).sub(hero_before)
	ck("displayed next-level gain matches the real per-hero DPS delta",
		predicted.format() == actual.format(), "shown %s, actual %s" % [predicted.format(), actual.format()])

	# ---- milestone visual state must match the applied bonus ----
	var s3 = SH.new()
	s3.gold = BN.from_float(1e25)
	s3.hire(first, 100)
	s3.level_up(first, 8)                       # just below the level-10 milestone
	var below: BigNumber = s3.total_dps()
	s3.level_up(first, 2)                       # crosses it
	var above: BigNumber = s3.total_dps()
	ck("crossing a milestone actually raises DPS", above.is_greater_than(below),
		"%s -> %s" % [below.format(), above.format()])
	if s3.has_method("milestone_progress"):
		var prog: Dictionary = s3.milestone_progress(first)
		ck("milestone progress reports the crossed threshold",
			int(prog.get("level", 0)) >= 10, str(prog))

	# ---- skill remaining-time values must be real, not decorative ----
	var sk = SK.new()
	var t0: int = 1_700_000_000_000
	sk.activate("sand_fury", t0)
	var remain_at_2s: int = sk.remaining_active_ms("sand_fury", t0 + 2000) if sk.has_method("remaining_active_ms") else -1
	if remain_at_2s >= 0:
		ck("remaining ACTIVE time counts down truthfully",
			remain_at_2s > 7000 and remain_at_2s <= 8000, "%d ms left after 2s of a 10s skill" % remain_at_2s)
	sk.tick(t0 + 11000)
	var cd: int = sk.remaining_cooldown_ms("sand_fury", t0 + 11000) if sk.has_method("remaining_cooldown_ms") else -1
	if cd >= 0:
		ck("remaining COOLDOWN time is real", cd > 30000 and cd <= 45000, "%d ms" % cd)

	# ---- close/reopen during ACTIVE and during COOLDOWN ----
	var a = SK.new()
	a.activate("golden_wind", t0)
	var mid: SkillSystem = SK.new()
	mid.from_dict(a.to_dict())
	mid.tick(t0 + 3000)
	ck("reopening mid-ACTIVE keeps the skill active", mid.multiplier_for("gold") > 1.0)
	var late: SkillSystem = SK.new()
	late.from_dict(a.to_dict())
	late.tick(t0 + 20000)
	ck("reopening mid-COOLDOWN keeps it on cooldown", late.activate("golden_wind", t0 + 20000) == false)

	print("UI/RUNTIME: FAIL %d" % failed if failed > 0 else "UI/RUNTIME: all passed")
	quit(1 if failed > 0 else 0)
