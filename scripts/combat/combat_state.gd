class_name CombatState
extends RefCounted

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const SupportHeroes = preload("res://scripts/progression/support_heroes.gd")
const Inventory = preload("res://scripts/progression/inventory.gd")
const RewardSystem = preload("res://scripts/progression/reward_system.gd")
const SaveAdapterLogic = preload("res://scripts/utilities/save_adapter.gd")
const SaveManagerLogic = preload("res://autoload/save_manager.gd")

# All combat balance lives here. Presentation code must consume results instead
# of duplicating these values or formulas.
## Balance lives in data, per the master brief. `BALANCE_OVERRIDE` exists only
## so the balance simulation can sweep candidate values without editing the file.
static var BALANCE_OVERRIDE: Dictionary = {}
static var _balance_cache: Dictionary = {}

static func balance() -> Dictionary:
	if not BALANCE_OVERRIDE.is_empty():
		return BALANCE_OVERRIDE
	if _balance_cache.is_empty():
		var loop: MainLoop = Engine.get_main_loop()
		if loop is SceneTree:
			var loader: Node = (loop as SceneTree).root.get_node_or_null("BalanceData")
			if loader != null:
				_balance_cache = (loader.call("data") as Dictionary).duplicate(true)
		if _balance_cache.is_empty():
			var standalone_loader: Node = preload("res://autoload/balance_data.gd").new()
			_balance_cache = (standalone_loader.call("load_from_path", "res://resources/balance.json") as Dictionary).duplicate(true)
			standalone_loader.free()
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
var boss_first_clears: Dictionary = {}
var max_stage_reached: int = 1
## Variant permits small duck-typed failure adapters in headless tests while
## the production default is the concrete SaveAdapter requested by the API.
var save_adapter: Variant = SaveAdapterLogic.new()
var reward_pity: Dictionary = {}

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
	max_stage_reached = maxi(stage, int(permanent_state.get("max_stage", stage)))
	inventory.max_stage_reached = max_stage_reached
	var saved_equipment: Variant = permanent_state.get("equipment", {})
	if saved_equipment is Dictionary:
		inventory.from_dict(saved_equipment as Dictionary)
	_load_boss_first_clears(permanent_state.get("boss_first_clears", {}))
	var saved_pity: Variant = permanent_state.get("reward_pity", {})
	if saved_pity is Dictionary:
		reward_pity = (saved_pity as Dictionary).duplicate(true)
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
	var equipment_mult: float = 1.0 + _diminished(inventory.total_stat("dps_mult"))
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
	var equipment_mult: float = 1.0 + _diminished(inventory.total_stat("tap_damage_mult"))
	# The master brief defines tap damage as base x hero_level_MULTIPLIER, i.e. it
	# grows multiplicatively with level. It was implemented linearly, which cannot
	# keep pace with exponential enemy HP and guarantees an impassable wall.
	var growth: float = float(balance().get("tap_damage_growth", 1.0))
	var per_level: float = float(balance()["tap_damage_per_level"])
	var scaled: BigNumber = BigNumber.from_float(per_level).mul(BigNumber.from_float(growth).pow_float(float(maxi(0, tap_level - 1))))
	return scaled.mul_float(_relic_damage_mult * equipment_mult)


static func _diminished(raw: float) -> float:
	## Diminishing returns on summed equipment bonuses. Raw sums let a full
	## legendary set nearly double early damage, which collapsed first-Prestige
	## pacing to 13.5 min. This keeps rarity meaningful while stopping the
	## early game from being skipped. k is tuned by measured sweep, not guessed.
	if raw <= 0.0:
		return 0.0
	var k: float = float(balance().get("equipment_diminishing_k", 1.5))
	return raw / (1.0 + k * raw)


func set_inventory(value: Inventory) -> void:
	inventory = value if value != null else Inventory.new()
	inventory.max_stage_reached = max_stage_reached


func begin_boss_first_clear(boss_stage: int, rewards: RewardSystem) -> Dictionary:
	## This is the reversible in-memory half of the transaction. The arena only
	## finalizes it by saving; a failed save calls rollback_boss_first_clear().
	if boss_stage < 1 or rewards == null:
		return {"granted": false, "reason": "invalid"}
	var stage_key: String = str(boss_stage)
	if bool(boss_first_clears.get(stage_key, false)):
		return {"granted": false, "reason": "already_cleared"}
	var table_id: String = rewards.table_id_for_boss(boss_stage)
	if table_id.is_empty():
		push_error("CombatState: no first-clear reward table for boss %d" % boss_stage)
		return {"granted": false, "reason": "invalid"}
	rewards.pity_counter = maxi(0, int(reward_pity.get(table_id, rewards.pity_counter)))
	var reward: Dictionary = rewards.roll(table_id, maxi(max_stage_reached, boss_stage), inventory)
	if not bool(reward.get("granted", false)):
		return reward
	var uid: String = inventory.acquire(str(reward["item_id"]), maxi(max_stage_reached, boss_stage))
	if uid.is_empty():
		return {"granted": false, "item_id": "", "rarity": "", "reason": "inventory_full" if inventory.is_full() else "invalid"}
	boss_first_clears[stage_key] = true
	reward["previous_max_stage"] = max_stage_reached
	max_stage_reached = maxi(max_stage_reached, boss_stage + 1)
	inventory.max_stage_reached = max_stage_reached
	reward["uid"] = uid
	reward["boss_stage"] = boss_stage
	reward["table_id"] = table_id
	reward["reward_system"] = rewards
	reward_pity[table_id] = rewards.pity_counter
	return reward


func commit_boss_first_clear(transaction: Dictionary) -> bool:
	if not bool(transaction.get("granted", false)) or save_adapter == null or not save_adapter.has_method("save"):
		return false
	var save_data: Dictionary = transaction.get("save_data", {})
	if save_data.is_empty():
		save_data = _transaction_save_data()
	if not bool(save_adapter.call("save", save_data.duplicate(true))):
		rollback_boss_first_clear(transaction)
		return false
	return true


func rollback_boss_first_clear(transaction: Dictionary) -> void:
	if not bool(transaction.get("granted", false)):
		return
	var uid: String = str(transaction.get("uid", ""))
	var boss_stage: int = int(transaction.get("boss_stage", 0))
	if not uid.is_empty():
		inventory.remove(uid)
	if boss_stage > 0:
		boss_first_clears.erase(str(boss_stage))
	max_stage_reached = int(transaction.get("previous_max_stage", max_stage_reached))
	inventory.max_stage_reached = max_stage_reached
	var table_id: String = str(transaction.get("table_id", ""))
	var previous_pity: int = int(transaction.get("previous_pity", 0))
	if not table_id.is_empty():
		reward_pity[table_id] = previous_pity
	var rewards: Variant = transaction.get("reward_system")
	if rewards != null and rewards is RewardSystem:
		(rewards as RewardSystem).pity_counter = previous_pity


func save_into(base: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	if result.is_empty():
		var standalone_manager: Node = SaveManagerLogic.new()
		result = standalone_manager.call("default_data") as Dictionary
		standalone_manager.free()
	var run_state: Dictionary = result.get("run_state", {})
	var permanent_state: Dictionary = result.get("permanent_state", {})
	run_state["stage"] = stage
	run_state["gold"] = gold.to_dict()
	run_state["tap_level"] = tap_level
	run_state["boss_time_left"] = boss_time_left
	run_state["awaiting_retry"] = awaiting_retry
	permanent_state["max_stage"] = maxi(maxi(int(permanent_state.get("max_stage", 1)), max_stage_reached), stage)
	permanent_state["equipment"] = inventory.to_dict()
	permanent_state["boss_first_clears"] = boss_first_clears.duplicate(true)
	permanent_state["reward_pity"] = reward_pity.duplicate(true)
	permanent_state["last_seen_utc"] = int(Time.get_unix_time_from_system())
	result["run_state"] = run_state
	result["permanent_state"] = permanent_state
	return result


func _transaction_save_data() -> Dictionary:
	var base: Dictionary = {}
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var manager: Node = (loop as SceneTree).root.get_node_or_null("SaveManager")
		if manager != null:
			var current: Variant = manager.get("data")
			if current is Dictionary:
				base = current as Dictionary
	return save_into(base)


func _load_boss_first_clears(value: Variant) -> void:
	boss_first_clears.clear()
	if not value is Dictionary:
		push_warning("CombatState: ignoring malformed boss_first_clears")
		return
	for stage_value: Variant in value:
		var boss_stage: int = int(stage_value)
		if boss_stage > 0 and bool((value as Dictionary)[stage_value]):
			boss_first_clears[str(boss_stage)] = true


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


func get_pity(table_id: String = "boss_first_clear_default") -> int:
	return maxi(0, int(reward_pity.get(table_id, 0)))


func _cannot_attack() -> bool:
	return awaiting_retry or enemy_hp.mantissa == 0.0


func _apply_damage(damage: BigNumber, kind: String) -> Dictionary:
	var defeated_stage: int = stage
	var defeated_boss: bool = is_boss
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
		"boss_stage": defeated_stage if killed and defeated_boss else 0,
	}
