extends SceneTree
## Independent adversarial suite for offline rewards. The whole risk here is a
## player collecting the same absence twice, or a manipulated clock minting gold.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func fresh(last_seen: int, claimed: int = 0):
	var SMS = load("res://autoload/save_manager.gd")
	var sm = SMS.new()
	get_root().add_child(sm)
	var d: Dictionary = sm.default_data()
	d["permanent_state"]["last_seen_utc"] = last_seen
	d["permanent_state"]["offline_claimed_utc"] = claimed
	sm.save(d)
	sm.load()
	return sm

func _init() -> void:
	const CAP: int = 28800   # 8 hours
	var base: int = 1_700_000_000

	# ---- normal return, under the cap ----
	var a = fresh(base)
	var r = a.claim_offline(base + 3600)
	ck("1h away is granted", r["granted"] == true, str(r))
	ck("1h away reports ~3600s", int(r["seconds"]) == 3600, str(r["seconds"]))

	# ---- collect exactly once ----
	var again = a.claim_offline(base + 3600)
	ck("second collect refused", again["granted"] == false, str(again))
	var spam_granted: int = 0
	for i in range(50):
		if a.claim_offline(base + 3600)["granted"]: spam_granted += 1
	ck("rapid collect grants nothing extra", spam_granted == 0, str(spam_granted))

	# ---- beyond the cap ----
	var b = fresh(base)
	var rb = b.claim_offline(base + 999999)
	ck("beyond 8h is capped", int(rb["seconds"]) == CAP, str(rb["seconds"]))
	ck("capped return still granted", rb["granted"] == true)

	# ---- clock moved backward ----
	var c = fresh(base)
	var rc = c.claim_offline(base - 50000)
	ck("backward clock grants nothing", rc["granted"] == false and int(rc["seconds"]) == 0, str(rc))
	ck("backward clock did not consume the claim", c.claim_offline(base + 600)["granted"] == true,
		"a legitimate later return must still work")

	# ---- exactly zero elapsed ----
	var d0 = fresh(base)
	var rz = d0.claim_offline(base)
	ck("zero elapsed grants nothing", rz["granted"] == false or int(rz["seconds"]) == 0, str(rz))

	# ---- absurd future timestamp ----
	var e = fresh(base)
	var re = e.claim_offline(9_223_372_036)
	ck("far-future clamped to cap", int(re["seconds"]) <= CAP, str(re["seconds"]))

	# ---- missing / invalid stored timestamp ----
	var SMS = load("res://autoload/save_manager.gd")
	var f = SMS.new(); get_root().add_child(f)
	var bad: Dictionary = f.default_data()
	bad["permanent_state"].erase("last_seen_utc")
	f.save(bad); f.load()
	var rf = f.claim_offline(base + 3600)
	ck("missing timestamp does not mint gold", int(rf["seconds"]) <= CAP and int(rf["seconds"]) >= 0, str(rf))

	var g = SMS.new(); get_root().add_child(g)
	var bad2: Dictionary = g.default_data()
	bad2["permanent_state"]["last_seen_utc"] = -999999
	g.save(bad2); g.load()
	var rg = g.claim_offline(base)
	ck("negative stored timestamp clamped", int(rg["seconds"]) <= CAP and int(rg["seconds"]) >= 0, str(rg))

	# ---- claim survives reload: cannot re-collect after reopening ----
	var h = fresh(base)
	h.claim_offline(base + 7200)
	var SMS2 = load("res://autoload/save_manager.gd")
	var h2 = SMS2.new(); get_root().add_child(h2)
	h2.load()
	ck("cannot re-collect the same absence after reload",
		h2.claim_offline(base + 7200)["granted"] == false, "reload must not reset the guard")

	print("OFFLINE ADVERSARIAL: FAIL %d" % failed if failed > 0 else "OFFLINE ADVERSARIAL: all passed")
	quit(1 if failed > 0 else 0)
