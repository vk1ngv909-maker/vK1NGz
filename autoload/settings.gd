extends Node

signal changed(values: Dictionary)
signal vibration_dispatched(duration_ms: int, amplitude: float)

const DEFAULTS: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"ui_volume": 0.8,
	"vibration": true,
	"reduced_flash": false,
	"damage_numbers": true,
	"language": "en",
}
const VOLUME_BUSES: Dictionary = {
	"master_volume": "Master",
	"music_volume": "Music",
	"sfx_volume": "SFX",
	"ui_volume": "UI",
}

var values: Dictionary = DEFAULTS.duplicate(true)
var vibration_dispatch_count: int = 0
var save_manager_override: Node


func _ready() -> void:
	ensure_audio_buses()
	var manager: Node = _save_manager()
	var permanent_state: Dictionary = manager.get("data").get("permanent_state", {}) if manager != null else {}
	load_values(permanent_state.get("settings", {}), false)


func ensure_audio_buses() -> void:
	for bus_name: String in ["Master", "Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func load_values(raw: Variant, persist_sanitized: bool = false) -> Dictionary:
	values = sanitize(raw)
	apply()
	if persist_sanitized:
		_persist()
	changed.emit(values.duplicate(true))
	return values.duplicate(true)


func set_value(key: String, value: Variant, persist: bool = true) -> void:
	var candidate: Dictionary = values.duplicate(true)
	candidate[key] = value
	values = sanitize(candidate)
	apply()
	if persist:
		_persist()
	changed.emit(values.duplicate(true))


func reset_tutorial() -> void:
	var manager: Node = _save_manager()
	if manager == null:
		return
	if (manager.get("data") as Dictionary).is_empty():
		manager.set("data", manager.call("default_data"))
	var save_data: Dictionary = (manager.get("data") as Dictionary).duplicate(true)
	(save_data["permanent_state"] as Dictionary)["tutorial"] = {
		"completed": false,
		"current_step": 0,
	}
	manager.call("save", save_data)
	for tutorial: Node in get_tree().get_nodes_in_group("tutorial"):
		if tutorial.has_method("reset"):
			tutorial.call("reset")


func apply() -> void:
	ensure_audio_buses()
	for key: String in VOLUME_BUSES:
		var bus_name: String = str(VOLUME_BUSES[key])
		var index: int = AudioServer.get_bus_index(bus_name)
		var linear: float = float(values[key])
		AudioServer.set_bus_mute(index, linear <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	TranslationServer.set_locale(str(values["language"]))
	if is_inside_tree():
		for arena: Node in get_tree().get_nodes_in_group("combat_arena"):
			if arena.has_method("apply_accessibility_settings"):
				arena.call("apply_accessibility_settings", values)


func vibrate(duration_ms: int = 40, amplitude: float = -1.0) -> bool:
	if not bool(values.get("vibration", true)):
		return false
	vibration_dispatch_count += 1
	vibration_dispatched.emit(maxi(0, duration_ms), clampf(amplitude, -1.0, 1.0))
	Input.vibrate_handheld(maxi(0, duration_ms), clampf(amplitude, -1.0, 1.0))
	return true


func sanitize(raw: Variant) -> Dictionary:
	var clean: Dictionary = DEFAULTS.duplicate(true)
	if not raw is Dictionary:
		return clean
	var source: Dictionary = raw as Dictionary
	var legacy_percent: bool = true
	for volume_key: String in VOLUME_BUSES:
		var legacy_value: Variant = source.get(volume_key)
		if not (legacy_value is int or legacy_value is float) or not is_finite(float(legacy_value)):
			legacy_percent = false
			break
	legacy_percent = legacy_percent and (
		float(source.get("master_volume", 0.0)) > 1.0
		or float(source.get("music_volume", 0.0)) > 1.0
		or float(source.get("sfx_volume", 0.0)) > 1.0
		or float(source.get("ui_volume", 0.0)) > 1.0
	)
	for key: String in VOLUME_BUSES:
		var candidate: Variant = source.get(key, DEFAULTS[key])
		if candidate is int or candidate is float:
			var numeric: float = float(candidate)
			if is_finite(numeric):
				if legacy_percent:
					numeric /= 100.0
				clean[key] = clampf(numeric, 0.0, 1.0)
	for key: String in ["vibration", "damage_numbers"]:
		var candidate: Variant = source.get(key, DEFAULTS[key])
		if candidate is bool:
			clean[key] = candidate
	var reduced: Variant = source.get("reduced_flash", source.get("reduced_flashing", DEFAULTS["reduced_flash"]))
	if reduced is bool:
		clean["reduced_flash"] = reduced
	var locale: Variant = source.get("language", DEFAULTS["language"])
	if locale is String and str(locale) in ["en", "ar"]:
		clean["language"] = str(locale)
	return clean


func _persist() -> void:
	var manager: Node = _save_manager()
	if manager == null:
		return
	if (manager.get("data") as Dictionary).is_empty():
		manager.set("data", manager.call("default_data"))
	var save_data: Dictionary = (manager.get("data") as Dictionary).duplicate(true)
	(save_data["permanent_state"] as Dictionary)["settings"] = values.duplicate(true)
	manager.call("save", save_data)


func _save_manager() -> Node:
	if is_instance_valid(save_manager_override):
		return save_manager_override
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("SaveManager")
	return null
