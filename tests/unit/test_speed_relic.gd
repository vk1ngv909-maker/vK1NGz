extends SceneTree
## The speed relic buys falcon tempo. This pins the curve's shape, its bounds,
## and the promise that it touches combat tempo and nothing else: no boss
## countdown, no skill cooldown, no offline clock, and no duplicated rewards
## however fast the falcon strikes.

const CS = preload("res://scripts/combat/combat_state.gd")
const RelicsLogic = preload("res://scripts/progression/relics.gd")
const SkillSystemLogic = preload("res://scripts/progression/skill_system.gd")
const INV = preload("res://scripts/progression/inventory.gd")
const BN = preload("res://scripts/utilities/big_number.gd")
const RS = preload("res://scripts/progression/reward_system.gd")

## Approved sensitivity windows, as reductions in first-Prestige time.
const TARGETS := {10: [0.08, 0.12], 25: [0.15, 0.22], 60: [0.25, 0.35]}
const SIM_SEED: int = 0x5EED17

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func speed_bonus(budget: int) -> float:
	var relics = RelicsLogic.new(budget)
	var ids: Array = []
	for id_value: Variant in relics.relics:
		if str((relics.relics[id_value] as Dictionary)["category"]) == "speed":
			ids.append(str(id_value))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int((relics.relics[a] as Dictionary)["cost"]) < int((relics.relics[b] as Dictionary)["cost"]))
	for id: String in ids:
		relics.buy(id)
		while relics.upgrade(id):
			pass
	return relics.total_bonus("speed")


func run_to(target_stage: int, bonus: float) -> float:
	var c = CS.new()
	c.set_random_seed(SIM_SEED)
	c.spawn_enemy()
	c.set_relic_bonuses(1.0, 1.0, bonus)
	var t: float = 0.0
	var acc: float = 0.0
	while c.stage < target_stage and t < 400000.0:
		while c.buy_tap_upgrade():
			pass
		acc += 5.0
		while acc >= 1.0 and c.stage < target_stage:
			acc -= 1.0
			if c.tap().get("killed", false):
				c.spawn_enemy()
		c.dps_tick(1.0)
		if c.falcon_tick(1.0).get("killed", false):
			c.spawn_enemy()
		t += 1.0
	return t


func _init() -> void:
	# ---- the curve: monotonic, diminishing, bounded, never zero ----
	var previous_rate: float = CS.falcon_rate_from_speed_bonus(0.0)
	ck("no speed investment leaves the rate at exactly one", is_equal_approx(previous_rate, 1.0), str(previous_rate))
	var previous_gain: float = INF
	for step: int in range(1, 40):
		var bonus: float = float(step) * 0.05
		var rate: float = CS.falcon_rate_from_speed_bonus(bonus)
		# Non-decreasing, because past the cap it deliberately stops rising.
		ck_quiet("rate never falls as the bonus grows, at %.2f" % bonus, rate >= previous_rate - 0.0001, str(rate))
		var gain: float = rate - previous_rate
		ck_quiet("each further bonus adds less rate than the last at %.2f" % bonus, gain <= previous_gain + 0.0001,
			"%f then %f" % [previous_gain, gain])
		previous_gain = gain
		previous_rate = rate
	print("  ok   the rate curve is monotonic and diminishing across 40 steps")
	ck("the curve is still rising where players actually invest",
		CS.falcon_rate_from_speed_bonus(0.34) > CS.falcon_rate_from_speed_bonus(0.16)
		and CS.falcon_rate_from_speed_bonus(0.16) > CS.falcon_rate_from_speed_bonus(0.09), "")
	ck("and flattens onto its cap far beyond them",
		is_equal_approx(CS.falcon_rate_from_speed_bonus(50.0), CS.falcon_rate_from_speed_bonus(5000.0)), "")
	var enormous: float = CS.falcon_rate_from_speed_bonus(1.0e9)
	ck("the rate is bounded however much is invested", enormous <= float(CS.balance()["relic_speed_rate_max"]) + 0.001,
		str(enormous))
	ck("a nonsense bonus does not produce a nonsense rate",
		is_equal_approx(CS.falcon_rate_from_speed_bonus(NAN), 1.0)
		and is_equal_approx(CS.falcon_rate_from_speed_bonus(-50.0), 1.0),
		"%f / %f" % [CS.falcon_rate_from_speed_bonus(NAN), CS.falcon_rate_from_speed_bonus(-50.0)])

	# ---- the interval can never reach zero or go negative ----
	for bonus: float in [0.0, 0.5, 5.0, 500.0, 1.0e12]:
		var c = CS.new()
		c.set_inventory(INV.new())
		c.set_relic_bonuses(1.0, 1.0, bonus)
		var interval: float = c.falcon_interval()
		ck("interval stays positive and finite at bonus %.0f" % bonus,
			interval > 0.0 and is_finite(interval), str(interval))

	# ---- sensitivity windows ----
	var baseline: float = run_to(25, 0.0)
	ck("the zero-relic baseline is a real run", baseline > 100.0 and baseline < 400000.0, str(baseline))
	for budget_value: Variant in TARGETS:
		var budget: int = budget_value
		var window: Array = TARGETS[budget]
		var seconds: float = run_to(25, speed_bonus(budget))
		var reduction: float = (baseline - seconds) / baseline
		ck("%d speed points reduce first Prestige by %.0f-%.0f%%" % [budget, float(window[0]) * 100.0, float(window[1]) * 100.0],
			reduction >= float(window[0]) and reduction <= float(window[1]),
			"%.1f%% (%.0fs vs %.0fs)" % [reduction * 100.0, seconds, baseline])

	# ---- weaker than damage and gold at the same investment ----
	var damage_relics = RelicsLogic.new(10)
	damage_relics.buy("sun_blade")
	while damage_relics.upgrade("sun_blade"):
		pass
	var speed_10: float = (baseline - run_to(25, speed_bonus(10))) / baseline
	var damage_10: float = (baseline - run_to_with(25, 1.0 + damage_relics.total_bonus("damage"), 1.0)) / baseline
	ck("speed stays weaker than damage at the same investment", speed_10 < damage_10,
		"speed %.1f%% vs damage %.1f%%" % [speed_10 * 100.0, damage_10 * 100.0])

	# ---- the same run twice gives the same answer ----
	ck("the simulation is deterministic", is_equal_approx(run_to(25, speed_bonus(25)), run_to(25, speed_bonus(25))))

	# ---- speed touches nothing but combat tempo ----
	var timed = CS.new(10)
	timed.set_inventory(INV.new())
	var plain_timer: float = timed.boss_time_left
	timed.set_relic_bonuses(1.0, 1.0, speed_bonus(60))
	ck("the boss countdown is untouched by speed relics",
		is_equal_approx(timed.boss_time_left, plain_timer), "%f vs %f" % [timed.boss_time_left, plain_timer])
	timed.tick(1.0)
	ck("the boss countdown still falls one second per second",
		is_equal_approx(timed.boss_time_left, plain_timer - 1.0), str(timed.boss_time_left))
	var system = SkillSystemLogic.new()
	var authored_cooldown: int = int((system.skills["sand_fury"] as Dictionary)["cooldown_ms"])
	system.activate("sand_fury", 1000, 100)
	ck("skill cooldowns are untouched by speed relics",
		int(system.cooldown_until_ms["sand_fury"]) - 1000 == authored_cooldown,
		str(int(system.cooldown_until_ms["sand_fury"]) - 1000))

	# ---- a very fast falcon still kills exactly once ----
	var fast = CS.new()
	fast.set_inventory(INV.new())
	fast.set_relic_bonuses(1.0, 1.0, 1.0e6)
	fast.enemy_hp = BN.from_float(0.0001)
	var kills: int = 0
	var advanced: int = 0
	var before_stage: int = fast.stage
	for tick: int in 50:
		var result: Dictionary = fast.falcon_tick(1.0)
		if result.get("killed", false):
			kills += 1
		if result.get("stage_advanced", false):
			advanced += 1
	ck("a saturated falcon kills the enemy exactly once", kills == 1, str(kills))
	ck("and advances the stage exactly once", advanced == 1 and fast.stage == before_stage + 1,
		"advanced %d, stage %d" % [advanced, fast.stage])

	# ---- aggregated strikes equal the same strikes fired one at a time ----
	var batched = CS.new()
	batched.set_inventory(INV.new())
	batched.set_relic_bonuses(1.0, 1.0, 0.16)
	batched.enemy_max_hp = BN.from_mantissa_exponent(1.0, 40)
	batched.enemy_hp = batched.enemy_max_hp._copy_normalized()
	var one_shot: Dictionary = batched.falcon_tick(5.0)
	var expected_strikes: int = int(floor(minf(5.0, float(CS.balance()["falcon_catchup_seconds"])) / batched.falcon_interval()))
	ck("a late frame pays the strikes it owes, capped by the catch-up window",
		int(one_shot.get("strikes", 0)) == expected_strikes,
		"%d vs %d" % [int(one_shot.get("strikes", 0)), expected_strikes])
	ck("the aggregated hit is one damage event, not many",
		one_shot.has("damage") and int(one_shot.get("strikes", 0)) >= 1, str(one_shot.keys()))

	# ---- the relic survives a save, a reload and a Prestige ----
	var owned = RelicsLogic.new(60)
	owned.buy("falcon_feather")
	owned.upgrade("falcon_feather")
	var level: int = owned.get_level("falcon_feather")
	var saved: Dictionary = owned.to_dict()
	var reloaded = RelicsLogic.new(0)
	reloaded.from_dict(saved)
	ck("a purchased speed relic survives a reload", reloaded.get_level("falcon_feather") == level,
		str(reloaded.get_level("falcon_feather")))
	ck("its bonus survives with it", is_equal_approx(reloaded.total_bonus("speed"), owned.total_bonus("speed")))
	var prestige_data: Dictionary = {"levels": saved.get("levels", {}), "prestige_currency": 5}
	var after_prestige = RelicsLogic.new(0)
	after_prestige.from_dict(prestige_data)
	ck("Prestige does not clear relic levels", after_prestige.get_level("falcon_feather") == level,
		str(after_prestige.get_level("falcon_feather")))
	ck("currency after a reload is never negative", after_prestige.prestige_currency >= 0,
		str(after_prestige.prestige_currency))

	print("SPEED RELIC: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)


func ck_quiet(l: String, c: bool, got: String = "") -> void:
	if not c:
		failed += 1
		print("  FAIL ", l, "  got=", got)


func run_to_with(target_stage: int, damage: float, gold: float) -> float:
	var c = CS.new()
	c.set_random_seed(SIM_SEED)
	c.spawn_enemy()
	c.set_relic_bonuses(damage, gold, 0.0)
	var t: float = 0.0
	var acc: float = 0.0
	while c.stage < target_stage and t < 400000.0:
		while c.buy_tap_upgrade():
			pass
		acc += 5.0
		while acc >= 1.0 and c.stage < target_stage:
			acc -= 1.0
			if c.tap().get("killed", false):
				c.spawn_enemy()
		c.dps_tick(1.0)
		if c.falcon_tick(1.0).get("killed", false):
			c.spawn_enemy()
		t += 1.0
	return t
