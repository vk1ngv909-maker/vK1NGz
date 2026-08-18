class_name Worlds
extends RefCounted

const DATA_PATH: String = "res://resources/worlds/worlds.json"

var worlds: Array[Dictionary] = []
var _logged_beyond_authored_range: bool = false


func _init(path: String = DATA_PATH) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Worlds: cannot read %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var values: Variant = (parsed as Dictionary).get("entries") if parsed is Dictionary else parsed
	if not values is Array:
		push_error("Worlds: invalid world catalog at %s" % path)
		return
	for value: Variant in values as Array:
		if value is Dictionary:
			worlds.append((value as Dictionary).duplicate(true))
	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("stage_from", 0)) < int(b.get("stage_from", 0)))


func world_for_stage(stage: int) -> Dictionary:
	if worlds.is_empty():
		return {}
	var safe_stage: int = maxi(1, stage)
	for world: Dictionary in worlds:
		if safe_stage >= int(world.get("stage_from", 1)) and safe_stage <= int(world.get("stage_to", 0)):
			return world.duplicate(true)
	# Endless progression deliberately reuses the final authored presentation.
	# Content validation guarantees there is no authored gap leading here.
	if safe_stage > int(worlds.back().get("stage_to", 0)):
		if not _logged_beyond_authored_range:
			_logged_beyond_authored_range = true
			push_warning("Worlds: stage %d is beyond authored content; clamping to '%s'" % [safe_stage, str(worlds.back().get("id", ""))])
		return worlds.back().duplicate(true)
	return worlds.front().duplicate(true)
