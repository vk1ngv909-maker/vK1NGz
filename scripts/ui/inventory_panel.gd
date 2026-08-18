class_name InventoryPanel
extends Control

const InventoryLogic = preload("res://scripts/progression/inventory.gd")
const BigNumber = preload("res://scripts/utilities/big_number.gd")
const Settings = preload("res://autoload/settings.gd")

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
@onready var salvage_button: Button = %Salvage
@onready var salvage_reason: Label = %SalvageReason
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
	refresh_localized_text()


func open_panel() -> void:
	_debug_fixture = false
	var manager: Node = _save_manager()
	var loaded: Dictionary = manager.get("data") if manager != null else {}
	if loaded.is_empty():
		loaded = manager.call("load") if manager != null else {}
	if loaded.is_empty():
		return
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


func debug_open_salvage_state(kind: String) -> void:
	_debug_fixture = true
	inventory = InventoryLogic.new()
	var item_id: String = "sunsteel_sabre" if kind == "rare" else "dune_knife"
	var uid: String = inventory.add(item_id)
	if kind == "equipped":
		inventory.equip(uid)
	elif kind == "locked":
		inventory.set_locked(uid, true)
	elif kind == "favorite":
		inventory.set_favorite(uid, true)
	_selected_uid = uid
	message.text = ""
	confirmation.hide()
	visible = true
	_refresh()


func salvage_ui_state(uid: String) -> Dictionary:
	if inventory == null:
		return {"enabled": false, "reason_key": "ui.inventory.cannot_unknown", "needs_confirm": false}
	var preview: Dictionary = inventory.salvage_refusal_preview(uid)
	var enabled: bool = bool(preview.get("ok", false))
	var reason_key: String = ""
	if not enabled:
		var reason: String = str(preview.get("reason", "unknown"))
		reason_key = "ui.inventory.cannot_%s" % reason
	var needs: Array = preview.get("needs", [])
	return {"enabled": enabled, "reason_key": reason_key, "needs_confirm": not needs.is_empty()}


func refresh_localized_text() -> void:
	%InventoryTitle.text = Settings.t("ui.inventory.title")
	%Close.text = Settings.t("ui.close")
	%CompareTitle.text = Settings.t("ui.inventory.compare")
	equip_button.text = Settings.t("ui.inventory.equip")
	salvage_button.text = Settings.t("ui.inventory.salvage")
	%SalvageTitle.text = Settings.t("ui.salvage.title")
	cancel_salvage.text = Settings.t("ui.cancel_safe")
	%ConfirmSalvage.text = Settings.t("ui.salvage.confirm")
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
		empty_state.text = Settings.t("ui.inventory.empty")
		compare_panel.hide()
		actions.hide()
		message.text = Settings.t("ui.inventory.empty_hint")
		return
	for uid_value: Variant in uids:
		item_grid.add_child(_make_item_button(str(uid_value)))
	if not _selected_uid.is_empty() and inventory.owned_items.has(_selected_uid):
		_refresh_compare()
	else:
		compare_panel.hide()
		actions.hide()
		if message.text.is_empty():
			message.text = Settings.t("ui.inventory.select_hint")


func _make_item_button(uid: String) -> Button:
	var owned: Dictionary = inventory.owned_items[uid]
	var definition: Dictionary = inventory.definitions[str(owned["item_id"])]
	var badges: PackedStringArray = []
	if bool(owned.get("locked", false)):
		badges.append(Settings.t("ui.badge.locked"))
	if bool(owned.get("favorite", false)):
		badges.append(Settings.t("ui.badge.favorite"))
	if bool(owned.get("equipped", false)):
		badges.append(Settings.t("ui.badge.equipped"))
	var badge_line: String = "\n".join(badges) if not badges.is_empty() else Settings.t("ui.badge.none")
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 154.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 17)
	button.text = "%s\n%s · %s %s\n%s" % [
		Settings.t(str(definition["name_key"])),
		Settings.t("ui.rarity.%s" % str(definition["rarity"])),
		Settings.t("ui.inventory.score"),
		Settings.format_number(int(round(inventory.score(uid)))),
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
	selected_item_label.text = "%s\n%s" % [Settings.t("ui.inventory.selected"), Settings.t(str(definition["name_key"]))]
	if equipped_uid.is_empty():
		equipped_item_label.text = "%s\n%s" % [Settings.t("ui.inventory.equipped"), Settings.t("ui.inventory.none")]
	else:
		var equipped_owned: Dictionary = inventory.owned_items[equipped_uid]
		var equipped_definition: Dictionary = inventory.definitions[str(equipped_owned["item_id"])]
		equipped_item_label.text = "%s\n%s" % [Settings.t("ui.inventory.equipped"), Settings.t(str(equipped_definition["name_key"]))]
	var lines: PackedStringArray = []
	var delta: Dictionary = comparison.get("delta", {})
	for stat: String in Inventory.STAT_NAMES:
		lines.append("%s %s" % [Settings.t("ui.stat.%s" % stat), Settings.format_percent(float(delta.get(stat, 0.0)) * 100.0, 0, true)])
	lines.append("%s %s" % [Settings.t("ui.inventory.score_delta"), Settings.format_number(float(comparison.get("score_delta", 0.0)), 0, true)])
	stat_deltas.text = "  ·  ".join(lines)
	# An equal-score item is NOT a downgrade. Calling it one misleads the player
	# into salvaging a sidegrade, so equality gets its own verdict.
	var score_change: float = float(comparison.get("score_delta", 0.0))
	var is_upgrade: bool = bool(comparison.get("is_upgrade", false))
	if is_equal_approx(score_change, 0.0):
		verdict.text = Settings.t("ui.inventory.same")
		verdict.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	elif is_upgrade:
		verdict.text = Settings.t("ui.inventory.upgrade")
		verdict.add_theme_color_override("font_color", Color(0.42, 1.0, 0.6))
	else:
		verdict.text = Settings.t("ui.inventory.downgrade")
		verdict.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	equip_button.disabled = bool(owned.get("equipped", false))
	lock_button.text = Settings.t("ui.inventory.unlock" if bool(owned.get("locked", false)) else "ui.inventory.lock")
	favorite_button.text = Settings.t("ui.inventory.unfavorite" if bool(owned.get("favorite", false)) else "ui.inventory.favorite")
	var salvage_state: Dictionary = salvage_ui_state(_selected_uid)
	salvage_button.disabled = not bool(salvage_state["enabled"])
	var reason_key: String = str(salvage_state["reason_key"])
	salvage_reason.text = Settings.t(reason_key) if not reason_key.is_empty() else ""
	compare_panel.show()
	actions.show()


func _on_equip() -> void:
	if inventory.equip(_selected_uid):
		message.text = Settings.t("ui.inventory.equipped_ok")
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
	var state: Dictionary = salvage_ui_state(_selected_uid)
	if not bool(state["enabled"]):
		return
	if bool(state["needs_confirm"]):
		_show_confirmation(_selected_uid)
	else:
		var result: Dictionary = inventory.salvage(_selected_uid)
		if bool(result.get("ok", false)):
			_finish_salvage(result)


func _show_confirmation(uid: String) -> void:
	_pending_salvage_uid = uid
	var owned: Dictionary = inventory.owned_items[uid]
	var definition: Dictionary = inventory.definitions[str(owned["item_id"])]
	var warning_lines: PackedStringArray = [Settings.t("ui.salvage.warning") % Settings.t(str(definition["name_key"]))]
	var preview: Dictionary = inventory.salvage_refusal_preview(uid)
	if (preview.get("needs", []) as Array).has("favorite"):
		warning_lines.append(Settings.t("ui.salvage.favorite_warning"))
	warning.text = "\n".join(warning_lines)
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
		message.text = Settings.t("ui.salvage.blocked.%s" % str(result.get("reason", "unknown")))


func _finish_salvage(result: Dictionary) -> void:
	var awarded: float = float(result.get("gold_awarded", 0.0))
	_selected_uid = ""
	message.text = Settings.t("ui.salvage.success") % Settings.format_number(int(awarded))
	if not _debug_fixture:
		var manager: Node = _save_manager()
		if manager == null:
			return
		var save_data: Dictionary = (manager.get("data") as Dictionary).duplicate(true)
		var run_state: Dictionary = save_data["run_state"]
		var current_gold: BigNumber = BigNumber.from_dict(run_state["gold"] as Dictionary)
		run_state["gold"] = current_gold.add(BigNumber.from_float(awarded)).to_dict()
		(save_data["permanent_state"] as Dictionary)["equipment"] = inventory.to_dict()
		manager.call("save", save_data)
		_apply_runtime_inventory()
	_refresh()


func _save_inventory() -> void:
	if _debug_fixture:
		return
	var manager: Node = _save_manager()
	if manager == null:
		return
	var save_data: Dictionary = (manager.get("data") as Dictionary).duplicate(true)
	(save_data["permanent_state"] as Dictionary)["equipment"] = inventory.to_dict()
	manager.call("save", save_data)
	_apply_runtime_inventory()


func _apply_runtime_inventory() -> void:
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena != null and arena.has_method("apply_inventory_state"):
		arena.call("apply_inventory_state", inventory.to_dict())


func _save_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("SaveManager")
	return null
