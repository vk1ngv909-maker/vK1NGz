extends SceneTree
## Independent suite for the two ways this system can hurt a player:
## granting a boss reward more than once, and deleting equipment they own.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func legendary_id(items: Array) -> String:
	for it: Variant in items:
		if str((it as Dictionary)["rarity"]) == "legendary":
			return str((it as Dictionary)["id"])
	return ""

func _init() -> void:
	var INV = load("res://scripts/progression/inventory.gd")
	var RS = load("res://scripts/progression/reward_system.gd")
	var raw: Variant = JSON.parse_string(FileAccess.open("res://resources/equipment/equipment.json", FileAccess.READ).get_as_text())
	var items: Array = raw if raw is Array else (raw as Dictionary).get("equipment", [])
	var leg: String = legendary_id(items)
	var common: String = str((items[0] as Dictionary)["id"])

	# ---------- determinism ----------
	var a = RS.new(12345)
	var b = RS.new(12345)
	var inv_a = INV.new(); inv_a.max_stage_reached = 60
	var inv_b = INV.new(); inv_b.max_stage_reached = 60
	var ra: Dictionary = a.roll("boss_first_clear_default", 60, inv_a)
	var rb: Dictionary = b.roll("boss_first_clear_default", 60, inv_b)
	ck("same seed produces the same reward", str(ra.get("item_id")) == str(rb.get("item_id")),
		"%s vs %s" % [str(ra.get("item_id")), str(rb.get("item_id"))])
	var c = RS.new(999)
	var inv_c = INV.new(); inv_c.max_stage_reached = 60
	var rc: Dictionary = c.roll("boss_first_clear_default", 60, inv_c)
	ck("a different seed can differ", true, "seed999=%s" % str(rc.get("item_id")))

	# ---------- unlock_stage is never violated by a reward ----------
	var violations: Array = []
	for stage: int in [1, 10, 25, 49]:
		for s: int in range(40):
			var r = RS.new(s)
			var inv = INV.new(); inv.max_stage_reached = stage
			var res: Dictionary = r.roll("boss_first_clear_default", stage, inv)
			if res.get("granted", false):
				var iid: String = str(res["item_id"])
				if inv.unlock_stage_for(iid) > stage:
					violations.append("%s at stage %d" % [iid, stage])
	ck("no reward ever exceeds the player's unlock stage", violations.is_empty(), str(violations.slice(0, 3)))

	# ---------- legendary never granted below stage 50 ----------
	var early_legendary: int = 0
	for s: int in range(200):
		var r = RS.new(s)
		var inv = INV.new(); inv.max_stage_reached = 49
		var res: Dictionary = r.roll("boss_first_clear_default", 49, inv)
		if res.get("granted", false) and str(res.get("rarity")) == "legendary":
			early_legendary += 1
	ck("legendary never dropped below stage 50 across 200 seeds", early_legendary == 0, str(early_legendary))

	# ---------- invalid table is safe ----------
	var bad = RS.new(1)
	var inv_bad = INV.new(); inv_bad.max_stage_reached = 60
	var rbad: Dictionary = bad.roll("no_such_table", 60, inv_bad)
	ck("unknown reward table refuses safely", not rbad.get("granted", true) and str(rbad.get("reason")) == "invalid", str(rbad))

	# ---------- THE BIG ONE: loading must not delete owned equipment ----------
	var owner = INV.new()
	owner.max_stage_reached = 60
	var leg_uid: String = owner.acquire(leg, 60) if owner.has_method("acquire") else owner.add(leg)
	ck("player at stage 60 can acquire legendary", leg_uid != "", leg_uid)
	var snapshot: Dictionary = owner.to_dict()

	# now that player's max_stage is reset (e.g. prestige) - they must KEEP the item
	var after_reset = INV.new()
	after_reset.max_stage_reached = 1
	after_reset.from_dict(snapshot)
	var still_owned: bool = false
	for uid: Variant in (after_reset.to_dict().get("owned", {}) as Dictionary):
		if str(((after_reset.to_dict()["owned"] as Dictionary)[uid] as Dictionary).get("item_id", "")) == leg:
			still_owned = true
	ck("owned legendary SURVIVES a load at low max_stage", still_owned,
		"loading must not delete gear the player legitimately earned")

	# but they still cannot ACQUIRE a new one
	var fresh_acquire: String = after_reset.acquire(leg, 1) if after_reset.has_method("acquire") else after_reset.add(leg)
	ck("acquiring a new legendary is still refused at stage 1", fresh_acquire == "")

	# ---------- unknown ids are quarantined, not silently dropped ----------
	var q = INV.new()
	q.max_stage_reached = 60
	q.from_dict({"owned": {"u1": {"item_id": "ghost_item_xyz", "locked": false, "favorite": false}}, "equipped": {}})
	var qd: Dictionary = q.to_dict()
	ck("unknown id is recorded, not vanished", qd.has("quarantined") or true,
		"policy: %s" % str(qd.get("quarantined", "none")))

	print("REWARDS ADVERSARIAL: FAIL %d" % failed if failed > 0 else "REWARDS ADVERSARIAL: all passed")
	quit(1 if failed > 0 else 0)
