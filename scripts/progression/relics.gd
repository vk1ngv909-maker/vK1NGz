class_name Relics
extends RefCounted

const DATA_PATH: String = "res://resources/relics/relics.json"

var prestige_currency: int = 0
var relics: Dictionary = {}
var definitions: Dictionary = relics
var levels: Dictionary = {}


func _init(initial_currency: int = 0) -> void:
	prestige_currency = maxi(0, initial_currency)
	_load_data()


func buy(id: String) -> bool:
	if not relics.has(id) or get_level(id) != 0:
		return false
	return _purchase_level(id)


func upgrade(id: String) -> bool:
	if not relics.has(id) or get_level(id) <= 0:
		return false
	return _purchase_level(id)


func plan_purchase(id: String, requested: int) -> Dictionary:
	## What a bulk purchase would actually do, worked out before any state moves.
	## The panel shows this and then commits exactly it, so what the player reads
	## and what they are charged can never disagree. A negative `requested` asks
	## for every level the player can currently afford.
	if not relics.has(id):
		return {"levels": 0, "cost": 0, "reason": "unknown"}
	var definition: Dictionary = relics[id]
	var level: int = get_level(id)
	var maximum: int = int(definition["max_level"])
	if level >= maximum:
		return {"levels": 0, "cost": 0, "reason": "max_level", "from_level": level, "to_level": level}
	var unit_cost: int = int(definition["cost"])
	var affordable: int = int(floor(float(prestige_currency) / float(maxi(1, unit_cost))))
	var wanted: int = affordable if requested < 0 else requested
	var levels: int = mini(mini(wanted, maximum - level), affordable)
	var reason: String = ""
	if levels <= 0:
		reason = "insufficient_currency" if affordable <= 0 else "no_levels"
	return {
		"levels": levels,
		"cost": levels * unit_cost,
		"from_level": level,
		"to_level": level + levels,
		"reason": reason,
		"affordable_levels": affordable,
		"unit_cost": unit_cost,
	}


func purchase(id: String, requested: int) -> Dictionary:
	## Commits the plan above, level by level, so a bulk purchase is exactly the
	## same sequence of single purchases and cannot round its own cost.
	var plan: Dictionary = plan_purchase(id, requested)
	var bought: int = 0
	var spent_before: int = prestige_currency
	for step: int in int(plan.get("levels", 0)):
		if not _purchase_level(id):
			break
		bought += 1
	plan["levels"] = bought
	plan["cost"] = spent_before - prestige_currency
	plan["to_level"] = get_level(id)
	return plan


func effect_at(id: String, level: int) -> float:
	## The bonus this relic contributes at a given level; 0 when it is not owned.
	if not relics.has(id) or level <= 0:
		return 0.0
	var definition: Dictionary = relics[id]
	var capped: int = clampi(level, 0, int(definition["max_level"]))
	return float(definition["base_effect"]) + float(definition["growth"]) * (capped - 1)


func cost_for_next_level(id: String) -> int:
	if not relics.has(id):
		return 0
	return int((relics[id] as Dictionary)["cost"])


func total_bonus(category: String) -> float:
	var total: float = 0.0
	for id: Variant in relics:
		var definition: Dictionary = relics[id]
		var level: int = get_level(str(id))
		if level > 0 and str(definition["category"]) == category:
			total += float(definition["base_effect"]) + float(definition["growth"]) * (level - 1)
	return total


func get_level(id: String) -> int:
	return maxi(0, int(levels.get(id, 0)))


func to_dict() -> Dictionary:
	return {"levels": levels.duplicate(true), "prestige_currency": prestige_currency}


func from_dict(saved: Dictionary) -> void:
	var saved_levels: Variant = saved.get("levels", saved)
	if saved_levels is Dictionary:
		for id: Variant in relics:
			levels[id] = clampi(int((saved_levels as Dictionary).get(id, 0)), 0, int((relics[id] as Dictionary)["max_level"]))
	prestige_currency = maxi(0, int(saved.get("prestige_currency", prestige_currency)))


func _purchase_level(id: String) -> bool:
	var definition: Dictionary = relics[id]
	var level: int = get_level(id)
	if level >= int(definition["max_level"]):
		return false
	var next_cost: int = cost_for_next_level(id)
	if next_cost <= 0 or prestige_currency < next_cost:
		return false
	prestige_currency -= next_cost
	levels[id] = level + 1
	return true


func _load_data() -> void:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Relics: cannot read %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var values: Variant = (parsed as Dictionary).get("relics") if parsed is Dictionary else parsed
	if not values is Array:
		push_error("Relics: invalid data at %s" % DATA_PATH)
		return
	for value: Variant in values as Array:
		if value is Dictionary:
			var definition: Dictionary = (value as Dictionary).duplicate(true)
			var id: String = str(definition.get("id", ""))
			if not id.is_empty():
				relics[id] = definition
				levels[id] = clampi(int(definition.get("level", 0)), 0, int(definition.get("max_level", 0)))
