class_name SkillSystem
extends RefCounted

const DATA_PATH: String = "res://resources/skills/skills.json"

var skills: Dictionary = {}
var definitions: Dictionary = skills
var activated_at_ms: Dictionary = {}
var cooldown_until_ms: Dictionary = {}
var active_skills: Dictionary = activated_at_ms
var cooldowns: Dictionary = cooldown_until_ms


func _init() -> void:
	_load_data()


func activate(id: String, now_ms: int) -> bool:
	if not skills.has(id):
		return false
	if activated_at_ms.has(id) or now_ms < int(cooldown_until_ms.get(id, 0)):
		return false
	activated_at_ms[id] = now_ms
	cooldown_until_ms[id] = now_ms + int((skills[id] as Dictionary)["cooldown_ms"])
	return true


func tick(now_ms: int) -> void:
	for id: Variant in activated_at_ms.keys():
		var definition: Dictionary = skills.get(id, {})
		var expires_at: int = int(activated_at_ms[id]) + int(definition.get("duration_ms", 0))
		if now_ms >= expires_at:
			activated_at_ms.erase(id)
	for id: Variant in cooldown_until_ms.keys():
		if now_ms >= int(cooldown_until_ms[id]):
			cooldown_until_ms.erase(id)


func is_active(id: String) -> bool:
	return activated_at_ms.has(id)


func is_on_cooldown(id: String) -> bool:
	return cooldown_until_ms.has(id)


func multiplier_for(kind: String) -> float:
	var multiplier: float = 1.0
	for id: Variant in activated_at_ms:
		var effects: Dictionary = (skills[id] as Dictionary).get("effects", {})
		if effects.has(kind):
			multiplier *= float(effects[kind])
	return multiplier


func bonus_for(kind: String) -> float:
	var bonus: float = 0.0
	for id: Variant in activated_at_ms:
		var bonuses: Dictionary = (skills[id] as Dictionary).get("bonuses", {})
		if bonuses.has(kind):
			bonus += float(bonuses[kind])
	return bonus


func clear() -> void:
	activated_at_ms.clear()
	cooldown_until_ms.clear()


func to_dict() -> Dictionary:
	return {
		"activated_at_ms": activated_at_ms.duplicate(true),
		"cooldown_until_ms": cooldown_until_ms.duplicate(true),
	}


func from_dict(saved: Dictionary) -> void:
	clear()
	var saved_active: Variant = saved.get("activated_at_ms", {})
	var saved_cooldowns: Variant = saved.get("cooldown_until_ms", {})
	if saved_active is Dictionary:
		for id: Variant in saved_active:
			if skills.has(str(id)):
				activated_at_ms[str(id)] = int(saved_active[id])
	if saved_cooldowns is Dictionary:
		for id: Variant in saved_cooldowns:
			if skills.has(str(id)):
				cooldown_until_ms[str(id)] = int(saved_cooldowns[id])


func _load_data() -> void:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("SkillSystem: cannot read %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		push_error("SkillSystem: invalid data at %s" % DATA_PATH)
		return
	for value: Variant in parsed as Array:
		if value is Dictionary:
			var definition: Dictionary = (value as Dictionary).duplicate(true)
			var id: String = str(definition.get("id", ""))
			if not id.is_empty():
				skills[id] = definition
