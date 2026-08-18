extends SceneTree

const InventoryLogic = preload("res://scripts/progression/inventory.gd")
const InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")

const ITEMS_BY_RARITY: Dictionary = {
	"common": "dune_knife",
	"rare": "sunsteel_sabre",
	"epic": "ifrit_fang",
	"legendary": "blade_of_high_noon",
}

var passed: int = 0
var failed: int = 0


func _init() -> void:
	for equipped: bool in [false, true]:
		for locked: bool in [false, true]:
			for favorite: bool in [false, true]:
				for rarity: String in ITEMS_BY_RARITY:
					_check_combination(equipped, locked, favorite, rarity)
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check_combination(equipped: bool, locked: bool, favorite: bool, rarity: String) -> void:
	var inventory: Inventory = InventoryLogic.new()
	var uid: String = inventory.add(str(ITEMS_BY_RARITY[rarity]))
	if equipped:
		inventory.equip(uid)
	inventory.set_locked(uid, locked)
	inventory.set_favorite(uid, favorite)
	var panel: Node = InventoryPanelScene.instantiate()
	panel.set("inventory", inventory)
	var ui_state: Dictionary = panel.call("salvage_ui_state", uid)
	var destructive_copy: Inventory = InventoryLogic.new(inventory.to_dict())
	var result: Dictionary = destructive_copy.salvage(uid, true, true)
	var label: String = "equipped=%s locked=%s favorite=%s rarity=%s" % [equipped, locked, favorite, rarity]
	_check(bool(ui_state["enabled"]) == bool(result.get("ok", false)), "UI matches salvage: " + label)
	if locked:
		_check(ui_state["reason_key"] == "ui.inventory.cannot_locked", "locked wins: " + label)
	elif equipped:
		_check(ui_state["reason_key"] == "ui.inventory.cannot_equipped", "equipped reason: " + label)
	else:
		_check(bool(ui_state["needs_confirm"]) == (favorite or rarity != "common"), "confirmation state: " + label)
	panel.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
