extends Control

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")
const Relics = preload("res://scripts/progression/relics.gd")
const RewardSystem = preload("res://scripts/progression/reward_system.gd")
const WorldsLogic = preload("res://scripts/progression/worlds.gd")
const InventoryLogic = preload("res://scripts/progression/inventory.gd")

@onready var hero: TextureRect = %Hero
@onready var falcon: TextureRect = %Falcon
@onready var enemy: TextureRect = %Enemy
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
## While a defeated enemy is still dissolving on screen the run has already
## advanced internally. The HUD keeps describing the encounter the player can
## still see, otherwise it reads "Stage 11 - BOSS" over a dead stage-10 boss.
var _displayed_stage: int = 0
## Test-only counter so a capture sequence can prove the falcon's strike rate
## really rises while Falcon Storm is active, instead of asserting it.
var debug_falcon_hits: int = 0
var _enemy_tint: Color = Color.WHITE
var _reduced_flashing: bool = false
## Test-only: raises max_stage for captures so a jumped-to stage renders the
## unlock state a real player at that stage would actually see.
var debug_forced_max_stage: int = 0
var _damage_numbers_enabled: bool = true
var worlds: RefCounted = WorldsLogic.new()
var current_world_id: String = ""
var _debug_boss_id: String = ""


func _ready() -> void:
	add_to_group("combat_arena")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_combat_children_to_ignore_mouse()
	_load_combat()
	_apply_saved_accessibility()
	_enemy_tint = enemy.modulate
	hero.texture = _sprite("res://assets/sprites/hero/main_hero.png")
	falcon.texture = _sprite("res://assets/sprites/hero/falcon.png")
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
	enemy.modulate = _enemy_tint.lerp(Color.WHITE, 0.25 if _reduced_flashing else 1.0)


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


func debug_open_heroes(locked_only: bool = false) -> void:
	var panel: Node = get_tree().get_first_node_in_group("heroes_panel")
	if panel != null:
		panel.call("debug_open", locked_only)


func debug_hero_journey(step: String) -> void:
	var panel: Node = get_tree().get_first_node_in_group("heroes_panel")
	if panel == null:
		panel = get_tree().current_scene.find_child("HeroesPanel", true, false)
	if panel == null:
		push_error("CombatArena: heroes panel not found")
		return
	panel.call("debug_journey", step)


func debug_skill_state(id: String, state: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		hud = get_tree().current_scene.find_child("HUD", true, false)
	if hud == null:
		push_error("CombatArena: HUD not found")
		return
	hud.call("debug_skill_state", id, state)


func debug_falcon_sequence_setup() -> void:
	## Test-only: park the run on an enemy that cannot die, so a frame sequence
	## measures falcon cadence rather than stage churn.
	combat.enemy_max_hp = BigNumber.from_mantissa_exponent(1.0, 40)
	combat.enemy_hp = combat.enemy_max_hp._copy_normalized()
	debug_falcon_hits = 0
	_refresh_hud()


func debug_falcon_state() -> String:
	return "hits=%d falcon_x=%.1f falcon_y=%.1f rate_mult=%.2f" % [
		debug_falcon_hits, falcon.position.x, falcon.position.y, combat.get("_skill_falcon_rate_mult")]


func debug_boss_victory(phase: String) -> void:
	## Test-only: drives a real boss kill through the ordinary tap -> death ->
	## first-clear path. The only shortcut is dropping the boss HP to a single
	## tap so the capture lands on the killing hit; the reward, the save and the
	## inventory all still go through production code.
	if not combat.is_boss:
		var interval: int = int(CombatState.balance()["boss_stage_interval"])
		combat.stage = int(ceil(float(combat.stage) / float(interval))) * interval
		combat.spawn_enemy()
	var boss_stage: int = combat.stage
	var before: int = combat.inventory.owned_items.size()
	combat.enemy_hp = combat.get_tap_damage()._copy_normalized()
	debug_tap()
	var after: int = combat.inventory.owned_items.size()
	var granted_id: String = ""
	for uid: Variant in combat.inventory.owned_items:
		granted_id = str((combat.inventory.owned_items[uid] as Dictionary).get("item_id", ""))
	print("BOSSWIN phase=%s boss_stage=%d cleared=%s items_before=%d items_after=%d item=%s" % [
		phase, boss_stage, combat.boss_first_clears.has(CombatState.encounter_id(boss_stage)),
		before, after, granted_id])
	if phase == "replay":
		# Same boss, second kill: the first-clear reward must not fire again.
		combat.stage = boss_stage
		combat.spawn_enemy()
		combat.enemy_hp = combat.get_tap_damage()._copy_normalized()
		debug_tap()
		print("BOSSWIN replay_items=%d (expected %d)" % [combat.inventory.owned_items.size(), after])
	if phase == "reload":
		# Reload from the saved data the grant wrote; a duplicate would show up
		# as an extra owned item.
		var saved: Dictionary = combat.save_into(SaveManager.data)
		var reloaded_inventory := InventoryLogic.new()
		reloaded_inventory.from_dict((saved.get("permanent_state", {}) as Dictionary).get("equipment", {}))
		print("BOSSWIN reload_items=%d (expected %d)" % [reloaded_inventory.owned_items.size(), after])
	_refresh_hud()
	if phase == "reward":
		# The live inventory, not the debug fixture: the capture must show the
		# item this boss actually granted.
		var panel: Node = get_tree().get_first_node_in_group("inventory_panel")
		if panel != null:
			panel.call("open_panel")


func debug_open_skills_panel() -> void:
	var panel: Node = get_tree().get_first_node_in_group("skills_panel")
	if panel != null:
		panel.call("debug_open")


func apply_skill_modifiers(skill_system: RefCounted) -> void:
	if combat == null or skill_system == null:
		return
	combat.set_skill_modifiers(
		float(skill_system.call("tap_damage_multiplier")),
		float(skill_system.call("falcon_rate_multiplier")),
		float(skill_system.call("gold_multiplier")),
		float(skill_system.call("support_dps_multiplier")),
		float(skill_system.call("bonus_for", "crit_chance")),
		float(skill_system.call("crit_damage_multiplier"))
	)
	var before: float = combat.boss_time_left
	var after: float = float(skill_system.call("apply_time_fracture", before))
	if not is_equal_approx(before, after):
		combat.add_boss_time_once(after - before)


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
		if args[index] == "--debug-inventory-all":
			var every: Node = get_tree().get_first_node_in_group("inventory_panel")
			if every != null:
				every.call("debug_open_every_item")
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
		if args[index] == "--debug-skill" and index + 2 < args.size():
			debug_skill_state(args[index + 1], args[index + 2])
			return
		if args[index] == "--debug-boss-victory" and index + 1 < args.size():
			debug_boss_victory(args[index + 1])
			return
		if args[index] == "--debug-hero-journey" and index + 1 < args.size():
			debug_hero_journey(args[index + 1])
			return
		if args[index] == "--debug-heroes":
			debug_open_heroes(false)
			return
		if args[index] == "--debug-heroes-locked":
			debug_open_heroes(true)
			return
		if args[index] == "--debug-skill-showcase":
			var showcase: Node = get_tree().get_first_node_in_group("hud")
			if showcase != null:
				showcase.call("debug_skill_showcase")
			return
		if args[index] == "--debug-skills-panel":
			debug_open_skills_panel()
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
		debug_falcon_hits += 1
		_play_falcon_strike()
	if result.get("killed", false):
		_death_in_progress = true
		_displayed_stage = maxi(1, combat.stage - 1) if bool(result.get("stage_advanced", false)) else combat.stage
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
	var reaction: Dictionary = combat.current_enemy.get("hit_reaction", {})
	var recoil: float = clampf(float(reaction.get("recoil_px", 12.0)), 0.0, 100.0)
	var strength: float = clampf(float(reaction.get("flash_strength", 1.0)), 0.0, 1.0)
	_enemy_tween = create_tween()
	_enemy_tween.tween_property(enemy, "position:x", rest_position.x + recoil * direction, 0.055).set_trans(Tween.TRANS_QUAD)
	_enemy_tween.tween_property(enemy, "position:x", rest_position.x, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween = create_tween()
	var flash_color: Color = _enemy_tint.lerp(Color.WHITE, strength * (0.25 if _reduced_flashing else 1.0))
	var flash_duration: float = 0.035
	_flash_tween.tween_property(enemy, "modulate", flash_color, flash_duration)
	_flash_tween.tween_property(enemy, "modulate", _enemy_tint, 0.10)


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
	enemy.modulate = Color.WHITE
	_apply_enemy_presentation()
	_death_in_progress = false
	_displayed_stage = 0
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
			# A capture that jumps to stage 90 must also reflect a player who
			# REACHED stage 90, otherwise the shot shows skills locked that a
			# real player at that stage would already own — a misleading image.
			debug_forced_max_stage = maxi(debug_forced_max_stage, start_stage)
		if cli[i] == "--debug-stage" and i + 1 < cli.size() and OS.is_debug_build():
			start_stage = maxi(1, int(cli[i + 1]))
		if cli[i] == "--debug-world" and i + 1 < cli.size() and OS.is_debug_build():
			start_stage = maxi(1, int(cli[i + 1]))
			debug_forced_max_stage = maxi(debug_forced_max_stage, start_stage)
		if cli[i] == "--debug-boss" and i + 1 < cli.size() and OS.is_debug_build():
			_debug_boss_id = cli[i + 1]
			start_stage = 10
	var permanent_state: Dictionary = loaded["permanent_state"]
	if debug_forced_max_stage > 0:
		permanent_state["max_stage"] = maxi(int(permanent_state.get("max_stage", 1)), debug_forced_max_stage)
	combat = CombatState.new(start_stage, loaded_gold, int(run_state.get("tap_level", 1)), run_state, permanent_state)
	var relics: Relics = Relics.new(int(permanent_state.get("prestige_currency", 0)))
	relics.from_dict({
		"levels": permanent_state.get("relic_levels", {}),
		"prestige_currency": permanent_state.get("prestige_currency", 0),
	})
	combat.set_relic_bonuses(1.0 + relics.total_bonus("damage"), 1.0 + relics.total_bonus("gold"))
	# The saved timer belongs to the saved stage. When the run starts on a
	# different stage the fresh encounter keeps its own timer, otherwise a
	# boss inherits a zero countdown and fails the instant it appears.
	if int(run_state.get("stage", start_stage)) == combat.stage:
		combat.boss_time_left = maxf(0.0, float(run_state.get("boss_time_left", combat.boss_time_left)))
		combat.awaiting_retry = bool(run_state.get("awaiting_retry", false))
	# Debug boss selection is applied last so stale saved timer/retry state cannot
	# overwrite the requested live archetype before the capture frame.
	if not _debug_boss_id.is_empty() and not combat.debug_spawn_boss(_debug_boss_id):
		push_warning("BossPool: unknown --debug-boss archetype '%s'" % _debug_boss_id)


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
	var shown_stage: int = _displayed_stage if _death_in_progress and _displayed_stage > 0 else combat.stage
	stage_label.text = Settings.t("hud.stage_boss" if combat.is_boss else "hud.stage") % Settings.format_number(shown_stage)
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
	# One isolated left-to-right run for the whole "current / maximum"
	# expression: as two separate placeholders, Arabic reordered them and the
	# label read the maximum first.
	enemy_hp_label.text = Settings.t("hud.enemy_hp") % Settings.format_pair(
		Settings.format_big_number(combat.enemy_hp),
		Settings.format_big_number(combat.enemy_max_hp))
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
	_apply_enemy_presentation()
	var world_id: String = str(world.get("id", ""))
	if world_id == current_world_id and not force_text_refresh:
		return
	current_world_id = world_id
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("apply_world"):
		hud.call("apply_world", world)


func _apply_enemy_presentation() -> void:
	if combat == null or combat.current_enemy.is_empty() or not is_instance_valid(enemy):
		return
	var id: String = str(combat.current_enemy.get("id", ""))
	var folder: String = "bosses" if combat.is_boss else "enemies"
	# A boss keeps its mechanical archetype but wears the visual its world
	# assigns, so the sprite and the name always belong to the place it is
	# fought in.
	var name_key: String = str(combat.current_enemy.get("name_key", "hud.enemy_unknown"))
	if combat.is_boss:
		var visual: Dictionary = worlds.boss_visual_for(combat.stage, id)
		if visual.is_empty():
			push_error("CombatArena: no boss visual for stage %d archetype '%s'" % [combat.stage, id])
		else:
			id = str(visual.get("visual_id", id))
			name_key = str(visual.get("name_key", name_key))
	var texture: Texture2D = _sprite("res://assets/sprites/%s/%s.png" % [folder, id])
	enemy.texture = texture
	# A world whose art is not built yet still reads correctly: the palette
	# colour paints the rectangle exactly as it did before.
	var palette: Dictionary = combat.current_enemy.get("palette", {})
	var body_html: String = str(palette.get("body", "#777777"))
	if texture == null and Color.html_is_valid(body_html):
		enemy.modulate = Color.WHITE
		_enemy_tint = Color.WHITE
		enemy.self_modulate = Color.html(body_html)
	else:
		enemy.self_modulate = Color.WHITE
		enemy.modulate = Color.WHITE
		_enemy_tint = Color.WHITE
	var placeholder: Label = enemy.get_node_or_null("Placeholder") as Label
	if placeholder != null:
		placeholder.text = Settings.t(name_key)
		# Drawn over artwork rather than a flat swatch, so the name is always
		# light with a dark outline instead of being matched to a body colour.
		placeholder.add_theme_color_override("font_color", Color(1, 1, 1))
		placeholder.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.05, 0.95))
		placeholder.add_theme_constant_override("outline_size", 7)
		placeholder.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		placeholder.add_theme_constant_override("shadow_offset_x", 2)
		placeholder.add_theme_constant_override("shadow_offset_y", 3)
		placeholder.add_theme_font_size_override("font_size", 21)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.04, 0.03, 0.07, 0.58)
		plate.content_margin_left = 12
		plate.content_margin_right = 12
		plate.content_margin_top = 3
		plate.content_margin_bottom = 3
		plate.corner_radius_top_left = 9
		plate.corner_radius_top_right = 9
		plate.corner_radius_bottom_left = 9
		plate.corner_radius_bottom_right = 9
		placeholder.add_theme_stylebox_override("normal", plate)
		# The name belongs under the enemy, not across its face. The rect is
		# scaled per enemy, so the label scale is inverted to keep the text the
		# same size whatever the creature's size class is.
		placeholder.size = Vector2(enemy.size.x, 30.0)
	var size_scale: float = clampf(float(combat.current_enemy.get("size_scale", 1.0)), 0.8, 1.25)
	var shape_scale: Vector2 = Vector2.ONE
	if texture == null:
		# Only the placeholder rectangle is stretched to suggest a silhouette;
		# real artwork already has one and must not be distorted.
		match str(combat.current_enemy.get("silhouette", "squat")):
			"tall": shape_scale = Vector2(0.72, 1.18)
			"wide": shape_scale = Vector2(1.18, 0.72)
			"spindly": shape_scale = Vector2(0.58, 1.08)
			_: shape_scale = Vector2(1.05, 0.72)
	enemy.pivot_offset = enemy.size * 0.5
	enemy.scale = shape_scale * size_scale
	place_enemy_name()


func place_enemy_name() -> void:
	## Called again once the layout has given the enemy its real size: the rect
	## is scaled about its centre, so a label pinned to the bottom edge is
	## pulled inward. Undo the scale and that shift so the name sits under the
	## creature instead of across it.
	if not is_instance_valid(enemy):
		return
	var placeholder: Label = enemy.get_node_or_null("Placeholder") as Label
	if placeholder == null or enemy.size.y <= 0.0:
		return
	placeholder.scale = Vector2(1.0 / maxf(0.01, enemy.scale.x), 1.0 / maxf(0.01, enemy.scale.y))
	placeholder.size = Vector2(enemy.size.x * enemy.scale.x, 30.0)
	placeholder.position = Vector2(
		(enemy.size.x - placeholder.size.x) * 0.5,
		enemy.size.y * 0.5 + enemy.size.y * 0.5 / maxf(0.01, enemy.scale.y) + 6.0)


func _sprite(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


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
