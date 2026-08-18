extends SceneTree

const WorldsLogic = preload("res://scripts/progression/worlds.gd")

var failed: int = 0


func _init() -> void:
	var worlds: Worlds = WorldsLogic.new()
	_check(str(worlds.world_for_stage(1).get("id", "")) == "oasis_frontier", "stage 1 uses Oasis Frontier")
	_check(str(worlds.world_for_stage(33).get("id", "")) == "oasis_frontier", "stage 33 stays in world 1")
	_check(str(worlds.world_for_stage(34).get("id", "")) == "moonlit_dunes", "stage 34 crosses into world 2")
	_check(str(worlds.world_for_stage(66).get("id", "")) == "moonlit_dunes", "stage 66 stays in world 2")
	_check(str(worlds.world_for_stage(67).get("id", "")) == "ruins_of_the_sun_kingdom", "stage 67 crosses into world 3")
	_check(str(worlds.world_for_stage(100).get("id", "")) == "ruins_of_the_sun_kingdom", "stage 100 is authored")
	_check(str(worlds.world_for_stage(101).get("id", "")) == "ruins_of_the_sun_kingdom", "endless stages clamp to final world")
	var colors: Dictionary = {}
	for stage: int in [1, 34, 67]:
		colors[str((worlds.world_for_stage(stage).get("palette", {}) as Dictionary).get("sand", ""))] = true
	_check(colors.size() == 3, "all three worlds have visibly distinct palettes")
	print("WORLDS: FAIL %d" % failed if failed > 0 else "WORLDS: all passed")
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)
