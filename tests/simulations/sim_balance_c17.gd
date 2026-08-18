extends SceneTree
## C17 re-measurement: first-Prestige pacing with equipment rarities and the
## effect of offline gold. Deterministic; no wall clock.

const CS = preload("res://scripts/combat/combat_state.gd")
const BN = preload("res://scripts/utilities/big_number.gd")

const STEP: float = 1.0
const TAPS: float = 5.0
const PRESTIGE_STAGE: int = 25          # reward_for() first becomes non-zero here
const MAX_SECONDS: float = 400000.0

func run_to(target_stage: int, dmg_mult: float, gold_mult: float, start_gold: float = 0.0) -> Dictionary:
	var c = CS.new()
	c.set_relic_bonuses(dmg_mult, gold_mult)
	if start_gold > 0.0:
		c.gold = BN.from_float(start_gold)
	var t: float = 0.0
	var tap_acc: float = 0.0
	var upgrades: int = 0
	var stalled: float = 0.0
	var worst: float = 0.0
	var worst_stage: int = 0
	var last: int = c.stage
	while c.stage < target_stage and t < MAX_SECONDS:
		while c.buy_tap_upgrade():
			upgrades += 1
		tap_acc += TAPS * STEP
		while tap_acc >= 1.0 and c.stage < target_stage:
			tap_acc -= 1.0
			var r: Dictionary = c.tap()
			if r.get("killed", false):
				c.spawn_enemy()
		c.dps_tick(STEP)
		t += STEP
		if c.stage == last:
			stalled += STEP
			if stalled > worst:
				worst = stalled; worst_stage = c.stage
		else:
			stalled = 0.0; last = c.stage
	return {"seconds": t, "upgrades": upgrades, "worst_stall": worst, "stall_stage": worst_stage,
		"reached": c.stage, "gold_ok": not c.gold.is_less_than(BN.from_float(0.0)) and c.gold.is_valid()}

func row(label: String, r: Dictionary) -> void:
	print("%-34s | %9.0fs | %6.1f min | stage %3d | stall %7.0fs @%3d | gold_ok=%s" % [
		label, r["seconds"], float(r["seconds"]) / 60.0, int(r["reached"]),
		float(r["worst_stall"]), int(r["stall_stage"]), str(r["gold_ok"])])

func _init() -> void:
	print("=== C17 re-measurement: time to FIRST PRESTIGE (stage %d) ===" % PRESTIGE_STAGE)
	print("target window: 25-45 min (1500-2700s)")
	print("")
	var base := run_to(PRESTIGE_STAGE, 1.0, 1.0)
	row("no equipment", base)
	# representative equipment multipliers taken from equipment.json rarity tiers
	var common := run_to(PRESTIGE_STAGE, 1.05, 1.0)
	var rare := run_to(PRESTIGE_STAGE, 1.25, 1.05)
	var epic := run_to(PRESTIGE_STAGE, 1.60, 1.15)
	var legend := run_to(PRESTIGE_STAGE, 2.20, 1.30)
	row("common equipment", common)
	row("rare equipment", rare)
	row("epic equipment", epic)
	row("legendary equipment", legend)
	print("")
	print("=== offline gold effect (does it bypass the wall?) ===")
	var one_h := run_to(PRESTIGE_STAGE, 1.0, 1.0, 3600.0 * 1.0)
	var eight_h := run_to(PRESTIGE_STAGE, 1.0, 1.0, 14400.0)
	row("start with ~1h offline gold", one_h)
	row("start with ~8h offline gold", eight_h)
	print("")
	print("=== wall depth: stage 49 ===")
	var deep := run_to(50, 1.0, 1.0)
	row("no equipment to stage 50", deep)
	print("")
	var mins: float = float(base["seconds"]) / 60.0
	print("VERDICT first prestige (no equipment): %.1f min" % mins)
	if mins >= 25.0 and mins <= 45.0:
		print("C17 CRITERION 1: MET")
	else:
		print("C17 CRITERION 1: NOT MET (target 25-45 min)")
	quit(0)
