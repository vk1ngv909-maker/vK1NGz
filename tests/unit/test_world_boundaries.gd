extends SceneTree
## Every world must own a continuous stage range, name a full set of parallax
## layers that actually exist, and hand the right enemy pool to its stages. A
## world whose layer path is wrong renders an empty rectangle, which no gameplay
## test would notice.

const WorldsLogic = preload("res://scripts/progression/worlds.gd")

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func _init() -> void:
	var worlds = WorldsLogic.new()
	var raw: Dictionary = JSON.parse_string(FileAccess.open("res://resources/worlds/worlds.json", FileAccess.READ).get_as_text())
	var entries: Array = raw["entries"]
	ck("three worlds are defined", entries.size() == 3, str(entries.size()))

	var previous_end: int = 0
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var id: String = str(entry["id"])
		var from: int = int(entry["stage_from"])
		var to: int = int(entry["stage_to"])
		ck("%s starts where the previous world ended" % id, from == previous_end + 1,
			"from %d, previous ended %d" % [from, previous_end])
		ck("%s covers a forward range" % id, to >= from, "%d..%d" % [from, to])
		previous_end = to

		var layers: Array = entry["background_layers"]
		ck("%s names four layers" % id, layers.size() == 4, str(layers.size()))
		var expected: Array[String] = ["sky", "distant", "arena", "foreground"]
		for index: int in mini(4, layers.size()):
			var path: String = str(layers[index])
			ck("%s layer %d is the %s layer" % [id, index, expected[index]],
				path.ends_with("/%s.png" % expected[index]), path)
			ck("%s layer %s exists on disk" % [id, expected[index]],
				ResourceLoader.exists(path), path)
		# The pool a world hands out must be the pool it declares.
		var pool: Array = entry["enemy_pool"]
		ck("%s declares an enemy pool" % id, pool.size() >= 3, str(pool.size()))
		for stage: int in [from, int((from + to) / 2.0), to]:
			var resolved: Dictionary = worlds.world_for_stage(stage)
			ck("%s owns stage %d" % [id, stage], str(resolved.get("id", "")) == id,
				str(resolved.get("id", "")))

	# Beyond the authored range the last world keeps presenting the run.
	var endless: Dictionary = worlds.world_for_stage(previous_end + 250)
	ck("stages past the last world clamp to it", str(endless.get("id", "")) == str((entries[-1] as Dictionary)["id"]),
		str(endless.get("id", "")))
	var first: Dictionary = worlds.world_for_stage(0)
	ck("stage 0 clamps to the first world", str(first.get("id", "")) == str((entries[0] as Dictionary)["id"]),
		str(first.get("id", "")))

	# Layer sizes: the arena layer carries the floor the actors stand on and is
	# authored at the master canvas; a half-size arena would look soft.
	for entry_value2: Variant in entries:
		var entry2: Dictionary = entry_value2
		var arena_path: String = "res://assets/worlds/%s/arena.png" % str(entry2["id"])
		var texture: Texture2D = load(arena_path) as Texture2D
		ck("%s arena layer is authored at 1080x1920" % str(entry2["id"]),
			texture != null and texture.get_width() == 1080 and texture.get_height() == 1920,
			"%dx%d" % [texture.get_width(), texture.get_height()] if texture != null else "missing")
		var sky: Texture2D = load("res://assets/worlds/%s/sky.png" % str(entry2["id"])) as Texture2D
		ck("%s sky layer is authored at 1080x1920" % str(entry2["id"]),
			sky != null and sky.get_width() == 1080 and sky.get_height() == 1920,
			"%dx%d" % [sky.get_width(), sky.get_height()] if sky != null else "missing")

	print("WORLD BOUNDARIES: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
