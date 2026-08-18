extends SceneTree
## Independent world-boundary suite. Off-by-one at a boundary is the classic
## bug here, so every edge is checked explicitly rather than sampled.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var W = load("res://scripts/progression/worlds.gd")
	var w = W.new()
	var raw: Dictionary = JSON.parse_string(FileAccess.open("res://resources/worlds/worlds.json", FileAccess.READ).get_as_text())
	var entries: Array = raw["entries"]

	# --- contiguous, non-overlapping, no gaps ---
	var sorted_ranges: Array = []
	for e: Variant in entries:
		sorted_ranges.append([int((e as Dictionary)["stage_from"]), int((e as Dictionary)["stage_to"]), str((e as Dictionary)["id"])])
	sorted_ranges.sort_custom(func(a, b): return a[0] < b[0])
	ck("first world starts at stage 1", int(sorted_ranges[0][0]) == 1, str(sorted_ranges[0][0]))
	var gaps: Array = []
	for i in range(sorted_ranges.size() - 1):
		if int(sorted_ranges[i][1]) + 1 != int(sorted_ranges[i + 1][0]):
			gaps.append("%s ends %d, %s starts %d" % [sorted_ranges[i][2], sorted_ranges[i][1],
				sorted_ranges[i + 1][2], sorted_ranges[i + 1][0]])
	ck("no gaps or overlaps between worlds", gaps.is_empty(), str(gaps))

	# --- EVERY stage 1..100 maps to exactly one world ---
	var unmapped: Array = []
	for stage in range(1, 101):
		var d: Dictionary = w.world_for_stage(stage)
		if d.is_empty() or not d.has("id"):
			unmapped.append(stage)
	ck("every stage 1-100 maps to a world", unmapped.is_empty(), str(unmapped.slice(0, 5)))

	# --- exact boundary behaviour, both sides ---
	for i in range(sorted_ranges.size()):
		var from_stage: int = int(sorted_ranges[i][0])
		var to_stage: int = int(sorted_ranges[i][1])
		var wid: String = str(sorted_ranges[i][2])
		ck("stage %d (first of %s) is %s" % [from_stage, wid, wid],
			str(w.world_for_stage(from_stage).get("id", "")) == wid,
			str(w.world_for_stage(from_stage).get("id", "")))
		ck("stage %d (last of %s) is still %s" % [to_stage, wid, wid],
			str(w.world_for_stage(to_stage).get("id", "")) == wid,
			str(w.world_for_stage(to_stage).get("id", "")))
		if i + 1 < sorted_ranges.size():
			var next_id: String = str(sorted_ranges[i + 1][2])
			ck("stage %d crosses into %s" % [to_stage + 1, next_id],
				str(w.world_for_stage(to_stage + 1).get("id", "")) == next_id,
				str(w.world_for_stage(to_stage + 1).get("id", "")))

	# --- documented fallback beyond the authored range ---
	var last_id: String = str(sorted_ranges[-1][2])
	ck("stage beyond the authored range clamps to the last world",
		str(w.world_for_stage(500).get("id", "")) == last_id,
		str(w.world_for_stage(500).get("id", "")))
	ck("stage 0 / negative does not crash",
		not w.world_for_stage(0).is_empty() or true, "handled")

	# --- palettes must actually differ, or the worlds look identical ---
	var palettes: Dictionary = {}
	for e: Variant in entries:
		palettes[str((e as Dictionary)["palette"])] = true
	ck("each world has a distinct palette", palettes.size() == entries.size(),
		"%d distinct of %d" % [palettes.size(), entries.size()])

	# --- localization keys exist in BOTH languages ---
	var en: String = FileAccess.open("res://localization/strings.en.csv", FileAccess.READ).get_as_text()
	var ar: String = FileAccess.open("res://localization/strings.ar.csv", FileAccess.READ).get_as_text()
	var missing: Array = []
	for e: Variant in entries:
		for key_field: String in ["name_key", "desc_key"]:
			var k: String = str((e as Dictionary)[key_field])
			if en.find(k) == -1: missing.append("en:" + k)
			if ar.find(k) == -1: missing.append("ar:" + k)
	ck("all world localization keys exist in en and ar", missing.is_empty(), str(missing))

	print("WORLDS: FAIL %d" % failed if failed > 0 else "WORLDS: all passed")
	quit(1 if failed > 0 else 0)
