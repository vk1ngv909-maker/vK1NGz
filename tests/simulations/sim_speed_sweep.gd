extends SceneTree
## Deterministic sweep for the speed relic curve.
##
## Speed relics were worth 0.6 seconds per prestige point against 45 for damage,
## which is not a choice a player can meaningfully make. This sweeps the two
## curve parameters and prints every candidate against the approved targets, so
## the value that ships is picked from measurements rather than taste.
##
## Targets, as reductions in first-Prestige time against the zero-relic run:
##   10 points  ->  8-12%
##   25 points  -> 15-22%
##   60 points  -> 25-35%
## and speed must stay weaker than damage and gold at the same investment.

const CS = preload("res://scripts/combat/combat_state.gd")
const RelicsLogic = preload("res://scripts/progression/relics.gd")

const SIM_SEED: int = 0x5EED17
const STEP: float = 1.0
const TAPS: float = 5.0
const PRESTIGE_STAGE: int = 25
const MAX_SECONDS: float = 400000.0
const BUDGETS: Array[int] = [10, 25, 60]
const TARGETS := {10: [0.08, 0.12], 25: [0.15, 0.22], 60: [0.25, 0.35]}


func bonus_for(category: String, budget: int) -> float:
	var relics = RelicsLogic.new(budget)
	var ids: Array = []
	for id_value: Variant in relics.relics:
		if str((relics.relics[id_value] as Dictionary)["category"]) == category:
			ids.append(str(id_value))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int((relics.relics[a] as Dictionary)["cost"]) < int((relics.relics[b] as Dictionary)["cost"]))
	for id: String in ids:
		relics.buy(id)
		while relics.upgrade(id):
			pass
	return relics.total_bonus(category)


func run_to(target_stage: int, damage: float, gold: float, falcon_rate: float) -> float:
	var c = CS.new()
	c.set_random_seed(SIM_SEED)
	c.spawn_enemy()
	c.set_relic_bonuses(damage, gold, 0.0)
	c._relic_falcon_rate_mult = falcon_rate
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
		var f: Dictionary = c.falcon_tick(STEP)
		if f.get("killed", false):
			c.spawn_enemy()
		t += STEP
	return t


func curve(bonus: float, gain: float, softcap: float, maximum: float) -> float:
	return minf(maximum, 1.0 + gain * bonus / (1.0 + softcap * bonus))


func _init() -> void:
	var baseline: float = run_to(PRESTIGE_STAGE, 1.0, 1.0, 1.0)
	print("=== Speed relic curve sweep (baseline %.0fs to stage %d) ===" % [baseline, PRESTIGE_STAGE])
	print("curve: rate = min(max, 1 + gain*bonus / (1 + softcap*bonus))")
	print("")
	var bonuses: Dictionary = {}
	for budget: int in BUDGETS:
		bonuses[budget] = bonus_for("speed", budget)
	print("speed bonus by budget: 10 -> %.3f, 25 -> %.3f, 60 -> %.3f" % [bonuses[10], bonuses[25], bonuses[60]])
	print("")

	# Reference: what damage and gold buy, so speed can be checked as weaker.
	var damage_10: float = run_to(PRESTIGE_STAGE, 1.0 + bonus_for("damage", 10), 1.0, 1.0)
	var gold_10: float = run_to(PRESTIGE_STAGE, 1.0, 1.0 + bonus_for("gold", 10), 1.0)
	print("reference at 10 points: damage -%.1f%%, gold -%.1f%%" % [
		(baseline - damage_10) / baseline * 100.0, (baseline - gold_10) / baseline * 100.0])
	print("")

	print("%6s | %8s | %7s | %8s | %8s | %8s | %s" % ["gain", "softcap", "max", "10pts", "25pts", "60pts", "verdict"])
	var accepted: Array = []
	for gain: float in [24.0, 40.0, 55.0, 70.0, 90.0]:
		for softcap: float in [0.35, 1.0, 2.0]:
			var maximum: float = 24.0
			var reductions: Array = []
			var rates: Array = []
			for budget: int in BUDGETS:
				var rate: float = curve(float(bonuses[budget]), gain, softcap, maximum)
				rates.append(rate)
				var seconds: float = run_to(PRESTIGE_STAGE, 1.0, 1.0, rate)
				reductions.append((baseline - seconds) / baseline)
			var reasons: Array[String] = []
			for index: int in BUDGETS.size():
				var budget: int = BUDGETS[index]
				var window: Array = TARGETS[budget]
				if float(reductions[index]) < float(window[0]):
					reasons.append("%dpt low" % budget)
				elif float(reductions[index]) > float(window[1]):
					reasons.append("%dpt high" % budget)
			# Monotonic and bounded are properties of the curve itself.
			if rates[0] >= rates[1] or rates[1] >= rates[2]:
				reasons.append("not monotonic")
			# Weaker than damage and gold at the SAME investment, early game.
			if float(reductions[0]) >= (baseline - damage_10) / baseline:
				reasons.append("beats damage at 10pt")
			if float(reductions[0]) >= (baseline - gold_10) / baseline:
				reasons.append("beats gold at 10pt")
			var verdict: String = "ACCEPT" if reasons.is_empty() else "reject: " + ", ".join(reasons)
			if reasons.is_empty():
				accepted.append([gain, softcap, maximum])
			print("%6.1f | %8.2f | %7.1f | %7.1f%% | %7.1f%% | %7.1f%% | %s" % [
				gain, softcap, maximum,
				float(reductions[0]) * 100.0, float(reductions[1]) * 100.0, float(reductions[2]) * 100.0,
				verdict])

	print("")
	if accepted.is_empty():
		print("SPEED SWEEP: no candidate met every target")
	else:
		print("SPEED SWEEP: %d candidates accepted; shipping gain=%.1f softcap=%.2f max=%.1f" % [
			accepted.size(), float(accepted[0][0]), float(accepted[0][1]), float(accepted[0][2])])
	quit(0)
