extends SceneTree
## How much a prestige point is worth, per relic category.
##
## Relics are the only permanent spend in the game, so the question a player
## asks is "what does this point buy me?". This measures it: for each category
## it spends a fixed budget cheapest-first, reads the bonus the relic system
## actually produces, and runs the same deterministic progression used by the
## C17 balance measurement. A category that cannot move the number is a category
## that does not exist as far as the player is concerned.

const CS = preload("res://scripts/combat/combat_state.gd")
const BN = preload("res://scripts/utilities/big_number.gd")
const RelicsLogic = preload("res://scripts/progression/relics.gd")
const SkillSystemLogic = preload("res://scripts/progression/skill_system.gd")

const SIM_SEED: int = 0x5EED17
const STEP: float = 1.0
const TAPS: float = 5.0
const PRESTIGE_STAGE: int = 25
const MAX_SECONDS: float = 400000.0
const BUDGETS: Array[int] = [0, 10, 25, 60]


func spend(category: String, budget: int) -> Dictionary:
	## Cheapest relic first, which is what a player does with a small budget.
	var relics = RelicsLogic.new(budget)
	var ids: Array = []
	for id_value: Variant in relics.relics:
		if str((relics.relics[id_value] as Dictionary)["category"]) == category:
			ids.append(str(id_value))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int((relics.relics[a] as Dictionary)["cost"]) < int((relics.relics[b] as Dictionary)["cost"]))
	var spent: int = 0
	for id: String in ids:
		# The first level is a purchase, every level after it an upgrade.
		if relics.buy(id):
			spent = budget - relics.prestige_currency
		while relics.upgrade(id):
			spent = budget - relics.prestige_currency
	return {"bonus": relics.total_bonus(category), "spent": spent, "relics": relics}


func run_to(target_stage: int, damage: float, gold: float, falcon: float) -> float:
	var c = CS.new()
	c.set_random_seed(SIM_SEED)
	c.spawn_enemy()
	c.set_relic_bonuses(damage, gold, falcon)
	var t: float = 0.0
	var tap_acc: float = 0.0
	while c.stage < target_stage and t < MAX_SECONDS:
		while c.buy_tap_upgrade():
			pass
		tap_acc += TAPS * STEP
		while tap_acc >= 1.0 and c.stage < target_stage:
			tap_acc -= 1.0
			var r: Dictionary = c.tap()
			if r.get("killed", false):
				c.spawn_enemy()
		c.dps_tick(STEP)
		var falcon_result: Dictionary = c.falcon_tick(STEP)
		if falcon_result.get("killed", false):
			c.spawn_enemy()
		t += STEP
	return t


func _init() -> void:
	print("=== Relic sensitivity: seconds to first Prestige (stage %d) ===" % PRESTIGE_STAGE)
	print("deterministic seed %d; budgets are prestige currency spent cheapest-first" % SIM_SEED)
	print("")
	var baseline: float = run_to(PRESTIGE_STAGE, 1.0, 1.0, 1.0)
	print("%-12s | %7s | %8s | %9s | %10s | %s" % ["category", "budget", "bonus", "seconds", "saved", "per point"])
	print("%-12s | %7d | %8s | %9.0f | %10s | %s" % ["baseline", 0, "-", baseline, "-", "-"])

	var inert: Array[String] = []
	for category: String in ["damage", "gold", "speed", "skills", "utility"]:
		var moved: bool = false
		for budget: int in BUDGETS:
			if budget == 0:
				continue
			var result: Dictionary = spend(category, budget)
			var bonus: float = float(result["bonus"])
			var seconds: float = baseline
			var note: String = ""
			match category:
				"damage": seconds = run_to(PRESTIGE_STAGE, 1.0 + bonus, 1.0, 1.0)
				"gold": seconds = run_to(PRESTIGE_STAGE, 1.0, 1.0 + bonus, 1.0)
				"speed": seconds = run_to(PRESTIGE_STAGE, 1.0, 1.0, 1.0 + bonus)
				"skills":
					# Skill relics shorten cooldowns; the effect is measured on the
					# skill system directly because this harness does not fire skills.
					var system = SkillSystemLogic.new()
					system.set_cooldown_multiplier(1.0 / (1.0 + bonus))
					system.activate("sand_fury", 1000, 100)
					var cooldown: int = int(system.cooldown_until_ms["sand_fury"]) - 1000
					note = "cooldown %.1fs (was 45.0s)" % (float(cooldown) / 1000.0)
					moved = moved or cooldown < 45000
				"utility":
					# Utility relics raise offline gold; measured as the multiplier
					# the offline reward is scaled by.
					note = "offline gold x%.2f" % (1.0 + bonus)
					moved = moved or bonus > 0.0
			if category in ["damage", "gold", "speed"]:
				var saved: float = baseline - seconds
				moved = moved or absf(saved) > 1.0
				print("%-12s | %7d | %8.3f | %9.0f | %10.0f | %8.1f s" % [
					category, budget, bonus, seconds, saved, saved / float(maxi(1, budget))])
			else:
				print("%-12s | %7d | %8.3f | %9s | %10s | %s" % [category, budget, bonus, "-", "-", note])
		if not moved:
			inert.append(category)

	print("")
	if inert.is_empty():
		print("RELIC SENSITIVITY: every category changes the game")
	else:
		print("RELIC SENSITIVITY: INERT CATEGORIES: %s" % ", ".join(inert))
	quit(1 if not inert.is_empty() else 0)
