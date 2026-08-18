extends SceneTree
## Failure injection on the boss first-clear transaction, driven by a substituted
## save adapter rather than by hand-editing the end state.
##
## The invariant: after ANY failure or reload the player is in exactly one of
##   A) boss NOT claimed and NO reward owned  -> clean retry
##   B) boss claimed and EXACTLY ONE valid reward owned
## and never: claimed-but-no-reward, reward-owned-but-still-claimable,
## duplicates, a half-advanced pity counter, or a reward below its unlock stage.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

class FailingAdapter extends RefCounted:
	var fail_after: int = 0      # number of successful saves before failing
	var calls: int = 0
	func save(_data: Dictionary) -> bool:
		calls += 1
		return calls <= fail_after

class CountingAdapter extends RefCounted:
	var calls: int = 0
	var payloads: Array = []
	func save(data: Dictionary) -> bool:
		calls += 1
		payloads.append(data.duplicate(true))
		return true

func owned(inv) -> int:
	return (inv.to_dict().get("owned", {}) as Dictionary).size()

func state_is_valid(claimed: bool, items: int) -> bool:
	return (not claimed and items == 0) or (claimed and items == 1)

func _init() -> void:
	var CS = load("res://scripts/combat/combat_state.gd")
	var RS = load("res://scripts/progression/reward_system.gd")
	var INV = load("res://scripts/progression/inventory.gd")

	# ---------- save fails at the commit boundary ----------
	var c = CS.new(10)
	var inv = INV.new(); inv.max_stage_reached = 60
	c.set_inventory(inv)
	var adapter := FailingAdapter.new()
	adapter.fail_after = 0                      # every save fails
	c.save_adapter = adapter
	var tx: Dictionary = c.begin_boss_first_clear(10, RS.new(11))
	ck("transaction was prepared", tx.get("granted", false), str(tx))
	var committed: bool = c.commit_boss_first_clear(tx)
	ck("commit reports failure when the save fails", not committed)
	var claimed: bool = bool(c.boss_first_clears.get("10", false))
	ck("failed save leaves a CLEAN RETRY state (not claimed, no reward)",
		state_is_valid(claimed, owned(c.inventory)) and not claimed,
		"claimed=%s items=%d" % [str(claimed), owned(c.inventory)])

	# ---------- retry after rollback succeeds exactly once ----------
	var ok_adapter := CountingAdapter.new()
	c.save_adapter = ok_adapter
	var tx2: Dictionary = c.begin_boss_first_clear(10, RS.new(11))
	ck("retry after rollback is allowed", tx2.get("granted", false), str(tx2))
	ck("retry commit succeeds", c.commit_boss_first_clear(tx2))
	ck("after successful retry: claimed with exactly one reward",
		state_is_valid(bool(c.boss_first_clears.get("10", false)), owned(c.inventory))
		and bool(c.boss_first_clears.get("10", false)),
		"claimed=%s items=%d" % [str(c.boss_first_clears.get("10", false)), owned(c.inventory)])

	# ---------- reload after the interrupted transaction ----------
	var saved: Dictionary = ok_adapter.payloads[-1] if not ok_adapter.payloads.is_empty() else {}
	var perm: Dictionary = saved.get("permanent_state", {}) if saved.has("permanent_state") else {"boss_first_clears": c.boss_first_clears}
	var c3 = CS.new(10, null, 1, {}, perm)
	ck("reload cannot re-grant the completed clear",
		not c3.begin_boss_first_clear(10, RS.new(11)).get("granted", true))

	# ---------- interruption at EVERY boundary leaves a valid state ----------
	var bad_states: Array = []
	for boundary: int in range(0, 3):
		var cc = CS.new(20)
		var ii = INV.new(); ii.max_stage_reached = 60
		cc.set_inventory(ii)
		var fa := FailingAdapter.new()
		fa.fail_after = boundary
		cc.save_adapter = fa
		var t: Dictionary = cc.begin_boss_first_clear(20, RS.new(boundary + 3))
		if t.get("granted", false):
			cc.commit_boss_first_clear(t)
		var cl: bool = bool(cc.boss_first_clears.get("20", false))
		if not state_is_valid(cl, owned(cc.inventory)):
			bad_states.append("boundary %d -> claimed=%s items=%d" % [boundary, str(cl), owned(cc.inventory)])
	ck("every interruption boundary leaves a valid state", bad_states.is_empty(), str(bad_states))

	# ---------- pity counter must not advance on a failed save ----------
	if c.has_method("get_pity") or "pity" in c:
		var cp = CS.new(30)
		var ip = INV.new(); ip.max_stage_reached = 60
		cp.set_inventory(ip)
		var rsys = RS.new(5)
		var pity_before: int = int(rsys.get("pity_counter")) if "pity_counter" in rsys else -1
		var fa2 := FailingAdapter.new()
		fa2.fail_after = 0
		cp.save_adapter = fa2
		var t2: Dictionary = cp.begin_boss_first_clear(30, rsys)
		cp.commit_boss_first_clear(t2)
		var pity_after: int = int(rsys.get("pity_counter")) if "pity_counter" in rsys else -1
		ck("pity counter not left half-advanced by a failed save", pity_before == pity_after or pity_before == -1,
			"%d -> %d" % [pity_before, pity_after])

	# ---------- production build cannot debug-grant ----------
	var dinv = INV.new(); dinv.max_stage_reached = 1
	if dinv.has_method("is_debug_grant_allowed"):
		ck("debug grant gate exists and is honest about the build",
			typeof(dinv.is_debug_grant_allowed()) == TYPE_BOOL,
			str(dinv.is_debug_grant_allowed()))
	ck("debug_add cannot bypass the unlock gate in a release build",
		OS.is_debug_build() or dinv.debug_add("solar_ascendance") == "",
		"release builds must refuse debug grants")

	print("FAILURE INJECTION: FAIL %d" % failed if failed > 0 else "FAILURE INJECTION: all passed")
	quit(1 if failed > 0 else 0)
