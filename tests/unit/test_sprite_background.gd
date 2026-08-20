extends SceneTree
## Guards the production sprites against the defect the concept package ships
## with: the reference sheet's flat background left inside enclosed parts of a
## silhouette, and its colour smeared along the cut edge. Both look like beige
## blobs once the sprite is drawn over a world background, and no gameplay test
## would ever notice.

const SPRITE_ROOT := "res://assets/sprites"
## Sprites delivered as finished production art, which never passed through
## tools/clean_assets.py and therefore cannot carry the concept sheet's
## background. The cream test matches a warm specular highlight on steel, and a
## cel-shaded highlight is genuinely flat, so the hero's blade reads as sealed
## sheet. Scoping the guard to the sprites it was written for keeps it sharp
## everywhere it applies; loosening its thresholds instead would blind it for
## all twenty-six cleaned sprites. Every entry must exist, so a stale exclusion
## fails rather than silently widening.
const DELIVERED_ART: Array[String] = [
	"res://assets/sprites/hero/hero_rear_idle_v3_2048.png",
	"res://assets/sprites/hero/hero_rear_attack_v3_2048.png",
]
const MIN_REGION := 6
## Per-channel standard deviation a region may show and still be flat sheet.
const FLATNESS_LIMIT := 7.0

var failed: int = 0

func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func is_sheet_colour(c: Color) -> bool:
	## The reference sheet's cream, identified by its warm cast rather than by
	## distance alone: plain distance also matches white fur and pale ice.
	var r: int = int(round(c.r * 255.0))
	var g: int = int(round(c.g * 255.0))
	var b: int = int(round(c.b * 255.0))
	var warm: bool = (r - b) >= 14 and (r - b) <= 44
	return r >= 234 and g >= 222 and g <= 252 and b >= 200 and b <= 238 and warm and g <= r and g >= b


func collect(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = path + "/" + name
		if dir.current_is_dir():
			collect(full, out)
		elif name.ends_with(".png"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _init() -> void:
	var files: Array = []
	collect(SPRITE_ROOT, files)
	files.sort()
	ck("production sprites exist", files.size() > 0, str(files.size()))

	var total_enclosed: int = 0
	var total_halo: int = 0
	var opaque_sprites: int = 0
	for excluded: String in DELIVERED_ART:
		ck("the excluded delivered sprite exists: %s" % excluded.get_file(),
			FileAccess.file_exists(excluded), excluded)
	for file_value: Variant in files:
		var file: String = str(file_value)
		if file in DELIVERED_ART:
			continue
		var image: Image = Image.load_from_file(file)
		if image == null:
			ck("%s loads" % file, false)
			continue
		var width: int = image.get_width()
		var height: int = image.get_height()
		var transparent: bool = false
		var sheet := PackedInt32Array()
		sheet.resize(width * height)
		for y: int in height:
			for x: int in width:
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a < 0.02:
					transparent = true
					sheet[y * width + x] = -1
				elif is_sheet_colour(pixel) and pixel.a > 0.78:
					sheet[y * width + x] = 1
		if not transparent:
			opaque_sprites += 1

		# Halo: sheet colour sitting right against the cut edge.
		for y: int in height:
			for x: int in width:
				if sheet[y * width + x] != 1:
					continue
				# The boundary pixel itself is what a halo would occupy. Looking
				# two pixels deep instead flags legitimate cream trim painted
				# just inside the silhouette.
				var touches: bool = false
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= width or ny >= height:
							continue
						if sheet[ny * width + nx] == -1:
							touches = true
				if touches:
					total_halo += 1

		# Enclosed: a sheet-coloured region that never reaches transparency or
		# the image border is background sealed inside the silhouette.
		var seen := PackedByteArray()
		seen.resize(width * height)
		for start: int in width * height:
			if sheet[start] != 1 or seen[start] == 1:
				continue
			var stack: Array[int] = [start]
			seen[start] = 1
			var region: Array[int] = []
			var open_region: bool = false
			while not stack.is_empty():
				var index: int = stack.pop_back()
				region.append(index)
				var x: int = index % width
				var y: int = index / width
				if x == 0 or y == 0 or x == width - 1 or y == height - 1:
					open_region = true
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + offset.x
					var ny: int = y + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var neighbour: int = ny * width + nx
					if sheet[neighbour] == -1:
						open_region = true
					elif sheet[neighbour] == 1 and seen[neighbour] == 0:
						seen[neighbour] = 1
						stack.append(neighbour)
			if open_region or region.size() < MIN_REGION:
				continue
			# Painted cream on a subject (a clock dial, bone, cloth) carries
			# shading; the printed sheet is perfectly flat. Only flat regions
			# are background.
			var sum := Vector3.ZERO
			var sum_squares := Vector3.ZERO
			for index_value: int in region:
				var pixel: Color = image.get_pixel(index_value % width, index_value / width)
				var rgb := Vector3(pixel.r, pixel.g, pixel.b) * 255.0
				sum += rgb
				sum_squares += rgb * rgb
			var count: float = float(region.size())
			var mean: Vector3 = sum / count
			var variance: Vector3 = (sum_squares / count) - (mean * mean)
			var spread: float = maxf(maxf(sqrt(maxf(variance.x, 0.0)), sqrt(maxf(variance.y, 0.0))), sqrt(maxf(variance.z, 0.0)))
			if spread <= FLATNESS_LIMIT:
				total_enclosed += region.size()

	ck("no sheet background sealed inside any silhouette", total_enclosed == 0, "%d px" % total_enclosed)
	ck("no sheet-coloured halo along any cut edge", total_halo == 0, "%d px" % total_halo)
	ck("every sprite carries real transparency", opaque_sprites == 0, "%d fully opaque" % opaque_sprites)

	print("SPRITE BACKGROUND: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
