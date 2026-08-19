extends SceneTree
## The Arabic health readout showed "صحة 8.5 / 0": the bidirectional algorithm
## reordered the two number runs, so the label announced the maximum as if it
## were the current value. Numbers a player reads to decide whether to keep
## tapping must never be reordered, so the pair is emitted inside a Unicode
## isolate. This pins that behaviour.

const SettingsLogic = preload("res://autoload/settings.gd")

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func visible_order(text: String) -> String:
	## The characters inside the isolate, in the order they were written.
	var start: int = text.find(SettingsLogic.LTR_ISOLATE)
	var stop: int = text.find(SettingsLogic.POP_ISOLATE)
	if start < 0 or stop < 0 or stop < start:
		return ""
	return text.substr(start + 1, stop - start - 1)


func _init() -> void:
	var BN = load("res://scripts/utilities/big_number.gd")
	# A bare SceneTree has no autoloads and no project translations, so the
	# compiled files are added here to exercise the real strings.
	for locale_file: String in ["res://localization/strings.en.en.translation",
			"res://localization/strings.ar.ar.translation"]:
		var translation: Translation = load(locale_file)
		if translation != null:
			TranslationServer.add_translation(translation)

	for locale: String in ["en", "ar"]:
		TranslationServer.set_locale(locale)
		var cases: Array = [
			["zero health", BN.from_float(0.0), BN.from_float(8.5)],
			["full health", BN.from_float(8.5), BN.from_float(8.5)],
			["decimals", BN.from_float(12.25), BN.from_float(40.75)],
			["big numbers", BN.from_mantissa_exponent(6.0166, 20), BN.from_mantissa_exponent(6.0166, 20)],
			["very big numbers", BN.from_mantissa_exponent(1.5, 300), BN.from_mantissa_exponent(9.9, 4000)],
		]
		for case_value: Variant in cases:
			var case: Array = case_value
			var label: String = str(case[0])
			var current: String = SettingsLogic.format_big_number(case[1])
			var maximum: String = SettingsLogic.format_big_number(case[2])
			var text: String = SettingsLogic.t("hud.enemy_hp") % SettingsLogic.format_pair(current, maximum)
			var inner: String = visible_order(text)
			ck("%s/%s: the pair is isolated" % [locale, label], not inner.is_empty(), text)
			ck("%s/%s: current comes before maximum" % [locale, label],
				inner == "%s / %s" % [current, maximum], inner)
			ck("%s/%s: exactly one isolate pair" % [locale, label],
				text.count(SettingsLogic.LTR_ISOLATE) == 1 and text.count(SettingsLogic.POP_ISOLATE) == 1, text)
			ck("%s/%s: the isolate closes after the numbers" % [locale, label],
				text.find(SettingsLogic.LTR_ISOLATE) < text.find(SettingsLogic.POP_ISOLATE), text)

	TranslationServer.set_locale("ar")
	var arabic: String = SettingsLogic.t("hud.enemy_hp") % SettingsLogic.format_pair("0", "8.5")
	ck("the Arabic label is worded as a health readout", arabic.begins_with("الصحة:"), arabic)
	ck("the Arabic label carries no stray latin word", not arabic.contains("HP"), arabic)
	TranslationServer.set_locale("en")
	var english: String = SettingsLogic.t("hud.enemy_hp") % SettingsLogic.format_pair("0", "8.5")
	ck("the English label still reads as before", english.ends_with("HP"), english)

	# The same call path serves regular enemies and bosses: the arena builds one
	# label from combat.enemy_hp / combat.enemy_max_hp regardless of encounter.
	var source: String = FileAccess.open("res://scripts/combat/combat_arena.gd", FileAccess.READ).get_as_text()
	ck("the arena composes the readout through the isolating helper",
		source.contains("Settings.format_pair("), "")
	ck("no caller formats the pair with two separate placeholders",
		not source.contains('Settings.t("hud.enemy_hp") % ['), "")

	print("RTL NUMERIC ISOLATION: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
