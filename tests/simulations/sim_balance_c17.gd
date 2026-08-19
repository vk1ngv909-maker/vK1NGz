extends SceneTree
## C17 re-measurement: first-Prestige pacing with equipment rarities and the
## effect of offline gold. Deterministic; no wall clock.

const CS = preload("res://scripts/combat/combat_state.gd")
const BN = preload("res://scripts/utilities/big_number.gd")

const STEP: float = 1.0
const TAPS: float = 5.0
const PRESTIGE_STAGE: int = 25          # reward_for() first becomes non-zero here
const MAX_SECONDS: float = 400000.0

## Combat seeds its RNG from entropy, which is right for a real run and wrong
## for a measurement: five runs of this file on identical code spanned 2117-2155
## seconds purely from critical-hit and enemy-selection rolls. Every simulated
## run is pinned to the same seed so a difference in the output means a
## difference in the game.
const SIM_SEED: int = 0x5EED17

func run_to(target_stage: int, dmg_mult: float, gold_mult: float, start_gold: float = 0.0) -> Dictionary:
	var c = CS.new()
	c.set_random_seed(SIM_SEED)
	c.spawn_enemy()
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
	# Raw summed tap_damage_mult for a full 5-slot set of each rarity, taken from
	# equipment.json, then passed through the SAME diminishing-returns curve the
	# game uses. Passing raw multipliers here would bypass that curve and report
	# numbers the player will never experience.
	var common := run_to(PRESTIGE_STAGE, 1.0 + CS._diminished(0.09), 1.0)
	var rare := run_to(PRESTIGE_STAGE, 1.0 + CS._diminished(0.29), 1.0)
	var epic := run_to(PRESTIGE_STAGE, 1.0 + CS._diminished(0.51), 1.0)
	var legend := run_to(PRESTIGE_STAGE, 1.0 + CS._diminished(0.93), 1.0)
	row("common equipment", common)
	row("rare equipment", rare)
	row("epic equipment", epic)
	row("legendary equipment", legend)
	print("")
	print("=== offline gold effect (does it bypass the wall?) ===")
	# Real grants from the brief-conformant offline formula for a stage-1 player.
	var one_h := run_to(PRESTIGE_STAGE, 1.0, 1.0, 945.0)
	var eight_h := run_to(PRESTIGE_STAGE, 1.0, 1.0, 7560.0)
	row("1h offline (945g)", one_h)
	row("8h offline (7560g)", eight_h)
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
