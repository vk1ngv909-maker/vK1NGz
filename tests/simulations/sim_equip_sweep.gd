extends SceneTree
## Sweep diminishing-returns k and offline starting gold against the C17 targets.
const CS = preload("res://scripts/combat/combat_state.gd")
const BN = preload("res://scripts/utilities/big_number.gd")
const STEP := 1.0
const TAPS := 5.0
const PRESTIGE := 25

# raw summed tap_damage_mult for a full set of each rarity, from equipment.json
const RAW := {"none": 0.0, "common": 0.09, "rare": 0.29, "epic": 0.51, "legendary": 0.93}

func mins(raw_bonus: float, k: float, start_gold: float) -> float:
	var b: Dictionary = JSON.parse_string(FileAccess.open("res://resources/balance.json", FileAccess.READ).get_as_text())
	b["equipment_diminishing_k"] = k
	CS.BALANCE_OVERRIDE = b
	var c = CS.new()
	var eff: float = 0.0 if raw_bonus <= 0.0 else raw_bonus / (1.0 + k * raw_bonus)
	c.set_relic_bonuses(1.0 + eff, 1.0)
	if start_gold > 0.0:
		c.gold = BN.from_float(start_gold)
	var t := 0.0
	var acc := 0.0
	while c.stage < PRESTIGE and t < 20000.0:
		while c.buy_tap_upgrade(): pass
		acc += TAPS * STEP
		while acc >= 1.0 and c.stage < PRESTIGE:
			acc -= 1.0
			if c.tap().get("killed", false): c.spawn_enemy()
		c.dps_tick(STEP)
		t += STEP
	CS.BALANCE_OVERRIDE = {}
	return t / 60.0

func _init() -> void:
	print("=== diminishing-returns k sweep (first Prestige, minutes) ===")
	print("%-6s | %6s %6s %6s %6s %6s" % ["k", "none", "common", "rare", "epic", "legend"])
	for k: float in [0.0, 1.0, 1.5, 2.5, 4.0]:
		var row := "%-6.1f |" % k
		for r: String in ["none", "common", "rare", "epic", "legendary"]:
			row += " %6.1f" % mins(float(RAW[r]), k, 0.0)
		print(row)
	print("")
	print("=== FINAL: k=2.5 with real offline grants (stage-1 player) ===")
	print("no offline           -> %5.1f min" % mins(0.0, 2.5, 0.0))
	print("1h offline  (945g)   -> %5.1f min" % mins(0.0, 2.5, 945.0))
	print("8h offline  (7560g)  -> %5.1f min" % mins(0.0, 2.5, 7560.0))
	print("8h offline + legendary -> %5.1f min" % mins(0.93, 2.5, 7560.0))
	quit(0)
