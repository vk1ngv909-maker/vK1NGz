extends SceneTree

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")
const Prestige = preload("res://scripts/progression/prestige.gd")
const Relics = preload("res://scripts/progression/relics.gd")

const TARGET_STAGE: int = 50
const FIXED_STEP: float = 10.0
const TAPS_PER_SECOND: float = 5.0  # a real player taps far faster than once a second
const RANDOM_SEED: int = 20_260_818
const MAX_SIMULATED_SECONDS: float = 1_000_000.0

var _failed: bool = false

class RecordingSaveManager extends Node:
	var save_calls: int = 0

	func save(_state: Dictionary) -> bool:
		save_calls += 1
		return true


func _init() -> void:
	var empty_relics: Relics = Relics.new()
	var run_a: Dictionary = _simulate_run("A", empty_relics)

	var save_recorder: RecordingSaveManager = RecordingSaveManager.new()
	var prestige: Prestige = Prestige.new(save_recorder)
	var prestige_state: Dictionary = {
		"schema_version": 3,
		"run_state": {
			"stage": TARGET_STAGE,
			"gold": (run_a["final_gold"] as BigNumber).to_dict(),
			"tap_level": 1,
			"support_hero_levels": {},
		},
		"permanent_state": {
			"max_stage": TARGET_STAGE,
			"prestige_currency": 0,
			"relic_levels": {},
		},
	}
	var prestiged: Dictionary = prestige.apply(prestige_state)
	var reward: int = int((prestiged["permanent_state"] as Dictionary)["prestige_currency"])
	_require(reward > 0, "stage 50 must award Prestige currency")
	_require(save_recorder.save_calls == 1, "Prestige must save the reset immediately")
	var earned_relics: Relics = Relics.new(reward)
	var currency_spent: int = _spend_on_damage_relics(earned_relics, TARGET_STAGE)
	_require(currency_spent == reward, "Run B must spend all earned currency on damage relics")
	_require(earned_relics.total_bonus("damage") > 0.0, "Run B must own a damage relic")

	var run_b: Dictionary = _simulate_run("B", earned_relics)
	_print_results(run_a, run_b)
	_require(float(run_b["seconds"]) < float(run_a["seconds"]), "Run B must be strictly faster than Run A")
	save_recorder.free()
	quit(1 if _failed else 0)


func _simulate_run(run_name: String, relics: Relics) -> Dictionary:
	var run_state: Dictionary = {"support_hero_levels": {}}
	var combat: CombatState = CombatState.new(1, BigNumber.new(), 1, run_state)
	combat.set_random_seed(RANDOM_SEED)
	combat.set_relic_bonuses(1.0 + relics.total_bonus("damage"), 1.0 + relics.total_bonus("gold"))

	var elapsed: float = 0.0
	var tap_progress: float = 0.0
	var upgrades_bought: int = 0
	var half_at: float = -1.0
	var eighty_at: float = -1.0
	var half_stage: int = int(ceil(TARGET_STAGE * 0.5))
	var eighty_stage: int = int(ceil(TARGET_STAGE * 0.8))
	var last_stage: int = combat.stage
	var stalled_for: float = 0.0
	var worst_stall: float = 0.0
	var stall_stage: int = 0
	while combat.stage < TARGET_STAGE and elapsed < MAX_SIMULATED_SECONDS:
		if combat.stage >= half_stage and half_at < 0.0:
			half_at = elapsed
		if combat.stage >= eighty_stage and eighty_at < 0.0:
			eighty_at = elapsed
		if combat.stage == last_stage:
			stalled_for += FIXED_STEP
			if stalled_for > worst_stall:
				worst_stall = stalled_for
				stall_stage = combat.stage
		else:
			stalled_for = 0.0
			last_stage = combat.stage
		while _buy_cheapest_upgrade(combat):
			upgrades_bought += 1
			_validate_gold(combat.gold, "%s after upgrade %d" % [run_name, upgrades_bought])

		_apply_and_spawn(combat, combat.dps_tick(FIXED_STEP))
		_apply_and_spawn(combat, combat.falcon_tick(FIXED_STEP))
		tap_progress += TAPS_PER_SECOND * FIXED_STEP
		while tap_progress >= 1.0 and combat.stage < TARGET_STAGE:
			tap_progress -= 1.0
			_apply_and_spawn(combat, combat.tap())

		elapsed += FIXED_STEP
		_validate_gold(combat.gold, "%s at %.2f seconds" % [run_name, elapsed])

	_require(combat.stage >= TARGET_STAGE, "%s stopped at stage %d before target %d" % [run_name, combat.stage, TARGET_STAGE])
	return {
		"run": run_name,
		"seconds": elapsed,
		"half_at": half_at,
		"eighty_at": eighty_at,
		"worst_stall": worst_stall,
		"stall_stage": stall_stage,
		"upgrades_bought": upgrades_bought,
		"final_gold": combat.gold._copy_normalized(),
	}


func _apply_and_spawn(combat: CombatState, result: Dictionary) -> void:
	if result.get("killed", false):
		combat.spawn_enemy()


func _buy_cheapest_upgrade(combat: CombatState) -> bool:
	var cheapest_kind: String = "tap"
	var cheapest_id: String = ""
	var cheapest_cost: BigNumber = combat.get_upgrade_cost()
	for id_value: Variant in combat.support_heroes.heroes:
		var id: String = str(id_value)
		var definition: Dictionary = combat.support_heroes.heroes[id]
		if combat.stage < int(definition.get("unlock_stage", 1)):
			continue
		var hero_cost: BigNumber = combat.support_heroes.cost_for_level(id, combat.support_heroes.get_level(id))
		if hero_cost.compare(cheapest_cost) < 0:
			cheapest_kind = "hero"
			cheapest_id = id
			cheapest_cost = hero_cost

	if combat.gold.compare(cheapest_cost) < 0:
		return false
	if cheapest_kind == "tap":
		return combat.buy_tap_upgrade()

	combat.support_heroes.gold = combat.gold._copy_normalized()
	var purchased: bool
	if combat.support_heroes.get_level(cheapest_id) == 0:
		purchased = combat.support_heroes.hire(cheapest_id)
	else:
		purchased = combat.support_heroes.level_up(cheapest_id)
	if purchased:
		combat.gold = combat.support_heroes.gold._copy_normalized()
		combat.set_support_hero_levels(combat.support_heroes.levels)
	return purchased


func _spend_on_damage_relics(relics: Relics, max_stage: int) -> int:
	var starting_currency: int = relics.prestige_currency
	while relics.prestige_currency > 0:
		var best_id: String = ""
		var best_value: float = -1.0
		for id_value: Variant in relics.relics:
			var id: String = str(id_value)
			var definition: Dictionary = relics.relics[id]
			if str(definition.get("category", "")) != "damage":
				continue
			var unlock: Dictionary = definition.get("unlock_condition", {})
			if max_stage < int(unlock.get("max_stage", 0)):
				continue
			var cost: int = relics.cost_for_next_level(id)
			if cost <= 0 or cost > relics.prestige_currency:
				continue
			if relics.get_level(id) >= int(definition.get("max_level", 0)):
				continue
			var gain: float = float(definition["base_effect"]) if relics.get_level(id) == 0 else float(definition["growth"])
			var value: float = gain / float(cost)
			if value > best_value:
				best_value = value
				best_id = id
		if best_id.is_empty():
			break
		var bought: bool = relics.buy(best_id) if relics.get_level(best_id) == 0 else relics.upgrade(best_id)
		if not bought:
			break
	return starting_currency - relics.prestige_currency


func _validate_gold(value: BigNumber, context: String) -> void:
	_require(value.is_valid(), "%s produced NaN/INF gold" % context)
	_require(value.mantissa >= 0.0, "%s produced negative gold" % context)


func _print_results(run_a: Dictionary, run_b: Dictionary) -> void:
	print("run | to_stage_50 | to_50%_of_max | to_80%_of_max | upgrades | final_gold")
	print("----|-------------|---------------|---------------|----------|-----------")
	_print_row(run_a)
	_print_row(run_b)
	var a_s: float = float(run_a["seconds"])
	var b_s: float = float(run_b["seconds"])
	print("")
	print("improvement to stage 50 : %.1f%% faster after prestige" % ((1.0 - b_s / a_s) * 100.0))
	print("worst stall  run A      : %.0fs at stage %d" % [float(run_a["worst_stall"]), int(run_a["stall_stage"])])
	print("worst stall  run B      : %.0fs at stage %d" % [float(run_b["worst_stall"]), int(run_b["stall_stage"])])
	print("")
	print("BRIEF TARGET: first prestige in 25-45 minutes (1500-2700s).")
	if a_s > 2700.0:
		print("BALANCE WARNING: run A took %.0fs (%.1f hours) to reach stage %d — far above target." % [a_s, a_s / 3600.0, TARGET_STAGE])


func _print_row(result: Dictionary) -> void:
	var final_gold: BigNumber = result["final_gold"] as BigNumber
	print("%s   | %11.0f | %13.0f | %13.0f | %8d | %s" % [
		result["run"], result["seconds"], float(result["half_at"]), float(result["eighty_at"]),
		result["upgrades_bought"], final_gold.format()])


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("ASSERTION FAILED: " + message)
