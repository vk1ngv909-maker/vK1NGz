class_name EnemyPool
extends RefCounted

const ENEMIES_PATH: String = "res://resources/enemies/enemies.json"
const BOSS_INTERVAL: int = 10
const WorldsLogic = preload("res://scripts/progression/worlds.gd")

var enemies: Dictionary = {}
var worlds: RefCounted


func _init(enemy_path: String = ENEMIES_PATH, worlds_value: RefCounted = null) -> void:
	worlds = worlds_value if worlds_value != null else WorldsLogic.new()
	var file: FileAccess = FileAccess.open(enemy_path, FileAccess.READ)
	if file == null:
		push_error("EnemyPool: cannot read %s" % enemy_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var values: Variant = (parsed as Dictionary).get("entries", []) if parsed is Dictionary else parsed
	if not values is Array:
		push_error("EnemyPool: invalid enemy catalog at %s" % enemy_path)
		return
	for value: Variant in values as Array:
		if value is Dictionary:
			var entry: Dictionary = (value as Dictionary).duplicate(true)
			var id: String = str(entry.get("id", ""))
			if not id.is_empty():
				enemies[id] = entry


func select(stage: int, seed: int) -> Dictionary:
	var safe_stage: int = maxi(1, stage)
	if safe_stage % BOSS_INTERVAL == 0:
		return {}
	var world: Dictionary = worlds.call("world_for_stage", safe_stage) as Dictionary
	if world.is_empty():
		return _fallback("EnemyPool: no active world for stage %d" % safe_stage)
	var candidates: Array[Dictionary] = []
	for id_value: Variant in world.get("enemy_pool", []):
		var entry: Dictionary = enemies.get(str(id_value), {})
		if not entry.is_empty() and str(entry.get("world_id", "")) == str(world.get("id", "")):
			candidates.append(entry)
	if candidates.is_empty():
		return _fallback("EnemyPool: world '%s' has no valid enemies" % str(world.get("id", "")))
	var mixed: int = _mix_seed(seed, safe_stage)
	var index: int = int(posmod(mixed, candidates.size()))
	return candidates[index].duplicate(true)


func _fallback(message: String) -> Dictionary:
	push_error(message)
	return {
		"id": "fallback_enemy",
		"name_key": "hud.enemy_unknown",
		"desc_key": "hud.enemy_unknown",
		"world_id": "fallback",
		"hp_modifier": 1.0,
		"gold_modifier": 1.0,
		"palette": {"body": "#777777", "accent": "#FFFFFF"},
		"silhouette": "squat",
		"size_scale": 1.0,
		"hit_reaction": {"recoil_px": 8, "flash_strength": 0.5},
		"asset_status": "PLACEHOLDER",
	}


func _mix_seed(seed: int, stage: int) -> int:
	# Integer-only mixing is stable across platforms and does not mutate global RNG state.
	var value: int = seed ^ (stage * 1103515245)
	value = value ^ (value >> 16)
	return value & 0x7fffffff
