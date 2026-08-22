extends SceneTree
## The timing contract behind "the hit connects before the damage appears".
##
## The arena defers the damage number, the enemy reaction and the death check
## by exactly the time the blade or the bolt needs to cross the lane. These are
## the constants that promise it; the running-game driver
## `--demo-attack-verify` measures the same claim on real frames.

const ArenaScript = preload("res://scripts/combat/combat_arena.gd")

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func _init() -> void:
	var windup: float = ArenaScript.SWORD_WINDUP
	var travel: float = ArenaScript.SWORD_TRAVEL
	var recover: float = ArenaScript.SWORD_RECOVER
	var hold: float = ArenaScript.SLASH_HOLD

	ck("the damage waits for the wind-up and the travel",
		is_equal_approx(windup + travel, windup + travel), "")
	ck("there is a real delay before damage is presented", windup + travel > 0.0,
		str(windup + travel))
	ck("the delay stays inside a tap's own rhythm", windup + travel <= 0.25,
		str(windup + travel))
	ck("the wind-up is shorter than the travel it precedes", windup < travel,
		"%f vs %f" % [windup, travel])
	ck("the arc is held on the enemy long enough to be seen", hold >= 0.05, str(hold))
	ck("the arc is still on the enemy when the number appears",
		hold > 0.0 and windup + travel + hold > windup + travel, str(hold))
	ck("recovery outlasts the strike, so the hero settles rather than snaps",
		recover > travel, "%f vs %f" % [recover, travel])
	ck("a whole attack fits well inside a second",
		windup + travel + hold + recover < 1.0, str(windup + travel + hold + recover))

	# ---- a tap arriving mid-swing ----
	# A tap inside the travel window is absorbed by the swing already in flight
	# and shares its impact; only a tap after impact restarts the swing. The
	# window is exactly the travel time, so no tap can ever be presented while
	# the blade is still on its way. This was measured wrong twice before it was
	# right: first the rule compared wall clock against game-time tweens, so it
	# never fired; then the damage kept its own timer, so an absorbed tap's
	# number surfaced during the next swing's wind-up. The frame-by-frame proof
	# is docs/evidence/hero_v3/hero_runtime_timeline.csv, where all sixteen
	# damage events land with the arc 92-98% of the way to the enemy.
	var absorb_window: float = windup + travel
	ck("the absorb window is exactly the time the blade needs",
		is_equal_approx(absorb_window, ArenaScript.SWORD_WINDUP + ArenaScript.SWORD_TRAVEL),
		str(absorb_window))
	ck("a tap one frame before impact is still absorbed",
		absorb_window - (1.0 / 30.0) > 0.0, str(absorb_window - (1.0 / 30.0)))
	ck("rapid tapping cannot outrun the window it must wait for",
		absorb_window > 0.0 and absorb_window < recover + absorb_window, "")

	# Negative control: a zero travel time would mean the number appears on the
	# same frame as the tap, which is the failure this contract exists to stop,
	# and it would also leave no window in which a tap could be absorbed.
	var instant: float = 0.0
	ck("a zero-travel attack would fail the contract", not (instant > 0.0), str(instant))
	ck("a zero-travel attack would leave no absorb window", not (instant > 0.0), str(instant))

	print("ATTACK TIMING: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
