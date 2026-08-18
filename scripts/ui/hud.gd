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

var skill_system: SkillSystem


func _ready() -> void:
	add_to_group("hud")
	safe_area.add_theme_constant_override("margin_top", SAFE_TOP)
	bottom_margin.add_theme_constant_override("margin_bottom", SAFE_BOTTOM)
	combat_area.resized.connect(_layout_combat)
	_setup_skills()
	settings_button.pressed.connect(settings_panel.open_panel)
	inventory_button.pressed.connect(inventory_panel.open_panel)
	support_dps_button.pressed.connect(_on_support_dps_pressed)
	relics_button.pressed.connect(_on_relics_pressed)
	refresh_localized_text()
	_layout_combat.call_deferred()


func _process(_delta: float) -> void:
	if skill_system == null:
		return
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
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


func _on_skill_pressed(id: String) -> void:
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if skill_system.activate(id, now_ms):
		_save_skills()
		EventBus.tutorial_action.emit("activate_skill")
	_refresh_skill_buttons(now_ms)


func _refresh_skill_buttons(now_ms: int) -> void:
	for index: int in skill_buttons.size():
		var id: String = SKILL_IDS[index]
		var button: Button = skill_buttons[index]
		var state_text: String = Settings.t("hud.ready")
		if skill_system.is_active(id):
			var definition: Dictionary = skill_system.skills.get(id, {})
			var active_until_ms: int = int(skill_system.activated_at_ms[id]) + int(definition.get("duration_ms", 0))
			state_text = "%s\n%s" % [Settings.t("hud.active"), Settings.t("hud.seconds_short") % Settings.format_number(_remaining_seconds(active_until_ms, now_ms))]
		elif skill_system.is_on_cooldown(id):
			state_text = "%s\n%s" % [Settings.t("hud.cooldown"), Settings.t("hud.seconds_short") % Settings.format_number(_remaining_seconds(int(skill_system.cooldown_until_ms[id]), now_ms))]
		button.text = "%s\n%s" % [Settings.t("skill.%s" % id), state_text]
		button.disabled = state_text != Settings.t("hud.ready")


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
	%BackgroundLabel.text = Settings.t("hud.desert_placeholder")
	%BalanceDataInvalid.visible = OS.is_debug_build() and BalanceData.balance_data_invalid
	%BalanceDataInvalid.text = Settings.t("debug.balance_data_invalid")
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if skill_system != null:
		_refresh_skill_buttons(now_ms)
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena != null and arena.has_method("refresh_localized_text"):
		arena.call("refresh_localized_text")


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
