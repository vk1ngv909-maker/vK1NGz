extends Control

const SkillSystemLogic = preload("res://scripts/progression/skill_system.gd")

const SAFE_TOP: int = 48
const SAFE_BOTTOM: int = 24
const ACTOR_WIDTH_RATIO: float = 0.20
const ACTOR_HEIGHT_RATIO: float = 0.26
const FALCON_SCALE: float = 0.60
const SKILL_IDS: Array[String] = [
	"sand_fury",
	"falcon_storm",
	"golden_wind",
	"time_fracture",
	"ancestor_call",
	"critical_eclipse",
]
@onready var safe_area: MarginContainer = %SafeArea
@onready var bottom_margin: MarginContainer = %BottomMargin
@onready var combat_area: Control = %CombatArea
@onready var hero: ColorRect = %Hero
@onready var falcon: ColorRect = %Falcon
@onready var enemy: ColorRect = %Enemy
@onready var enemy_hp_label: Label = %EnemyHPLabel
@onready var enemy_hp: ProgressBar = %EnemyHP
@onready var skill_buttons: Array[Button] = [
	%Skill1,
	%Skill2,
	%Skill3,
	%Skill4,
	%Skill5,
	%Skill6,
]
@onready var settings_button: Button = %Settings
@onready var inventory_button: Button = %Inventory
@onready var support_dps_button: Button = %HeroDPS
@onready var relics_button: Button = %Relics
@onready var inventory_panel: InventoryPanel = %InventoryPanel
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var heroes_panel: HeroesPanel = %HeroesPanel
@onready var skills_panel: SkillsPanel = %SkillsPanel
@onready var combat_background: ColorRect = %DesertBackground
@onready var world_name: Label = %WorldName

var skill_system: SkillSystem
var current_music_ref: String = ""
var current_world: Dictionary = {}


func _ready() -> void:
	add_to_group("hud")
	safe_area.add_theme_constant_override("margin_top", SAFE_TOP)
	bottom_margin.add_theme_constant_override("margin_bottom", SAFE_BOTTOM)
	combat_area.resized.connect(_layout_combat)
	_setup_skills()
	settings_button.pressed.connect(settings_panel.open_panel)
	inventory_button.pressed.connect(inventory_panel.open_panel)
	%Heroes.pressed.connect(heroes_panel.open_panel)
	%Skills.pressed.connect(skills_panel.open_panel)
	support_dps_button.pressed.connect(_on_support_dps_pressed)
	relics_button.pressed.connect(_on_relics_pressed)
	refresh_localized_text()
	_layout_combat.call_deferred()


func _process(_delta: float) -> void:
	if skill_system == null:
		return
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
	sync_skill_effects()
	_refresh_skill_buttons(now_ms)


func _setup_skills() -> void:
	skill_system = SkillSystemLogic.new()
	var loaded: Dictionary = SaveManager.data
	if loaded.is_empty():
		loaded = SaveManager.load()
	var run_state: Dictionary = loaded["run_state"]
	var timestamps: Variant = run_state.get("skill_timestamps", {})
	if timestamps is Dictionary:
		skill_system.from_dict(timestamps as Dictionary)
	for index: int in skill_buttons.size():
		skill_buttons[index].pressed.connect(_on_skill_pressed.bind(SKILL_IDS[index]))
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
	_refresh_skill_buttons(now_ms)


func debug_activate_skills(ids: PackedStringArray) -> void:
	## Test-only: activate skills through the same path the buttons use, so
	## ACTIVE and COOLDOWN states can be captured from the real running UI.
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	for id: String in ids:
		skill_system.activate(id, now_ms)
	_refresh_skill_buttons(now_ms)


func debug_force_cooldown(ids: PackedStringArray) -> void:
	## Test-only: activate then jump past the duration so the button shows the
	## COOLDOWN state rather than ACTIVE.
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	for id: String in ids:
		skill_system.activate(id, now_ms)
	var later: int = now_ms + 20000
	skill_system.tick(later)
	_refresh_skill_buttons(later)


func debug_skill_state(id: String, state: String) -> void:
	## Test-only: put ONE skill into the requested lifecycle state through the
	## same skill system the buttons use, then report the modifier it produces so
	## the screenshot can be checked against a real number.
	# Same clock the HUD's own _process uses; a different one expires the skill
	# on the next frame and the capture would show READY over an active skill.
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
	if state == "cooldown":
		# Activated far enough in the past that the duration has already run out
		# while the cooldown still has time left, which is exactly the state the
		# real UI shows after a skill ends.
		var definition: Dictionary = skill_system.skills.get(id, {})
		skill_system.activate(id, now_ms - int(definition.get("duration_ms", 0)) - 1000, 100)
		skill_system.tick(now_ms)
	elif state == "active":
		skill_system.activate(id, now_ms, 100)
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	var timer_before: float = float(arena.get("combat").get("boss_time_left")) if arena != null else 0.0
	sync_skill_effects()
	var timer_after: float = float(arena.get("combat").get("boss_time_left")) if arena != null else 0.0
	print("SKILL_TIMER %s state=%s boss_time_before=%.1f boss_time_after=%.1f" % [id, state, timer_before, timer_after])
	_refresh_skill_buttons(now_ms)
	print("SKILL %s state=%s tap=%.2f falcon=%.2f gold=%.2f support=%.2f crit_dmg=%.2f active=%s cooldown=%s" % [
		id, state,
		float(skill_system.tap_damage_multiplier()), float(skill_system.falcon_rate_multiplier()),
		float(skill_system.gold_multiplier()), float(skill_system.support_dps_multiplier()),
		float(skill_system.crit_damage_multiplier()),
		skill_system.is_active(id), skill_system.is_on_cooldown(id)])


func debug_button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for button: Button in skill_buttons:
		out.append(button.text.replace("\n", "/"))
	return out


func _on_skill_pressed(id: String) -> void:
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if skill_system.activate(id, now_ms, _max_stage()):
		sync_skill_effects()
		_save_skills()
		EventBus.tutorial_action.emit("activate_skill")
	_refresh_skill_buttons(now_ms)


func _refresh_skill_buttons(now_ms: int) -> void:
	for index: int in skill_buttons.size():
		var id: String = SKILL_IDS[index]
		var button: Button = skill_buttons[index]
		var state_text: String = Settings.t("hud.ready")
		if not skill_system.is_unlocked(id, _max_stage()):
			var requirement: int = int(((skill_system.skills[id] as Dictionary).get("unlock_condition", {}) as Dictionary).get("max_stage", 1))
			state_text = "%s\n%s" % [Settings.t("ui.state.locked"), Settings.t("ui.unlock_stage") % requirement]
		elif skill_system.is_active(id):
			var definition: Dictionary = skill_system.skills.get(id, {})
			var active_until_ms: int = int(skill_system.activated_at_ms[id]) + int(definition.get("duration_ms", 0))
			state_text = "%s\n%s" % [Settings.t("hud.active"), Settings.t("hud.seconds_short") % Settings.format_number(_remaining_seconds(active_until_ms, now_ms))]
		elif skill_system.is_on_cooldown(id):
			state_text = "%s\n%s" % [Settings.t("hud.cooldown"), Settings.t("hud.seconds_short") % Settings.format_number(_remaining_seconds(int(skill_system.cooldown_until_ms[id]), now_ms))]
		button.text = "%s\n%s" % [Settings.t("skill.%s" % id), state_text]
		button.disabled = state_text != Settings.t("hud.ready")


func sync_skill_effects() -> void:
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena != null and arena.has_method("apply_skill_modifiers"):
		arena.call("apply_skill_modifiers", skill_system)


func _max_stage() -> int:
	return maxi(1, int((SaveManager.data.get("permanent_state", {}) as Dictionary).get("max_stage", 1)))


func refresh_localized_text() -> void:
	%Battle.text = Settings.t("hud.battle")
	%Heroes.text = Settings.t("hud.heroes")
	%Skills.text = Settings.t("hud.skills")
	%Inventory.text = Settings.t("hud.inventory")
	%Relics.text = Settings.t("hud.relics")
	%Shop.text = Settings.t("hud.shop")
	%HeroDPS.text = Settings.t("hud.hero_dps_placeholder")
	# The gold icon is placeholder ART, not placeholder TEXT. Rendering a
	# localized sentence inside a 72px swatch clipped it — and under RTL the clip
	# falls on the left, which produced the confusing "الذهب — ACEHOLDER".
	# Placeholder status is recorded in docs/ASSET_MANIFEST.md instead.
	%GoldPlaceholder.text = ""
	# WorldName presents the active localized world. Do not expose the art
	# placeholder label, which incorrectly called every later world a desert.
	%BackgroundLabel.text = ""
	if not current_world.is_empty():
		world_name.text = Settings.t(str(current_world.get("name_key", "")))
	%BalanceDataInvalid.visible = OS.is_debug_build() and BalanceData.balance_data_invalid
	%BalanceDataInvalid.text = Settings.t("debug.balance_data_invalid")
	%ContentDataInvalid.visible = OS.is_debug_build() and ContentValidator.content_invalid
	%ContentDataInvalid.text = Settings.t("debug.content_data_invalid")
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if skill_system != null:
		_refresh_skill_buttons(now_ms)
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena != null and arena.has_method("refresh_localized_text"):
		arena.call("refresh_localized_text")


func apply_world(world: Dictionary) -> void:
	if world.is_empty():
		return
	current_world = world.duplicate(true)
	var palette: Dictionary = world.get("palette", {})
	var sand_html: String = str(palette.get("sand", "#C28C4C"))
	if Color.html_is_valid(sand_html):
		combat_background.color = Color.html(sand_html)
	var accent_html: String = str(palette.get("accent", "#FFFFFF"))
	if Color.html_is_valid(accent_html):
		world_name.add_theme_color_override("font_color", Color.html(accent_html))
	world_name.text = Settings.t(str(world.get("name_key", "")))
	%BackgroundLabel.text = ""
	current_music_ref = str(world.get("music_ref", ""))
	combat_background.set_meta("music_ref", current_music_ref)


func _remaining_seconds(until_ms: int, now_ms: int) -> int:
	return maxi(0, int(ceil(float(until_ms - now_ms) / 1000.0)))


func _save_skills() -> void:
	var save_data: Dictionary = SaveManager.data.duplicate(true)
	if save_data.is_empty():
		save_data = SaveManager.default_data()
	(save_data["run_state"] as Dictionary)["skill_timestamps"] = skill_system.to_dict()
	(save_data["permanent_state"] as Dictionary)["last_seen_utc"] = int(Time.get_unix_time_from_system())
	SaveManager.save(save_data)


func _on_support_dps_pressed() -> void:
	EventBus.tutorial_action.emit("support_dps")


func _on_relics_pressed() -> void:
	var permanent_state: Dictionary = SaveManager.data.get("permanent_state", {})
	if int(permanent_state.get("max_stage", 1)) >= 25:
		EventBus.tutorial_action.emit("prestige_intro")


func _layout_combat() -> void:
	var area_size: Vector2 = combat_area.size
	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	# Actor dimensions are derived only from the live combat rectangle. These
	# ratios stay below the brief's 22% width and 28% height limits.
	var actor_size := Vector2(
		area_size.x * ACTOR_WIDTH_RATIO,
		area_size.y * ACTOR_HEIGHT_RATIO
	)
	# Actors sit in the middle band, not the lower edge. This leaves headroom
	# above for the boss banner, timer and rising damage numbers, and stops the
	# large dead area that the first composition pass left at the top.
	var hero_position := Vector2(
		area_size.x * 0.10,
		area_size.y * 0.42
	)
	var enemy_position := Vector2(
		area_size.x * 0.68,
		area_size.y * 0.34
	)

	hero.size = actor_size
	hero.position = hero_position
	enemy.size = actor_size
	enemy.position = enemy_position

	var falcon_size := actor_size * FALCON_SCALE
	falcon.size = falcon_size
	falcon.position = Vector2(
		maxf(0.0, hero_position.x - falcon_size.x * 0.45),
		maxf(0.0, hero_position.y - falcon_size.y * 1.25)
	)

	var hp_width := actor_size.x * 1.20
	var hp_height := maxf(32.0, area_size.y * 0.045)
	var hp_x := clampf(
		enemy_position.x + (actor_size.x - hp_width) * 0.5,
		0.0,
		area_size.x - hp_width
	)
	var hp_y := maxf(30.0, enemy_position.y - hp_height - 34.0)
	enemy_hp_label.position = Vector2(hp_x, hp_y - 28.0)
	enemy_hp_label.size = Vector2(hp_width, 26.0)
	enemy_hp.position = Vector2(hp_x, hp_y)
	enemy_hp.size = Vector2(hp_width, hp_height)
