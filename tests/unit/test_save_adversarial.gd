extends SceneTree
## Independent adversarial suite for SaveManager. Written from the spec, not
## from the implementation, so it stays honest if internals are rewritten.

var failed: int = 0
var SM

func ck(label: String, cond: bool, got: String = "") -> void:
	if cond: print("  ok   ", label)
	else:
		failed += 1
		print("  FAIL ", label, "  got=", got)

func wipe() -> void:
	for p in ["user://save.json", "user://save.backup.json", "user://save.tmp.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text); f.close()

func _init() -> void:
	SM = load("res://autoload/save_manager.gd").new()
	get_root().add_child(SM)

	# 1. round trip
	wipe()
	var d = SM.default_data(); d["run_state"]["stage"] = 7
	ck("save returns true", SM.save(d) == true)
	ck("primary exists", FileAccess.file_exists("user://save.json"))
	ck("reload keeps stage", SM.load()["run_state"]["stage"] == 7, str(SM.load()["run_state"]["stage"]))

	# 2. corrupted primary -> recovers from backup AND repairs primary
	SM.save(d)                      # creates backup from previous primary
	write_raw("user://save.json", "{ this is not json ")
	var rec = SM.load()
	ck("recovered from backup", SM.last_load_source == "backup", str(SM.last_load_source))
	ck("recovered data usable", rec.has("run_state"))
	var after := FileAccess.open("user://save.json", FileAccess.READ).get_as_text()
	ck("primary repaired after recovery", JSON.parse_string(after) != null)

	# 3. both corrupt -> defaults, never crash
	write_raw("user://save.json", "@@@")
	write_raw("user://save.backup.json", "@@@")
	var dd = SM.load()
	ck("falls back to defaults", SM.last_load_source == "default" and dd["run_state"]["stage"] == 1)

	# 4. malformed values rejected
	ck("negative gold rejected", SM.validate({"schema_version": 2, "gold": -5, "stage": 1}) == false)
	ck("stage 0 rejected", SM.validate({"schema_version": 2, "gold": {"mantissa":0.0,"exponent":0}, "stage": 0}) == false)
	ck("missing version rejected", SM.validate({"gold": {"mantissa":0.0,"exponent":0}, "stage": 1}) == false)
	ck("NAN rejected", SM.validate({"schema_version": 2, "gold": NAN, "stage": 1}) == false)

	# 5. v1 -> v2 migration fixture
	var v1 := {"schema_version": 1, "gold": 1234.0, "stage": 3}
	var m = SM.migrate(v1)
	ck("migrated through v2 to v3", m["schema_version"] == 3, str(m.get("schema_version")))
	ck("gold became BigNumber dict", typeof(m["run_state"]["gold"]) == TYPE_DICTIONARY, str(m["run_state"]["gold"]))

	# 6. offline: cap, rollback, and NO duplicate grant
	wipe()
	var od = SM.default_data()
	od["permanent_state"]["last_seen_utc"] = 1000
	od["permanent_state"]["offline_claimed_utc"] = 0
	SM.save(od)
	SM.load()
	var far: int = 1000 + 999999          # way beyond 8h
	var r1 = SM.claim_offline(far)
	ck("offline capped at 8h", r1["seconds"] <= 28800, str(r1["seconds"]))
	ck("first claim granted", r1["granted"] == true)
	var r2 = SM.claim_offline(far)
	ck("second claim NOT granted (no duplicate)", r2["granted"] == false, str(r2))
	var r3 = SM.claim_offline(500)        # clock rolled back
	ck("clock rollback grants nothing", r3["granted"] == false and r3["seconds"] == 0, str(r3))

	print("SAVE ADVERSARIAL: FAIL %d" % failed if failed > 0 else "SAVE ADVERSARIAL: all passed")
	quit(1 if failed > 0 else 0)
