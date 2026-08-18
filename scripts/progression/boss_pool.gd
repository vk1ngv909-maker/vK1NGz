class_name BossPool
extends RefCounted

const BOSSES_PATH: String = "res://resources/bosses/bosses.json"
const BOSS_INTERVAL: int = 10
const LAST_AUTHORED_STAGE: int = 100
# Authored milestone cadence: stage 10's archetype intentionally returns at 40.
const ASSIGNMENT_PATTERN: Array[int] = [0, 1, 2, 0, 3, 1, 2, 0, 3, 1]

var bosses: Array[Dictionary] = []


func _init(path: String = BOSSES_PATH) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BossPool: cannot read %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var values: Variant = (parsed as Dictionary).get("entries", []) if parsed is Dictionary else parsed
	if not values is Array:
		push_error("BossPool: invalid boss catalog at %s" % path)
		return
	for value: Variant in values as Array:
		if value is Dictionary:
			bosses.append((value as Dictionary).duplicate(true))


static func encounter_id(stage: int) -> String:
	return "stage_%d" % maxi(1, stage)


func select(stage: int) -> Dictionary:
	var safe_stage: int = maxi(1, stage)
	if safe_stage % BOSS_INTERVAL != 0:
		return {}
	if bosses.is_empty():
		push_error("BossPool: no boss archetypes are available")
		return {}
	# Beyond 100 keeps the final world's presentation and repeats its boss cycle.
	# The authored assignment anchor is clamped to stage 100.
	var assignment_stage: int = mini(safe_stage, LAST_AUTHORED_STAGE)
	var index: int = archetype_index(assignment_stage, bosses.size())
	var result: Dictionary = bosses[index].duplicate(true)
	result["encounter_id"] = encounter_id(safe_stage)
	result["stage"] = safe_stage
	return result


func select_by_id(archetype_id: String, stage: int = 10) -> Dictionary:
	if archetype_id.is_empty():
		return {}
	for value: Dictionary in bosses:
		if str(value.get("id", "")) == archetype_id:
			var result: Dictionary = value.duplicate(true)
			var safe_stage: int = maxi(BOSS_INTERVAL, stage)
			result["encounter_id"] = encounter_id(safe_stage)
			result["stage"] = safe_stage
			return result
	return {}


static func archetype_index(stage: int, archetype_count: int) -> int:
	if archetype_count <= 0:
		return 0
	var slot: int = clampi(int(stage / BOSS_INTERVAL) - 1, 0, ASSIGNMENT_PATTERN.size() - 1)
	return ASSIGNMENT_PATTERN[slot] % archetype_count
