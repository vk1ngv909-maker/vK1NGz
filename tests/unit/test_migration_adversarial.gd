extends SceneTree
## Independent migration check: a real v1 and a real v2 save on disk must reach
## v3 with every permanent value intact. Losing a player's relics or max stage
## during an upgrade is unrecoverable, so this is verified from actual files.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text); f.close()

func _init() -> void:
	var SMS = load("res://autoload/save_manager.gd")

	# ---- v2 flat save with real player investment ----
	var v2 := {
		"schema_version": 2,
		"gold": {"mantissa": 4.2, "exponent": 12},
		"stage": 87, "max_stage": 143, "tap_level": 55,
		"prestige_currency": 412,
		"relic_levels": {"seal_of_the_first_dune": 9, "merchants_astrolabe": 3},
		"equipment": ["falcon_charm_epic"],
		"achievements": ["first_prestige"],
		"settings": {"vibration": false, "reduced_flash": true},
		"statistics": {"total_taps": 88421},
		"last_seen_utc": 1700000000,
		"offline_claimed_utc": 1699999000
	}
	write_raw("user://save.json", JSON.stringify(v2))
	if FileAccess.file_exists("user://save.backup.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.backup.json"))

	var sm = SMS.new()
	get_root().add_child(sm)
	var m: Dictionary = sm.load()

	ck("migrated to v3", int(m.get("schema_version", 0)) == 3, str(m.get("schema_version")))
	ck("has run_state", m.has("run_state"))
	ck("has permanent_state", m.has("permanent_state"))

	var perm: Dictionary = m.get("permanent_state", {})
	ck("max_stage survived migration", int(perm.get("max_stage", 0)) == 143, str(perm.get("max_stage")))
	ck("prestige currency survived", int(perm.get("prestige_currency", 0)) == 412, str(perm.get("prestige_currency")))
	ck("relic levels survived", int((perm.get("relic_levels", {}) as Dictionary).get("seal_of_the_first_dune", 0)) == 9,
		str(perm.get("relic_levels")))
	ck("equipment survived", (perm.get("equipment", []) as Array).has("falcon_charm_epic"), str(perm.get("equipment")))
	ck("achievements survived", (perm.get("achievements", []) as Array).size() == 1)
	ck("settings survived", (perm.get("settings", {}) as Dictionary).get("reduced_flash") == true, str(perm.get("settings")))
	ck("statistics survived", int((perm.get("statistics", {}) as Dictionary).get("total_taps", 0)) == 88421)
	ck("offline guard survived", int(perm.get("offline_claimed_utc", 0)) == 1699999000)

	var run: Dictionary = m.get("run_state", {})
	ck("in-run stage carried over", int(run.get("stage", 0)) == 87, str(run.get("stage")))
	ck("tap level carried over", int(run.get("tap_level", 0)) == 55, str(run.get("tap_level")))

	# ---- v1 -> v3 chain ----
	write_raw("user://save.json", JSON.stringify({"schema_version": 1, "gold": 5000.0, "stage": 12}))
	if FileAccess.file_exists("user://save.backup.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.backup.json"))
	var sm2 = SMS.new()
	get_root().add_child(sm2)
	var m1: Dictionary = sm2.load()
	ck("v1 chains all the way to v3", int(m1.get("schema_version", 0)) == 3, str(m1.get("schema_version")))
	ck("v1 stage preserved through chain", int((m1.get("run_state", {}) as Dictionary).get("stage", 0)) == 12,
		str((m1.get("run_state", {}) as Dictionary).get("stage")))

	print("MIGRATION: FAIL %d" % failed if failed > 0 else "MIGRATION: all passed")
	quit(1 if failed > 0 else 0)
