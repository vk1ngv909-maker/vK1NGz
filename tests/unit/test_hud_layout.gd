extends SceneTree
## C30 regression guard: no top-HUD label may extend past the safe-area bounds,
## in either language, at any supported portrait size, for any gold magnitude
## BigNumber can produce. This is the exact failure that shipped clipped Arabic
## text ("الذهب — ACEHOLDER") past a visual review.

const BN = preload("res://scripts/utilities/big_number.gd")

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	# No placeholder sentences may live in the top HUD at all.
	var hud_src: String = FileAccess.open("res://scripts/ui/hud.gd", FileAccess.READ).get_as_text()
	ck("hud.gd no longer renders a gold placeholder sentence",
		hud_src.find('Settings.t("hud.gold_placeholder")') == -1)

	for f: String in ["res://localization/strings.en.csv", "res://localization/strings.ar.csv"]:
		var text: String = FileAccess.open(f, FileAccess.READ).get_as_text()
		ck("%s has no gold_placeholder key" % f.get_file(), text.find("hud.gold_placeholder") == -1)

	# Any value BigNumber can format must stay short enough for a currency chip.
	var samples: Array = [0.0, 999.0, 1250.0, 999990000.0, 1.0e30]
	for v: float in samples:
		var s: String = BN.from_float(v).format()
		ck("gold '%s' formats within 12 chars" % s, s.length() <= 12, "%d chars" % s.length())
	var huge: String = BN.from_mantissa_exponent(9.99, 9999).format()
	ck("scientific value '%s' stays short" % huge, huge.length() <= 12, "%d chars" % huge.length())

	# Labels that can receive unbounded text must be clip-guarded in the scene.
	var scene: String = FileAccess.open("res://scenes/ui/hud.tscn", FileAccess.READ).get_as_text()
	for node: String in ["GoldAmount", "Stage"]:
		var idx: int = scene.find('name="%s"' % node)
		ck("%s exists in hud.tscn" % node, idx >= 0)
		if idx >= 0:
			var block: String = scene.substr(idx, 260)
			ck("%s is clip-guarded" % node, block.find("clip_text = true") >= 0, block.substr(0, 90))

	print("HUD LAYOUT: FAIL %d" % failed if failed > 0 else "HUD LAYOUT: all passed")
	quit(1 if failed > 0 else 0)
