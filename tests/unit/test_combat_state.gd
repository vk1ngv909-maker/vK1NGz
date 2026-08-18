extends SceneTree

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	_test_formulas_and_boss_setup()
	_test_one_tap_one_application()
	_test_kill_rewards_and_advances_once()
	_test_falcon_interval_and_guard()
	_test_support_dps_and_kill_guard()
	_test_relic_multipliers()
	_test_upgrade_never_makes_gold_negative()
	_test_boss_failure_and_retry()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)


func _approx_number(value: BigNumber, expected: float) -> bool:
	return is_equal_approx(value.mantissa * pow(10.0, value.exponent), expected)


func _test_formulas_and_boss_setup() -> void:
	var state: CombatState = CombatState.new(10)
	_check(state.is_boss, "every tenth stage is a boss")
	_check(is_equal_approx(state.boss_time_left, 30.0), "boss starts with a 30 second timer")
	_check(_approx_number(CombatState.get_enemy_hp(2), 15.5), "enemy HP follows configured growth")
	_check(_approx_number(state.get_tap_damage(), 5.0), "tap damage is five per level")


func _test_one_tap_one_application() -> void:
	var state: CombatState = CombatState.new()
	state.set_random_seed(1)
	var before: BigNumber = state.enemy_hp
	var result: Dictionary = state.tap()
	var expected: BigNumber = before.sub(result["damage"] as BigNumber)
	_check(state.enemy_hp.equals(expected), "one tap applies its reported damage exactly once")


func _test_kill_rewards_and_advances_once() -> void:
	var state: CombatState = CombatState.new()
	state.enemy_hp = BigNumber.from_float(1.0)
	var first: Dictionary = state.tap()
	var gold_after_kill: BigNumber = state.gold
	var second: Dictionary = state.tap()
	_check(first["killed"] and first["stage_advanced"], "a lethal tap reports one kill and stage advance")
	_check(state.stage == 2, "stage advances exactly once per kill")
	var expected_gold: float = 5.0 * float(state.current_enemy.get("gold_modifier", 1.0))
	_check(_approx_number(gold_after_kill, expected_gold), "kill awards modifier-adjusted stage gold once")
	_check(second.get("ignored", false), "a same-frame tap after death is ignored")
	_check(state.gold.equals(gold_after_kill), "ignored post-death tap cannot duplicate gold")
	state.spawn_enemy()
	_check(state.enemy_hp.mantissa > 0.0, "next enemy is explicitly spawned after presentation finishes")


func _test_falcon_interval_and_guard() -> void:
	var state: CombatState = CombatState.new()
	var before: BigNumber = state.enemy_hp
	var waiting: Dictionary = state.falcon_tick(1.49)
	var attack: Dictionary = state.falcon_tick(0.01)
	_check(not waiting["attacked"] and state.enemy_hp.is_less_than(before), "falcon waits until its interval then attacks")
	_check(attack["kind"] == "falcon" and _approx_number(attack["damage"], 2.0), "falcon deals 40 percent tap damage")
	state.enemy_hp = BigNumber.new()
	_check(state.falcon_tick(2.0).get("ignored", false), "falcon cannot attack a dead enemy")


func _test_support_dps_and_kill_guard() -> void:
	var state: CombatState = CombatState.new(1, null, 1, {"support_hero_levels": {"dune_scout": 2}})
	state.falcon_dps = BigNumber.from_float(1.0)
	var result: Dictionary = state.dps_tick(0.5)
	_check(result["kind"] == "dps" and _approx_number(result["damage"], 2.5), "DPS reads support levels and adds explicit falcon DPS")
	state.enemy_hp = BigNumber.from_float(1.0)
	var kill: Dictionary = state.dps_tick(1.0)
	var gold_after_kill: BigNumber = state.gold
	var after_death: Dictionary = state.dps_tick(1.0)
	_check(kill["killed"] and kill["stage_advanced"] and state.stage == 2, "lethal DPS advances exactly one stage")
	var expected_gold: float = 5.0 * float(state.current_enemy.get("gold_modifier", 1.0))
	_check(_approx_number(gold_after_kill, expected_gold), "lethal DPS awards modifier-adjusted gold exactly once")
	_check(after_death.get("ignored", false) and state.gold.equals(gold_after_kill), "DPS after death cannot duplicate its reward")


func _test_relic_multipliers() -> void:
	var state: CombatState = CombatState.new(1, null, 2, {"support_hero_levels": {"dune_scout": 1}})
	state.set_relic_bonuses(2.0, 3.0)
	# Derive the expectation from the balance data, so retuning a balance value
	# does not fail a correctness test. The test asserts the RELATIONSHIP
	# (relic multiplier applies), not a hardcoded tuned number.
	var b: Dictionary = CombatState.balance()
	var expected_tap: float = float(b["tap_damage_per_level"]) * pow(float(b.get("tap_damage_growth", 1.0)), 1.0) * 2.0
	_check(_approx_number(state.get_tap_damage(), expected_tap), "damage relic multiplier applies to tap damage")
	var dps: Dictionary = state.dps_tick(0.5)
	_check(_approx_number(dps["damage"], 2.0), "damage relic multiplier applies to support DPS")
	state.enemy_hp = BigNumber.from_float(1.0)
	state.tap()
	var expected_gold: float = 15.0 * float(state.current_enemy.get("gold_modifier", 1.0))
	_check(_approx_number(state.gold, expected_gold), "gold relic and enemy multipliers apply to kill rewards")


func _test_upgrade_never_makes_gold_negative() -> void:
	var state: CombatState = CombatState.new()
	_check(not state.buy_tap_upgrade(), "unaffordable upgrade is rejected")
	_check(state.gold.equals(BigNumber.new()), "rejected upgrade leaves zero gold, never negative")
	state.gold = state.get_upgrade_cost()
	_check(state.buy_tap_upgrade(), "exactly affordable upgrade succeeds")
	_check(state.gold.equals(BigNumber.new()) and state.tap_level == 2, "upgrade spends exact cost and increments level")


func _test_boss_failure_and_retry() -> void:
	var state: CombatState = CombatState.new(10, BigNumber.from_float(321.0))
	var result: Dictionary = state.tick(30.0)
	_check(result["boss_failed"] and state.awaiting_retry, "boss timeout enters retry state")
	_check(state.stage == 10, "boss failure never resets progression to stage zero")
	_check(_approx_number(state.gold, 321.0), "boss failure preserves gold")
	_check(state.tap().get("ignored", false), "attacks are blocked while awaiting boss retry")
	state.retry_boss()
	_check(not state.awaiting_retry and state.is_boss and is_equal_approx(state.boss_time_left, 30.0), "retry restores the current boss and timer")
