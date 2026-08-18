class_name Tutorial
extends Control

const STEPS: Array[String] = [
	"tap_enemy",
	"upgrade_hero",
	"support_dps",
	"activate_skill",
	"boss_intro",
	"boss_retry",
	"prestige_intro",
]
const TARGET_NAMES: Dictionary = {
	"tap_enemy": "Enemy",
	"upgrade_hero": "TapDamage",
	"support_dps": "HeroDPS",
	"activate_skill": "Skill1",
	"boss_intro": "BossWarning",
	"boss_retry": "RetryBoss",
	"prestige_intro": "Relics",
}

@onready var instruction: PanelContainer = %Instruction
@onready var instruction_text: Label = %InstructionText
@onready var skip_button: Button = %Skip

var current_step: int = 0
var completed: bool = false
var _target: Control
var _debug_unlock_gate: bool = false
var prestige_unlocked_override: Variant = null


func _ready() -> void:
	add_to_group("tutorial")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_button.pressed.connect(skip)
	var bus: Node = _event_bus()
	if bus != null:
		bus.connect("tutorial_action", handle_action)
	var manager: Node = _save_manager()
	var permanent_state: Dictionary = manager.get("data").get("permanent_state", {}) if manager != null else {}
	load_state(permanent_state.get("tutorial", {}))
	get_viewport().size_changed.connect(_refresh_display)
	_refresh_display.call_deferred()


func _process(_delta: float) -> void:
	if completed:
		return
	# Visibility of boss/retry controls and prestige unlock can change without
	# rebuilding the HUD, so keep the outline attached to the live target.
	_refresh_display()


func load_state(raw: Variant) -> void:
	var state: Dictionary = raw as Dictionary if raw is Dictionary else {}
	completed = bool(state.get("completed", false)) if state.get("completed", false) is bool else false
	var saved_step: Variant = state.get("current_step", 0)
	current_step = clampi(int(saved_step), 0, STEPS.size() - 1) if saved_step is int or saved_step is float else 0
	_refresh_display()


func to_dict() -> Dictionary:
	return {"completed": completed, "current_step": current_step}


func handle_action(action: String, persist: bool = true) -> bool:
	if completed or action != step_name():
		return false
	if action == "prestige_intro" and not _prestige_unlocked():
		return false
	if current_step >= STEPS.size() - 1:
		completed = true
	else:
		current_step += 1
	if persist:
		_persist()
	_refresh_display()
	return true


func skip(persist: bool = true) -> void:
	completed = true
	if persist:
		_persist()
	_refresh_display()


func reset(persist: bool = false) -> void:
	completed = false
	current_step = 0
	_debug_unlock_gate = false
	if persist:
		_persist()
	_refresh_display()


func step_name() -> String:
	if completed or current_step < 0 or current_step >= STEPS.size():
		return ""
	return STEPS[current_step]


func debug_open_step(index: int) -> void:
	completed = false
	current_step = clampi(index, 0, STEPS.size() - 1)
	_debug_unlock_gate = true
	_refresh_display()


func refresh_localized_text() -> void:
	_refresh_display()


func _refresh_display() -> void:
	if not is_node_ready():
		return
	visible = not completed
	if completed:
		return
	skip_button.text = tr("ui.tutorial.skip")
	var gated: bool = step_name() == "prestige_intro" and not _prestige_unlocked()
	_target = _find_target(step_name())
	var can_show_instruction: bool = not gated and _target != null and _target.is_visible_in_tree()
	instruction.visible = can_show_instruction
	if can_show_instruction:
		instruction_text.text = tr("ui.tutorial.%s" % step_name())
		_position_instruction()
	queue_redraw()


func _find_target(step: String) -> Control:
	var target_name: String = str(TARGET_NAMES.get(step, ""))
	if target_name.is_empty() or get_tree() == null or get_tree().current_scene == null:
		return null
	return get_tree().current_scene.find_child(target_name, true, false) as Control


func _prestige_unlocked() -> bool:
	if _debug_unlock_gate:
		return true
	if prestige_unlocked_override is bool:
		return bool(prestige_unlocked_override)
	var manager: Node = _save_manager()
	var permanent_state: Dictionary = manager.get("data").get("permanent_state", {}) if manager != null else {}
	return int(permanent_state.get("max_stage", 1)) >= 25


func _position_instruction() -> void:
	if _target == null:
		return
	var target_center_y: float = _target.get_global_rect().get_center().y
	var viewport_height: float = get_viewport_rect().size.y
	var panel_height: float = maxf(instruction.size.y, 150.0)
	instruction.position.y = 100.0 if target_center_y > viewport_height * 0.5 else viewport_height - panel_height - 130.0


func _draw() -> void:
	if completed or not is_instance_valid(_target) or not instruction.visible:
		return
	var rect: Rect2 = _target.get_global_rect().grow(10.0)
	rect.position -= global_position
	draw_rect(rect, Color(1.0, 0.78, 0.18, 0.95), false, 6.0)


func _persist() -> void:
	var manager: Node = _save_manager()
	if manager == null:
		return
	if (manager.get("data") as Dictionary).is_empty():
		manager.set("data", manager.call("default_data"))
	var save_data: Dictionary = (manager.get("data") as Dictionary).duplicate(true)
	(save_data["permanent_state"] as Dictionary)["tutorial"] = to_dict()
	manager.call("save", save_data)


func _save_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("SaveManager")
	return null


func _event_bus() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null
