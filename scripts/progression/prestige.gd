class_name Prestige
extends RefCounted

const SaveManager = preload("res://autoload/save_manager.gd")
const RESET_FIELDS: Array[String] = [
	"stage", "gold", "tap_level", "support_hero_levels", "active_skills",
	"skill_timestamps", "temporary_buffs", "boss_time_left", "awaiting_retry",
]
const KEEP_FIELDS: Array[String] = [
	"max_stage", "prestige_currency", "relic_levels", "equipment", "achievements",
	"settings", "statistics", "last_seen_utc", "offline_claimed_utc",
]

var save_manager: Node


func _init(manager: Node = null) -> void:
	save_manager = manager


func reward_for(max_stage: int) -> int:
	if max_stage <= 0:
		return 0
	return int(floor(pow(float(max_stage) / 25.0, 1.65)))


func can_prestige(max_stage: int) -> bool:
	return reward_for(max_stage) > 0


func preview(state: Dictionary) -> Dictionary:
	var permanent_state: Dictionary = state.get("permanent_state", {})
	return {
		"resets": RESET_FIELDS.duplicate(),
		"keeps": KEEP_FIELDS.duplicate(),
		"reward": reward_for(int(permanent_state.get("max_stage", 0))),
	}


func apply(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	var permanent_state: Dictionary = result.get("permanent_state", {})
	var reward: int = reward_for(int(permanent_state.get("max_stage", 0)))
	if reward <= 0:
		result["refused"] = true
		return result
	result.erase("refused")
	result["run_state"] = SaveManager.default_run_state()
	permanent_state["prestige_currency"] = maxi(0, int(permanent_state.get("prestige_currency", 0))) + reward
	result["permanent_state"] = permanent_state
	_save_immediately(result)
	return result


func _save_immediately(state: Dictionary) -> void:
	var manager: Node = save_manager
	if manager == null:
		var tree: MainLoop = Engine.get_main_loop()
		if tree is SceneTree:
			manager = (tree as SceneTree).root.get_node_or_null("SaveManager")
	if manager != null and manager.has_method("save"):
		manager.call("save", state.duplicate(true))
