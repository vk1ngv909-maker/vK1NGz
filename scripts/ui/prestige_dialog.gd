class_name PrestigeDialog
extends Control

signal prestige_confirmed(preview: Dictionary)

const PrestigeLogic = preload("res://scripts/progression/prestige.gd")

@onready var reset_list: Label = %ResetList
@onready var keep_list: Label = %KeepList
@onready var reward_amount: Label = %RewardAmount
@onready var requirement_message: Label = %RequirementMessage
@onready var confirm_button: Button = %ConfirmPrestige
@onready var cancel_button: Button = %Cancel

var _preview: Dictionary = {}


func _ready() -> void:
	add_to_group("prestige_dialog")
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func show_preview(preview: Dictionary) -> void:
	_preview = preview.duplicate(true)
	reset_list.text = _format_entries(_preview.get("resets", []))
	keep_list.text = _format_entries(_preview.get("keeps", []))
	var reward: int = maxi(0, int(_preview.get("reward", 0)))
	reward_amount.text = str(reward)
	confirm_button.disabled = reward <= 0
	requirement_message.visible = reward <= 0
	visible = true
	if reward > 0:
		confirm_button.grab_focus()
	else:
		cancel_button.grab_focus()


func debug_open(max_stage: int) -> void:
	var prestige: Prestige = PrestigeLogic.new()
	show_preview(prestige.preview({"permanent_state": {"max_stage": max_stage}}))


func _format_entries(entries: Variant) -> String:
	if not entries is Array or (entries as Array).is_empty():
		return "• None"
	var lines: PackedStringArray = []
	for entry: Variant in entries as Array:
		lines.append("• %s" % _display_name(str(entry)))
	return "\n".join(lines)


func _display_name(raw_name: String) -> String:
	var words: PackedStringArray = raw_name.replace("_", " ").split(" ", false)
	for index: int in words.size():
		words[index] = words[index].capitalize()
	return " ".join(words)


func _on_confirm_pressed() -> void:
	if confirm_button.disabled:
		return
	prestige_confirmed.emit(_preview.duplicate(true))
	hide()


func _on_cancel_pressed() -> void:
	hide()
