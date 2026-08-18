class_name SupportHeroes
extends RefCounted

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const DATA_PATH: String = "res://resources/heroes/support_heroes.json"

var gold: BigNumber = BigNumber.new()
var heroes: Dictionary = {}
var definitions: Dictionary = heroes
var levels: Dictionary = {}


func _init(initial_gold: BigNumber = null) -> void:
	gold = initial_gold._copy_normalized() if initial_gold != null else BigNumber.new()
	_load_data()


func hire(id: String) -> bool:
	if not heroes.has(id) or get_level(id) != 0:
		return false
	var cost: BigNumber = cost_for_level(id, 0)
	if gold.compare(cost) < 0:
		return false
	gold = gold.sub(cost)
	levels[id] = 1
	return true


func level_up(id: String, count: int = 1) -> bool:
	if not heroes.has(id) or count <= 0 or get_level(id) <= 0:
		return false
	var total_cost: BigNumber = BigNumber.new()
	var start_level: int = get_level(id)
	for offset: int in range(count):
		total_cost = total_cost.add(cost_for_level(id, start_level + offset))
	if gold.compare(total_cost) < 0:
		return false
	gold = gold.sub(total_cost)
	levels[id] = start_level + count
	return true


func cost_for_level(id: String, level: int) -> BigNumber:
	if not heroes.has(id):
		return BigNumber.new()
	var definition: Dictionary = heroes[id]
	var growth: BigNumber = BigNumber.from_float(float(definition["cost_growth"]))
	return BigNumber.from_float(float(definition["base_cost"])).mul(growth.pow_float(maxi(0, level)))


func total_dps() -> BigNumber:
	var total: BigNumber = BigNumber.new()
	for id: Variant in heroes:
		var level: int = get_level(str(id))
		if level <= 0:
			continue
		var definition: Dictionary = heroes[id]
		var multiplier: float = 1.0
		for milestone: Variant in definition["milestones"]:
			if level >= int(milestone):
				multiplier *= 2.0
		total = total.add(BigNumber.from_float(float(definition["base_dps"])).mul_float(level * multiplier))
	return total


func get_level(id: String) -> int:
	return maxi(0, int(levels.get(id, 0)))


func to_dict() -> Dictionary:
	return {"levels": levels.duplicate(true), "gold": gold.to_dict()}


func from_dict(saved: Dictionary) -> void:
	var saved_levels: Variant = saved.get("levels", saved)
	if saved_levels is Dictionary:
		for id: Variant in heroes:
			levels[id] = maxi(0, int((saved_levels as Dictionary).get(id, 0)))
	if saved.get("gold") is Dictionary:
		gold = BigNumber.from_dict(saved["gold"] as Dictionary)


func reset_levels() -> void:
	for id: Variant in heroes:
		levels[id] = 0


func _load_data() -> void:
	var parsed: Variant = _read_json(DATA_PATH)
	if not parsed is Array:
		push_error("SupportHeroes: invalid data at %s" % DATA_PATH)
		return
	for value: Variant in parsed as Array:
		if not value is Dictionary:
			continue
		var definition: Dictionary = (value as Dictionary).duplicate(true)
		var id: String = str(definition.get("id", ""))
		if id.is_empty():
			continue
		heroes[id] = definition
		levels[id] = maxi(0, int(definition.get("level", 0)))


static func _read_json(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed
