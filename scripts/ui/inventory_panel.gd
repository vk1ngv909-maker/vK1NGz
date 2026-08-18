class_name InventoryPanel
extends Control

const InventoryLogic = preload("res://scripts/progression/inventory.gd")
const BigNumber = preload("res://scripts/utilities/big_number.gd")

const RARITY_COLORS: Dictionary = {
	"common": Color(0.55, 0.57, 0.62),
	"rare": Color(0.24, 0.55, 0.95),
	"epic": Color(0.68, 0.3, 0.9),
	"legendary": Color(1.0, 0.62, 0.12),
}
const DEBUG_ITEMS: Array[String] = [
	"dune_knife", "sunsteel_sabre", "ifrit_fang", "scarab_circlet",
	"stormweave_mantle", "solar_ascendance",
]

@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_state: Label = %EmptyState
@onready var compare_panel: PanelContainer = %ComparePanel
@onready var selected_item_label: Label = %SelectedItem
@onready var equipped_item_label: Label = %EquippedItem
@onready var stat_deltas: Label = %StatDeltas
@onready var verdict: Label = %Verdict
@onready var message: Label = %Message
@onready var actions: GridContainer = %Actions
@onready var equip_button: Button = %Equip
@onready var lock_button: Button = %Lock
@onready var favorite_button: Button = %Favorite
@onready var confirmation: Control = %Confirmation
@onready var warning: Label = %Warning
@onready var cancel_salvage: Button = %CancelSalvage

var inventory: Inventory
var _selected_uid: String = ""
var _pending_salvage_uid: String = ""
var _debug_fixture: bool = false


func _ready() -> void:
	add_to_group("inventory_panel")
	%Close.pressed.connect(hide)
	%Equip.pressed.connect(_on_equip)
	%Lock.pressed.connect(_on_lock)
	%Favorite.pressed.connect(_on_favorite)
	%Salvage.pressed.connect(_on_salvage)
	cancel_salvage.pressed.connect(_cancel_confirmation)
	%ConfirmSalvage.pressed.connect(_confirm_salvage)


func open_panel() -> void:
	_debug_fixture = false
	var loaded: Dictionary = SaveManager.data
	if loaded.is_empty():
		loaded = SaveManager.load()
	inventory = InventoryLogic.new((loaded["permanent_state"] as Dictionary).get("equipment", {}))
	_selected_uid = ""
	message.text = ""
	confirmation.hide()
	visible = true
	_refresh()
	%Close.grab_focus()


func debug_open_empty() -> void:
	_debug_fixture = true
	inventory = InventoryLogic.new()
	_selected_uid = ""
	message.text = ""
	confirmation.hide()
	visible = true
	_refresh()


func debug_open_populated(select_compare: bool = false) -> void:
	_debug_fixture = true
	inventory = _make_debug_inventory()
	_selected_uid = ""
	message.text = ""
	confirmation.hide()
	visible = true
	_refresh()
	if select_compare:
		_select_item("owned_3")


func debug_open_salvage_confirmation() -> void:
	debug_open_populated(false)
	inventory.set_favorite("owned_2", true)
	_refresh()
	_select_item("owned_2")
	_show_confirmation("owned_2")


func refresh_localized_text() -> void:
	if visible:
		_refresh()
		if not _pending_salvage_uid.is_empty():
			_show_confirmation(_pending_salvage_uid)


func _make_debug_inventory() -> Inventory:
	var result: Inventory = InventoryLogic.new()
	for item_id: String in DEBUG_ITEMS:
		result.add(item_id)
	result.equip("owned_2")
	result.set_locked("owned_4", true)
	result.set_favorite("owned_5", true)
	return result


func _refresh() -> void:
	for child: Node in item_grid.get_children():
		child.queue_free()
	var uids: Array = inventory.owned_items.keys() if inventory != null else []
	uids.sort()
	var is_empty: bool = uids.is_empty()
	item_grid.get_parent().visible = not is_empty
	empty_state.visible = is_empty
	if is_empty:
		empty_state.text = tr("ui.inventory.empty")
		compare_panel.hide()
		actions.hide()
		message.text = tr("ui.inventory.empty_hint")
		return
	for uid_value: Variant in uids:
		item_grid.add_child(_make_item_button(str(uid_value)))
	if not _selected_uid.is_empty() and inventory.owned_items.has(_selected_uid):
		_refresh_compare()
	else:
		compare_panel.hide()
		actions.hide()
		if message.text.is_empty():
			message.text = tr("ui.inventory.select_hint")


func _make_item_button(uid: String) -> Button:
	var owned: Dictionary = inventory.owned_items[uid]
	var definition: Dictionary = inventory.definitions[str(owned["item_id"])]
	var badges: PackedStringArray = []
	if bool(owned.get("locked", false)):
		badges.append(tr("ui.badge.locked"))
	if bool(owned.get("favorite", false)):
		badges.append(tr("ui.badge.favorite"))
	if bool(owned.get("equipped", false)):
		badges.append(tr("ui.badge.equipped"))
	var badge_line: String = "\n".join(badges) if not badges.is_empty() else tr("ui.badge.none")
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 154.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 17)
	button.text = "%s\n%s · %s %d\n%s" % [
		tr(str(definition["name_key"])),
		tr("ui.rarity.%s" % str(definition["rarity"])),
		tr("ui.inventory.score"),
		int(round(inventory.score(uid))),
		badge_line,
	]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.095, 0.085, 0.13, 1.0)
	style.border_width_top = 12
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = RARITY_COLORS.get(str(definition["rarity"]), Color.GRAY)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(_select_item.bind(uid))
	return button


func _select_item(uid: String) -> void:
	if inventory == null or not inventory.owned_items.has(uid):
		return
	_selected_uid = uid
	message.text = ""
	_refresh_compare()


func _refresh_compare() -> void:
	var owned: Dictionary = inventory.owned_items[_selected_uid]
	var definition: Dictionary = inventory.definitions[str(owned["item_id"])]
	var comparison: Dictionary = inventory.compare(_selected_uid)
	var equipped_uid: String = str(comparison.get("equipped_uid", ""))
	selected_item_label.text = "%s\n%s" % [tr("ui.inventory.selected"), tr(str(definition["name_key"]))]
	if equipped_uid.is_empty():
		equipped_item_label.text = "%s\n%s" % [tr("ui.inventory.equipped"), tr("ui.inventory.none")]
	else:
		var equipped_owned: Dictionary = inventory.owned_items[equipped_uid]
		var equipped_definition: Dictionary = inventory.definitions[str(equipped_owned["item_id"])]
		equipped_item_label.text = "%s\n%s" % [tr("ui.inventory.equipped"), tr(str(equipped_definition["name_key"]))]
	var lines: PackedStringArray = []
	var delta: Dictionary = comparison.get("delta", {})
	for stat: String in Inventory.STAT_NAMES:
		lines.append("%s %+.0f%%" % [tr("ui.stat.%s" % stat), float(delta.get(stat, 0.0)) * 100.0])
	lines.append("%s %+.0f" % [tr("ui.inventory.score_delta"), float(comparison.get("score_delta", 0.0))])
	stat_deltas.text = "  ·  ".join(lines)
	# An equal-score item is NOT a downgrade. Calling it one misleads the player
	# into salvaging a sidegrade, so equality gets its own verdict.
	var score_change: float = float(comparison.get("score_delta", 0.0))
	var is_upgrade: bool = bool(comparison.get("is_upgrade", false))
	if is_equal_approx(score_change, 0.0):
		verdict.text = tr("ui.inventory.same")
		verdict.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	elif is_upgrade:
		verdict.text = tr("ui.inventory.upgrade")
		verdict.add_theme_color_override("font_color", Color(0.42, 1.0, 0.6))
	else:
		verdict.text = tr("ui.inventory.downgrade")
		verdict.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	equip_button.disabled = bool(owned.get("equipped", false))
	lock_button.text = tr("ui.inventory.unlock" if bool(owned.get("locked", false)) else "ui.inventory.lock")
	favorite_button.text = tr("ui.inventory.unfavorite" if bool(owned.get("favorite", false)) else "ui.inventory.favorite")
	compare_panel.show()
	actions.show()


func _on_equip() -> void:
	if inventory.equip(_selected_uid):
		message.text = tr("ui.inventory.equipped_ok")
		_save_inventory()
		_refresh()


func _on_lock() -> void:
	var new_value: bool = not inventory.is_locked(_selected_uid)
	if inventory.set_locked(_selected_uid, new_value):
		_save_inventory()
		_refresh()


func _on_favorite() -> void:
	var new_value: bool = not inventory.is_favorite(_selected_uid)
	if inventory.set_favorite(_selected_uid, new_value):
		_save_inventory()
		_refresh()


func _on_salvage() -> void:
	var result: Dictionary = inventory.salvage(_selected_uid)
	if bool(result.get("ok", false)):
		_finish_salvage(result)
	elif str(result.get("reason", "")) == "needs_confirmation":
		_show_confirmation(_selected_uid)
	else:
		message.text = tr("ui.salvage.blocked.%s" % str(result.get("reason", "unknown")))


func _show_confirmation(uid: String) -> void:
	_pending_salvage_uid = uid
	var owned: Dictionary = inventory.owned_items[uid]
	var definition: Dictionary = inventory.definitions[str(owned["item_id"])]
	warning.text = tr("ui.salvage.warning") % tr(str(definition["name_key"]))
	confirmation.show()
	cancel_salvage.grab_focus()


func _cancel_confirmation() -> void:
	_pending_salvage_uid = ""
	confirmation.hide()


func _confirm_salvage() -> void:
	var result: Dictionary = inventory.salvage(_pending_salvage_uid, true, true)
	_pending_salvage_uid = ""
	confirmation.hide()
	if bool(result.get("ok", false)):
		_finish_salvage(result)
	else:
		message.text = tr("ui.salvage.blocked.%s" % str(result.get("reason", "unknown")))


func _finish_salvage(result: Dictionary) -> void:
	var awarded: float = float(result.get("gold_awarded", 0.0))
	_selected_uid = ""
	message.text = tr("ui.salvage.success") % int(awarded)
	if not _debug_fixture:
		var save_data: Dictionary = SaveManager.data.duplicate(true)
		var run_state: Dictionary = save_data["run_state"]
		var current_gold: BigNumber = BigNumber.from_dict(run_state["gold"] as Dictionary)
		run_state["gold"] = current_gold.add(BigNumber.from_float(awarded)).to_dict()
		(save_data["permanent_state"] as Dictionary)["equipment"] = inventory.to_dict()
		SaveManager.save(save_data)
		_apply_runtime_inventory()
	_refresh()


func _save_inventory() -> void:
	if _debug_fixture:
		return
	var save_data: Dictionary = SaveManager.data.duplicate(true)
	(save_data["permanent_state"] as Dictionary)["equipment"] = inventory.to_dict()
	SaveManager.save(save_data)
	_apply_runtime_inventory()


func _apply_runtime_inventory() -> void:
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena != null and arena.has_method("apply_inventory_state"):
		arena.call("apply_inventory_state", inventory.to_dict())
