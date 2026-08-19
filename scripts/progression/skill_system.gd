class_name SkillSystem
extends RefCounted

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const DATA_PATH: String = "res://resources/skills/skills.json"
const MAX_TIMESTAMP_MS: int = 9_000_000_000_000_000
const MAX_SKILL_LEVEL: int = 1_000_000

var skills: Dictionary = {}
var definitions: Dictionary = skills
var levels: Dictionary = {}
var activated_at_ms: Dictionary = {}
var cooldown_until_ms: Dictionary = {}
var active_skills: Dictionary = activated_at_ms
var cooldowns: Dictionary = cooldown_until_ms
var one_shot_consumed: Dictionary = {}


func _init() -> void:
	_load_data()


func is_unlocked(id: String, max_stage: int) -> bool:
	if not skills.has(id):
		return false
	var condition: Dictionary = (skills[id] as Dictionary).get("unlock_condition", {})
	return maxi(0, max_stage) >= int(condition.get("max_stage", 1))


## Skill relics shorten every cooldown. 1.0 is no reduction; 0.8 is twenty per
## cent off. Clamped so a relic set can never make a skill permanent.
var cooldown_multiplier: float = 1.0


func set_cooldown_multiplier(value: float) -> void:
	cooldown_multiplier = clampf(value, 0.35, 1.0) if is_finite(value) else 1.0


func activate(id: String, now_ms: int, max_stage: int = 2_000_000_000) -> bool:
	if not is_unlocked(id, max_stage):
		return false
	var safe_now: int = clampi(now_ms, 0, MAX_TIMESTAMP_MS)
	if activated_at_ms.has(id) or safe_now < int(cooldown_until_ms.get(id, 0)):
		return false
	for blocked_value: Variant in (skills[id] as Dictionary).get("incompatible_with", []):
		if activated_at_ms.has(str(blocked_value)):
			return false
	activated_at_ms[id] = safe_now
	var cooldown_ms: int = int(float((skills[id] as Dictionary).get("cooldown_ms", 0)) * cooldown_multiplier)
	cooldown_until_ms[id] = mini(MAX_TIMESTAMP_MS, safe_now + maxi(0, cooldown_ms))
	if id == "time_fracture":
		one_shot_consumed[id] = false
	return true


func tick(now_ms: int) -> void:
	var safe_now: int = clampi(now_ms, 0, MAX_TIMESTAMP_MS)
	for id_value: Variant in activated_at_ms.keys():
		var id: String = str(id_value)
		var definition: Dictionary = skills.get(id, {})
		var expires_at: int = mini(MAX_TIMESTAMP_MS, int(activated_at_ms[id]) + int(definition.get("duration_ms", 0)))
		if safe_now >= expires_at:
			activated_at_ms.erase(id)
	for id_value: Variant in cooldown_until_ms.keys():
		var id: String = str(id_value)
		if safe_now >= int(cooldown_until_ms[id]):
			cooldown_until_ms.erase(id)
			one_shot_consumed.erase(id)


func is_active(id: String) -> bool:
	return skills.has(id) and activated_at_ms.has(id)


func is_on_cooldown(id: String) -> bool:
	return skills.has(id) and cooldown_until_ms.has(id)


func get_level(id: String) -> int:
	return clampi(int(levels.get(id, 0)), 0, MAX_SKILL_LEVEL) if skills.has(id) else 0


func set_level(id: String, level: int) -> bool:
	if not skills.has(id):
		return false
	levels[id] = clampi(level, 1, MAX_SKILL_LEVEL)
	return true


func multiplier_for(kind: String) -> float:
	var multiplier: float = 1.0
	for id_value: Variant in activated_at_ms:
		var id: String = str(id_value)
		var effects: Dictionary = (skills[id] as Dictionary).get("effects", {})
		if effects.has(kind):
			multiplier *= _scaled_value(id, float(effects[kind]))
	return multiplier if is_finite(multiplier) else 1.0


func bonus_for(kind: String) -> float:
	var bonus: float = 0.0
	for id_value: Variant in activated_at_ms:
		var id: String = str(id_value)
		var bonuses: Dictionary = (skills[id] as Dictionary).get("bonuses", {})
		if bonuses.has(kind):
			bonus += float(bonuses[kind])
	return bonus if is_finite(bonus) else 0.0


func tap_damage_multiplier() -> float:
	return multiplier_for("tap_damage")


func falcon_rate_multiplier() -> float:
	return multiplier_for("falcon_rate")


func gold_multiplier() -> float:
	return multiplier_for("gold")


func support_dps_multiplier() -> float:
	return multiplier_for("support_dps")


func crit_chance(base_chance: float) -> float:
	var safe_base: float = clampf(base_chance, 0.0, 0.95) if is_finite(base_chance) else 0.0
	return clampf(safe_base + bonus_for("crit_chance"), 0.0, 0.95)


func crit_damage_multiplier() -> float:
	return multiplier_for("crit_damage")


func apply_gold_award(amount: BigNumber) -> BigNumber:
	if amount == null or not amount.is_valid() or amount.mantissa < 0.0:
		return BigNumber.new()
	return amount.mul_float(gold_multiplier())


func apply_time_fracture(current_timer: float) -> float:
	## Single rule: consume +10 seconds once for this activation, clamp [0, 60].
	var safe_timer: float = clampf(current_timer, 0.0, 60.0) if is_finite(current_timer) else 0.0
	if not is_active("time_fracture") or bool(one_shot_consumed.get("time_fracture", true)):
		return safe_timer
	one_shot_consumed["time_fracture"] = true
	return clampf(safe_timer + 10.0, 0.0, 60.0)


func remaining_active_seconds(id: String, now_ms: int) -> int:
	if not is_active(id):
		return 0
	var until: int = int(activated_at_ms[id]) + int((skills[id] as Dictionary).get("duration_ms", 0))
	return maxi(0, int(ceil(float(until - clampi(now_ms, 0, MAX_TIMESTAMP_MS)) / 1000.0)))


func remaining_cooldown_seconds(id: String, now_ms: int) -> int:
	if not is_on_cooldown(id):
		return 0
	return maxi(0, int(ceil(float(int(cooldown_until_ms[id]) - clampi(now_ms, 0, MAX_TIMESTAMP_MS)) / 1000.0)))


func clear() -> void:
	activated_at_ms.clear()
	cooldown_until_ms.clear()
	one_shot_consumed.clear()


func to_dict() -> Dictionary:
	return {
		"activated_at_ms": activated_at_ms.duplicate(true),
		"cooldown_until_ms": cooldown_until_ms.duplicate(true),
		"levels": levels.duplicate(true),
		"one_shot_consumed": one_shot_consumed.duplicate(true),
	}


func from_dict(saved: Dictionary) -> void:
	clear()
	var saved_active: Variant = saved.get("activated_at_ms", {})
	var saved_cooldowns: Variant = saved.get("cooldown_until_ms", {})
	if saved_active is Dictionary:
		for id_value: Variant in saved_active:
			var id: String = str(id_value)
			var value: Variant = saved_active[id_value]
			if skills.has(id) and (value is int or value is float) and is_finite(float(value)):
				activated_at_ms[id] = clampi(int(value), 0, MAX_TIMESTAMP_MS)
	if saved_cooldowns is Dictionary:
		for id_value: Variant in saved_cooldowns:
			var id: String = str(id_value)
			var value: Variant = saved_cooldowns[id_value]
			if skills.has(id) and (value is int or value is float) and is_finite(float(value)):
				cooldown_until_ms[id] = clampi(int(value), 0, MAX_TIMESTAMP_MS)
	var saved_levels: Variant = saved.get("levels", {})
	if saved_levels is Dictionary:
		for id_value: Variant in skills:
			var id: String = str(id_value)
			levels[id] = clampi(int((saved_levels as Dictionary).get(id, levels[id])), 1, MAX_SKILL_LEVEL)
	var saved_consumed: Variant = saved.get("one_shot_consumed", {})
	if saved_consumed is Dictionary:
		for id_value: Variant in saved_consumed:
			if skills.has(str(id_value)):
				one_shot_consumed[str(id_value)] = bool((saved_consumed as Dictionary)[id_value])
	# Old saves did not record one-shot consumption. Treat a restored activation
	# as consumed so reopening the game can never duplicate the timer addition.
	if activated_at_ms.has("time_fracture") and not one_shot_consumed.has("time_fracture"):
		one_shot_consumed["time_fracture"] = true


func _scaled_value(id: String, base_value: float) -> float:
	var rule: Dictionary = (skills[id] as Dictionary).get("scaling_rule", {})
	if str(rule.get("type", "fixed")) != "linear_multiplier":
		return base_value
	var scale: float = 1.0 + float(rule.get("per_level", 0.0)) * float(maxi(0, get_level(id) - 1))
	var result: float = base_value * scale
	return result if is_finite(result) else base_value


func _load_data() -> void:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("SkillSystem: cannot read %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var values: Variant = (parsed as Dictionary).get("skills") if parsed is Dictionary else parsed
	if not values is Array:
		push_error("SkillSystem: invalid data at %s" % DATA_PATH)
		return
	for value: Variant in values as Array:
		if value is Dictionary:
			var definition: Dictionary = (value as Dictionary).duplicate(true)
			var id: String = str(definition.get("id", ""))
			if not id.is_empty():
				skills[id] = definition
				levels[id] = clampi(int(definition.get("level", 1)), 1, MAX_SKILL_LEVEL)
