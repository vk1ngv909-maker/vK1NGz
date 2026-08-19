class_name EnemyBossValidator
extends RefCounted

const BossPoolLogic = preload("res://scripts/progression/boss_pool.gd")


static func validate(dataset: Dictionary, catalogs: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var worlds: Dictionary = catalogs.get("worlds", {})
	for type_name: String in ["enemies", "bosses"]:
		var packet: Dictionary = dataset.get(type_name, {})
		var path: String = str(packet.get("file", type_name))
		for value: Variant in packet.get("entries", []):
			if not value is Dictionary:
				continue
			var entry: Dictionary = value as Dictionary
			var entry_id: String = str(entry.get("id", "<entry>"))
			var world_id: String = str(entry.get("world_id", ""))
			var world: Dictionary = worlds.get(world_id, {})
			if type_name == "enemies" and not world.is_empty():
				if int(entry.get("stage_from", 0)) < int(world.get("stage_from", 0)) or int(entry.get("stage_to", 0)) > int(world.get("stage_to", 0)):
					_add(issues, path, entry_id, "stage_from", "enemy stage range is outside its world")
				if int(entry.get("stage_from", 0)) > int(entry.get("stage_to", 0)):
					_add(issues, path, entry_id, "stage_from", "invalid stage range")
			if type_name == "bosses" and world_id != "milestone" and world.is_empty():
				_add(issues, path, entry_id, "world_id", "unknown world reference '%s'" % world_id)
			for modifier: String in ["hp_modifier", "gold_modifier"]:
				if entry.has(modifier) and (not is_finite(float(entry[modifier])) or float(entry[modifier]) <= 0.0 or float(entry[modifier]) > 1000.0):
					_add(issues, path, entry_id, modifier, "invalid modifier")
			_validate_identity(issues, path, entry_id, entry, worlds, type_name)
	_validate_distinct_sets(issues, dataset, catalogs)
	_validate_assignments(issues, dataset, catalogs)
	return issues


static func validate_first_clear_keys(first_clears: Dictionary, archetype_ids: Array) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	for key_value: Variant in first_clears:
		var key: String = str(key_value)
		if key in archetype_ids or not key.begins_with("stage_") or not key.trim_prefix("stage_").is_valid_int():
			_add(issues, "<save>", key, "boss_first_clears", "must be keyed by encounter id")
	return issues


static func validate_encounter_ids(encounter_ids: Array) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value: Variant in encounter_ids:
		var encounter: String = str(value)
		if seen.has(encounter):
			_add(issues, "<assignments>", encounter, "encounter_id", "duplicate encounter id")
		seen[encounter] = true
	return issues


static func _validate_identity(issues: Array[Dictionary], path: String, entry_id: String, entry: Dictionary,
		worlds: Dictionary = {}, type_name: String = "enemies") -> void:
	if str(entry.get("silhouette", "")) not in ["squat", "tall", "wide", "spindly"]:
		_add(issues, path, entry_id, "silhouette", "invalid silhouette")
	var status: String = str(entry.get("asset_status", ""))
	if status not in ["PLACEHOLDER", "CONCEPT_SOURCED"]:
		_add(issues, path, entry_id, "asset_status", "must be PLACEHOLDER or CONCEPT_SOURCED")
	elif status == "CONCEPT_SOURCED":
		# Claiming real art is only allowed when the sprite is actually there,
		# so the status can never drift ahead of the assets.
		if type_name == "bosses":
			# A boss archetype has no sprite of its own: each world dresses it in
			# a visual of that world. Its art is proven when every world that can
			# spawn it maps it to a sprite that exists.
			var covered: int = 0
			for world_value: Variant in worlds.values():
				var world: Dictionary = world_value
				var visuals: Variant = world.get("boss_visuals")
				if not visuals is Dictionary:
					continue
				var mapped: Variant = (visuals as Dictionary).get(entry_id)
				if not mapped is Dictionary:
					_add(issues, path, entry_id, "asset_status",
						"world '%s' has no visual for this archetype" % str(world.get("id", "")))
					continue
				var visual_id: String = str((mapped as Dictionary).get("visual_id", ""))
				if not ResourceLoader.exists("res://assets/sprites/bosses/%s.png" % visual_id):
					_add(issues, path, entry_id, "asset_status",
						"world '%s' maps this archetype to missing visual '%s'" % [str(world.get("id", "")), visual_id])
				else:
					covered += 1
			if covered == 0:
				_add(issues, path, entry_id, "asset_status", "CONCEPT_SOURCED without any world visual")
		elif not ResourceLoader.exists("res://assets/sprites/enemies/%s.png" % entry_id):
			_add(issues, path, entry_id, "asset_status", "CONCEPT_SOURCED without a sprite file")
	var palette: Variant = entry.get("palette")
	if palette is Dictionary:
		for field: String in ["body", "accent"]:
			if not (palette as Dictionary).has(field) or not Color.html_is_valid(str((palette as Dictionary).get(field, ""))):
				_add(issues, path, entry_id, "palette.%s" % field, "missing or invalid color")
	var reaction: Variant = entry.get("hit_reaction")
	if reaction is Dictionary:
		var recoil: float = float((reaction as Dictionary).get("recoil_px", -1.0))
		var flash: float = float((reaction as Dictionary).get("flash_strength", -1.0))
		if not is_finite(recoil) or recoil < 0.0 or recoil > 100.0:
			_add(issues, path, entry_id, "hit_reaction.recoil_px", "out of range")
		if not is_finite(flash) or flash < 0.0 or flash > 1.0:
			_add(issues, path, entry_id, "hit_reaction.flash_strength", "out of range")


static func _validate_distinct_sets(issues: Array[Dictionary], dataset: Dictionary, catalogs: Dictionary) -> void:
	var enemy_path: String = str((dataset.get("enemies", {}) as Dictionary).get("file", "enemies"))
	var enemy_catalog: Dictionary = catalogs.get("enemies", {})
	for world_value: Variant in (catalogs.get("worlds", {}) as Dictionary).values():
		var world: Dictionary = world_value as Dictionary
		var ids: Array = world.get("enemy_pool", [])
		if ids.size() != 4:
			_add(issues, enemy_path, str(world.get("id", "")), "enemy_pool", "exactly four enemies are required per world")
		var palettes: Dictionary = {}
		var silhouettes: Dictionary = {}
		for id_value: Variant in ids:
			var enemy: Dictionary = enemy_catalog.get(str(id_value), {})
			if enemy.is_empty():
				continue
			var palette_key: String = JSON.stringify(enemy.get("palette", {}))
			var silhouette: String = str(enemy.get("silhouette", ""))
			if palettes.has(palette_key):
				_add(issues, enemy_path, str(id_value), "palette", "enemy palette must be distinct within its world")
			if silhouettes.has(silhouette):
				_add(issues, enemy_path, str(id_value), "silhouette", "enemy silhouette must be distinct within its world")
			palettes[palette_key] = true
			silhouettes[silhouette] = true
	_validate_boss_identity_sets(issues, dataset)


static func _validate_boss_identity_sets(issues: Array[Dictionary], dataset: Dictionary) -> void:
	var path: String = str((dataset.get("bosses", {}) as Dictionary).get("file", "bosses"))
	var palettes: Dictionary = {}
	var silhouettes: Dictionary = {}
	for value: Variant in (dataset.get("bosses", {}) as Dictionary).get("entries", []):
		if not value is Dictionary:
			continue
		var boss: Dictionary = value as Dictionary
		var palette_key: String = JSON.stringify(boss.get("palette", {}))
		var silhouette: String = str(boss.get("silhouette", ""))
		if palettes.has(palette_key):
			_add(issues, path, str(boss.get("id", "")), "palette", "boss palette must be distinct")
		if silhouettes.has(silhouette):
			_add(issues, path, str(boss.get("id", "")), "silhouette", "boss silhouette must be distinct")
		palettes[palette_key] = true
		silhouettes[silhouette] = true


static func _validate_assignments(issues: Array[Dictionary], dataset: Dictionary, catalogs: Dictionary) -> void:
	var path: String = str((dataset.get("bosses", {}) as Dictionary).get("file", "bosses"))
	var bosses: Array = (dataset.get("bosses", {}) as Dictionary).get("entries", [])
	if bosses.size() != 4:
		_add(issues, path, "<file>", "entries", "exactly four boss archetypes are required")
	for stage: int in range(10, 101, 10):
		var encounter: String = "stage_%d" % stage
		if bosses.is_empty():
			_add(issues, path, encounter, "boss_id", "boss stage has no archetype")
			continue
		var value: Variant = bosses[BossPoolLogic.archetype_index(stage, bosses.size())]
		if not value is Dictionary:
			_add(issues, path, encounter, "boss_id", "boss stage has no archetype")
			continue
		var boss: Dictionary = value as Dictionary
		var world: Dictionary = _world_for_stage(catalogs.get("worlds", {}), stage)
		if world.is_empty():
			_add(issues, path, encounter, "stage", "boss stage disagrees with world ranges")
			continue
		if str(boss.get("id", "")) not in world.get("boss_ids", []):
			_add(issues, path, encounter, "boss_id", "boss archetype is not assigned to active world")
		var boss_world: String = str(boss.get("world_id", ""))
		if boss_world != "milestone" and boss_world != str(world.get("id", "")):
			_add(issues, path, encounter, "world_id", "boss stage is outside its world")


static func _world_for_stage(worlds: Dictionary, stage: int) -> Dictionary:
	for value: Variant in worlds.values():
		var world: Dictionary = value as Dictionary
		if stage >= int(world.get("stage_from", 0)) and stage <= int(world.get("stage_to", 0)):
			return world
	return {}


static func _add(issues: Array[Dictionary], path: String, id: String, field: String, reason: String) -> void:
	issues.append({"path": path, "id": id, "field": field, "reason": reason})
