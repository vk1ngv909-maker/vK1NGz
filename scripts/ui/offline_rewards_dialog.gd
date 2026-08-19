class_name OfflineRewardsDialog
extends Control

const CombatState = preload("res://scripts/combat/combat_state.gd")
const BigNumber = preload("res://scripts/utilities/big_number.gd")
const Settings = preload("res://autoload/settings.gd")

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
	# Master brief: offline_gold = min(hours, 8) * gold_per_second * 0.35.
	# The previous formula scaled with max_stage directly, which handed a brand
	# new player ~14400 gold for one absence and pulled first Prestige to 22 min,
	# below the 25-45 min target. Gold rate is now estimated from what the
	# player's best stage actually pays per kill.
	var b: Dictionary = CombatState.balance()
	var gold_per_kill: float = float(b["enemy_gold_base"]) * pow(float(b["enemy_gold_growth"]), maxf(0.0, float(max_stage) - 1.0))
	var gold_per_second: float = gold_per_kill * float(b.get("offline_kills_per_second", 0.2))
	# Utility relics raise what an absence is worth. Without this the whole
	# utility category could be bought with prestige currency for no effect.
	var relic_multiplier: float = 1.0
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena != null:
		relic_multiplier = maxf(1.0, float(arena.get("_relic_offline_multiplier")))
	_gold = floor(float(_seconds) * gold_per_second * float(b.get("offline_efficiency", 0.35)) * relic_multiplier)
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
	%Title.text = Settings.t("ui.offline.title")
	time_away.text = Settings.t("ui.offline.time") % _human_duration(_seconds)
	gold_earned.text = Settings.t("ui.offline.gold") % Settings.format_number(int(_gold))
	capped.text = Settings.t("ui.offline.capped")
	confirmation.text = Settings.t("ui.offline.collected")
	collect_button.text = Settings.t("ui.offline.collect")


func _human_duration(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return Settings.t("ui.duration.hours_minutes") % [Settings.format_number(hours), Settings.format_number(minutes)]
	if minutes > 0:
		return Settings.t("ui.duration.minutes") % Settings.format_number(minutes)
	return Settings.t("ui.duration.seconds") % Settings.format_number(seconds)


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
