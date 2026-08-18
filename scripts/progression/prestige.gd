class_name Prestige
extends RefCounted

const BigNumber = preload("res://scripts/utilities/big_number.gd")

const RESET_FIELDS: Array[String] = [
	"stage", "gold", "tap_level", "support_hero_levels", "active_skills",
	"skill_cooldowns", "skill_timestamps", "temporary_buffs"
]
const KEEP_FIELDS: Array[String] = [
	"prestige_currency", "relics", "relic_levels", "equipment", "max_stage", "achievements",
	"settings", "statistics"
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
	return {
		"resets": RESET_FIELDS.duplicate(),
		"keeps": KEEP_FIELDS.duplicate(),
		"reward": reward_for(int(state.get("max_stage", 0))),
	}


func apply(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	var reward: int = reward_for(int(result.get("max_stage", 0)))
	if reward <= 0:
		result["refused"] = true
		return result
	result.erase("refused")
	result["stage"] = 1
	result["gold"] = BigNumber.new() if result.get("gold") is BigNumber else {"mantissa": 0.0, "exponent": 0}
	result["tap_level"] = 1
	result["prestige_currency"] = maxi(0, int(result.get("prestige_currency", 0))) + reward
	result["support_hero_levels"] = _zero_dictionary(result.get("support_hero_levels", {}))
	if result.get("support_heroes") is Dictionary:
		var support_state: Dictionary = (result["support_heroes"] as Dictionary).duplicate(true)
		support_state["levels"] = _zero_dictionary(support_state.get("levels", {}))
		result["support_heroes"] = support_state
	result["active_skills"] = {}
	result["skill_cooldowns"] = {}
	result["skill_timestamps"] = {"activated_at_ms": {}, "cooldown_until_ms": {}}
	if result.get("skills") is Dictionary:
		result["skills"] = {"activated_at_ms": {}, "cooldown_until_ms": {}}
	result["temporary_buffs"] = {}
	_save_immediately(result)
	return result


static func _zero_dictionary(value: Variant) -> Dictionary:
	var zeroed: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			zeroed[key] = 0
	return zeroed


func _save_immediately(state: Dictionary) -> void:
	var manager: Node = save_manager
	if manager == null:
		var tree: MainLoop = Engine.get_main_loop()
		if tree is SceneTree:
			manager = (tree as SceneTree).root.get_node_or_null("SaveManager")
	if manager != null and manager.has_method("save"):
		var save_state: Dictionary = state.duplicate(true)
		if save_state.get("gold") is BigNumber:
			save_state["gold"] = (save_state["gold"] as BigNumber).to_dict()
		manager.call("save", save_state)
