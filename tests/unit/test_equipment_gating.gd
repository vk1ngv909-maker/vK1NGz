extends SceneTree
## Proves the invariant that was previously only ASSERTED: legendary equipment
## cannot be obtained before the first Prestige. Earlier this was claimed with
## no mechanism behind it — there was no drop system and no unlock gate at all.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var INV = load("res://scripts/progression/inventory.gd")
	var raw: Variant = JSON.parse_string(FileAccess.open("res://resources/equipment/equipment.json", FileAccess.READ).get_as_text())
	var items: Array = raw if raw is Array else (raw as Dictionary).get("equipment", [])

	# --- every item must declare an unlock stage ---
	var missing: Array = []
	for it: Variant in items:
		if not (it as Dictionary).has("unlock_stage"):
			missing.append(str((it as Dictionary).get("id")))
	ck("every equipment item declares unlock_stage", missing.is_empty(), str(missing))

	# --- rarity ordering must be monotonic: rarer gear unlocks no earlier ---
	var order := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
	var min_by_rarity := {}
	for it: Variant in items:
		var d: Dictionary = it
		var r: String = str(d["rarity"])
		var u: int = int(d["unlock_stage"])
		min_by_rarity[r] = u if not min_by_rarity.has(r) else mini(int(min_by_rarity[r]), u)
	var prev: int = -1
	var monotonic: bool = true
	for r: String in ["common", "rare", "epic", "legendary"]:
		var u: int = int(min_by_rarity.get(r, 1))
		if u < prev: monotonic = false
		prev = u
	ck("unlock stages never decrease as rarity rises", monotonic, str(min_by_rarity))

	# --- THE INVARIANT: legendary is gated past the first-Prestige stage (25) ---
	var legendary_min: int = int(min_by_rarity.get("legendary", 1))
	ck("legendary unlocks strictly after the first Prestige stage (25)",
		legendary_min > 25, "legendary unlocks at %d" % legendary_min)

	# --- a fresh player literally cannot acquire one ---
	var inv = INV.new()
	inv.max_stage_reached = 1
	var legendary_id: String = ""
	for it: Variant in items:
		if str((it as Dictionary)["rarity"]) == "legendary":
			legendary_id = str((it as Dictionary)["id"]); break
	ck("fresh player cannot add legendary equipment", inv.add(legendary_id) == "", "add() must refuse")
	ck("fresh player CAN add common equipment", inv.add(str((items[0] as Dictionary)["id"])) != "")

	# --- still refused right up to the first Prestige ---
	inv.max_stage_reached = 25
	ck("still refused at stage 25 (first Prestige)", inv.add(legendary_id) == "")
	inv.max_stage_reached = 50
	ck("allowed once the unlock stage is reached", inv.add(legendary_id) != "")

	# --- a corrupt save cannot smuggle one in ---
	var inv2 = INV.new()
	inv2.max_stage_reached = 1
	inv2.from_dict({"owned": {"hacked": {"item_id": legendary_id, "locked": false, "favorite": false}}, "equipped": {}})
	var owned_ids: Array = []
	for uid: Variant in inv2.to_dict().get("owned", {}):
		owned_ids.append(str((inv2.to_dict()["owned"][uid] as Dictionary).get("item_id", "")))
	ck("locked-rarity item from a save is not usable by a fresh player",
		not owned_ids.has(legendary_id) or inv2.max_stage_reached >= 50,
		"owned=%s" % str(owned_ids))

	print("EQUIPMENT GATING: FAIL %d" % failed if failed > 0 else "EQUIPMENT GATING: all passed")
	quit(1 if failed > 0 else 0)
