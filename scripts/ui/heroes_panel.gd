class_name HeroesPanel
extends Control

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const SupportHeroesLogic = preload("res://scripts/progression/support_heroes.gd")
const QUANTITIES: Array[int] = [1, 10, 25, 100, -1]

@onready var hero_list: VBoxContainer = %HeroList
@onready var quantity: OptionButton = %Quantity

var roster: SupportHeroes
var max_stage: int = 1
var _combat: RefCounted
var _debug_fixture: bool = false


func _ready() -> void:
	add_to_group("heroes_panel")
	%Close.pressed.connect(hide)
	for amount: int in QUANTITIES:
		quantity.add_item("Max" if amount < 0 else "x%d" % amount)
		quantity.set_item_metadata(quantity.item_count - 1, amount)
	quantity.item_selected.connect(func(_index: int) -> void: _refresh())
	refresh_localized_text()


func open_panel() -> void:
	_debug_fixture = false
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena == null:
		return
	_combat = arena.get("combat") as RefCounted
	if _combat == null:
		return
	roster = _combat.get("support_heroes") as SupportHeroes
	roster.gold = (_combat.get("gold") as BigNumber)._copy_normalized()
	max_stage = maxi(1, int(_combat.get("max_stage_reached")))
	show()
	_refresh()
	%Close.grab_focus()


func debug_open(locked_only: bool = false) -> void:
	_debug_fixture = true
	max_stage = 1 if locked_only else 100
	roster = SupportHeroesLogic.new(BigNumber.from_mantissa_exponent(9.0, 30))
	if not locked_only:
		for id_value: Variant in roster.heroes:
			var id: String = str(id_value)
			if roster.is_unlocked(id, max_stage):
				roster.hire(id, max_stage)
				roster.level_up(id, 8 + int((roster.heroes[id] as Dictionary).get("unlock_stage", 1)) % 18)
	show()
	_refresh()


func refresh_localized_text() -> void:
	%Title.text = Settings.t("ui.heroes.title")
	%Close.text = Settings.t("ui.close")
	%QuantityLabel.text = Settings.t("ui.heroes.buy_quantity")
	if visible and roster != null:
		_refresh()


func _refresh() -> void:
	for child: Node in hero_list.get_children():
		child.queue_free()
	if roster == null:
		return
	for id_value: Variant in roster.heroes:
		hero_list.add_child(_make_hero_card(str(id_value)))


func _make_hero_card(id: String) -> PanelContainer:
	var definition: Dictionary = roster.heroes[id]
	var level: int = roster.get_level(id)
	var unlocked: bool = roster.is_unlocked(id, max_stage)
	var amount: int = _selected_amount(id)
	var cost: BigNumber = roster.cost_for(id, amount)
	var affordable: bool = unlocked and amount > 0 and roster.gold.compare(cost) >= 0
	var current_dps: BigNumber = roster.hero_dps(id)
	var next_dps: BigNumber = roster.hero_dps(id, level + 1)
	var gain: BigNumber = next_dps.sub(current_dps)
	var milestone: Dictionary = roster.next_milestone(id)
	var milestone_text: String = Settings.t("ui.heroes.milestones_complete")
	if not milestone.is_empty():
		milestone_text = Settings.t("ui.heroes.milestone_progress") % [level, int(milestone["level"])]
	var state: String
	if not unlocked:
		state = Settings.t("ui.state.locked") + " — " + Settings.t("ui.unlock_stage") % int(definition["unlock_stage"])
	elif affordable:
		state = Settings.t("ui.state.available_affordable")
	else:
		state = Settings.t("ui.state.available_unaffordable")
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 220.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.13, 1.0)
	style.border_width_left = 3
	style.border_color = Color(0.78, 0.58, 0.2, 1.0) if unlocked else Color(0.42, 0.42, 0.48, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var details := Label.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 17)
	details.text = "%s — %s\n%s %s  ·  %s\n%s %s  ·  %s %s\n%s\n%s" % [
		Settings.t(str(definition["name_key"])), Settings.t("ui.role.%s" % str(definition["role"])),
		Settings.t("ui.level"), level, state,
		Settings.t("ui.heroes.current_dps"), Settings.format_big_number(current_dps),
		Settings.t("ui.heroes.next_gain"), Settings.format_big_number(gain),
		milestone_text, Settings.t(str(definition["desc_key"])),
	]
	row.add_child(details)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(190.0, 0.0)
	buy.disabled = not affordable
	buy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buy.add_theme_font_size_override("font_size", 16)
	buy.text = "%s\n%s\n%s" % [
		Settings.t("ui.heroes.hire") if level == 0 else Settings.t("ui.heroes.level_up"),
		"Max" if quantity.get_item_metadata(quantity.selected) == -1 else "x%d" % amount,
		Settings.t("ui.heroes.cost") % Settings.format_big_number(cost),
	]
	buy.pressed.connect(_buy.bind(id, amount))
	row.add_child(buy)
	return card


func _selected_amount(id: String) -> int:
	var selected: int = int(quantity.get_item_metadata(quantity.selected))
	return roster.max_affordable(id, roster.gold) if selected < 0 else selected


func _buy(id: String, amount: int) -> void:
	if roster == null or amount <= 0 or not roster.is_unlocked(id, max_stage):
		return
	var bought: bool = false
	if roster.get_level(id) == 0:
		bought = roster.hire(id, max_stage)
		if bought and amount > 1:
			bought = roster.level_up(id, amount - 1)
	else:
		bought = roster.level_up(id, amount)
	if bought and not _debug_fixture and _combat != null:
		_combat.set("gold", roster.gold._copy_normalized())
		_combat.set("support_total_dps", roster.total_dps())
		var arena: Node = get_tree().get_first_node_in_group("combat_arena")
		if arena != null:
			arena.call("_save_combat")
	_refresh()
