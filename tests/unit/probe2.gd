extends SceneTree
func _init() -> void:
	print("A")
	var INV = load("res://scripts/progression/inventory.gd")
	print("B new"); var inv = INV.new()
	print("C add"); var uid = inv.add("dune_knife")
	print("D uid=", uid)
	print("E salvage=", inv.salvage(uid))
	print("F second=", inv.salvage(uid))
	quit(0)
