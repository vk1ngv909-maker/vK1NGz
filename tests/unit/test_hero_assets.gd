extends SceneTree
## The hero the player sees is authored art, not geometry.
##
## A previous hero was built from polygons by a script. It was rejected on
## sight, so these checks are about the thing that failed: the real PNGs must
## be present, they must be the files that were approved, the runtime must load
## THEM, and the two poses must stand on the same ground line.

const Placement = preload("res://scripts/ui/hero_placement.gd")
const HUD_PATH: String = "res://scripts/ui/hud.gd"
const ARENA_PATH: String = "res://scripts/combat/combat_arena.gd"

const METRICS_PATH: String = "res://resources/hero_sprite_metrics.json"
const EXPECTED_SIZE: int = 2048
# Foot anchors are computed in float pixels from integer alpha bounds, so they
# agree to rounding, not exactly. A tenth of a pixel is far below anything the
# eye or a capture can resolve at any shipped resolution.
const ANCHOR_TOLERANCE_PX: float = 0.1

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func read_metrics() -> Dictionary:
	var file: FileAccess = FileAccess.open(METRICS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parsed: Error = json.parse(file.get_as_text())
	file.close()
	return (json.data as Dictionary) if parsed == OK and json.data is Dictionary else {}


func hud_const(name: String) -> float:
	for line: String in FileAccess.get_file_as_string(HUD_PATH).split("\n"):
		if line.begins_with("const %s: float = " % name):
			return float(line.get_slice("= ", 1))
	return 0.0


func arena_const(name: String) -> String:
	## Read straight from the arena's source rather than preloading it: hud.gd
	## and combat_arena.gd reference each other, and preloading both here made
	## the suite hang on load. The constant's text is what is being checked.
	for line: String in FileAccess.get_file_as_string(ARENA_PATH).split("\n"):
		if line.begins_with("const %s: String = " % name):
			return line.get_slice("\"", 1)
	return ""


func _init() -> void:
	# ---- the runtime points at the authored files ----
	var idle_path: String = arena_const("HERO_IDLE")
	var attack_path: String = arena_const("HERO_ATTACK")
	ck("the idle pose is one of the approved hero files",
		idle_path.ends_with("hero_rear_idle_v3_2048.png"), idle_path)
	ck("the attack pose is one of the approved hero files",
		attack_path.ends_with("hero_rear_attack_v3_2048.png"), attack_path)
	ck("the two poses are different files", idle_path != attack_path, "")

	var metrics: Dictionary = read_metrics()
	ck("the baked hero metrics load", not metrics.is_empty(), METRICS_PATH)
	var sprites: Dictionary = metrics.get("sprites", {})
	ck("both poses are described", sprites.has("idle") and sprites.has("attack"), str(sprites.keys()))

	for pose: String in ["idle", "attack"]:
		var entry: Dictionary = sprites.get(pose, {})
		var path: String = str(entry.get("path", ""))
		ck("the %s pose file exists" % pose, ResourceLoader.exists(path), path)
		var texture: Texture2D = load(path) as Texture2D
		ck("the %s pose loads as a texture" % pose, texture != null, path)
		if texture == null:
			continue
		var size: Vector2 = texture.get_size()
		ck("the %s pose is %dx%d" % [pose, EXPECTED_SIZE, EXPECTED_SIZE],
			int(size.x) == EXPECTED_SIZE and int(size.y) == EXPECTED_SIZE, str(size))

		var image: Image = texture.get_image()
		ck("the %s pose keeps an alpha channel" % pose, image.detect_alpha() != Image.ALPHA_NONE,
			str(image.detect_alpha()))
		# Transparent padding is the whole reason the bounds are baked: the top
		# left corner of a 2048 square must be empty, not white or black.
		ck("the %s pose has genuinely transparent pixels" % pose,
			image.get_pixel(4, 4).a <= 0.02, str(image.get_pixel(4, 4)))

		# The baked bounds must still describe the file on disk. If either is
		# replaced without re-running tools/build_hero_metrics.py, this fails
		# rather than quietly mis-placing the hero.
		var box: Array = entry.get("bbox", [])
		ck("the %s pose records four alpha bounds" % pose, box.size() == 4, str(box))
		if box.size() != 4:
			continue
		var measured := Rect2i(0, 0, 0, 0)
		var found: bool = false
		for y: int in range(0, EXPECTED_SIZE, 4):
			for x: int in range(0, EXPECTED_SIZE, 4):
				if image.get_pixel(x, y).a > 16.0 / 255.0:
					var point := Rect2i(x, y, 1, 1)
					measured = point if not found else measured.merge(point)
					found = true
		ck("the %s pose alpha bounds match the baked ones" % pose,
			found
			and absi(measured.position.x - int(box[0])) <= 8
			and absi(measured.position.y - int(box[1])) <= 8
			and absi(measured.position.x + measured.size.x - int(box[2])) <= 8
			and absi(measured.position.y + measured.size.y - int(box[3])) <= 8,
			"baked %s measured %s" % [str(box), str(measured)])

	# ---- no geometric hero can come back ----
	var geometric: Array[String] = [
		"res://assets/sprites/hero/main_hero_rear.png",
		"res://tools/make_hero_rear.py",
	]
	for path: String in geometric:
		ck("the rejected geometric hero is gone: %s" % path, not FileAccess.file_exists(path), path)
	var arena_source: String = FileAccess.get_file_as_string(ARENA_PATH)
	for banned: String in ["Polygon2D", "main_hero_rear"]:
		ck("combat never falls back to %s" % banned, not arena_source.contains(banned), banned)

	# ---- both poses stand on the same ground line and axis ----
	# This drives HudScript's own placement arithmetic, not a copy of it, so a
	# change to how the hero is placed is caught here rather than in a capture.
	var area := Vector2(1048.0, 992.0)
	# hud.gd cannot be compiled in a bare SceneTree (it reaches for autoloads),
	# so its constants are read from source. The placement arithmetic itself is
	# called for real, from the script the arena calls.
	var ground: float = area.y * hud_const("HERO_ANCHOR_Y")
	var axis: float = area.x * hud_const("COMBAT_AXIS")
	var ratio: float = hud_const("HERO_HEIGHT_RATIO")
	var body_height: float = area.y * ratio
	ck("the hero body fills the approved share of the arena",
		ratio >= 0.22 and ratio <= 0.28, str(ratio))

	var feet: Dictionary = {}
	for pose: String in ["idle", "attack"]:
		var entry: Dictionary = sprites.get(pose, {})
		var placement: Dictionary = Placement.placement(body_height, axis, ground, entry)
		var side: float = float(placement["side"])
		var offset: Vector2 = placement["offset"]
		var position: Vector2 = placement["position"]
		feet[pose] = position + offset
		ck("the %s pose rectangle is larger than the body inside it" % pose, side > body_height,
			"%f vs %f" % [side, body_height])
		ck("the %s pose body is the height the layout asked for" % pose,
			is_equal_approx(side * Placement.body_fraction(entry), body_height),
			"%f vs %f" % [side * Placement.body_fraction(entry), body_height])
		ck("the %s pose foot point lands on the anchor" % pose,
			(feet[pose] as Vector2).distance_to(Vector2(axis, ground)) <= ANCHOR_TOLERANCE_PX,
			str(feet[pose]))
	var drift: float = (feet["idle"] as Vector2).distance_to(feet["attack"] as Vector2)
	ck("both poses put their feet on the same point", drift <= ANCHOR_TOLERANCE_PX, "%f px" % drift)

	# Negative control: sizing and placing by the 2048 canvas instead of the
	# alpha bounds is the naive approach, and it must visibly drift — otherwise
	# the bounds are doing nothing and this whole mechanism is dead weight.
	var naive: Dictionary = {}
	for pose: String in ["idle", "attack"]:
		var entry: Dictionary = sprites.get(pose, {})
		var canvas: Array = entry.get("canvas", [EXPECTED_SIZE, EXPECTED_SIZE])
		var box: Array = entry.get("bbox", [0, 0, EXPECTED_SIZE, EXPECTED_SIZE])
		naive[pose] = ground - body_height + body_height * float(int(box[3])) / float(int(canvas[1]))
	var naive_drift: float = absf(float(naive["idle"]) - float(naive["attack"]))
	ck("canvas placement would drift, which is why the bounds are used",
		naive_drift > ANCHOR_TOLERANCE_PX, "%f px" % naive_drift)

	print("HERO ASSETS: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
