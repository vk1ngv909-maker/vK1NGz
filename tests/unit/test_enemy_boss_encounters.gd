extends SceneTree

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const EnemyPool = preload("res://scripts/progression/enemy_pool.gd")
const BossPool = preload("res://scripts/progression/boss_pool.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")
const Validator = preload("res://autoload/content_validator.gd")

var failed: int = 0


func _init() -> void:
	_test_enemy_selection()
	_test_boss_archetypes_and_encounters()
	_test_simultaneous_death_rule()
	_test_first_clear_key_guards()
	print("ENEMY/BOSS ENCOUNTERS: FAIL %d" % failed if failed > 0 else "ENEMY/BOSS ENCOUNTERS: all passed")
	quit(1 if failed > 0 else 0)


func _test_enemy_selection() -> void:
	var pool: EnemyPool = EnemyPool.new()
	for stage: int in [1, 9, 34, 66, 67, 99]:
		var first: Dictionary = pool.select(stage, 8675309)
		var second: Dictionary = pool.select(stage, 8675309)
		_check(first == second, "same stage and seed select deterministically")
		var expected_world: String = "oasis_frontier" if stage <= 33 else ("moonlit_dunes" if stage <= 66 else "ruins_of_the_sun_kingdom")
		_check(str(first.get("world_id", "")) == expected_world, "regular enemy stays in active world")
	_check(pool.select(10, 1).is_empty(), "boss stage never selects a regular enemy")
	var state: CombatState = CombatState.new(1, null, 1, {"enemy_seed": 22})
	var base_hp: BigNumber = CombatState.get_enemy_hp(1)
	var expected_hp: BigNumber = base_hp.mul_float(float(state.current_enemy.get("hp_modifier", 1.0)))
	_check(state.enemy_max_hp.equals(expected_hp), "combat applies selected enemy HP modifier")
	state.enemy_hp = BigNumber.from_float(1.0)
	var reward: Dictionary = state.tap()
	var expected_gold: BigNumber = CombatState.get_enemy_gold(1).mul_float(float(state.current_enemy.get("gold_modifier", 1.0)))
	_check((reward["gold_awarded"] as BigNumber).equals(expected_gold), "combat applies selected enemy gold modifier")


func _test_boss_archetypes_and_encounters() -> void:
	var pool: BossPool = BossPool.new()
	_check(pool.bosses.size() == 4, "exactly four boss archetypes load")
	_check(str(pool.select(10).get("id", "")) == str(pool.select(40).get("id", "")), "stage 10 archetype repeats at stage 40")
	_check(str(pool.select(10).get("encounter_id", "")) == "stage_10", "encounter id is stage keyed")
	_check(str(pool.select(40).get("encounter_id", "")) == "stage_40", "repeated archetype receives a distinct encounter id")
	_check(pool.select(11).is_empty(), "non-boss stage has no boss archetype")
	_check(str(pool.select(110).get("id", "")) == str(pool.select(100).get("id", "")), "stages beyond 100 clamp to final-world boss assignment")


func _test_simultaneous_death_rule() -> void:
	var victory: CombatState = CombatState.new(10)
	victory.enemy_hp = BigNumber.from_float(1.0)
	var lethal: Dictionary = victory.skill_damage(BigNumber.from_float(1.0))
	var late_timeout: Dictionary = victory.tick(99.0)
	_check(lethal.get("killed", false) and victory.encounter_state == CombatState.EncounterState.VICTORY, "lethal skill damage accepted before timeout wins")
	_check(late_timeout.is_empty(), "timer cannot overwrite victory")
	_check(victory.tap().get("ignored", false) and victory.dps_tick(1.0).get("ignored", false) and victory.falcon_tick(9.0).get("ignored", false), "all later damage paths ignore completed encounter")
	var failed_state: CombatState = CombatState.new(10)
	failed_state.tick(99.0)
	_check(failed_state.encounter_state == CombatState.EncounterState.FAILED, "timer expiry transitions active encounter to failed")
	_check(failed_state.skill_damage(failed_state.enemy_hp).get("ignored", false), "damage after official failure is ignored")


func _test_first_clear_key_guards() -> void:
	var validator: Node = Validator.new()
	_check(validator.validate_first_clear_keys({"stage_10": true}, ["sandstorm_colossus"]), "encounter-keyed first clear is accepted")
	_check(not validator.validate_first_clear_keys({"sandstorm_colossus": true}, ["sandstorm_colossus"]), "archetype-keyed first clear is rejected")
	_check(not validator.validate_encounter_ids(["stage_10", "stage_10"]), "duplicate encounter ids are rejected")
	validator.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)
