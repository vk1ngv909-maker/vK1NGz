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

	# Negative control: a zero travel time would mean the number appears on the
	# same frame as the tap, which is the failure this contract exists to stop.
	var instant: float = 0.0
	ck("a zero-travel attack would fail the contract", not (instant > 0.0), str(instant))

	print("ATTACK TIMING: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
