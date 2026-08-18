class_name OfflineRewardsDialog
extends Control

const BigNumber = preload("res://scripts/utilities/big_number.gd")

@onready var time_away: Label = %TimeAway
@onready var gold_earned: Label = %GoldEarned
@onready var capped: Label = %Capped
@onready var confirmation: Label = %Confirmation
@onready var collect_button: Button = %Collect

var _seconds: int = 0
var _gold: float = 0.0
var _debug_fixture: bool = false


func _ready() -> void:
	add_to_group("offline_rewards_dialog")
	collect_button.pressed.connect(_on_collect)


func open_for_seconds(seconds_away: int, debug_fixture: bool = false) -> void:
	_debug_fixture = debug_fixture
	_seconds = mini(maxi(0, seconds_away), SaveManager.MAX_OFFLINE_SECONDS)
	var state: Dictionary = SaveManager.data
	if state.is_empty():
		state = SaveManager.load()
	var max_stage: int = int((state["permanent_state"] as Dictionary).get("max_stage", 1))
	_gold = floor(float(_seconds) * maxf(1.0, float(max_stage)) * 0.5)
	capped.visible = seconds_away > SaveManager.MAX_OFFLINE_SECONDS
	confirmation.hide()
	collect_button.disabled = false
	visible = true
	_refresh_text()
	collect_button.grab_focus()


func refresh_localized_text() -> void:
	if visible:
		_refresh_text()


func _refresh_text() -> void:
	time_away.text = tr("ui.offline.time") % _human_duration(_seconds)
	gold_earned.text = tr("ui.offline.gold") % int(_gold)
	capped.text = tr("ui.offline.capped")
	confirmation.text = tr("ui.offline.collected")
	collect_button.text = tr("ui.offline.collect")


func _human_duration(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return tr("ui.duration.hours_minutes") % [hours, minutes]
	if minutes > 0:
		return tr("ui.duration.minutes") % minutes
	return tr("ui.duration.seconds") % seconds


func _on_collect() -> void:
	if collect_button.disabled:
		return
	if not _debug_fixture:
		var save_data: Dictionary = SaveManager.data.duplicate(true)
		var run_state: Dictionary = save_data["run_state"]
		var current_gold: BigNumber = BigNumber.from_dict(run_state["gold"] as Dictionary)
		run_state["gold"] = current_gold.add(BigNumber.from_float(_gold)).to_dict()
		SaveManager.save(save_data)
	collect_button.disabled = true
	confirmation.show()

