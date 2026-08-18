extends SceneTree
## Independent settings verification. Reads the REAL AudioServer bus state back
## rather than trusting a stored value, and re-checks it after a full reload.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func bus_db(name: String) -> float:
	var i: int = AudioServer.get_bus_index(name)
	return AudioServer.get_bus_volume_db(i) if i >= 0 else NAN

func bus_muted(name: String) -> bool:
	var i: int = AudioServer.get_bus_index(name)
	return AudioServer.is_bus_mute(i) if i >= 0 else false

func _init() -> void:
	var S = load("res://autoload/settings.gd")
	var SMS = load("res://autoload/save_manager.gd")
	var sm = SMS.new(); get_root().add_child(sm)
	var st = S.new(); get_root().add_child(st)

	st.ensure_audio_buses()
	for b: String in ["Master", "Music", "SFX", "UI"]:
		ck("bus %s exists" % b, AudioServer.get_bus_index(b) >= 0, str(AudioServer.get_bus_index(b)))

	# --- volume actually reaches the bus ---
	st.set_value("music_volume", 0.5); st.apply()
	var half: float = bus_db("Music")
	st.set_value("music_volume", 1.0); st.apply()
	var full: float = bus_db("Music")
	ck("music volume changes the real bus", full > half and is_finite(half), "half=%.2f full=%.2f" % [half, full])

	# --- 0 really mutes ---
	st.set_value("sfx_volume", 0.0); st.apply()
	ck("zero volume mutes the real SFX bus", bus_muted("SFX"), str(bus_muted("SFX")))
	st.set_value("sfx_volume", 0.8); st.apply()
	ck("raising volume unmutes", not bus_muted("SFX"))

	# --- invalid values clamped, not applied raw ---
	st.set_value("master_volume", 99.0); st.apply()
	ck("above-range volume clamped", is_finite(bus_db("Master")) and bus_db("Master") <= 6.0, str(bus_db("Master")))
	st.set_value("master_volume", -50.0); st.apply()
	ck("below-range volume clamped (muted, finite)", is_finite(bus_db("Master")) or bus_muted("Master"), str(bus_db("Master")))
	st.set_value("master_volume", NAN); st.apply()
	ck("NaN volume rejected", is_finite(bus_db("Master")), str(bus_db("Master")))

	# --- survives save + a FRESH manager (simulated restart) ---
	st.save_manager_override = sm
	st.set_value("music_volume", 0.25)
	st.set_value("vibration", false)
	st.set_value("reduced_flash", true)
	st.apply()
	var quiet: float = bus_db("Music")

	var sm2 = SMS.new(); get_root().add_child(sm2)
	var st2 = S.new(); get_root().add_child(st2)
	st2.save_manager_override = sm2
	var reloaded: Dictionary = sm2.load()
	st2.load_values((reloaded.get("permanent_state", {}) as Dictionary).get("settings", {}))
	st2.apply()
	ck("music volume restored to the same real bus level after reload",
		is_equal_approx(bus_db("Music"), quiet), "%.3f vs %.3f" % [bus_db("Music"), quiet])
	ck("vibration off survived reload", st2.values["vibration"] == false, str(st2.values["vibration"]))
	ck("reduced flash survived reload", st2.values["reduced_flash"] == true, str(st2.values["reduced_flash"]))

	# --- vibration gate: disabled must produce no request ---
	st2.set_value("vibration", false)
	var before_count: int = st2.vibration_dispatch_count
	ck("vibrate() is a no-op while disabled", st2.vibrate() == false)
	ck("no vibration request was dispatched", st2.vibration_dispatch_count == before_count, str(st2.vibration_dispatch_count))
	st2.set_value("vibration", true)
	ck("vibrate() issues a request while enabled", st2.vibrate() == true)
	ck("request counter advanced", st2.vibration_dispatch_count == before_count + 1)

	# --- survives prestige ---
	var P = load("res://scripts/progression/prestige.gd")
	var pr = P.new(sm2)
	var state: Dictionary = sm2.load()
	state["permanent_state"]["max_stage"] = 200
	var after: Dictionary = pr.apply(state.duplicate(true))
	var settings_after: Dictionary = (after.get("permanent_state", {}) as Dictionary).get("settings", {})
	ck("settings survive prestige", not settings_after.is_empty(), str(settings_after))

	print("SETTINGS ADVERSARIAL: FAIL %d" % failed if failed > 0 else "SETTINGS ADVERSARIAL: all passed")
	quit(1 if failed > 0 else 0)
