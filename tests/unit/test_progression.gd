extends SceneTree

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const SupportHeroes = preload("res://scripts/progression/support_heroes.gd")
const SkillSystem = preload("res://scripts/progression/skill_system.gd")
const Prestige = preload("res://scripts/progression/prestige.gd")
const Relics = preload("res://scripts/progression/relics.gd")
const SaveManagerScript = preload("res://autoload/save_manager.gd")

var passed: int = 0
var failed: int = 0

class RecordingSaveManager extends Node:
	var calls: int = 0
	var saved: Dictionary = {}

	func save(value: Dictionary) -> bool:
		calls += 1
		saved = value.duplicate(true)
		return true


func _init() -> void:
	_test_support_heroes()
	_test_skills()
	_test_prestige()
	_test_relics()
	_test_save_defaults()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)


func _value(number: BigNumber) -> float:
	return number.mantissa * pow(10.0, number.exponent)


func _test_support_heroes() -> void:
	var roster: SupportHeroes = SupportHeroes.new(BigNumber.from_float(1000000.0))
	_check(roster.heroes.size() == 8, "loads eight support heroes")
	_check(roster.hire("dune_scout"), "hires an affordable hero")
	var gold_after_hire: BigNumber = roster.gold
	_check(not roster.hire("dune_scout") and roster.gold.equals(gold_after_hire), "cannot hire one hero twice")
	_check(roster.level_up("dune_scout", 9), "buys multiple hero levels")
	_check(is_equal_approx(_value(roster.total_dps()), 40.0), "level-ten milestone doubles that hero DPS")
	var poor: SupportHeroes = SupportHeroes.new()
	_check(not poor.hire("dune_scout") and poor.gold.mantissa == 0.0, "failed hire never makes gold negative")


func _test_skills() -> void:
	var system: SkillSystem = SkillSystem.new()
	_check(system.skills.size() == 6, "loads six skills")
	_check(system.activate("sand_fury", 1000), "activates ready skill")
	var before: Dictionary = system.to_dict()
	_check(not system.activate("sand_fury", 1001) and system.to_dict() == before, "double activation changes nothing")
	_check(is_equal_approx(system.multiplier_for("tap_damage"), 3.0), "active skill applies its multiplier once")
	_check(system.activate("critical_eclipse", 1001), "different skill activates concurrently")
	_check(is_equal_approx(system.multiplier_for("crit_damage"), 2.0), "different skill effect is active")
	system.tick(11000)
	_check(not system.is_active("sand_fury") and system.is_on_cooldown("sand_fury"), "duration expiry keeps cooldown")
	_check(not system.activate("sand_fury", 45999), "cooldown guard uses absolute time")
	system.tick(46000)
	_check(not system.is_on_cooldown("sand_fury") and system.activate("sand_fury", 46000), "cooldown clears exactly at timestamp")
	var saved: Dictionary = system.to_dict()
	var restored: SkillSystem = SkillSystem.new()
	restored.from_dict(saved)
	_check(restored.to_dict() == saved, "skill absolute timestamps round-trip")


func _test_prestige() -> void:
	var recorder: RecordingSaveManager = RecordingSaveManager.new()
	var prestige: Prestige = Prestige.new(recorder)
	_check(prestige.reward_for(24) == 0 and not prestige.can_prestige(24), "prestige is refused below first reward")
	_check(prestige.reward_for(25) == 1 and prestige.can_prestige(25), "reward formula unlocks at stage 25")
	var state: Dictionary = {
		"schema_version": 3,
		"run_state": {
			"stage": 30, "gold": {"mantissa": 5.0, "exponent": 4}, "tap_level": 8,
			"support_hero_levels": {"dune_scout": 10},
			"skill_timestamps": {"activated_at_ms": {"sand_fury": 1}, "cooldown_until_ms": {"sand_fury": 2}},
			"temporary_buffs": {"damage": 2}, "future_run_multiplier": 99,
		},
		"permanent_state": {
			"max_stage": 50, "prestige_currency": 3, "relic_levels": {"sun_blade": 2},
			"equipment": {"weapon": "x"}, "achievements": ["a"],
			"settings": {"music": true}, "statistics": {"taps": 9},
		},
	}
	var result: Dictionary = prestige.apply(state)
	var run_state: Dictionary = result["run_state"]
	var permanent_state: Dictionary = result["permanent_state"]
	_check(run_state["stage"] == 1 and run_state["tap_level"] == 1 and float(run_state["gold"]["mantissa"]) == 0.0, "prestige resets run progression")
	_check(run_state["support_hero_levels"].is_empty() and run_state["skill_timestamps"]["activated_at_ms"].is_empty(), "prestige clears heroes and skills")
	_check(not run_state.has("future_run_multiplier"), "prestige structurally removes future run fields")
	_check(permanent_state["prestige_currency"] == 6 and permanent_state["relic_levels"] == state["permanent_state"]["relic_levels"], "prestige awards currency and preserves relics")
	_check(recorder.calls == 1 and recorder.saved["run_state"]["stage"] == 1, "successful prestige saves immediately")
	var refused_state: Dictionary = {
		"schema_version": 3,
		"run_state": {"stage": 2, "gold": {"mantissa": 7.0, "exponent": 0}},
		"permanent_state": {"max_stage": 2},
	}
	var refused: Dictionary = prestige.apply(refused_state)
	_check(refused.get("refused", false) and refused["run_state"] == refused_state["run_state"], "invalid prestige returns unchanged state with refusal")
	_check(recorder.calls == 1, "refused prestige does not save")
	var view: Dictionary = prestige.preview(state)
	_check(view["resets"] is Array and view["keeps"] is Array and view["reward"] == 3, "preview supplies explicit UI lists")
	prestige.save_manager = null
	recorder.free()


func _test_relics() -> void:
	var collection: Relics = Relics.new(10)
	_check(collection.relics.size() == 15, "loads fifteen relics")
	_check(collection.buy("sun_blade"), "buys a relic")
	_check(collection.prestige_currency == 9 and collection.get_level("sun_blade") == 1, "relic purchase spends currency")
	_check(collection.upgrade("sun_blade"), "upgrades an owned relic")
	_check(is_equal_approx(collection.total_bonus("damage"), 0.12), "relic category bonus grows by level")
	var empty: Relics = Relics.new()
	_check(not empty.buy("sun_blade") and empty.prestige_currency == 0, "failed relic purchase never goes negative")
	var saved: Dictionary = collection.to_dict()
	var restored: Relics = Relics.new()
	restored.from_dict(saved)
	_check(restored.to_dict() == saved, "relic levels and currency round-trip")


func _test_save_defaults() -> void:
	var manager: Node = SaveManagerScript.new()
	var defaults: Dictionary = manager.call("default_data")
	_check(defaults["run_state"].has("support_hero_levels") and defaults["run_state"].has("skill_timestamps"), "run defaults include heroes and skills")
	_check(defaults["permanent_state"].has("prestige_currency") and defaults["permanent_state"].has("relic_levels") and defaults["permanent_state"].has("max_stage"), "permanent defaults include permanent progression")
	manager.free()
