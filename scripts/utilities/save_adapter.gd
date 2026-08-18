class_name SaveAdapter
extends RefCounted


func save(data: Dictionary) -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var manager: Node = (loop as SceneTree).root.get_node_or_null("SaveManager")
		if manager != null and manager.has_method("save"):
			return bool(manager.call("save", data.duplicate(true)))
	push_error("SaveAdapter.save: SaveManager autoload is unavailable")
	return false
