extends SceneTree
## Independent adversarial suite for destructive inventory actions.
## Salvage permanently destroys player property, so every refusal path and the
## exactly-once guarantee are verified here rather than trusted.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	print("START")
	var INV = load("res://scripts/progression/inventory.gd")

	# pick real ids out of the data file rather than inventing them
	var f := FileAccess.open("res://resources/equipment/equipment.json", FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text()); f.close()
	var items: Array = (raw if raw is Array else (raw as Dictionary).get("equipment", []))
	var by_rarity: Dictionary = {}
	for it: Variant in items:
		var d: Dictionary = it
		by_rarity[str(d.get("rarity"))] = str(d.get("id"))
	ck("data has common and a high rarity", by_rarity.has("common") and (by_rarity.has("rare") or by_rarity.has("epic")))

	var common_id: String = str(by_rarity.get("common", ""))
	var rare_id: String = str(by_rarity.get("rare", by_rarity.get("epic", "")))

	# ---------- salvage exactly once ----------
	var inv = INV.new()
	inv.max_stage_reached = 999
	var uid: String = inv.add(common_id)
	var r1: Dictionary = inv.salvage(uid)
	ck("common salvage succeeds without confirmation", r1.get("ok", false), str(r1))
	var gold1: float = float(r1.get("gold_awarded", 0.0))
	ck("salvage awarded gold", gold1 > 0.0, str(gold1))
	var r2: Dictionary = inv.salvage(uid)
	ck("second salvage of same uid refused", not r2.get("ok", true) and str(r2.get("reason")) == "unknown", str(r2))
	ck("no gold on second attempt", float(r2.get("gold_awarded", 0.0)) == 0.0, str(r2.get("gold_awarded")))

	# ---------- rapid tapping cannot double-salvage ----------
	var inv2 = INV.new()
	inv2.max_stage_reached = 999
	var uid2: String = inv2.add(common_id)
	var successes: int = 0
	var total_gold: float = 0.0
	for i in range(50):
		var r: Dictionary = inv2.salvage(uid2)
		if r.get("ok", false):
			successes += 1
			total_gold += float(r.get("gold_awarded", 0.0))
	ck("rapid salvage succeeded exactly once", successes == 1, str(successes))
	ck("rapid salvage paid exactly once", is_equal_approx(total_gold, gold1), "%f vs %f" % [total_gold, gold1])

	# ---------- locked items are protected ----------
	var inv3 = INV.new()
	inv3.max_stage_reached = 999
	var uid3: String = inv3.add(common_id)
	inv3.set_locked(uid3, true)
	var rl: Dictionary = inv3.salvage(uid3)
	ck("locked item cannot be salvaged", not rl.get("ok", true) and str(rl.get("reason")) == "locked", str(rl))
	inv3.set_locked(uid3, false)
	ck("unlocking allows salvage again", inv3.salvage(uid3).get("ok", false))

	# ---------- equipped items are protected ----------
	var inv4 = INV.new()
	inv4.max_stage_reached = 999
	var uid4: String = inv4.add(common_id)
	inv4.equip(uid4)
	var re: Dictionary = inv4.salvage(uid4)
	ck("equipped item cannot be salvaged", not re.get("ok", true) and str(re.get("reason")) == "equipped", str(re))

	# ---------- rare+ needs confirmation ----------
	if rare_id != "":
		var inv5 = INV.new()
		inv5.max_stage_reached = 999
		var uid5: String = inv5.add(rare_id)
		var rr: Dictionary = inv5.salvage(uid5)
		ck("rare+ refused without confirmation",
			not rr.get("ok", true) and str(rr.get("reason")) == "needs_confirmation", str(rr))
		ck("item still exists after refusal", inv5.salvage(uid5, true).get("ok", false), "should salvage once confirmed")

	# ---------- favorite needs its own confirmation ----------
	var inv6 = INV.new()
	inv6.max_stage_reached = 999
	var uid6: String = inv6.add(common_id)
	inv6.set_favorite(uid6, true)
	var rf: Dictionary = inv6.salvage(uid6)
	ck("favorite refused without its confirmation",
		not rf.get("ok", true) and str(rf.get("reason")) == "needs_confirmation", str(rf))
	ck("favorite salvages once explicitly confirmed", inv6.salvage(uid6, true, true).get("ok", false))

	# ---------- wrong slot cannot be equipped ----------
	var inv7 = INV.new()
	inv7.max_stage_reached = 999
	var weapon_uid: String = ""
	var head_uid: String = ""
	for it: Variant in items:
		var d: Dictionary = it
		if str(d.get("slot")) == "weapon" and weapon_uid == "": weapon_uid = inv7.add(str(d.get("id")))
		if str(d.get("slot")) == "head" and head_uid == "": head_uid = inv7.add(str(d.get("id")))
	if weapon_uid != "" and head_uid != "":
		ck("weapon equips into weapon slot", inv7.equip(weapon_uid))
		ck("equipping head does not evict the weapon", inv7.equip(head_uid) and inv7.is_equipped(weapon_uid),
			"both slots should hold their own item")

	# ---------- malformed / unknown data is rejected safely ----------
	var inv8 = INV.new()
	inv8.max_stage_reached = 999
	ck("unknown item id rejected", inv8.add("no_such_item_zzz") == "")
	ck("salvaging unknown uid is safe", not inv8.salvage("not_a_uid").get("ok", true))
	inv8.from_dict({"owned": "not_a_dictionary", "equipped": 12345})
	ck("malformed save does not crash", true)

	# ---------- persistence round trip ----------
	var inv9 = INV.new()
	inv9.max_stage_reached = 999
	var a: String = inv9.add(common_id)
	inv9.set_locked(a, true); inv9.set_favorite(a, true); inv9.equip(a)
	var snap: Dictionary = inv9.to_dict()
	var inv10 = INV.new()
	inv10.max_stage_reached = 999
	inv10.from_dict(snap)
	ck("locked survived round trip", inv10.is_locked(a), str(inv10.is_locked(a)))
	ck("favorite survived round trip", inv10.is_favorite(a))
	ck("equipped survived round trip", inv10.is_equipped(a))

	print("INVENTORY ADVERSARIAL: FAIL %d" % failed if failed > 0 else "INVENTORY ADVERSARIAL: all passed")
	quit(1 if failed > 0 else 0)
