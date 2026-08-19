class_name SupportHeroes
extends RefCounted

signal milestone_reached(hero_id: String, threshold: int, effect: Dictionary)

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const DATA_PATH: String = "res://resources/heroes/support_heroes.json"
const MAX_HERO_LEVEL: int = 2_000_000_000
const MULTIPLIER_KINDS: Array[String] = [
	"self_dps_mult", "all_hero_dps_mult", "gold_mult",
	"skill_duration_mult", "skill_cooldown_mult",
]

var gold: BigNumber = BigNumber.new()
var heroes: Dictionary = {}
var definitions: Dictionary = heroes
var levels: Dictionary = {}
var fired_milestones: Dictionary = {}


func _init(initial_gold: BigNumber = null) -> void:
	gold = initial_gold._copy_normalized() if initial_gold != null and initial_gold.is_valid() else BigNumber.new()
	_load_data()


func is_unlocked(id: String, max_stage: int) -> bool:
	if not heroes.has(id):
		return false
	return maxi(0, max_stage) >= int((heroes[id] as Dictionary).get("unlock_stage", MAX_HERO_LEVEL))


func hire(id: String, max_stage: int = 1) -> bool:
	if not is_unlocked(id, max_stage) or get_level(id) != 0:
		return false
	var cost: BigNumber = cost_for(id, 1)
	if not cost.is_valid() or gold.compare(cost) < 0:
		return false
	gold = gold.sub(cost)
	levels[id] = 1
	_fire_crossed_milestones(id, 0, 1)
	return true


func level_up(id: String, count: int = 1) -> bool:
	if not heroes.has(id) or count <= 0 or get_level(id) <= 0:
		return false
	var start_level: int = get_level(id)
	var safe_count: int = mini(count, MAX_HERO_LEVEL - start_level)
	if safe_count <= 0:
		return false
	var total_cost: BigNumber = cost_for(id, safe_count)
	if not total_cost.is_valid() or gold.compare(total_cost) < 0:
		return false
	gold = gold.sub(total_cost)
	var end_level: int = start_level + safe_count
	levels[id] = end_level
	_fire_crossed_milestones(id, start_level, end_level)
	return true


func cost_for(id: String, count: int = 1) -> BigNumber:
	if not heroes.has(id) or count <= 0:
		return BigNumber.new()
	var start_level: int = get_level(id)
	var safe_count: int = mini(count, MAX_HERO_LEVEL - start_level)
	if safe_count <= 0:
		return BigNumber.new()
	var definition: Dictionary = heroes[id]
	var growth: float = float(definition.get("cost_growth", 1.0))
	var first: BigNumber = cost_for_level(id, start_level)
	if is_equal_approx(growth, 1.0):
		return first.mul_float(float(safe_count))
	var series: BigNumber = BigNumber.from_float(growth).pow_float(float(safe_count)).sub(BigNumber.from_float(1.0))
	return first.mul(series).div(BigNumber.from_float(growth - 1.0))


func max_affordable(id: String, available_gold: BigNumber) -> int:
	if not heroes.has(id) or available_gold == null or not available_gold.is_valid() or available_gold.mantissa <= 0.0:
		return 0
	var capacity: int = MAX_HERO_LEVEL - get_level(id)
	if capacity <= 0 or available_gold.compare(cost_for(id, 1)) < 0:
		return 0
	var low: int = 1
	var high: int = 2
	while high < capacity and available_gold.compare(cost_for(id, high)) >= 0:
		low = high
		high = mini(capacity, high * 2)
		if high == low:
			break
	if available_gold.compare(cost_for(id, high)) >= 0:
		return high
	while low + 1 < high:
		var middle: int = low + int((high - low) / 2)
		if available_gold.compare(cost_for(id, middle)) >= 0:
			low = middle
		else:
			high = middle
	return low


func cost_for_level(id: String, level: int) -> BigNumber:
	if not heroes.has(id):
		return BigNumber.new()
	var definition: Dictionary = heroes[id]
	var safe_level: int = clampi(level, 0, MAX_HERO_LEVEL)
	return BigNumber.from_float(float(definition["base_cost"])).mul(
		BigNumber.from_float(float(definition["cost_growth"])).pow_float(float(safe_level))
	)


func hero_dps(id: String, at_level: int = -1) -> BigNumber:
	if not heroes.has(id):
		return BigNumber.new()
	var level: int = get_level(id) if at_level < 0 else clampi(at_level, 0, MAX_HERO_LEVEL)
	if level <= 0:
		return BigNumber.new()
	var definition: Dictionary = heroes[id]
	var result: BigNumber = BigNumber.from_float(float(definition["base_dps"]))
	result = result.mul(BigNumber.from_float(float(definition["dps_growth"])).pow_float(float(level - 1)))
	result = result.mul_float(float(level) * _hero_multiplier(id, level, "self_dps_mult"))
	return result


func next_level_gain(id: String) -> BigNumber:
	## Single source of truth for the next-level gain figure shown in the panel. It
	## used to derive this inline, which lets the displayed number drift away
	## from the real one if either side changes.
	var level: int = get_level(id)
	return hero_dps(id, level + 1).sub(hero_dps(id, level))


func total_dps() -> BigNumber:
	var total: BigNumber = BigNumber.new()
	for id_value: Variant in heroes:
		var id: String = str(id_value)
		if get_level(id) > 0:
			total = total.add(hero_dps(id))
	return total.mul_float(passive_bonus("all_hero_dps_mult"))


func passive_bonus(kind: String) -> float:
	var result: float = 1.0 if kind in MULTIPLIER_KINDS else 0.0
	for id_value: Variant in heroes:
		var id: String = str(id_value)
		var level: int = get_level(id)
		if level <= 0:
			continue
		var definition: Dictionary = heroes[id]
		var passive: Dictionary = definition.get("passive", {})
		if str(passive.get("type", "")) == kind:
			result = _combine_bonus(result, kind, float(passive.get("value", 0.0)))
		for milestone_value: Variant in definition.get("milestones", []):
			if not milestone_value is Dictionary:
				continue
			var milestone: Dictionary = milestone_value as Dictionary
			if level < int(milestone.get("level", MAX_HERO_LEVEL)):
				continue
			var effect: Dictionary = milestone.get("effect", {})
			if str(effect.get("type", "")) == kind and kind != "self_dps_mult":
				result = _combine_bonus(result, kind, float(effect.get("value", 0.0)))
	return result if is_finite(result) else (1.0 if kind in MULTIPLIER_KINDS else 0.0)


func get_level(id: String) -> int:
	return clampi(int(levels.get(id, 0)), 0, MAX_HERO_LEVEL) if heroes.has(id) else 0


func next_milestone(id: String) -> Dictionary:
	if not heroes.has(id):
		return {}
	var level: int = get_level(id)
	for value: Variant in (heroes[id] as Dictionary).get("milestones", []):
		if value is Dictionary and int((value as Dictionary).get("level", 0)) > level:
			return (value as Dictionary).duplicate(true)
	return {}


func to_dict() -> Dictionary:
	return {
		"levels": levels.duplicate(true),
		"gold": gold.to_dict(),
		"fired_milestones": fired_milestones.duplicate(true),
	}


func from_dict(saved: Dictionary) -> void:
	var saved_levels: Variant = saved.get("levels", saved)
	if saved_levels is Dictionary:
		for id_value: Variant in heroes:
			var id: String = str(id_value)
			levels[id] = clampi(int((saved_levels as Dictionary).get(id, 0)), 0, MAX_HERO_LEVEL)
	var saved_fired: Variant = saved.get("fired_milestones", {})
	for id_value: Variant in heroes:
		var id: String = str(id_value)
		var recorded: Array = (saved_fired as Dictionary).get(id, []).duplicate() if saved_fired is Dictionary and (saved_fired as Dictionary).get(id, []) is Array else []
		for milestone_value: Variant in (heroes[id] as Dictionary).get("milestones", []):
			if milestone_value is Dictionary:
				var threshold: int = int((milestone_value as Dictionary).get("level", 0))
				if threshold <= get_level(id) and threshold not in recorded:
					recorded.append(threshold)
		fired_milestones[id] = recorded
	if saved.get("gold") is Dictionary:
		var loaded_gold: BigNumber = BigNumber.from_dict(saved["gold"] as Dictionary)
		gold = loaded_gold if loaded_gold.is_valid() and loaded_gold.mantissa >= 0.0 else BigNumber.new()


func reset_levels() -> void:
	for id_value: Variant in heroes:
		levels[str(id_value)] = 0
		fired_milestones[str(id_value)] = []


func _hero_multiplier(id: String, level: int, kind: String) -> float:
	var result: float = 1.0
	for milestone_value: Variant in (heroes[id] as Dictionary).get("milestones", []):
		if milestone_value is Dictionary:
			var milestone: Dictionary = milestone_value as Dictionary
			var effect: Dictionary = milestone.get("effect", {})
			if level >= int(milestone.get("level", MAX_HERO_LEVEL)) and str(effect.get("type", "")) == kind:
				result *= float(effect.get("value", 1.0))
	return result if is_finite(result) else 1.0


func _combine_bonus(current: float, kind: String, value: float) -> float:
	if not is_finite(value):
		return current
	return current * value if kind in MULTIPLIER_KINDS else current + value


func _fire_crossed_milestones(id: String, old_level: int, new_level: int) -> void:
	var recorded: Array = fired_milestones.get(id, [])
	for milestone_value: Variant in (heroes[id] as Dictionary).get("milestones", []):
		if not milestone_value is Dictionary:
			continue
		var milestone: Dictionary = milestone_value as Dictionary
		var threshold: int = int(milestone.get("level", 0))
		if old_level < threshold and new_level >= threshold and threshold not in recorded:
			recorded.append(threshold)
			milestone_reached.emit(id, threshold, (milestone.get("effect", {}) as Dictionary).duplicate(true))
	fired_milestones[id] = recorded


func _load_data() -> void:
	var parsed: Variant = _read_json(DATA_PATH)
	var values: Variant = (parsed as Dictionary).get("entries", (parsed as Dictionary).get("support_heroes", [])) if parsed is Dictionary else parsed
	if not values is Array:
		push_error("SupportHeroes: invalid data at %s" % DATA_PATH)
		return
	for value: Variant in values as Array:
		if not value is Dictionary:
			continue
		var definition: Dictionary = (value as Dictionary).duplicate(true)
		var id: String = str(definition.get("id", ""))
		if id.is_empty():
			continue
		heroes[id] = definition
		levels[id] = 0
		fired_milestones[id] = []


static func _read_json(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed
