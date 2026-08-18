extends SceneTree

const TutorialLogic = preload("res://scripts/ui/tutorial.gd")
const PrestigeLogic = preload("res://scripts/progression/prestige.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	var save_manager: Node = preload("res://autoload/save_manager.gd").new()
	var tutorial: Node = TutorialLogic.new()
	_check(tutorial.STEPS == ["tap_enemy", "upgrade_hero", "support_dps", "activate_skill", "boss_intro", "boss_retry", "prestige_intro"], "step order is fixed")
	_check(tutorial.handle_action("tap_enemy", false) and tutorial.current_step == 1, "real action advances one step")
	_check(not tutorial.handle_action("tap_enemy", false) and tutorial.current_step == 1, "rapid duplicate input cannot double advance")
	tutorial.skip(false)
	_check(tutorial.completed, "skip completes tutorial")
	tutorial.reset(false)
	_check(not tutorial.completed and tutorial.current_step == 0, "reset returns to first step")

	for action: String in ["tap_enemy", "upgrade_hero", "support_dps", "activate_skill", "boss_intro", "boss_retry"]:
		tutorial.handle_action(action, false)
	tutorial.prestige_unlocked_override = false
	_check(not tutorial.handle_action("prestige_intro", false), "prestige step is gated before unlock")
	tutorial.prestige_unlocked_override = true
	_check(tutorial.handle_action("prestige_intro", false) and tutorial.completed, "prestige step unlocks at real threshold")

	tutorial.reset(false)
	tutorial.handle_action("tap_enemy", false)
	var persisted: Dictionary = tutorial.to_dict()
	var reopened: Node = TutorialLogic.new()
	reopened.load_state(persisted)
	_check(reopened.current_step == 1 and not reopened.completed, "current step survives reload")
	var state: Dictionary = save_manager.default_data()
	(state["permanent_state"] as Dictionary)["max_stage"] = 25
	(state["permanent_state"] as Dictionary)["tutorial"] = persisted
	var after: Dictionary = PrestigeLogic.new().apply(state)
	_check(after["permanent_state"]["tutorial"] == persisted, "tutorial state survives prestige")
	tutorial.free()
	reopened.free()
	save_manager.free()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
