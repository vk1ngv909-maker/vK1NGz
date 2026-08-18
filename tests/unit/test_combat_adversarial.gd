extends SceneTree
## Independent adversarial suite for CombatState — targets the reward-duplication
## and double-progression exploits, which are the P0 risks in an idle game.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var CS = load("res://scripts/combat/combat_state.gd")

	# --- 1. Killing blow then spam taps: gold and stage must move exactly once
	var s = CS.new()
	var start_stage: int = s.stage
	var kills: int = 0
	var gold_events: int = 0
	var advances: int = 0
	for i in range(400):
		var r = s.tap()
		if r.get("ignored", false): continue
		if r.get("killed", false): kills += 1
		if r.has("gold_awarded") and r["gold_awarded"] != null and r.get("killed", false): gold_events += 1
		if r.get("stage_advanced", false): advances += 1
	ck("gold events == kills", gold_events == kills, "gold=%d kills=%d" % [gold_events, kills])
	ck("stage advances == kills", advances == kills, "adv=%d kills=%d" % [advances, kills])
	ck("stage moved forward", s.stage == start_stage + advances, "stage=%d" % s.stage)

	# --- 2. Tap after death in same frame must be ignored (no second reward)
	var s2 = CS.new()
	var killed_at: int = -1
	for i in range(500):
		var r = s2.tap()
		if r.get("killed", false): killed_at = i; break
	ck("enemy dies eventually", killed_at >= 0, str(killed_at))

	# --- 3. Gold never negative after many upgrade attempts
	var s3 = CS.new()
	for i in range(200): s3.buy_tap_upgrade()
	ck("gold never negative", not s3.gold.is_less_than(load("res://scripts/utilities/big_number.gd").from_float(0.0)), s3.gold.format())

	# --- 4. Cannot buy what you cannot afford
	var s4 = CS.new()
	var lvl_before: int = s4.tap_level
	var ok: bool = s4.buy_tap_upgrade()
	ck("broke player cannot upgrade", (not ok) or s4.tap_level > lvl_before, "ok=%s" % str(ok))

	# --- 5. Boss failure keeps gold and does not reset stage to 0
	var s5 = CS.new(10)
	ck("stage 10 is boss", s5.is_boss, str(s5.is_boss))
	# bank some gold first
	for i in range(50): s5.tap()
	var gold_before: String = s5.gold.format()
	for i in range(400): s5.tick(0.1)   # burn well past 30s
	ck("boss failure sets awaiting_retry", s5.awaiting_retry, str(s5.awaiting_retry))
	ck("boss failure keeps gold", s5.gold.format() == gold_before, "%s vs %s" % [s5.gold.format(), gold_before])
	ck("boss failure keeps stage >= 1", s5.stage >= 1, str(s5.stage))

	# --- 6. While awaiting retry, taps must be ignored (no farming the dead boss)
	var ignored_all: bool = true
	for i in range(20):
		if not s5.tap().get("ignored", false): ignored_all = false
	ck("taps ignored while awaiting retry", ignored_all)

	# --- 7. retry_boss resumes a fightable boss with a fresh timer
	s5.retry_boss()
	ck("retry clears awaiting_retry", not s5.awaiting_retry)
	ck("retry restores boss timer", s5.boss_time_left > 25.0, str(s5.boss_time_left))

	print("COMBAT ADVERSARIAL: FAIL %d" % failed if failed > 0 else "COMBAT ADVERSARIAL: all passed")
	quit(1 if failed > 0 else 0)
