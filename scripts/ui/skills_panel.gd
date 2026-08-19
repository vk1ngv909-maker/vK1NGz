class_name SkillsPanel
extends Control

const SkillSystemLogic = preload("res://scripts/progression/skill_system.gd")

@onready var skill_list: VBoxContainer = %SkillList

var skill_system: SkillSystem
var max_stage: int = 1
var _debug_fixture: bool = false


func _ready() -> void:
	add_to_group("skills_panel")
	%Close.pressed.connect(hide)
	refresh_localized_text()


func _process(_delta: float) -> void:
	if visible and skill_system != null:
		_refresh()


func open_panel() -> void:
	_debug_fixture = false
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	skill_system = hud.get("skill_system") as SkillSystem
	var permanent: Dictionary = SaveManager.data.get("permanent_state", {})
	max_stage = maxi(1, int(permanent.get("max_stage", 1)))
	show()
	# Localized chrome must be refreshed on open, not only when the language
	# changes, or the panel keeps the English text baked into the scene.
	refresh_localized_text()
	_refresh()
	%Close.grab_focus()


func debug_open() -> void:
	_debug_fixture = true
	max_stage = 100
	skill_system = SkillSystemLogic.new()
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.activate("sand_fury", now_ms, max_stage)
	skill_system.activate("golden_wind", now_ms - 20000, max_stage)
	skill_system.tick(now_ms)
	show()
	refresh_localized_text()
	_refresh()


func refresh_localized_text() -> void:
	%Title.text = Settings.t("ui.skills.title")
	%Close.text = Settings.t("ui.close")
	if visible and skill_system != null:
		_refresh()


func _refresh() -> void:
	for child: Node in skill_list.get_children():
		child.queue_free()
	if skill_system == null:
		return
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
	for id_value: Variant in skill_system.skills:
		skill_list.add_child(_make_skill_card(str(id_value), now_ms))


func _make_skill_card(id: String, now_ms: int) -> PanelContainer:
	var definition: Dictionary = skill_system.skills[id]
	var unlocked: bool = skill_system.is_unlocked(id, max_stage)
	var active_left: int = skill_system.remaining_active_seconds(id, now_ms)
	var cooldown_left: int = skill_system.remaining_cooldown_seconds(id, now_ms)
	var state: String = Settings.t("ui.state.ready")
	if not unlocked:
		state = Settings.t("ui.state.locked")
	elif active_left > 0:
		state = Settings.t("ui.state.active")
	elif cooldown_left > 0:
		state = Settings.t("ui.state.cooldown")
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 220.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.09, 0.15, 1.0)
	style.border_width_left = 3
	style.border_color = Color(0.35, 0.65, 0.95, 1.0) if unlocked else Color(0.42, 0.42, 0.48, 1.0)
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var details := Label.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 17)
	details.text = "%s — %s %d\n%s\n%s %ss  ·  %s %ss\n%s %d  ·  %s %d\n%s" % [
		Settings.t(str(definition["name_key"])), Settings.t("ui.level"), skill_system.get_level(id),
		Settings.t(str(definition["effect_key"])),
		Settings.t("ui.skills.duration"), int(definition["duration"]), Settings.t("ui.skills.cooldown"), int(definition["cooldown"]),
		Settings.t("ui.skills.active_remaining"), active_left, Settings.t("ui.skills.cooldown_remaining"), cooldown_left,
		Settings.t("ui.unlock_stage") % int((definition["unlock_condition"] as Dictionary).get("max_stage", 1)),
	]
	row.add_child(details)
	var activate_button := Button.new()
	activate_button.custom_minimum_size = Vector2(170.0, 0.0)
	activate_button.disabled = not unlocked or active_left > 0 or cooldown_left > 0
	activate_button.text = "%s\n%s" % [state, Settings.t("ui.skills.activate")]
	activate_button.pressed.connect(_activate.bind(id))
	row.add_child(activate_button)
	return card


func _activate(id: String) -> void:
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if not skill_system.activate(id, now_ms, max_stage):
		return
	if not _debug_fixture:
		var hud: Node = get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("sync_skill_effects")
			hud.call("_save_skills")
	_refresh()
