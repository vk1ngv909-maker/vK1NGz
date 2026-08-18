class_name PrestigeDialog
extends Control

signal prestige_confirmed(preview: Dictionary)

const PrestigeLogic = preload("res://scripts/progression/prestige.gd")
const Settings = preload("res://autoload/settings.gd")

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
	refresh_localized_text()


func show_preview(preview: Dictionary) -> void:
	_preview = preview.duplicate(true)
	reset_list.text = _format_entries(_preview.get("resets", []))
	keep_list.text = _format_entries(_preview.get("keeps", []))
	var reward: int = maxi(0, int(_preview.get("reward", 0)))
	reward_amount.text = Settings.format_number(reward)
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
		return Settings.t("ui.prestige.entry_line") % Settings.t("ui.inventory.none")
	var lines: PackedStringArray = []
	for entry: Variant in entries as Array:
		lines.append(Settings.t("ui.prestige.entry_line") % Settings.t("ui.prestige.entry.%s" % str(entry)))
	return "\n".join(lines)


func refresh_localized_text() -> void:
	%Title.text = Settings.t("ui.prestige.title")
	%Explanation.text = Settings.t("ui.prestige.explanation")
	%ResetHeading.text = Settings.t("ui.prestige.will_reset")
	%KeepHeading.text = Settings.t("ui.prestige.will_keep")
	%RewardHeading.text = Settings.t("ui.prestige.you_receive")
	%CurrencyLabel.text = Settings.t("ui.prestige.currency")
	requirement_message.text = Settings.t("ui.prestige.requirement")
	cancel_button.text = Settings.t("ui.cancel")
	confirm_button.text = Settings.t("ui.prestige.confirm")
	if not _preview.is_empty():
		reset_list.text = _format_entries(_preview.get("resets", []))
		keep_list.text = _format_entries(_preview.get("keeps", []))


func _on_confirm_pressed() -> void:
	if confirm_button.disabled:
		return
	prestige_confirmed.emit(_preview.duplicate(true))
	hide()


func _on_cancel_pressed() -> void:
	hide()
