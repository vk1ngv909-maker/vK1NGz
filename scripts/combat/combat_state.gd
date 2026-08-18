class_name CombatState
extends RefCounted

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const SupportHeroes = preload("res://scripts/progression/support_heroes.gd")
const Inventory = preload("res://scripts/progression/inventory.gd")

# All combat balance lives here. Presentation code must consume results instead
# of duplicating these values or formulas.
const BALANCE_PATH: String = "res://resources/balance.json"

## Balance lives in data, per the master brief. `BALANCE_OVERRIDE` exists only
## so the balance simulation can sweep candidate values without editing the file.
static var BALANCE_OVERRIDE: Dictionary = {}
static var _balance_cache: Dictionary = {}

static func balance() -> Dictionary:
	if not BALANCE_OVERRIDE.is_empty():
		return BALANCE_OVERRIDE
	if _balance_cache.is_empty():
		var f: FileAccess = FileAccess.open(BALANCE_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				_balance_cache = parsed
	return _balance_cache

var stage: int = 1
var is_boss: bool = false
var enemy_hp: BigNumber = BigNumber.new()
var enemy_max_hp: BigNumber = BigNumber.new()
var gold: BigNumber = BigNumber.new()
var tap_level: int = 1
var boss_time_left: float = 0.0
var awaiting_retry: bool = false
var support_heroes: SupportHeroes
var support_total_dps: BigNumber = BigNumber.new()
var falcon_dps: BigNumber = BigNumber.new()
var inventory: Inventory

var _falcon_elapsed: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _relic_damage_mult: float = 1.0
var _relic_gold_mult: float = 1.0


func _init(
	initial_stage: int = 1,
	initial_gold: BigNumber = null,
	initial_tap_level: int = 1,
	run_state: Dictionary = {},
	permanent_state: Dictionary = {}
) -> void:
	stage = maxi(1, initial_stage)
	gold = initial_gold._copy_normalized() if initial_gold != null else BigNumber.new()
	tap_level = maxi(1, initial_tap_level)
	support_heroes = SupportHeroes.new()
	set_support_hero_levels(run_state.get("support_hero_levels", {}))
	inventory = Inventory.new()
	var saved_equipment: Variant = permanent_state.get("equipment", {})
	if saved_equipment is Dictionary:
		inventory.from_dict(saved_equipment as Dictionary)
	_rng.randomize()
	spawn_enemy()


func tap() -> Dictionary:
	if _cannot_attack():
		return {"ignored": true}
	var critical: bool = _rng.randf() < float(balance()["critical_chance"])
	var damage: BigNumber = get_tap_damage()
	var kind: String = "normal"
	if critical:
		damage = damage.mul_float(float(balance()["critical_multiplier"]))
		kind = "critical"
	return _apply_damage(damage, kind)


func falcon_tick(delta: float) -> Dictionary:
	if _cannot_attack():
		return {"ignored": true}
	_falcon_elapsed += maxf(0.0, delta)
	if _falcon_elapsed < float(balance()["falcon_interval"]):
		return {"attacked": false}
	_falcon_elapsed = fmod(_falcon_elapsed, float(balance()["falcon_interval"]))
	var damage: BigNumber = get_tap_damage().mul_float(float(balance()["falcon_damage_multiplier"]))
	return _apply_damage(damage, "falcon")


func dps_tick(delta: float) -> Dictionary:
	if _cannot_attack():
		return {"ignored": true}
	var combined_dps: BigNumber = support_total_dps.add(falcon_dps)
	var equipment_mult: float = 1.0 + inventory.total_stat("dps_mult")
	var damage: BigNumber = combined_dps.mul_float(maxf(0.0, delta) * _relic_damage_mult * equipment_mult)
	return _apply_damage(damage, "dps")


func tick(delta: float) -> Dictionary:
	if not is_boss or awaiting_retry or enemy_hp.mantissa == 0.0:
		return {}
	boss_time_left = maxf(0.0, boss_time_left - maxf(0.0, delta))
	if boss_time_left > 0.0:
		return {"boss_failed": false, "boss_time_left": boss_time_left}
	awaiting_retry = true
	return {"boss_failed": true, "boss_time_left": boss_time_left}


func retry_boss() -> void:
	if not awaiting_retry:
		return
	awaiting_retry = false
	spawn_enemy()


func buy_tap_upgrade() -> bool:
	var cost: BigNumber = get_upgrade_cost()
	if gold.compare(cost) < 0:
		return false
	gold = gold.sub(cost)
	tap_level += 1
	return true


func spawn_enemy() -> void:
	is_boss = stage % int(balance()["boss_stage_interval"]) == 0
	enemy_max_hp = get_enemy_hp(stage)
	if is_boss:
		enemy_max_hp = enemy_max_hp.mul_float(float(balance()["boss_hp_multiplier"]))
	enemy_hp = enemy_max_hp._copy_normalized()
	boss_time_left = float(balance()["boss_duration"]) if is_boss else 0.0
	_falcon_elapsed = 0.0


func get_tap_damage() -> BigNumber:
	var equipment_mult: float = 1.0 + inventory.total_stat("tap_damage_mult")
	# The master brief defines tap damage as base x hero_level_MULTIPLIER, i.e. it
	# grows multiplicatively with level. It was implemented linearly, which cannot
	# keep pace with exponential enemy HP and guarantees an impassable wall.
	var growth: float = float(balance().get("tap_damage_growth", 1.0))
	var per_level: float = float(balance()["tap_damage_per_level"])
	var scaled: BigNumber = BigNumber.from_float(per_level).mul(BigNumber.from_float(growth).pow_float(float(maxi(0, tap_level - 1))))
	return scaled.mul_float(_relic_damage_mult * equipment_mult)


func set_inventory(value: Inventory) -> void:
	inventory = value if value != null else Inventory.new()


func set_support_hero_levels(saved_levels: Variant) -> void:
	if saved_levels is Dictionary:
		support_heroes.from_dict(saved_levels as Dictionary)
	support_total_dps = support_heroes.total_dps()


func set_relic_bonuses(damage_mult: float, gold_mult: float) -> void:
	_relic_damage_mult = maxf(0.0, damage_mult) if is_finite(damage_mult) else 1.0
	_relic_gold_mult = maxf(0.0, gold_mult) if is_finite(gold_mult) else 1.0


func get_upgrade_cost() -> BigNumber:
	var growth: BigNumber = BigNumber.from_float(float(balance()["upgrade_cost_growth"]))
	return BigNumber.from_float(float(balance()["upgrade_cost_base"])).mul(growth.pow_float(tap_level))


static func get_enemy_hp(for_stage: int) -> BigNumber:
	var growth: BigNumber = BigNumber.from_float(float(balance()["enemy_hp_growth"]))
	return BigNumber.from_float(float(balance()["enemy_hp_base"])).mul(growth.pow_float(maxi(0, for_stage - 1)))


static func get_enemy_gold(for_stage: int) -> BigNumber:
	var growth: BigNumber = BigNumber.from_float(float(balance()["enemy_gold_growth"]))
	return BigNumber.from_float(float(balance()["enemy_gold_base"])).mul(growth.pow_float(maxi(0, for_stage - 1)))


func set_random_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func _cannot_attack() -> bool:
	return awaiting_retry or enemy_hp.mantissa == 0.0


func _apply_damage(damage: BigNumber, kind: String) -> Dictionary:
	var hp_before: BigNumber = enemy_hp
	enemy_hp = enemy_hp.sub(damage)
	var killed: bool = hp_before.mantissa > 0.0 and enemy_hp.mantissa == 0.0
	var gold_awarded: BigNumber = BigNumber.new()
	var stage_advanced: bool = false
	if killed:
		gold_awarded = get_enemy_gold(stage).mul_float(_relic_gold_mult)
		gold = gold.add(gold_awarded)
		stage += 1
		stage_advanced = true
	return {
		"damage": damage,
		"kind": kind,
		"killed": killed,
		"gold_awarded": gold_awarded,
		"stage_advanced": stage_advanced,
	}
