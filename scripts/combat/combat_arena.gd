extends Control

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")
const Relics = preload("res://scripts/progression/relics.gd")
const RewardSystem = preload("res://scripts/progression/reward_system.gd")
const WorldsLogic = preload("res://scripts/progression/worlds.gd")

@onready var hero: ColorRect = %Hero
@onready var falcon: ColorRect = %Falcon
@onready var enemy: ColorRect = %Enemy
@onready var enemy_hp_label: Label = %EnemyHPLabel
@onready var enemy_hp_bar: ProgressBar = %EnemyHP
@onready var gold_label: Label = %GoldAmount
@onready var stage_label: Label = %Stage
@onready var tap_upgrade_button: Button = %TapDamage
@onready var boss_warning: Label = %BossWarning
@onready var boss_countdown: Label = %BossCountdown
@onready var retry_button: Button = %RetryBoss
@onready var damage_pool: DamageNumberPool = %DamageNumberPool

var combat: CombatState
var reward_system: RewardSystem = RewardSystem.new(0x5EED)
var _falcon_tween: Tween
var _enemy_tween: Tween
var _flash_tween: Tween
var _death_in_progress: bool = false
var _enemy_color: Color
var _reduced_flashing: bool = false
var _damage_numbers_enabled: bool = true
var worlds: RefCounted = WorldsLogic.new()
var current_world_id: String = ""


func _ready() -> void:
	add_to_group("combat_arena")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_combat_children_to_ignore_mouse()
	_load_combat()
	_apply_saved_accessibility()
	_enemy_color = enemy.color
	tap_upgrade_button.pressed.connect(_on_buy_tap_upgrade)
	retry_button.pressed.connect(_on_retry_boss)
	resized.connect(_update_facing)
	_update_facing.call_deferred()
	_refresh_hud()
	_apply_world_for_stage(combat.stage)
	_open_debug_panels_from_command_line.call_deferred()


func _process(delta: float) -> void:
	if combat == null:
		return
	_update_facing()
	var timer_result: Dictionary = combat.tick(delta)
	if timer_result.get("boss_failed", false):
		_refresh_hud()
	elif combat.is_boss and not combat.awaiting_retry:
		boss_countdown.text = Settings.t("hud.seconds_decimal") % Settings.format_number(combat.boss_time_left, 1)
	var dps_result: Dictionary = combat.dps_tick(delta)
	if dps_result.has("damage") and (dps_result["damage"] as BigNumber).mantissa > 0.0:
		_react_to_attack(dps_result)
	var falcon_result: Dictionary = combat.falcon_tick(delta)
	if falcon_result.has("damage"):
		_react_to_attack(falcon_result)


func debug_retry() -> void:
	## Test-only: press Retry Boss through the same handler the button uses.
	_on_retry_boss()


func debug_falcon() -> void:
	## Test-only: force one falcon attack so its cyan damage and the strike can
	## be captured in the same frame.
	_react_to_attack(combat.falcon_tick(999.0))


func debug_fail_boss() -> void:
	## Test-only: burn the boss timer to force the failure state.
	while not combat.awaiting_retry and combat.is_boss:
		combat.tick(1.0)
	_refresh_hud()


func debug_tap() -> void:
	## Test-only hook so automated capture can drive real taps through the same
	## path as a player touch, giving genuine in-motion visual evidence.
	_handle_player_tap_result(combat.tap())


func debug_flash(reduced: bool) -> void:
	## Test-only: apply the flash colour and HOLD it, so a screenshot can capture
	## the peak. The real flash decays in 35ms, far faster than a capture frame,
	## which made a normal-vs-reduced comparison look identical.
	apply_accessibility_settings({"reduced_flash": reduced, "damage_numbers": true})
	debug_tap()
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	enemy.color = _enemy_color.lerp(Color.WHITE, 0.25 if _reduced_flashing else 1.0)


func debug_open_prestige(max_stage: int) -> void:
	## Test-only hook for portrait captures of the real Prestige preview.
	var dialog: Node = get_tree().get_first_node_in_group("prestige_dialog")
	if dialog == null:
		dialog = get_tree().current_scene.find_child("PrestigeDialog", true, false)
	if dialog != null and dialog.has_method("debug_open"):
		dialog.call("debug_open", max_stage)


func debug_open_inventory() -> void:
	var panel: Node = get_tree().get_first_node_in_group("inventory_panel")
	if panel != null:
		panel.call("debug_open_populated", false)


func debug_open_inventory_empty() -> void:
	var panel: Node = get_tree().get_first_node_in_group("inventory_panel")
	if panel != null:
		panel.call("debug_open_empty")


func debug_open_compare() -> void:
	var panel: Node = get_tree().get_first_node_in_group("inventory_panel")
	if panel != null:
		panel.call("debug_open_populated", true)


func debug_open_salvage_confirm() -> void:
	var panel: Node = get_tree().get_first_node_in_group("inventory_panel")
	if panel != null:
		panel.call("debug_open_salvage_confirmation")


func debug_open_offline(seconds_away: int) -> void:
	var dialog: Node = get_tree().get_first_node_in_group("offline_rewards_dialog")
	if dialog != null:
		dialog.call("open_for_seconds", seconds_away, true)


func debug_open_settings() -> void:
	var panel: Node = get_tree().get_first_node_in_group("settings_panel")
	if panel != null:
		panel.call("open_panel")


func debug_set_language(code: String) -> void:
	var panel: Node = get_tree().get_first_node_in_group("settings_panel")
	if panel != null:
		panel.call("debug_set_language", code)
	else:
		TranslationServer.set_locale("ar" if code == "ar" else "en")


func _open_debug_panels_from_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	for index: int in args.size():
		if args[index] == "--debug-lang" and index + 1 < args.size():
			debug_set_language(args[index + 1])
	for index: int in args.size():
		if args[index] == "--debug-prestige" and index + 1 < args.size():
			debug_open_prestige(int(args[index + 1]))
			return
		if args[index] == "--debug-inventory":
			debug_open_inventory()
			return
		if args[index] == "--debug-inventory-empty":
			debug_open_inventory_empty()
			return
		if args[index] == "--debug-compare":
			debug_open_compare()
			return
		if args[index] == "--debug-salvage":
			debug_open_salvage_confirm()
			return
		if args[index] == "--debug-offline" and index + 1 < args.size():
			debug_open_offline(int(args[index + 1]))
			return
		if args[index] == "--debug-settings":
			debug_open_settings()
			return
		if args[index] == "--debug-salvage-equipped":
			_debug_open_salvage_state("equipped")
			return
		if args[index] == "--debug-salvage-locked":
			_debug_open_salvage_state("locked")
			return
		if args[index] == "--debug-salvage-eligible":
			_debug_open_salvage_state("eligible")
			return
		if args[index] == "--debug-salvage-rare":
			_debug_open_salvage_state("rare")
			return
		if args[index] == "--debug-salvage-favorite":
			_debug_open_salvage_state("favorite")
			return
		if args[index] == "--debug-flash-normal":
			debug_flash(false)
			return
		if args[index] == "--debug-flash-reduced":
			debug_flash(true)
			return
		if args[index] == "--debug-no-tutorial":
			var overlay: Node = get_tree().get_first_node_in_group("tutorial_overlay")
			if overlay == null:
				overlay = get_tree().current_scene.find_child("TutorialOverlay", true, false)
			if overlay is CanvasItem:
				(overlay as CanvasItem).hide()
		if args[index] == "--debug-tutorial" and index + 1 < args.size():
			var tutorial: Node = get_tree().get_first_node_in_group("tutorial")
			if tutorial != null:
				tutorial.call("debug_open_step", int(args[index + 1]))
			return


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed
	pressed = pressed or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not pressed or _death_in_progress:
		return
	var result: Dictionary = combat.tap()
	if result.get("ignored", false):
		return
	accept_event()
	_handle_player_tap_result(result)


func _handle_player_tap_result(result: Dictionary) -> void:
	if result.get("ignored", false):
		return
	if combat.is_boss:
		EventBus.tutorial_action.emit("boss_intro")
	EventBus.tutorial_action.emit("tap_enemy")
	Settings.vibrate()
	_react_to_attack(result)


func _react_to_attack(result: Dictionary) -> void:
	# Guard lives here, not only in _gui_input, so every caller (input, falcon
	# tick, automated capture) is safe against an ignored/no-op attack result.
	if result.get("ignored", false) or not result.has("damage"):
		return
	var damage: BigNumber = result["damage"] as BigNumber
	var kind: String = result["kind"] as String
	if _damage_numbers_enabled:
		damage_pool.show_damage(damage, kind, enemy.position + enemy.size * 0.5)
	_refresh_hp()
	_play_hit_reaction()
	if kind == "falcon":
		_play_falcon_strike()
	if result.get("killed", false):
		_death_in_progress = true
		if result.get("stage_advanced", false):
			var boss_stage: int = int(result.get("boss_stage", 0))
			if boss_stage > 0:
				var reward: Dictionary = _commit_boss_first_clear(boss_stage)
				if not bool(reward.get("granted", false)) and str(reward.get("reason", "")) != "already_cleared":
					# Saving is part of the boss-death transaction. Put the run back
					# on the boss so a later unrelated save cannot persist a half-clear.
					combat.stage = boss_stage
					combat.gold = combat.gold.sub(result["gold_awarded"] as BigNumber)
					result["stage_advanced"] = false
			else:
				_save_combat()
			if bool(result.get("stage_advanced", false)):
				EventBus.stage_changed.emit(combat.stage)
				_apply_world_for_stage(combat.stage)
		_play_death_reaction()


func _play_falcon_strike() -> void:
	## The falcon must visibly own its damage: it lunges toward the enemy on the
	## same frame the cyan number appears, then returns beside the hero.
	if not is_instance_valid(falcon) or not is_instance_valid(enemy):
		return
	if _falcon_tween != null and _falcon_tween.is_running():
		_falcon_tween.kill()
	var rest: Vector2 = falcon.position
	var toward: Vector2 = rest + (enemy.position - rest) * 0.45
	_falcon_tween = create_tween()
	_falcon_tween.tween_property(falcon, "position", toward, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_falcon_tween.tween_property(falcon, "position", rest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _play_hit_reaction() -> void:
	if is_instance_valid(_enemy_tween):
		_enemy_tween.kill()
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	var rest_position: Vector2 = enemy.position
	var direction: float = 1.0 if enemy.global_position.x >= hero.global_position.x else -1.0
	_enemy_tween = create_tween()
	_enemy_tween.tween_property(enemy, "position:x", rest_position.x + 12.0 * direction, 0.055).set_trans(Tween.TRANS_QUAD)
	_enemy_tween.tween_property(enemy, "position:x", rest_position.x, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween = create_tween()
	var flash_color: Color = _enemy_color.lerp(Color.WHITE, 0.25 if _reduced_flashing else 1.0)
	var flash_duration: float = 0.035
	_flash_tween.tween_property(enemy, "color", flash_color, flash_duration)
	_flash_tween.tween_property(enemy, "color", _enemy_color, 0.10)


func _play_death_reaction() -> void:
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(_enemy_tween):
		_enemy_tween.kill()
	enemy.pivot_offset = enemy.size * 0.5
	_enemy_tween = create_tween().set_parallel(true)
	_enemy_tween.tween_property(enemy, "scale", Vector2(0.15, 0.15), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_enemy_tween.tween_property(enemy, "modulate:a", 0.0, 0.24)
	await _enemy_tween.finished
	combat.spawn_enemy()
	enemy.scale = Vector2.ONE
	enemy.modulate = Color.WHITE
	enemy.color = _enemy_color
	_death_in_progress = false
	_update_facing()
	_refresh_hud()


func _on_buy_tap_upgrade() -> void:
	if combat.buy_tap_upgrade():
		_save_combat()
		EventBus.tutorial_action.emit("upgrade_hero")
	_refresh_hud()


func _on_retry_boss() -> void:
	var was_awaiting_retry: bool = combat.awaiting_retry
	combat.retry_boss()
	if was_awaiting_retry:
		EventBus.tutorial_action.emit("boss_retry")
	_death_in_progress = false
	enemy.scale = Vector2.ONE
	enemy.modulate = Color.WHITE
	_refresh_hud()


func _load_combat() -> void:
	var loaded: Dictionary = SaveManager.load()
	var run_state: Dictionary = loaded["run_state"]
	var gold_value: Variant = run_state.get("gold", BigNumber.new().to_dict())
	var loaded_gold: BigNumber
	if gold_value is Dictionary:
		loaded_gold = BigNumber.from_dict(gold_value as Dictionary)
	else:
		loaded_gold = BigNumber.from_float(float(gold_value))
	var start_stage: int = int(run_state.get("stage", 1))
	# --start-stage N lets automated capture jump straight to a boss stage so
	# boss visuals can be evidenced without farming ten stages first.
	var cli: PackedStringArray = OS.get_cmdline_args()
	cli.append_array(OS.get_cmdline_user_args())
	for i in cli.size():
		if cli[i] == "--start-stage" and i + 1 < cli.size():
			start_stage = int(cli[i + 1])
		if cli[i] == "--debug-world" and i + 1 < cli.size() and OS.is_debug_build():
			start_stage = maxi(1, int(cli[i + 1]))
	var permanent_state: Dictionary = loaded["permanent_state"]
	combat = CombatState.new(start_stage, loaded_gold, int(run_state.get("tap_level", 1)), run_state, permanent_state)
	var relics: Relics = Relics.new(int(permanent_state.get("prestige_currency", 0)))
	relics.from_dict({
		"levels": permanent_state.get("relic_levels", {}),
		"prestige_currency": permanent_state.get("prestige_currency", 0),
	})
	combat.set_relic_bonuses(1.0 + relics.total_bonus("damage"), 1.0 + relics.total_bonus("gold"))
	combat.boss_time_left = maxf(0.0, float(run_state.get("boss_time_left", combat.boss_time_left)))
	combat.awaiting_retry = bool(run_state.get("awaiting_retry", false))


func _save_combat() -> bool:
	var save_data: Dictionary = combat.save_into(SaveManager.data)
	if combat.save_adapter == null or not combat.save_adapter.has_method("save"):
		return false
	return bool(combat.save_adapter.call("save", save_data))


func _commit_boss_first_clear(boss_stage: int) -> Dictionary:
	var transaction: Dictionary = combat.begin_boss_first_clear(boss_stage, reward_system)
	var reason: String = str(transaction.get("reason", "invalid"))
	if not bool(transaction.get("granted", false)):
		# A durable prior clear is safe to save normally; all other failures leave
		# the clear and inventory untouched so retry/reload cannot half-commit it.
		if reason == "already_cleared":
			_save_combat()
		return transaction
	transaction["save_data"] = combat.save_into(SaveManager.data)
	if not combat.commit_boss_first_clear(transaction):
		return {"granted": false, "item_id": "", "rarity": "", "reason": "save_failed"}
	return transaction


func _refresh_hud() -> void:
	gold_label.text = Settings.t("hud.gold") % Settings.format_big_number(combat.gold)
	stage_label.text = Settings.t("hud.stage_boss" if combat.is_boss else "hud.stage") % Settings.format_number(combat.stage)
	var cost: BigNumber = combat.get_upgrade_cost()
	tap_upgrade_button.text = Settings.t("hud.tap_upgrade") % [Settings.format_number(combat.tap_level), Settings.format_big_number(combat.get_tap_damage()), Settings.format_big_number(cost)]
	tap_upgrade_button.disabled = combat.gold.compare(cost) < 0
	boss_warning.visible = combat.is_boss
	boss_countdown.visible = combat.is_boss
	retry_button.visible = combat.awaiting_retry
	boss_warning.text = Settings.t("hud.boss_failed" if combat.awaiting_retry else "hud.boss_battle")
	boss_countdown.text = Settings.t("hud.time_up") if combat.awaiting_retry else Settings.t("hud.seconds_decimal") % Settings.format_number(combat.boss_time_left, 1)
	retry_button.text = Settings.t("hud.retry_boss")
	_refresh_hp()


func _refresh_hp() -> void:
	enemy_hp_label.text = Settings.t("hud.enemy_hp") % [Settings.format_big_number(combat.enemy_hp), Settings.format_big_number(combat.enemy_max_hp)]
	var ratio: BigNumber = combat.enemy_hp.div(combat.enemy_max_hp)
	enemy_hp_bar.value = clampf(ratio.mantissa * pow(10.0, ratio.exponent) * 100.0, 0.0, 100.0)


func _update_facing() -> void:
	if not is_instance_valid(hero) or not is_instance_valid(enemy):
		return
	hero.pivot_offset = hero.size * 0.5
	var facing_right: bool = enemy.global_position.x >= hero.global_position.x
	hero.scale.x = 1.0 if facing_right else -1.0
	# Falcon positioning remains derived from the hero, so it follows future actor movement.
	falcon.position = Vector2(
		maxf(0.0, hero.position.x - falcon.size.x * 0.45),
		maxf(0.0, hero.position.y - falcon.size.y * 1.25)
	)


func _set_combat_children_to_ignore_mouse() -> void:
	for child: Node in get_children():
		_set_mouse_ignored_recursive(child)


func apply_accessibility_settings(settings: Dictionary) -> void:
	_reduced_flashing = bool(settings.get("reduced_flash", settings.get("reduced_flashing", false)))
	_damage_numbers_enabled = bool(settings.get("damage_numbers", true))
	damage_pool.visible = _damage_numbers_enabled
	if not _damage_numbers_enabled:
		damage_pool.hide_all()


func apply_inventory_state(saved_inventory: Dictionary) -> void:
	if combat == null:
		return
	combat.inventory.from_dict(saved_inventory)
	_refresh_hud()


func refresh_localized_text() -> void:
	if combat != null:
		_refresh_hud()
		_apply_world_for_stage(combat.stage, true)


func _apply_world_for_stage(for_stage: int, force_text_refresh: bool = false) -> void:
	var world: Dictionary = worlds.world_for_stage(for_stage)
	if world.is_empty():
		return
	var world_id: String = str(world.get("id", ""))
	if world_id == current_world_id and not force_text_refresh:
		return
	current_world_id = world_id
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("apply_world"):
		hud.call("apply_world", world)


func _apply_saved_accessibility() -> void:
	apply_accessibility_settings(Settings.values)


func _debug_open_salvage_state(kind: String) -> void:
	var panel: Node = get_tree().get_first_node_in_group("inventory_panel")
	if panel != null:
		panel.call("debug_open_salvage_state", kind)


func _set_mouse_ignored_recursive(node: Node) -> void:
	if node is Button:
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_ignored_recursive(child)
