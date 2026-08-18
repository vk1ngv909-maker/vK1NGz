extends SceneTree

const SettingsLogic = preload("res://autoload/settings.gd")
const PrestigeLogic = preload("res://scripts/progression/prestige.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	var settings: Node = SettingsLogic.new()
	var save_manager: Node = preload("res://autoload/save_manager.gd").new()
	save_manager.name = "SaveManager"
	root.add_child(save_manager)
	settings.name = "TestSettings"
	root.add_child(settings)
	settings.save_manager_override = save_manager
	settings.ensure_audio_buses()
	var clean: Dictionary = settings.sanitize({
		"master_volume": 5.0,
		"music_volume": -4.0,
		"sfx_volume": NAN,
		"ui_volume": "loud",
		"vibration": "false",
		"reduced_flash": true,
	})
	_check(clean["master_volume"] == 1.0, "out-of-range volume clamps to one")
	_check(clean["music_volume"] == 0.0, "negative volume clamps to zero")
	_check(clean["sfx_volume"] == 0.8 and clean["ui_volume"] == 0.8, "NaN and wrong types use safe defaults")
	_check(clean["vibration"] == true and clean["reduced_flash"] == true, "wrong bool defaults while valid bool loads")

	settings.load_values({"master_volume": 0.5, "music_volume": 0.0})
	var master: int = AudioServer.get_bus_index("Master")
	var music: int = AudioServer.get_bus_index("Music")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(master), linear_to_db(0.5)), "AudioServer master dB changes")
	_check(AudioServer.is_bus_mute(music), "zero volume really mutes")
	settings.set_value("music_volume", 0.4, false)
	_check(not AudioServer.is_bus_mute(music), "raising volume unmutes immediately")

	save_manager.data = save_manager.default_data()
	settings.load_values({"master_volume": 0.37, "vibration": false}, true)
	var reloaded: Dictionary = save_manager.load()
	_check(is_equal_approx(float(reloaded["permanent_state"]["settings"]["master_volume"]), 0.37), "settings survive save/reload: %s" % str(reloaded["permanent_state"]["settings"]))
	(reloaded["permanent_state"] as Dictionary)["max_stage"] = 25
	var prestiged: Dictionary = PrestigeLogic.new().apply(reloaded)
	_check(is_equal_approx(float(prestiged["permanent_state"]["settings"]["master_volume"]), 0.37), "settings survive prestige: %s" % str(prestiged["permanent_state"]["settings"]))
	var before: int = int(settings.vibration_dispatch_count)
	_check(not settings.vibrate() and int(settings.vibration_dispatch_count) == before, "vibration off gates dispatch")
	settings.set_value("vibration", true, false)
	_check(settings.vibrate(1, 0.1) and int(settings.vibration_dispatch_count) == before + 1, "vibration on dispatches once")
	settings.free()
	save_manager.free()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
