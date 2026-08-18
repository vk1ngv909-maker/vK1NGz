extends Control

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")

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
var _enemy_tween: Tween
var _flash_tween: Tween
var _death_in_progress: bool = false
var _enemy_color: Color


func _ready() -> void:
	add_to_group("combat_arena")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_combat_children_to_ignore_mouse()
	_load_combat()
	_enemy_color = enemy.color
	tap_upgrade_button.pressed.connect(_on_buy_tap_upgrade)
	retry_button.pressed.connect(_on_retry_boss)
	resized.connect(_update_facing)
	_update_facing.call_deferred()
	_refresh_hud()


func _process(delta: float) -> void:
	if combat == null:
		return
	_update_facing()
	var timer_result: Dictionary = combat.tick(delta)
	if timer_result.get("boss_failed", false):
		_refresh_hud()
	elif combat.is_boss and not combat.awaiting_retry:
		boss_countdown.text = "%.1fs" % combat.boss_time_left
	var falcon_result: Dictionary = combat.falcon_tick(delta)
	if falcon_result.has("damage"):
		_react_to_attack(falcon_result)


func debug_tap() -> void:
	## Test-only hook so automated capture can drive real taps through the same
	## path as a player touch, giving genuine in-motion visual evidence.
	_react_to_attack(combat.tap())


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed
	pressed = pressed or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not pressed or _death_in_progress:
		return
	var result: Dictionary = combat.tap()
	if result.get("ignored", false):
		return
	accept_event()
	_react_to_attack(result)


func _react_to_attack(result: Dictionary) -> void:
	# Guard lives here, not only in _gui_input, so every caller (input, falcon
	# tick, automated capture) is safe against an ignored/no-op attack result.
	if result.get("ignored", false) or not result.has("damage"):
		return
	var damage: BigNumber = result["damage"] as BigNumber
	var kind: String = result["kind"] as String
	damage_pool.show_damage(damage, kind, enemy.position + enemy.size * 0.5)
	_refresh_hp()
	_play_hit_reaction()
	if result.get("killed", false):
		_death_in_progress = true
		if result.get("stage_advanced", false):
			_save_combat()
		_play_death_reaction()


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
	_flash_tween.tween_property(enemy, "color", Color.WHITE, 0.035)
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
	_refresh_hud()


func _on_retry_boss() -> void:
	combat.retry_boss()
	_death_in_progress = false
	enemy.scale = Vector2.ONE
	enemy.modulate = Color.WHITE
	_refresh_hud()


func _load_combat() -> void:
	var loaded: Dictionary = SaveManager.load()
	var gold_value: Variant = loaded.get("gold", BigNumber.new().to_dict())
	var loaded_gold: BigNumber
	if gold_value is Dictionary:
		loaded_gold = BigNumber.from_dict(gold_value as Dictionary)
	else:
		loaded_gold = BigNumber.from_float(float(gold_value))
	var start_stage: int = int(loaded.get("stage", 1))
	# --start-stage N lets automated capture jump straight to a boss stage so
	# boss visuals can be evidenced without farming ten stages first.
	var cli: PackedStringArray = OS.get_cmdline_args()
	for i in cli.size():
		if cli[i] == "--start-stage" and i + 1 < cli.size():
			start_stage = int(cli[i + 1])
	combat = CombatState.new(start_stage, loaded_gold, int(loaded.get("tap_level", 1)))


func _save_combat() -> void:
	var save_data: Dictionary = SaveManager.data.duplicate(true)
	if save_data.is_empty():
		save_data = SaveManager.default_data()
	save_data["stage"] = combat.stage
	save_data["max_stage"] = maxi(int(save_data.get("max_stage", 1)), combat.stage)
	save_data["gold"] = combat.gold.to_dict()
	save_data["tap_level"] = combat.tap_level
	save_data["last_seen_utc"] = int(Time.get_unix_time_from_system())
	SaveManager.save(save_data)


func _refresh_hud() -> void:
	gold_label.text = "%s Gold" % combat.gold.format()
	stage_label.text = "Stage %d%s" % [combat.stage, " — BOSS" if combat.is_boss else ""]
	var cost: BigNumber = combat.get_upgrade_cost()
	tap_upgrade_button.text = "TAP Lv.%d — %s dmg\nCost: %s Gold" % [combat.tap_level, combat.get_tap_damage().format(), cost.format()]
	tap_upgrade_button.disabled = combat.gold.compare(cost) < 0
	boss_warning.visible = combat.is_boss
	boss_countdown.visible = combat.is_boss
	retry_button.visible = combat.awaiting_retry
	boss_warning.text = "BOSS FAILED" if combat.awaiting_retry else "⚠ BOSS BATTLE ⚠"
	boss_countdown.text = "TIME UP" if combat.awaiting_retry else "%.1fs" % combat.boss_time_left
	_refresh_hp()


func _refresh_hp() -> void:
	enemy_hp_label.text = "%s / %s HP" % [combat.enemy_hp.format(), combat.enemy_max_hp.format()]
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


func _set_mouse_ignored_recursive(node: Node) -> void:
	if node is Button:
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_ignored_recursive(child)
