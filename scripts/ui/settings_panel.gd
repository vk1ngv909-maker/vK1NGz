class_name SettingsPanel
extends Control

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
	%ResetTutorial.pressed.connect(_on_reset_tutorial)
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
	Settings.set_value("language", "ar" if code == "ar" else "en")
	_load_values()
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
	%ResetTutorial.text = tr("ui.settings.reset_tutorial")
	_build_language_options()


func _load_values() -> void:
	var permanent_state: Dictionary = SaveManager.data.get("permanent_state", {})
	var current: Dictionary = Settings.load_values(permanent_state.get("settings", {}), true)
	_loading = true
	master_slider.value = float(current["master_volume"])
	music_slider.value = float(current["music_volume"])
	sfx_slider.value = float(current["sfx_volume"])
	ui_slider.value = float(current["ui_volume"])
	vibration.button_pressed = bool(current["vibration"])
	reduced_flashing.button_pressed = bool(current["reduced_flash"])
	damage_numbers.button_pressed = bool(current["damage_numbers"])
	_select_language(str(current["language"]))
	_loading = false
	refresh_localized_text()


func _on_setting_changed() -> void:
	if _loading:
		return
	Settings.load_values({
		"master_volume": master_slider.value,
		"music_volume": music_slider.value,
		"sfx_volume": sfx_slider.value,
		"ui_volume": ui_slider.value,
		"vibration": vibration.button_pressed,
		"reduced_flash": reduced_flashing.button_pressed,
		"damage_numbers": damage_numbers.button_pressed,
		"language": str(language.get_item_metadata(language.selected)) if language.selected >= 0 else "en",
	}, true)


func _on_language_selected(index: int) -> void:
	if _loading:
		return
	Settings.set_value("language", str(language.get_item_metadata(index)))
	_refresh_all_localized_ui()


func _on_reset_tutorial() -> void:
	Settings.reset_tutorial()


func _build_language_options() -> void:
	var current: String = str(Settings.values.get("language", "en"))
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
	for group_name: String in ["hud", "settings_panel", "inventory_panel", "offline_rewards_dialog", "tutorial"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if node.has_method("refresh_localized_text"):
				node.call("refresh_localized_text")
