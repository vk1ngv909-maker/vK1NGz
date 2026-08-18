class_name SettingsPanel
extends Control

const DEFAULTS: Dictionary = {
	"master_volume": 100.0,
	"music_volume": 80.0,
	"sfx_volume": 80.0,
	"ui_volume": 80.0,
	"vibration": true,
	"reduced_flashing": false,
	"damage_numbers": true,
	"language": "en",
}

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var ui_slider: HSlider = %UiSlider
@onready var vibration: CheckButton = %Vibration
@onready var reduced_flashing: CheckButton = %ReducedFlashing
@onready var damage_numbers: CheckButton = %DamageNumbers
@onready var language: OptionButton = %Language

var _loading: bool = false


func _ready() -> void:
	add_to_group("settings_panel")
	%Close.pressed.connect(hide)
	for slider: HSlider in [master_slider, music_slider, sfx_slider, ui_slider]:
		slider.value_changed.connect(_on_setting_changed.unbind(1))
	for toggle: CheckButton in [vibration, reduced_flashing, damage_numbers]:
		toggle.toggled.connect(_on_setting_changed.unbind(1))
	language.item_selected.connect(_on_language_selected)
	_build_language_options()


func open_panel() -> void:
	_load_values()
	visible = true
	%Close.grab_focus()


func debug_set_language(code: String) -> void:
	var normalized: String = "ar" if code == "ar" else "en"
	TranslationServer.set_locale(normalized)
	_select_language(normalized)
	_save_values()
	_refresh_all_localized_ui()


func refresh_localized_text() -> void:
	%Title.text = tr("ui.settings.title")
	%Close.text = tr("ui.close")
	%MasterLabel.text = tr("ui.settings.master")
	%MusicLabel.text = tr("ui.settings.music")
	%SfxLabel.text = tr("ui.settings.sfx")
	%UiVolumeLabel.text = tr("ui.settings.ui_volume")
	vibration.text = tr("ui.settings.vibration")
	reduced_flashing.text = tr("ui.settings.reduced_flashing")
	damage_numbers.text = tr("ui.settings.damage_numbers")
	%LanguageLabel.text = tr("ui.settings.language")
	_build_language_options()


func _load_values() -> void:
	var state: Dictionary = SaveManager.data
	if state.is_empty():
		state = SaveManager.load()
	var settings: Dictionary = DEFAULTS.duplicate(true)
	settings.merge((state["permanent_state"] as Dictionary).get("settings", {}), true)
	_loading = true
	master_slider.value = float(settings["master_volume"])
	music_slider.value = float(settings["music_volume"])
	sfx_slider.value = float(settings["sfx_volume"])
	ui_slider.value = float(settings["ui_volume"])
	vibration.button_pressed = bool(settings["vibration"])
	reduced_flashing.button_pressed = bool(settings["reduced_flashing"])
	damage_numbers.button_pressed = bool(settings["damage_numbers"])
	TranslationServer.set_locale(str(settings["language"]))
	_select_language(str(settings["language"]))
	_loading = false
	_apply_runtime(settings)
	refresh_localized_text()


func _on_setting_changed() -> void:
	if not _loading:
		_save_values()


func _on_language_selected(index: int) -> void:
	if _loading:
		return
	var code: String = str(language.get_item_metadata(index))
	TranslationServer.set_locale(code)
	_save_values()
	_refresh_all_localized_ui()


func _save_values() -> void:
	if _loading or SaveManager.data.is_empty():
		return
	var settings: Dictionary = {
		"master_volume": master_slider.value,
		"music_volume": music_slider.value,
		"sfx_volume": sfx_slider.value,
		"ui_volume": ui_slider.value,
		"vibration": vibration.button_pressed,
		"reduced_flashing": reduced_flashing.button_pressed,
		"damage_numbers": damage_numbers.button_pressed,
		"language": str(language.get_item_metadata(language.selected)) if language.selected >= 0 else "en",
	}
	var save_data: Dictionary = SaveManager.data.duplicate(true)
	(save_data["permanent_state"] as Dictionary)["settings"] = settings
	SaveManager.save(save_data)
	_apply_runtime(settings)


func _apply_runtime(settings: Dictionary) -> void:
	_set_bus_volume("Master", float(settings["master_volume"]))
	_set_bus_volume("Music", float(settings["music_volume"]))
	_set_bus_volume("SFX", float(settings["sfx_volume"]))
	_set_bus_volume("UI", float(settings["ui_volume"]))
	for arena: Node in get_tree().get_nodes_in_group("combat_arena"):
		if arena.has_method("apply_accessibility_settings"):
			arena.call("apply_accessibility_settings", settings)


func _set_bus_volume(bus_name: String, percent: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(percent / 100.0, 0.0001, 1.0)))


func _build_language_options() -> void:
	var current: String = "en"
	if language.selected >= 0 and language.item_count > 0:
		current = str(language.get_item_metadata(language.selected))
	language.clear()
	language.add_item(tr("ui.language.en"))
	language.set_item_metadata(0, "en")
	language.add_item(tr("ui.language.ar"))
	language.set_item_metadata(1, "ar")
	_select_language(current)


func _select_language(code: String) -> void:
	for index: int in language.item_count:
		if str(language.get_item_metadata(index)) == code:
			language.select(index)
			return


func _refresh_all_localized_ui() -> void:
	for group_name: String in ["hud", "settings_panel", "inventory_panel", "offline_rewards_dialog"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if node.has_method("refresh_localized_text"):
				node.call("refresh_localized_text")
