extends SceneTree
## Parameter sweep for C17. Measures candidate balance sets rather than guessing.
const CS = preload("res://scripts/combat/combat_state.gd")
const BN = preload("res://scripts/utilities/big_number.gd")
const STEP: float = 1.0
const TAPS: float = 5.0

func base_values() -> Dictionary:
	var f := FileAccess.open("res://resources/balance.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text()); f.close()
	return d

func measure(target: int, ov: Dictionary, cap: float) -> Dictionary:
	CS.BALANCE_OVERRIDE = ov
	var c = CS.new()
	c.set_relic_bonuses(1.0, 1.0)
	var t: float = 0.0
	var acc: float = 0.0
	var last: int = c.stage
	var stalled: float = 0.0
	var worst: float = 0.0
	var wstage: int = 0
	while c.stage < target and t < cap:
		while c.buy_tap_upgrade(): pass
		acc += TAPS * STEP
		while acc >= 1.0 and c.stage < target:
			acc -= 1.0
			var r: Dictionary = c.tap()
			if r.get("killed", false): c.spawn_enemy()
		c.dps_tick(STEP)
		t += STEP
		if c.stage == last:
			stalled += STEP
			if stalled > worst: worst = stalled; wstage = c.stage
		else: stalled = 0.0; last = c.stage
	CS.BALANCE_OVERRIDE = {}
	return {"s": t, "reached": c.stage, "worst": worst, "wstage": wstage}

func _init() -> void:
	var base: Dictionary = base_values()
	print("%-46s | first prestige | to stage 40 | worst stall" % "candidate")
	print("-".repeat(100))
	var candidates: Array = [
		{"label": "linear damage (old, growth=1.0)", "d": {"tap_damage_growth": 1.0}},
		{"label": "growth 1.06", "d": {"tap_damage_per_level": 5.0, "tap_damage_growth": 1.06}},
		{"label": "growth 1.09", "d": {"tap_damage_per_level": 5.0, "tap_damage_growth": 1.09}},
		{"label": "growth 1.09, tap_base 2", "d": {"tap_damage_per_level": 2.0, "tap_damage_growth": 1.09}},
		{"label": "growth 1.09, tap_base 1.2", "d": {"tap_damage_per_level": 1.2, "tap_damage_growth": 1.09}},
	]
	for cand: Variant in candidates:
		var ov: Dictionary = base.duplicate(true)
		for k: Variant in (cand["d"] as Dictionary):
			ov[k] = (cand["d"] as Dictionary)[k]
		var p25: Dictionary = measure(25, ov, 20000.0)
		var p40: Dictionary = measure(40, ov, 300000.0)
		print("%-46s | %6.1f min     | %8.1f h  | %7.0fs @%d" % [
			cand["label"], float(p25["s"]) / 60.0, float(p40["s"]) / 3600.0,
			float(p40["worst"]), int(p40["wstage"])])
	quit(0)
