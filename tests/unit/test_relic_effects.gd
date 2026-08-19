extends SceneTree
## Every relic category must reach the game. Three of the five once did not:
## speed, skills and utility relics could be bought with prestige currency and
## changed nothing, which the sensitivity simulation exposed. These checks pin
## each category to the system it drives.

const RelicsLogic = preload("res://scripts/progression/relics.gd")
const CS = preload("res://scripts/combat/combat_state.gd")
const SkillSystemLogic = preload("res://scripts/progression/skill_system.gd")
const INV = preload("res://scripts/progression/inventory.gd")

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func invested(category: String, budget: int):
	var relics = RelicsLogic.new(budget)
	for id_value: Variant in relics.relics:
		var id: String = str(id_value)
		if str((relics.relics[id] as Dictionary)["category"]) != category:
			continue
		relics.buy(id)
		while relics.upgrade(id):
			pass
	return relics


func _init() -> void:
	var categories: Array[String] = ["damage", "gold", "speed", "skills", "utility"]
	for category: String in categories:
		var relics = invested(category, 40)
		ck("%s relics produce a bonus when bought" % category, relics.total_bonus(category) > 0.0,
			str(relics.total_bonus(category)))
		for other: String in categories:
			if other != category:
				ck("%s spending leaves %s alone" % [category, other],
					is_equal_approx(relics.total_bonus(other), 0.0), str(relics.total_bonus(other)))

	# ---- damage and gold reach combat ----
	var damage_bonus: float = invested("damage", 40).total_bonus("damage")
	var plain = CS.new()
	plain.set_inventory(INV.new())
	var boosted = CS.new()
	boosted.set_inventory(INV.new())
	boosted.set_relic_bonuses(1.0 + damage_bonus, 1.0, 1.0)
	ck("damage relics raise tap damage",
		boosted.get_tap_damage().is_greater_than(plain.get_tap_damage()),
		"%s vs %s" % [boosted.get_tap_damage().format(), plain.get_tap_damage().format()])

	# ---- speed relics shorten the falcon's interval ----
	var speed_bonus: float = invested("speed", 40).total_bonus("speed")
	var slow = CS.new()
	slow.set_inventory(INV.new())
	var fast = CS.new()
	fast.set_inventory(INV.new())
	fast.set_relic_bonuses(1.0, 1.0, 1.0 + speed_bonus)
	var interval: float = float(CS.balance()["falcon_interval"])
	# An enemy that cannot die, so the comparison measures cadence rather than
	# how quickly each run runs out of things to hit.
	var BN = load("res://scripts/utilities/big_number.gd")
	for state in [slow, fast]:
		state.enemy_max_hp = BN.from_mantissa_exponent(1.0, 40)
		state.enemy_hp = state.enemy_max_hp._copy_normalized()
	var slow_hits: int = 0
	var fast_hits: int = 0
	for tick: int in 200:
		if slow.falcon_tick(interval * 0.1).has("damage"):
			slow_hits += 1
		if fast.falcon_tick(interval * 0.1).has("damage"):
			fast_hits += 1
	ck("speed relics make the falcon strike more often", fast_hits > slow_hits,
		"%d vs %d strikes" % [fast_hits, slow_hits])

	# ---- skill relics shorten cooldowns, with a floor ----
	var skills_bonus: float = invested("skills", 40).total_bonus("skills")
	var system = SkillSystemLogic.new()
	var base_cooldown: int = int((system.skills["sand_fury"] as Dictionary)["cooldown_ms"])
	system.set_cooldown_multiplier(1.0 / (1.0 + skills_bonus))
	system.activate("sand_fury", 1000, 100)
	var shortened: int = int(system.cooldown_until_ms["sand_fury"]) - 1000
	ck("skill relics shorten the cooldown", shortened < base_cooldown,
		"%d vs %d ms" % [shortened, base_cooldown])
	var extreme = SkillSystemLogic.new()
	extreme.set_cooldown_multiplier(0.0)
	extreme.activate("sand_fury", 1000, 100)
	ck("a cooldown can never be removed entirely",
		int(extreme.cooldown_until_ms["sand_fury"]) - 1000 >= int(base_cooldown * 0.34),
		str(int(extreme.cooldown_until_ms["sand_fury"]) - 1000))
	var negative = SkillSystemLogic.new()
	negative.set_cooldown_multiplier(-5.0)
	ck("a nonsense cooldown multiplier is clamped, not applied",
		negative.cooldown_multiplier >= 0.35 and negative.cooldown_multiplier <= 1.0,
		str(negative.cooldown_multiplier))

	# ---- utility relics raise offline earnings ----
	var utility_bonus: float = invested("utility", 40).total_bonus("utility")
	ck("utility relics raise the offline multiplier above one", 1.0 + utility_bonus > 1.0,
		str(1.0 + utility_bonus))
	var dialog_source: String = FileAccess.open("res://scripts/ui/offline_rewards_dialog.gd", FileAccess.READ).get_as_text()
	ck("the offline reward applies the relic multiplier",
		dialog_source.contains("relic_multiplier"), "")
	var arena_source: String = FileAccess.open("res://scripts/combat/combat_arena.gd", FileAccess.READ).get_as_text()
	for category: String in categories:
		ck("the arena feeds %s relics into the game" % category,
			arena_source.contains('total_bonus("%s")' % category), "")

	# ---- spending stays inside its bounds ----
	var broke = RelicsLogic.new(0)
	ck("nothing can be bought without currency", not broke.buy("sun_blade"))
	var rich = RelicsLogic.new(100000)
	rich.buy("phoenix_ankh")
	while rich.upgrade("phoenix_ankh"):
		pass
	ck("a relic stops at its authored maximum level",
		rich.get_level("phoenix_ankh") == int((rich.relics["phoenix_ankh"] as Dictionary)["max_level"]),
		str(rich.get_level("phoenix_ankh")))
	ck("currency never goes negative", rich.prestige_currency >= 0, str(rich.prestige_currency))

	print("RELIC EFFECTS: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
