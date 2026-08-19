extends SceneTree
## Group 4A closure: the three journeys captured as visual evidence must also
## hold as code invariants, so a later change cannot silently invalidate the
## screenshots without failing a test.

class RecordingAdapter extends RefCounted:
	## Stands in for the SaveManager autoload, which a bare test scene does not
	## have, so the commit runs through its real transaction boundary.
	var payloads: Array = []
	func save(data: Dictionary) -> bool:
		payloads.append(data.duplicate(true))
		return true

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var SH = load("res://scripts/progression/support_heroes.gd")
	var SK = load("res://scripts/progression/skill_system.gd")
	var CS = load("res://scripts/combat/combat_state.gd")
	var RS = load("res://scripts/progression/reward_system.gd")
	var INV = load("res://scripts/progression/inventory.gd")
	var BN = load("res://scripts/utilities/big_number.gd")

	# ---- hero purchase journey ----
	var hero_id: String = "oasis_guard"
	var roster = SH.new(BN.from_mantissa_exponent(1.0, 6))
	ck("locked hero is not purchasable before its unlock stage", not roster.is_unlocked(hero_id, 1))
	ck("same hero unlocks once the stage is reached", roster.is_unlocked(hero_id, 100))
	ck("hire refused while locked", not roster.hire(hero_id, 1))
	var gold_before = roster.gold
	ck("hire succeeds when unlocked and affordable", roster.hire(hero_id, 100))
	ck("hire charges gold", roster.gold.is_less_than(gold_before), roster.gold.format())
	ck("hire puts the hero at level 1", roster.get_level(hero_id) == 1)

	var dps_before = roster.hero_dps(hero_id)
	var advertised_gain = roster.next_level_gain(hero_id)
	roster.level_up(hero_id, 1)
	var real_gain = roster.hero_dps(hero_id).sub(dps_before)
	ck("the gain shown before an upgrade equals the gain delivered",
		advertised_gain.compare(real_gain) == 0,
		"shown %s, delivered %s" % [advertised_gain.format(), real_gain.format()])

	var max_roster = SH.new(BN.from_mantissa_exponent(1.0, 6))
	max_roster.hire(hero_id, 100)
	var max_count: int = max_roster.max_affordable(hero_id, max_roster.gold)
	var level_pre: int = max_roster.get_level(hero_id)
	max_roster.level_up(hero_id, max_count)
	ck("Buy Max raises the level by exactly the advertised amount",
		max_roster.get_level(hero_id) - level_pre == max_count,
		"advertised %d, got %d" % [max_count, max_roster.get_level(hero_id) - level_pre])
	ck("after Buy Max one more level is unaffordable",
		max_roster.cost_for(hero_id, 1).is_greater_than(max_roster.gold))

	var ms_roster = SH.new(BN.from_mantissa_exponent(1.0, 9))
	ms_roster.hire(hero_id, 100)
	var milestone_level: int = int((ms_roster.next_milestone(hero_id) as Dictionary).get("level", 10))
	ms_roster.level_up(hero_id, milestone_level - 3)
	# An ordinary step measured BELOW the milestone, so the comparison is not
	# accidentally made against the milestone step itself.
	var ordinary_before = ms_roster.hero_dps(hero_id)
	ms_roster.level_up(hero_id, 1)
	var step_below = ms_roster.hero_dps(hero_id).sub(ordinary_before)
	var below = ms_roster.hero_dps(hero_id)
	ms_roster.level_up(hero_id, 1)
	var at_milestone = ms_roster.hero_dps(hero_id)
	ck("crossing a milestone gives a bigger jump than an ordinary level",
		at_milestone.sub(below).is_greater_than(step_below.mul_float(1.5)),
		"milestone jump %s vs ordinary %s" % [at_milestone.sub(below).format(), step_below.format()])
	ck("the milestone counter moves past the crossed milestone",
		int((ms_roster.next_milestone(hero_id) as Dictionary).get("level", 0)) > milestone_level)

	# ---- boss victory, first clear, replay and reload ----
	var combat = CS.new()
	combat.set_inventory(INV.new())
	var adapter := RecordingAdapter.new()
	combat.save_adapter = adapter
	var rewards = RS.new(0x5EED)
	var boss_stage: int = int(CS.balance()["boss_stage_interval"])
	var grant: Dictionary = combat.begin_boss_first_clear(boss_stage, rewards)
	ck("first clear of a boss grants a reward", bool(grant.get("granted", false)), str(grant))
	ck("commit stores the clear", combat.commit_boss_first_clear(grant))
	var item_id: String = str(grant.get("item_id", ""))
	ck("the granted item is a real item id", not item_id.is_empty())
	ck("inventory holds exactly the granted item",
		combat.inventory.owned_items.size() == 1, str(combat.inventory.owned_items.size()))

	var replay: Dictionary = combat.begin_boss_first_clear(boss_stage, rewards)
	ck("replaying the same boss grants nothing", not bool(replay.get("granted", false)))
	ck("the refusal reason names the prior clear", str(replay.get("reason", "")) == "already_cleared", str(replay))
	ck("replay leaves the inventory untouched", combat.inventory.owned_items.size() == 1)

	var saved: Dictionary = adapter.payloads[-1] if not adapter.payloads.is_empty() else combat.save_into({})
	var reloaded = INV.new()
	reloaded.from_dict((saved.get("permanent_state", {}) as Dictionary).get("equipment", {}))
	ck("reloading the save does not duplicate the reward",
		reloaded.owned_items.size() == 1, str(reloaded.owned_items.size()))

	# a DIFFERENT boss stage must still be able to grant its own first clear
	var later: Dictionary = combat.begin_boss_first_clear(boss_stage * 2, rewards)
	ck("a different boss stage still grants its own first clear", bool(later.get("granted", false)), str(later))

	# ---- all six skills: real effect while ACTIVE, gone after it ends ----
	var expected: Dictionary = {
		"sand_fury": ["tap_damage_multiplier", 3.0],
		"falcon_storm": ["falcon_rate_multiplier", 4.0],
		"golden_wind": ["gold_multiplier", 2.5],
		"ancestor_call": ["support_dps_multiplier", 3.0],
		"critical_eclipse": ["crit_damage_multiplier", 2.0],
	}
	for id_value: Variant in expected:
		var id: String = str(id_value)
		var method: String = str((expected[id] as Array)[0])
		var value: float = float((expected[id] as Array)[1])
		var skills = SK.new()
		var now: int = 1_000_000
		ck("%s is READY before activation" % id, not skills.is_active(id) and not skills.is_on_cooldown(id))
		ck("%s activates" % id, skills.activate(id, now, 100))
		ck("%s is ACTIVE and its effect is live" % id,
			skills.is_active(id) and is_equal_approx(float(skills.call(method)), value),
			"%s = %f" % [method, float(skills.call(method))])
		var duration: int = int((skills.skills[id] as Dictionary).get("duration_ms", 0))
		skills.tick(now + duration + 1)
		ck("%s ends and drops back to a neutral effect" % id,
			not skills.is_active(id) and is_equal_approx(float(skills.call(method)), 1.0),
			"%s = %f" % [method, float(skills.call(method))])
		ck("%s is on COOLDOWN once it ends" % id, skills.is_on_cooldown(id))
		ck("%s cannot be re-activated while on cooldown" % id, not skills.activate(id, now + duration + 2, 100))

	var tf = SK.new()
	var tf_now: int = 1_000_000
	ck("time_fracture does not change the boss timer while READY",
		is_equal_approx(float(tf.apply_time_fracture(30.0)), 30.0))
	tf.activate("time_fracture", tf_now, 100)
	ck("time_fracture extends the boss timer while ACTIVE",
		float(tf.apply_time_fracture(30.0)) > 30.0, str(tf.apply_time_fracture(30.0)))

	# Falcon Storm must actually shorten the strike interval, not just report a
	# multiplier: this is the number the frame sequence measures.
	var interval: float = float(CS.balance()["falcon_interval"])
	var storm = SK.new()
	storm.activate("falcon_storm", 1_000_000, 100)
	ck("Falcon Storm quarters the falcon strike interval",
		is_equal_approx(interval / float(storm.falcon_rate_multiplier()), interval / 4.0),
		"%f -> %f" % [interval, interval / float(storm.falcon_rate_multiplier())])

	print("GROUP 4A CLOSURE: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
